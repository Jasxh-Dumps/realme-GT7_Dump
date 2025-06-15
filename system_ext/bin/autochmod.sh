#! /system/bin/sh

CURTIME=`date +%F_%H-%M-%S`
CURTIME_FORMAT=`date "+%Y-%m-%d %H:%M:%S"`

DEFAULT_LOG_BASE_PATH=/sdcard/Android/data/com.oplus.olc/files/Log
SDCARD_LOG_BASE_PATH=`getprop persist.sys.olc.log.path ${DEFAULT_LOG_BASE_PATH}`
BASE_PATH=$(dirname $(dirname ${SDCARD_LOG_BASE_PATH}))
SDCARD_LOG_TRIGGER_PATH=${BASE_PATH}/trigger

DATA_DEBUGGING_PATH=/data/debugging
DATA_OPLUS_LOG_PATH=/data/persist_log
ANR_BINDER_PATH=${DATA_DEBUGGING_PATH}/anr_binder_info
CACHE_PATH=${DATA_DEBUGGING_PATH}/cache

MTK_DEBUG_PATH=/data/debuglogger

config="$1"

# change defalut permissions of folder created by current user
umask 007
function bugreportandtransfer() {
    local SOURCE_PATH=/data/user_de/0/com.android.shell/files/bugreports
    local DESTINATION_PATH=/data/oplus/psw/powermonitor
    traceTransferState "capture bugreport start"
    bugreportz
    traceTransferState "capture bugreport end"
    if [ -d "${SOURCE_PATH}" ]; then
        mkdir -p "${DESTINATION_PATH}/bugreports"
        local file_count=3
        local latest_files=$(find "$SOURCE_PATH" -maxdepth 1 -type f -printf '%T@ %p\n' | sort -nk 1 -r | head -n "$file_count" | cut -d' ' -f2-)
        for file in $latest_files; do
            cp "$file" "${DESTINATION_PATH}/bugreports"
            traceTransferState "copy $file to dir /data/oplus/psw/powermonitor/bugreports"
        done
    fi
}

function backup_unboot_log() {
    CACHE_EMPTY=`ls ${CACHE_PATH} | wc -l`
    if [ "${CACHE_EMPTY}" == "0" ];then
        return
    fi

    CACHE_PATH_FILES=`ls ${CACHE_PATH}/*`
    if [ "${CACHE_PATH_FILES}" = "" ];then
        traceTransferState "CACHE_PATH is empty"
    else
        traceTransferState "mv ${CACHE_PATH} TO ${DATA_DEBUGGING_PATH}/unboot"
        mv ${CACHE_PATH} ${DATA_DEBUGGING_PATH}/unboot
    fi
}

function kpoc_initcache() {
    CACHE_DIR="/data/debugging/cache"
    traceTransferState "initcache..."
    BOOT_MODE=`getprop sys.oplus_boot_mode`
    if [ x"${BOOT_MODE}" = x"ftm_at" ]; then
        traceTransferState "bootMode:${BOOT_MODE}, return!!!"
        setprop sys.oplus.kpoc.start false
        return
    fi

    if [ ! -d "${CACHGE_DIR}" ];then
        mkdir -p ${CACHE_DIR}
        if [ ! -d "${CACHE_DIR}" ];then
            traceTransferState "path_creat_failed!!!"
            setprop sys.oplus.kpoc.start creat_path_failed
            return
        fi
        if test ! -r /data/debugging/cache -o ! -w /data/debugging/cache;then
            echo "miss permission on /data/debugging/cache"
            setprop sys.oplus.kpoc.start permiss_not_allow
        fi
    fi

    if [ ! -d "${CACHE_DIR}/apps" ];then
        mkdir -p ${CACHE_DIR}/apps
    fi

    if [ ! -d "${CACHE_DIR}/kernel" ];then
        mkdir -p ${CACHE_DIR}/kernel
    fi

    chmod -R 777 ${CACHE_DIR}
    setprop sys.oplus.kpoc.start ready
}

function kpoc_collect_log() {
    traceTransferState "kpoc_collect_log: start..."

    BOOT_MODE=`getprop sys.oplus_boot_mode`
    boot_completed=`getprop sys.boot_completed`
    decrypt_delay=0
    bootCompleteCount=0
    while [ x${boot_completed} != x"1" ];do
        bootCompleteCount=$((bootCompleteCount + 1))
        sleep 1
        decrypt_delay=`expr $decrypt_delay + 1`
        boot_completed=`getprop sys.boot_completed`
        if [ bootCompleteCount -ge 5 ] && [ x"${BOOST_MODE}" = x"ftm_at" ]; then
            break
        fi
    done
    traceTransferState "sleep time: ${bootCompleteCount}"

    # get the kpoc log.
    backup_unboot_log

    echo "start mkdir"
    CURTIME_DEBUG_PATH=`getprop persist.sys.com.oplus.debug.time`
    DATA_LOG_DEBUG_PATH=${DATA_DEBUGGING_PATH}/${CURTIME_DEBUG_PATH}
    mkdir -p  ${DATA_LOG_DEBUG_PATH}
    chmod -R 777 ${DATA_LOG_DEBUG_PATH}
    mkdir -p  ${DATA_LOG_DEBUG_PATH}/unboot
    chmod -R 777 ${DATA_LOG_DEBUG_PATH}/unboot

    decrypt='false'
    if [ x"${decrypt}" != x"true" ]; then
        setprop ctl.stop kpoc_kerner_log_cache
        setprop ctl.stop kpoc_mainlog_cache
        setprop ctl.stop kpoc_kms_loop_cache
        traceTransferState "INITOPLUSLOG: mv cache log..."
        mv ${DATA_DEBUGGING_PATH}/unboot/* ${DATA_LOG_DEBUG_PATH}/unboot/
    fi
    traceTransferState "kpoc_collect_log:start debug time: ${CURTIME_DEBUG_PATH}"

    echo "Kpoc logs(such as android.log kernel.log) are kept in" \
        "/common/ or minilog !!!" > ${DATA_LOG_DEBUG_PATH}/00_Android_and_kernel_log_has_been_move_to_aplog_or_minilog
}

function record_dmesg_by_loop() {
    CACHE_DIR="/data/debugging/cache"
    kpoc_initcache
    count=100
    BOOT_MODE=`getprop ro.bootmode`
    if [ x"${BOOT_MODE}" = x"charger" ]; then
        while [ $count -gt 0 ]; do
            echo "$count "
            count=$((count - 1))
            dmesg >> ${CACHE_DIR}/kernel/dmesg_boot_loop.txt
            setprop sys.oplus.kpoc.start looping

            # record the dmesg every 10 mintutes. the default kmsg buffer is 2MB.
            sleep 600
        done
    fi
}

function kpoc_kmsg_loop_cache() {
    kpoc_initcache
    BOOT_MODE=`getprop ro.bootmode`
    if [ x"${BOOT_MODE}" = x"charger" ]; then
        sleep 1
        record_dmesg_by_loop
    fi
}

function kpoc_kernel_log_cache() {
    CACHE_DIR="/data/debugging/cache"
    kpoc_initcache
    BOOT_MODE=`getprop ro.bootmode`
    if [ x"${BOOT_MODE}" = x"charger" ]; then
        setprop sys.oplus.kpoc.start true
        sleep 1
        # get the dmesg which is the kernel boot mesg.
        dmesg > ${CACHE_DIR}/kernel/dmesg_boot.txt

        # get the dmesg until the kpoc is quit. Note: need to enable the logd by config ro.logd.kernel=true
        /system/bin/logcat -b kernel -f ${CACHE_DIR}/kernel/kernel_boot.txt -r 10240 -n 5 -v threadtime -A
    fi
}

function kpoc_mainlog_cache() {
    CACHE_DIR="/data/debugging/cache"
    kpoc_initcache
    BOOT_MODE=`getprop ro.bootmode`
    if [ x"${BOOT_MODE}" = x"charger" ]; then
        sleep 2
        # get the mainlog.
        /system/bin/logcat -b main -b system -b crash -f ${CACHE_DIR}/apps/android_boot.txt -r 10240 -n 5 -v threadtime
    fi
}


#Linjie.Xu@PSW.AD.Power.PowerMonitor.1104067, 2018/01/17, Add for OplusPowerMonitor get dmesg at O
function kernelcacheforopm(){
  opmlogpath=`getprop sys.opm.logpath`
  dmesg > ${opmlogpath}dmesg.txt
  chown system:system ${opmlogpath}dmesg.txt
}

function printMtkSleepState(){
  if test ! -r /dev/conn_dbg_dev -o ! -w /dev/conn_dbg_dev;then
    echo "miss permission on /dev/conn_dbg_dev"
    return
  fi
  echo 40 > /dev/conn_dbg_dev
  cat /dev/conn_dbg_dev
}

#Jianfa.Chen@PSW.AD.PowerMonitor,add for powermonitor getting Xlog
function catchWXlogForOpm() {
  currentDateWXlog=$(date "+%Y%m%d")
  newpath=`getprop sys.opm.logpath`

  XLOG_DIR="/sdcard/Android/data/com.tencent.mm/MicroMsg/xlog"
  CRASH_DIR="/sdcard/Android/data/com.tencent.mm/MicroMsg/crash"

  mkdir -p ${newpath}/wxlog
  chmod 777 -R ${newpath}/wxlog
  #wxlog/xlog
  if [ -d "${XLOG_DIR}" ]; then
    mkdir -p ${newpath}/wxlog/xlog
    ALL_FILE=$(find ${XLOG_DIR} | grep -E ${currentDateWXlog} | xargs ls -t)
    for file in $ALL_FILE; do
      cp $file ${newpath}/wxlog/xlog/
    done
  fi

  if [ -d "${CRASH_DIR}" ];then
    mkdir -p ${newpath}/wxlog/crash
    ALL_FILE = $(find ${XLOG_DIR} | grep -E ${currentDateWXlog} | xargs ls -t)
    for file in $ALL_FILE;do
      cp $file ${newpath}/wxlog/crash
    done
  fi
}

# Qiurun.Zhou@ANDROID.DEBUG, 2022/6/17, copy wxlog for EAP
function eapCopyWXlog() {
  currentDateWXlog=$(date "+%Y%m%d")
  newpath=`getprop sys.opm.logpath`

  XLOG_DIR="/sdcard/Android/data/com.tencent.mm/MicroMsg/xlog"
  CRASH_DIR="/sdcard/Android/data/com.tencent.mm/MicroMsg/crash"

  mkdir -p ${newpath}/wxlog
  chmod 777 -R ${newpath}/wxlog
  #wxlog/xlog
  if [ -d "${XLOG_DIR}" ]; then
    mkdir -p ${newpath}/wxlog/xlog
    ALL_FILE=$(find ${XLOG_DIR} | grep -E ${currentDateWXlog} | xargs ls -t)
    for file in $ALL_FILE; do
      cp $file ${newpath}/wxlog/xlog/
    done
  fi

  if [ -d "${CRASH_DIR}" ]; then
    mkdir -p ${newpath}/wxlog/crash
    ALL_FILE=$(find ${CRASH_DIR} | grep -E ${currentDateWXlog} | xargs ls -t)
    for file in $ALL_FILE; do
      cp $file ${newpath}/wxlog/crash/
    done
  fi
  chown -R system:system ${newpath}
}

# WangMin@ANDROID.RESCONTROL, 2023/05/11, Add for save newest wxlog when wx memleak
function copyWXlogForMemLeak() {
   newpath=`getprop sys.opm.logpath`
   XLOG_DIR="/sdcard/Android/data/com.tencent.mm/MicroMsg/xlog"
   mkdir -p ${newpath}/wxlog
   chmod 777 -R ${newpath}/wxlog
   #wxlog/xlog
   if [ -d "${XLOG_DIR}" ]; then
     mkdir -p ${newpath}/wxlog/xlog
     MM_FILE=$(find ${XLOG_DIR} | grep -E "MM_" | xargs ls -t)
     for file in $MM_FILE; do
       cp $file ${newpath}/wxlog/xlog/
     break
     done

     PUSH_FILE=$(find ${XLOG_DIR} | grep -E "PUSH_" | xargs ls -t)
     for file in $PUSH_FILE; do
       cp $file ${newpath}/wxlog/xlog/
     break
     done

     TOOL_FILE=$(find ${XLOG_DIR} | grep -E "TOOL_" | xargs ls -t)
     for file in $TOOL_FILE; do
       cp $file ${newpath}/wxlog/xlog/
     break
     done

     APPBRAND0_FILE=$(find ${XLOG_DIR} | grep -E "APPBRAND0_" | xargs ls -t)
     for file in $APPBRAND0_FILE; do
       cp $file ${newpath}/wxlog/xlog/
     break
     done

     APPBRAND1_FILE=$(find ${XLOG_DIR} | grep -E "APPBRAND1_" | xargs ls -t)
     for file in $APPBRAND1_FILE; do
       cp $file ${newpath}/wxlog/xlog/
     break
     done

     APPBRAND2_FILE=$(find ${XLOG_DIR} | grep -E "APPBRAND2_" | xargs ls -t)
     for file in $APPBRAND2_FILE; do
       cp $file ${newpath}/wxlog/xlog/
     break
     done

     APPBRAND3_FILE=$(find ${XLOG_DIR} | grep -E "APPBRAND3_" | xargs ls -t)
     for file in $APPBRAND3_FILE; do
       cp $file ${newpath}/wxlog/xlog/
     break
     done

     APPBRAND4_FILE=$(find ${XLOG_DIR} | grep -E "APPBRAND4_" | xargs ls -t)
     for file in $APPBRAND4_FILE; do
       cp $file ${newpath}/wxlog/xlog/
     break
     done

     TP_FILE=$(find ${XLOG_DIR} | grep -E "TP_" | xargs ls -t)
     for file in $TP_FILE; do
       cp $file ${newpath}/wxlog/xlog/
     break
     done
   fi
}

# WangMin@ANDROID.RESCONTROL, 2023/12/13, Add for save newest browser xlog when com.haytap.browser memleak
function copyBrowserXlogForMemLeak() {
   newpath=`getprop sys.opm.logpath`
   XLOG_DIR="/sdcard/Android/data/com.heytap.browser/files/xlog/Browser/.log/xlog"
   mkdir -p ${newpath}/xlog
   chmod 777 -R ${newpath}/xlog
   #wxlog/xlog
   if [ -d "${XLOG_DIR}" ]; then
     KERNEL_FILE=$(find ${XLOG_DIR} | grep -E "Kernel_" | xargs ls -t)
     for file in $KERNEL_FILE; do
       cp $file ${newpath}/xlog/
     break
     done

     MAIN_FILE=$(find ${XLOG_DIR} | grep -E "main_" | xargs ls -t)
     for file in $MAIN_FILE; do
       cp $file ${newpath}/xlog/
     break
     done

     MEDIA_FILE=$(find ${XLOG_DIR} | grep -E "media_" | xargs ls -t)
     for file in $MEDIA_FILE; do
       cp $file ${newpath}/xlog/
     break
     done

     PROXY_FILE=$(find ${XLOG_DIR} | grep -E "proxy_" | xargs ls -t)
     for file in $PROXY_FILE; do
       cp $file ${newpath}/xlog/
     break
     done

     SWAN0_FILE=$(find ${XLOG_DIR} | grep -E "swan0_" | xargs ls -t)
     for file in $SWAN0_FILE; do
       cp $file ${newpath}/xlog/
     break
     done
   fi
   chown -R system:system ${newpath}
}

# Zhurui2@ANDROID.STABILITY, 2023/11/17, add for save newest wxlog when theia anr\crash\nfw
function copyXlogForTheia() {
   newpath="/data/persist_log/theia30"
   XLOG_DIR="/sdcard/Android/data/com.tencent.mm/MicroMsg/xlog"
   mkdir -p ${newpath}/wxlog
   chmod 777 -R ${newpath}/wxlog
   #wxlog/xlog
   if [ -d "${XLOG_DIR}" ]; then
     mkdir -p ${newpath}/wxlog/xlog
     MM_FILE=$(find ${XLOG_DIR} | grep -E "MM_" | xargs ls -t)
     for file in $MM_FILE; do
       cp $file ${newpath}/wxlog/xlog/
     break
     done

     PUSH_FILE=$(find ${XLOG_DIR} | grep -E "PUSH_" | xargs ls -t)
     for file in $PUSH_FILE; do
       cp $file ${newpath}/wxlog/xlog/
     break
     done

     TOOL_FILE=$(find ${XLOG_DIR} | grep -E "TOOL_" | xargs ls -t)
     for file in $TOOL_FILE; do
       cp $file ${newpath}/wxlog/xlog/
     break
     done

     APPBRAND0_FILE=$(find ${XLOG_DIR} | grep -E "APPBRAND0_" | xargs ls -t)
     for file in $APPBRAND0_FILE; do
       cp $file ${newpath}/wxlog/xlog/
     break
     done

     APPBRAND1_FILE=$(find ${XLOG_DIR} | grep -E "APPBRAND1_" | xargs ls -t)
     for file in $APPBRAND1_FILE; do
       cp $file ${newpath}/wxlog/xlog/
     break
     done

     APPBRAND2_FILE=$(find ${XLOG_DIR} | grep -E "APPBRAND2_" | xargs ls -t)
     for file in $APPBRAND2_FILE; do
       cp $file ${newpath}/wxlog/xlog/
     break
     done

     APPBRAND3_FILE=$(find ${XLOG_DIR} | grep -E "APPBRAND3_" | xargs ls -t)
     for file in $APPBRAND3_FILE; do
       cp $file ${newpath}/wxlog/xlog/
     break
     done

     APPBRAND4_FILE=$(find ${XLOG_DIR} | grep -E "APPBRAND4_" | xargs ls -t)
     for file in $APPBRAND4_FILE; do
       cp $file ${newpath}/wxlog/xlog/
     break
     done

     TP_FILE=$(find ${XLOG_DIR} | grep -E "TP_" | xargs ls -t)
     for file in $TP_FILE; do
       cp $file ${newpath}/wxlog/xlog/
     break
     done

     chmod 777 -R ${newpath}/wxlog/xlog
   fi
}

function catchQQlogForOpm() {
  currentDateQlog=$(date "+%y.%m.%d")
  newpath=`getprop sys.opm.logpath`
  QLOG_DIR="/sdcard/Android/data/com.tencent.mobileqq/files/tencent/msflogs/com/tencent/mobileqq"
  #qlog
  mkdir -p ${newpath}/qlog
  chmod 777 -R ${newpath}/qlog
  if [ -d "${QLOG_DIR}" ]; then
    mkdir -p ${newpath}/qlog/log
    ALL_FILE=$(find ${QLOG_DIR} | grep -E ${currentDateQlog} | xargs ls -t)
    for file in $ALL_FILE; do
      cp $file ${newpath}/qlog
    done
  fi
}


function startSsLogPower() {
    traceTransferState "startSsLogPower"
    powermonitorCustomLogDir=${DATA_DEBUGGING_PATH}/powermonitor_custom_log
    
    if [ ! -d "${powermonitorCustomLogDir}" ];then
        mkdir -p ${powermonitorCustomLogDir}
    fi
    ssLogOutputPath=${powermonitorCustomLogDir}/sslog.txt

    while [ -d "$powermonitorCustomLogDir" ]
    do
       ss -ntp -o state established >> ${ssLogOutputPath}
       sleep 15s #Sleep 15 seconds
    done
    traceTransferState "startSsLogPower_End"
}

function tranferPowerRelated() {
  traceTransferState "tranferPowerRelated"
  powerExtraLogDir="/data/oplus/psw/powermonitor_backup/extra_log";
  powermonitorCustomLogDir=${DATA_DEBUGGING_PATH}/powermonitor_custom_log
  if [ ! -d "${powerExtraLogDir}" ];then
    mkdir -p ${powerExtraLogDir}
  fi
  
  chown system:system ${powerExtraLogDir}
  chmod 777 -R ${powerExtraLogDir}/

  #collect bluetooth log
  buletoothLogSaveDir="${powerExtraLogDir}/buletooth_log";
  if [ ! -d "${buletoothLogSaveDir}" ];then
    mkdir -p ${buletoothLogSaveDir}
  fi

  tar cvzf ${buletoothLogSaveDir}/buletooth_log.tar.gz /data/misc/bluetooth/
  traceTransferState "get bluetooth log"

  #collect sslog
  sslogSourcPath=${powermonitorCustomLogDir}/sslog.txt
  if [ -f "${sslogSourcPath}" ];then
    cp ${sslogSourcPath} ${powerExtraLogDir}/sslog.txt
    traceTransferState "get sslog"
  fi

  chown system:system ${powerExtraLogDir}
  chmod 777 -R ${powerExtraLogDir}/
  
  #clear file
  rm ${sslogSourcPath}
  traceTransferState "tranferPowerRelated_end"
}

#Linjie.Xu@PSW.AD.Power.PowerMonitor.1104067, 2018/01/17, Add for OplusPowerMonitor get Sysinfo at O
function psforopm(){
  opmlogpath=`getprop sys.opm.logpath`
  ps -A -T > ${opmlogpath}psO.txt
  chown system:system ${opmlogpath}psO.txt
}
function cpufreqforopm(){
  opmlogpath=`getprop sys.opm.logpath`
  cat /sys/devices/system/cpu/*/cpufreq/scaling_cur_freq > ${opmlogpath}cpufreq.txt
  chown system:system ${opmlogpath}cpufreq.txt
}


function logcatMainCacheForOpm(){
  opmlogpath=`getprop sys.opm.logpath`
  logcat -v threadtime -d > ${opmlogpath}logcat.txt
  chown system:system ${opmlogpath}logcat.txt
}

function catchHfManagerForOpm(){
  opmlogpath=`getprop sys.opm.logpath`
  cat  /proc/hf_manager > ${opmlogpath}hf_manager.txt
  chown system:system ${opmlogpath}hf_manager.txt
}

function logcatEventCacheForOpm(){
  opmlogpath=`getprop sys.opm.logpath`
  logcat -b events -d > ${opmlogpath}events.txt
  chown system:system ${opmlogpath}events.txt
}

function logcatRadioCacheForOpm(){
  opmlogpath=`getprop sys.opm.logpath`
  logcat -b radio -d > ${opmlogpath}radio.txt
  chown system:system ${opmlogpath}radio.txt
}

function catchBinderInfoForOpm(){
  opmlogpath=`getprop sys.opm.logpath`
  cat /sys/kernel/debug/binder/state > ${opmlogpath}binderinfo.txt
  chown system:system ${opmlogpath}binderinfo.txt
}

function catchInterruptsInfoForOpm(){
  opmlogpath=`getprop sys.opm.logpath`
  cat /proc/interrupts > ${opmlogpath}interruptsInfo.txt
  chown system:system ${opmlogpath}interruptsInfo.txt
}

function catchBattertFccForOpm(){
  opmlogpath=`getprop sys.opm.logpath`
  cat /sys/class/power_supply/battery/batt_fcc > ${opmlogpath}fcc.txt
  chown system:system ${opmlogpath}fcc.txt
}

function catchTopInfoForOpm(){
  opmlogpath=`getprop sys.opm.logpath`
  opmfilename=`getprop sys.opm.logpath.filename`
  top -H -n 3 > ${opmlogpath}${opmfilename}top.txt
  chown system:system ${opmlogpath}${opmfilename}top.txt
}

function dumpsysHansHistoryForOpm(){
  opmlogpath=`getprop sys.opm.logpath`
  dumpsys activity hans history > ${opmlogpath}hans.txt
  chown system:system ${opmlogpath}hans.txt
  dumpsys activity service com.oplus.battery deepsleepRcd > ${opmlogpath}deepsleepRcd.txt
  chown system:system ${opmlogpath}deepsleepRcd.txt
}

function dumpsysSurfaceFlingerForOpm(){
  opmlogpath=`getprop sys.opm.logpath`
  dumpsys sensorservice > ${opmlogpath}sensorservice.txt
  chown system:system ${opmlogpath}sensorservice.txt
}

function dumpsysSensorserviceForOpm(){
  opmlogpath=`getprop sys.opm.logpath`
  dumpsys sensorservice > ${opmlogpath}sensorservice.txt
  chown system:system ${opmlogpath}sensorservice.txt
}

function dumpsysBatterystatsForOpm(){
  opmlogpath=`getprop sys.opm.logpath`
  dumpsys batterystats > ${opmlogpath}batterystats.txt
  chown system:system ${opmlogpath}batterystats.txt
}

function dumpsysBatterystatsOplusCheckinForOpm(){
  opmlogpath=`getprop sys.opm.logpath`
  dumpsys batterystats --oplusCheckin > ${opmlogpath}batterystats_oplusCheckin.txt
  chown system:system ${opmlogpath}batterystats_oplusCheckin.txt
}

function dumpsysBatterystatsCheckinForOpm(){
  opmlogpath=`getprop sys.opm.logpath`
  dumpsys batterystats -c > ${opmlogpath}batterystats_checkin.txt
  chown system:system ${opmlogpath}batterystats_checkin.txt
}

function dumpsysMediaForOpm(){
  opmlogpath=`getprop sys.opm.logpath`
  dumpsys media.audio_flinger > ${opmlogpath}audio_flinger.txt
  dumpsys media.audio_policy > ${opmlogpath}audio_policy.txt
  dumpsys audio > ${opmlogpath}audio.txt

  chown system:system ${opmlogpath}audio_flinger.txt
  chown system:system ${opmlogpath}audio_policy.txt
  chown system:system ${opmlogpath}audio.txt
}

function getPropForOpm(){
  opmlogpath=`getprop sys.opm.logpath`
  getprop > ${opmlogpath}prop.txt
  chown system:system ${opmlogpath}prop.txt
}

function clearMtkDebuglogger() {
     rm -rf /data/debuglogger/*
}

function dmaprocsforhealth(){
  opmlogpath=`getprop sys.opm.logpath`
  cat /proc/ion/ion_mm_heap > ${opmlogpath}dmaprocs.txt
  cat /proc/osvelte/dma_buf/bufinfo >> ${opmlogpath}dmaprocs.txt
  cat /proc/osvelte/dma_buf/procinfo >> ${opmlogpath}dmaprocs.txt
  chown system:system ${opmlogpath}dmaprocs.txt
}
function slabinfoforhealth(){
  opmlogpath=`getprop sys.opm.logpath`
  cat /proc/slabinfo > ${opmlogpath}slabinfo.txt
  chown system:system ${opmlogpath}slabinfo.txt
}
function svelteforhealth(){
    sveltetracer=`getprop sys.opm.svelte_tracer`
    svelteops=`getprop sys.opm.svelte_ops`
    svelteargs=`getprop sys.opm.svelte_args`
    opmlogpath=`getprop sys.opm.logpath`

    if [ "${sveltetracer}" == "malloc" ]; then
        if [ "${svelteops}" == "enable" ]; then
            osvelte malloc-debug -e ${svelteargs}
        elif [ "${svelteops}" == "disable" ]; then
            osvelte malloc-debug -D ${svelteargs}
        elif [ "${svelteops}" == "dump" ]; then
            osvelte malloc-debug -d ${svelteargs} > ${opmlogpath}malloc_${svelteargs}_svelte.txt
            sleep 12
            chown system:system ${opmlogpath}*svelte.txt
        fi
    elif [ "${sveltetracer}" == "vmalloc" ]; then
        if [ "${svelteops}" == "dump" ]; then
            cat /proc/vmallocinfo > ${svelteargs}
            sleep 12
            chown system:system ${opmlogpath}*svelte.txt
        fi
    elif [ "${sveltetracer}" == "slab" ]; then
        if [ "${svelteops}" == "dump" ]; then
            cat /proc/slabinfo > ${svelteargs}
            sleep 5
            chown system:system ${opmlogpath}*svelte.txt
        fi
    elif [ "${sveltetracer}" == "kernelstack" ]; then
        if [ "${svelteops}" == "dump" ]; then
            ps -A -T > ${svelteargs}
            sleep 5
            chown system:system ${opmlogpath}*svelte.txt
        fi
    elif [ "${sveltetracer}" == "ion" ]; then
        if [ "${svelteops}" == "dump" ]; then
            cat /proc/osvelte/dma_buf/bufinfo > ${svelteargs}
            cat /proc/osvelte/dma_buf/procinfo >> ${svelteargs}
            sleep 5
            chown system:system ${opmlogpath}*svelte.txt
        fi
    elif [ "${sveltetracer}" == "gpu" ]; then
        if [ "${svelteops}" == "dump" ]; then
            echo "cat /sys/kernel/debug/mali0/ctx/${svelteargs}_*/mem_profile > ${opmlogpath}_gpu.txt"
            cat /sys/kernel/debug/mali0/ctx/${svelteargs}_*/mem_profile > ${opmlogpath}_gpu.txt
            sleep 3
            chown system:system ${opmlogpath}*gpu.txt
        fi
    elif [ "${sveltetracer}" == "kmalloc" ]; then
        if [ "${svelteops}" == "enable" ]; then
            echo 1 > /proc/oplus_mem/memleak_detect/kmalloc_debug_enable
            echo ${svelteargs} > /proc/oplus_mem/memleak_detect/kmalloc_debug_create
        elif [ "${svelteops}" == "disable" ]; then
            echo 0 > /proc/oplus_mem/memleak_detect/kmalloc_debug_enable
        elif [ "${svelteops}" == "dump" ]; then
            cat /proc/slabinfo > ${opmlogpath}slabinfo.txt
            cat /proc/oplus_mem/memleak_detect/kmalloc_debug > ${opmlogpath}kmalloc.txt
            sleep 5
            chown system:system ${opmlogpath}slabinfo.txt
            chown system:system ${opmlogpath}kmalloc.txt
        fi
    fi
}
function meminfoforhealth(){
  opmlogpath=`getprop sys.opm.logpath`
  cat /proc/meminfo > ${opmlogpath}meminfo.txt
  chown system:system ${opmlogpath}meminfo.txt
}

#Fei.Mo2017/09/01 ,Add for power monitor top info
function thermalTop(){
   top -m 3 -n 1 > /data/system/dropbox/thermalmonitor/top
   chown system:system /data/system/dropbox/thermalmonitor/top
}

#Deliang.Peng 2017/7/7,add for native watchdog
function nativedump() {
    LOGTIME=`date +%F-%H-%M-%S`
    SWTPID=`getprop debug.swt.pid`
    JUNKLOGSFBACKPATH=/sdcard/persist_log/native/${LOGTIME}
    NATIVEBACKTRACEPATH=${JUNKLOGSFBACKPATH}/user_backtrace
    mkdir -p ${NATIVEBACKTRACEPATH}
    cat proc/stat > ${JUNKLOGSFBACKPATH}/proc_stat.txt &
    cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_cur_freq > ${JUNKLOGSFBACKPATH}/cpu_freq_0_.txt &
    cat /sys/devices/system/cpu/cpu1/cpufreq/cpuinfo_cur_freq > ${JUNKLOGSFBACKPATH}/cpu_freq_1.txt &
    cat /sys/devices/system/cpu/cpu2/cpufreq/cpuinfo_cur_freq > ${JUNKLOGSFBACKPATH}/cpu_freq_2.txt &
    cat /sys/devices/system/cpu/cpu3/cpufreq/cpuinfo_cur_freq > ${JUNKLOGSFBACKPATH}/cpu_freq_3.txt &
    cat /sys/devices/system/cpu/cpu4/cpufreq/cpuinfo_cur_freq > ${JUNKLOGSFBACKPATH}/cpu_freq_4.txt &
    cat /sys/devices/system/cpu/cpu5/cpufreq/cpuinfo_cur_freq > ${JUNKLOGSFBACKPATH}/cpu_freq_5.txt &
    cat /sys/devices/system/cpu/cpu6/cpufreq/cpuinfo_cur_freq > ${JUNKLOGSFBACKPATH}/cpu_freq_6.txt &
    cat /sys/devices/system/cpu/cpu7/cpufreq/cpuinfo_cur_freq > ${JUNKLOGSFBACKPATH}/cpu_freq_7.txt &
    cat /sys/devices/system/cpu/cpu0/online > ${JUNKLOGSFBACKPATH}/cpu_online_0_.txt &
    cat /sys/devices/system/cpu/cpu1/online > ${JUNKLOGSFBACKPATH}/cpu_online_1_.txt &
    cat /sys/devices/system/cpu/cpu2/online > ${JUNKLOGSFBACKPATH}/cpu_online_2_.txt &
    cat /sys/devices/system/cpu/cpu3/online > ${JUNKLOGSFBACKPATH}/cpu_online_3_.txt &
    cat /sys/devices/system/cpu/cpu4/online > ${JUNKLOGSFBACKPATH}/cpu_online_4_.txt &
    cat /sys/devices/system/cpu/cpu5/online > ${JUNKLOGSFBACKPATH}/cpu_online_5_.txt &
    cat /sys/devices/system/cpu/cpu6/online > ${JUNKLOGSFBACKPATH}/cpu_online_6_.txt &
    cat /sys/devices/system/cpu/cpu7/online > ${JUNKLOGSFBACKPATH}/cpu_online_7_.txt &
    cat /proc/gpufreq/gpufreq_var_dump > ${JUNKLOGSFBACKPATH}/gpuclk.txt &
    top -n 1 -m 5 > ${JUNKLOGSFBACKPATH}/top.txt  &
    cp -R /data/native/* ${NATIVEBACKTRACEPATH}
    rm -rf /data/native
    ps -t > ${JUNKLOGSFBACKPATH}/pst.txt
}

function gettpinfo() {
    tplogflag=`getprop persist.sys.oplusdebug.tpcatcher`
    tplogflag=511
    # echo "$tplogflag"
    if [ "$tplogflag" == "" ]
    then
        echo "tplogflag == error"
    else
        subtime=`date +%F-%H-%M-%S`
        mkdir /sdcard/tp_debug_info
        subpath=/sdcard/tp_debug_info/${subtime}.txt
        echo "tplogflag = $tplogflag"
        # tplogflag=`echo $tplogflag | $XKIT awk '{print lshift($0, 1)}'`
        tpstate=0
        # tpstate=`echo $tplogflag | $XKIT awk '{print and($1, 1)}'`
        tpstate=$(($tplogflag & 1))
        echo "switch tpstate = $tpstate"
        if [ $tpstate == "0" ]
        then
            echo "switch tpstate off"
        else
            echo "switch tpstate on"
        # mFlagMainRegister = 1 << 1
        # subflag=`echo | $XKIT awk '{print lshift(1, 1)}'`
        subflag=$((1 << 1))
        echo "1 << 1 subflag = $subflag"
        # tpstate=`echo $tplogflag $subflag, | $XKIT awk '{print and($1, $2)}'`
        tpstate=$(($tplogflag & subflag))
        if [ $tpstate == "0" ]
        then
            echo "switch tpstate off mFlagMainRegister = 1 << 1 $tpstate"
        else
            echo "switch tpstate on mFlagMainRegister = 1 << 1 $tpstate"
            echo "Time : ${subtime}" >> $subpath
            echo /proc/touchpanel/debug_info/main_register  >> $subpath
            cat /proc/touchpanel/debug_info/main_register  >> $subpath
        fi
        # mFlagSelfDelta = 1 << 2;
        # subflag=`echo | $XKIT awk '{print lshift(1, 2)}'`
        subflag=$((1 << 2))
        echo " 1<<2 subflag = $subflag"
        # tpstate=`echo $tplogflag $subflag, | $XKIT awk '{print and($1, $2)}'`
        tpstate=$(($tplogflag & subflag))
        if [ $tpstate == "0" ]
        then
            echo "switch tpstate off mFlagSelfDelta = 1 << 2 $tpstate"
        else
            echo "switch tpstate on mFlagSelfDelta = 1 << 2 $tpstate"
            echo /proc/touchpanel/debug_info/self_delta  >> $subpath
            cat /proc/touchpanel/debug_info/self_delta  >> $subpath
        fi
        # mFlagDetal = 1 << 3;
        # subflag=`echo | $XKIT awk '{print lshift(1, 3)}'`
        subflag=$((1 << 3))
        echo "1 << 3 subflag = $subflag"
        # tpstate=`echo $tplogflag $subflag, | $XKIT awk '{print and($1, $2)}'`
        tpstate=$(($tplogflag & subflag))
        if [ $tpstate == "0" ]
        then
            echo "switch tpstate off mFlagDelta = 1 << 3 $tpstate"
        else
            echo "switch tpstate on mFlagDelta = 1 << 3 $tpstate"
            echo /proc/touchpanel/debug_info/delta  >> $subpath
            cat /proc/touchpanel/debug_info/delta  >> $subpath
        fi
        # mFlatSelfRaw = 1 << 4;
        # subflag=`echo | $XKIT awk '{print lshift(1, 4)}'`
        subflag=$((1 << 4))
        echo "1 << 4 subflag = $subflag"
        # tpstate=`echo $tplogflag $subflag, | $XKIT awk '{print and($1, $2)}'`
        tpstate=$(($tplogflag & subflag))
        if [ $tpstate == "0" ]
        then
            echo "switch tpstate off mFlagSelfRaw = 1 << 4 $tpstate"
        else
            echo "switch tpstate on mFlagSelfRaw = 1 << 4 $tpstate"
            echo /proc/touchpanel/debug_info/self_raw  >> $subpath
            cat /proc/touchpanel/debug_info/self_raw  >> $subpath
        fi
        # mFlagBaseLine = 1 << 5;
        # subflag=`echo | $XKIT awk '{print lshift(1, 5)}'`
        subflag=$((1 << 5))
        echo "1 << 5 subflag = $subflag"
        # tpstate=`echo $tplogflag $subflag, | $XKIT awk '{print and($1, $2)}'`
        tpstate=$(($tplogflag & subflag))
        if [ $tpstate == "0" ]
        then
            echo "switch tpstate off mFlagBaseline = 1 << 5 $tpstate"
        else
            echo "switch tpstate on mFlagBaseline = 1 << 5 $tpstate"
            echo /proc/touchpanel/debug_info/baseline  >> $subpath
            cat /proc/touchpanel/debug_info/baseline  >> $subpath
        fi
        # mFlagDataLimit = 1 << 6;
        # subflag=`echo | $XKIT awk '{print lshift(1, 6)}'`
        subflag=$((1 << 6))
        echo "1 << 6 subflag = $subflag"
        # tpstate=`echo $tplogflag $subflag, | $XKIT awk '{print and($1, $2)}'`
        tpstate=$(($tplogflag & subflag))
        if [ $tpstate == "0" ]
        then
            echo "switch tpstate off mFlagDataLimit = 1 << 6 $tpstate"
        else
            echo "switch tpstate on mFlagDataLimit = 1 << 6 $tpstate"
            echo /proc/touchpanel/debug_info/data_limit  >> $subpath
            cat /proc/touchpanel/debug_info/data_limit  >> $subpath
        fi
        # mFlagReserve = 1 << 7;
        # subflag=`echo | $XKIT awk '{print lshift(1, 7)}'`
        subflag=$((1 << 7))
        echo "1 << 7 subflag = $subflag"
        # tpstate=`echo $tplogflag $subflag, | $XKIT awk '{print and($1, $2)}'`
        tpstate=$(($tplogflag & subflag))
        if [ $tpstate == "0" ]
        then
            echo "switch tpstate off mFlagReserve = 1 << 7 $tpstate"
        else
            echo "switch tpstate on mFlagReserve = 1 << 7 $tpstate"
            echo /proc/touchpanel/debug_info/reserve  >> $subpath
            cat /proc/touchpanel/debug_info/reserve  >> $subpath
        fi
        # mFlagTpinfo = 1 << 8;
        # subflag=`echo | $XKIT awk '{print lshift(1, 8)}'`
        subflag=$((1 << 8))
        echo "1 << 8 subflag = $subflag"
        # tpstate=`echo $tplogflag $subflag, | $XKIT awk '{print and($1, $2)}'`
        tpstate=$(($tplogflag & subflag))
        if [ $tpstate == "0" ]
        then
            echo "switch tpstate off mFlagMainRegister = 1 << 8 $tpstate"
        else
            echo "switch tpstate on mFlagMainRegister = 1 << 8 $tpstate"
        fi

        echo $tplogflag " end else"
	fi
    fi
}

function inittpdebug(){
    panicstate=`getprop persist.sys.assert.panic`
    tplogflag=`getprop persist.sys.oplusdebug.tpcatcher`
    if [ "$panicstate" == "true" ]
    then
        # tplogflag=`echo $tplogflag , | $XKIT awk '{print or($1, 1)}'`
        tplogflag=$(($tplogflag | 1))
    else
        # tplogflag=`echo $tplogflag , | $XKIT awk '{print and($1, 510)}'`
        tplogflag=$(($tplogflag & 1))
    fi
    setprop persist.sys.oplusdebug.tpcatcher $tplogflag
}
function settplevel(){
    tplevel=`getprop persist.sys.oplusdebug.tplevel`
    if [ "$tplevel" == "0" ]
    then
        echo 0 > /proc/touchpanel/debug_level
    elif [ "$tplevel" == "1" ]
    then
        echo 1 > /proc/touchpanel/debug_level
    elif [ "$tplevel" == "2" ]
    then
        echo 2 > /proc/touchpanel/debug_level
    fi
}

#Fangfang.Hui@TECH.AD.Stability, 2019/08/13, Add for the quality feedback dcs config
function backupMinidump() {
    tag=`getprop sys.backup.minidump.tag`
    if [ x"$tag" = x"" ]; then
        echo "backup.minidump.tag is null, do nothing"
        return
    fi
    minidumppath="${DATA_OPLUS_LOG_PATH}/DCS/de/AEE_DB"
    miniDumpFile=$minidumppath/$(ls -t ${minidumppath} | head -1)
    if [ x"$miniDumpFile" = x"" ]; then
        echo "minidump.file is null, do nothing"
        return
    fi
    result=$(echo $miniDumpFile | grep "${tag}")
    if [ x"$result" = x"" ]; then
        echo "tag mismatch, do not backup"
        return
    else
        try_copy_minidump_to_oplusreserve $miniDumpFile
        setprop sys.backup.minidump.tag ""
    fi
}

function try_copy_minidump_to_oplusreserve() {
    OPLUSRESERVE_MINIDUMP_BACKUP_PATH="${DATA_OPLUS_LOG_PATH}/oplusreserve/media/log/minidumpbackup"
    OPLUSRESERVE2_MOUNT_POINT="/mnt/vendor/oplusreserve"

    if [ ! -d ${OPLUSRESERVE_MINIDUMP_BACKUP_PATH} ]; then
        mkdir ${OPLUSRESERVE_MINIDUMP_BACKUP_PATH}
    fi

    NewLogPath=$1
    if [ ! -f $NewLogPath ] ;then
        echo "Can not access ${NewLogPath}, the file may not exists "
        return
    fi
    TmpLogSize=$(du -sk ${NewLogPath} | sed 's/[[:space:]]/,/g' | cut -d "," -f1) #`du -s -k ${NewLogPath} | $XKIT awk '{print $1}'`
    curBakCount=`ls ${OPLUSRESERVE_MINIDUMP_BACKUP_PATH} | wc -l`
    echo "curBakCount = ${curBakCount}, TmpLogSize = ${TmpLogSize}, NewLogPath = ${NewLogPath}"
    while [ ${curBakCount} -gt 5 ]   #can only save 5 backup minidump logs at most
    do
        rm -rf ${OPLUSRESERVE_MINIDUMP_BACKUP_PATH}/$(ls -t ${OPLUSRESERVE_MINIDUMP_BACKUP_PATH} | tail -1)
        curBakCount=`ls ${OPLUSRESERVE_MINIDUMP_BACKUP_PATH} | wc -l`
        echo "delete one file curBakCount = $curBakCount"
    done
    FreeSize=$(df -ak | grep "${OPLUSRESERVE_MINIDUMP_BACKUP_PATH}" | sed 's/[ ][ ]*/,/g' | cut -d "," -f4)
    TotalSize=$(df -ak | grep "${OPLUSRESERVE_MINIDUMP_BACKUP_PATH}" | sed 's/[ ][ ]*/,/g' | cut -d "," -f2)
    ReserveSize=`expr $TotalSize / 5`
    NeedSize=`expr $TmpLogSize + $ReserveSize`
    echo "NeedSize = ${NeedSize}, ReserveSize = ${ReserveSize}, FreeSize = ${FreeSize}"
    while [ ${FreeSize} -le ${NeedSize} ]
    do
        curBakCount=`ls ${OPLUSRESERVE_MINIDUMP_BACKUP_PATH} | wc -l`
        if [ $curBakCount -gt 1 ]; then #leave at most on log file
            rm -rf ${OPLUSRESERVE_MINIDUMP_BACKUP_PATH}/$(ls -t ${OPLUSRESERVE_MINIDUMP_BACKUP_PATH} | tail -1)
            echo "${OPLUSRESERVE2_MOUNT_POINT} left space ${FreeSize} not enough for minidump, delete one de minidump"
            FreeSize=$(df -k | grep "${OPLUSRESERVE2_MOUNT_POINT}" | sed 's/[ ][ ]*/,/g' | cut -d "," -f4)
            continue
        fi
        echo "${OPLUSRESERVE2_MOUNT_POINT} left space ${FreeSize} not enough for minidump, nothing to delete"
        return 0
    done
    #space is enough, now copy
    cp $NewLogPath $OPLUSRESERVE_MINIDUMP_BACKUP_PATH
    chmod -R 0771 ${OPLUSRESERVE_MINIDUMP_BACKUP_PATH}
    chown -R system ${OPLUSRESERVE_MINIDUMP_BACKUP_PATH}
    chgrp -R system ${OPLUSRESERVE_MINIDUMP_BACKUP_PATH}
}

# Add for clean pcm dump file.
function cleanpcmdump() {
    rm -rf /data/vendor/audiohal/audio_dump/*
    rm -rf /data/vendor/audiohal/aurisys_dump/*
    rm -rf /data/debuglogger/audio_dump/*
    rm -rf /sdcard/mtklog/audio_dump/*
}

#Jianping.Zheng, 2017/04/04, Add for record performance
function perf_record() {
    check_interval=`getprop persist.sys.oplus.perfinteval`
    if [ x"${check_interval}" = x"" ]; then
        check_interval=60
    fi
    perf_record_path=${DATA_DEBUGGING_PATH}/perf_record_logs
    while [ true ];do
        if [ ! -d ${perf_record_path} ];then
            mkdir -p ${perf_record_path}
        fi

        echo "\ndate->" `date` >> ${perf_record_path}/cpu.txt
        cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq >> ${perf_record_path}/cpu.txt

        echo "\ndate->" `date` >> ${perf_record_path}/mem.txt
        cat /proc/meminfo >> ${perf_record_path}/mem.txt

        echo "\ndate->" `date` >> ${perf_record_path}/buddyinfo.txt
        cat /proc/buddyinfo >> ${perf_record_path}/buddyinfo.txt

        echo "\ndate->" `date` >> ${perf_record_path}/top.txt
        top -n 1 -H >> ${perf_record_path}/top.txt

        sleep "$check_interval"
    done
}

function pwkdumpon(){
    echo 1 >  /proc/aee_kpd_enable
}

function pwkdumpoff(){
    echo 0 >  /proc/aee_kpd_enable
}

# Add for full dump & mini dump
function mrdumpon(){
	/system/system_ext/bin/oplus_fulldump on
}

function mrdumpoff(){
	/system/system_ext/bin/oplus_fulldump off
}

function testTransferSystem(){
    TMPTIME=`date +%F-%H-%M-%S`
    setprop sys.oplus.log.stoptime ${TMPTIME}
    stoptime=`getprop sys.oplus.log.stoptime`;
    newpath="${SDCARD_LOG_BASE_PATH}/log@stop@${stoptime}"
    echo "${newpath}"

    mkdir -p ${newpath}/system
    #tar -cvf ${newpath}/log.tar ${DATA_OPLUS_LOG_PATH}/*
    cp -rf ${DATA_OPLUS_LOG_PATH}/ ${newpath}/system
}

function testTransferRoot(){
    TMPTIME=`date +%F-%H-%M-%S`
    setprop sys.oplus.log.stoptime ${TMPTIME}
    stoptime=`getprop sys.oplus.log.stoptime`;
    newpath="${SDCARD_LOG_BASE_PATH}/log@stop@${stoptime}"
    echo "${newpath}"

    mkdir -p ${newpath}
    mv ${MTK_DEBUG_PATH} ${newpath}
}

function checkNumberSizeAndCopy(){
    LOG_SOURCE_PATH="$1"
    LOG_TARGET_PATH="$2"
    LOG_LIMIT_NUM="$3"
    LOG_LIMIT_SIZE="$4"
    echo "${CURTIME_FORMAT} CHECKNUMBERSIZEANDCOPY:FROM ${LOG_SOURCE_PATH} TO ${LOG_TARGET_PATH}"
    LIMIT_NUM=500
    #500*1024MB
    LIMIT_SIZE="512000"

    if [ -d "${LOG_SOURCE_PATH}" ] && [ ! "`ls -A ${LOG_SOURCE_PATH}`" = "" ]; then
        TMP_LOG_NUM=`ls -lR ${LOG_SOURCE_PATH} |grep "^-"|wc -l | awk '{print $1}'`
        TMP_LOG_SIZE=`du -s -k ${LOG_SOURCE_PATH} | awk '{print $1}'`
        echo "${CURTIME_FORMAT} CHECKNUMBERSIZEANDCOPY:NUM:${TMP_LOG_NUM}/${LIMIT_NUM} SIZE:${TMP_LOG_SIZE}/${LIMIT_SIZE}"
        if [ ${TMP_LOG_NUM} -le ${LIMIT_NUM} ] && [ ${TMP_LOG_SIZE} -le ${LIMIT_SIZE} ]; then
            if [ ! -d ${LOG_TARGET_PATH} ];then
                mkdir -p ${LOG_TARGET_PATH}
            fi

            cp -rf ${LOG_SOURCE_PATH}/* ${LOG_TARGET_PATH}
            echo "${CURTIME_FORMAT} CHECKNUMBERSIZEANDCOPY:${LOG_SOURCE_PATH} done" >> ${SDCARD_LOG_BASE_PATH}/logkit_transfer.log
        else
            echo "${CURTIME_FORMAT} CHECKNUMBERSIZEANDCOPY:${LOG_SOURCE_PATH} NUM:${TMP_LOG_NUM}/${LIMIT_NUM} SIZE:${TMP_LOG_SIZE}/${LIMIT_SIZE}" >> ${SDCARD_LOG_BASE_PATH}/logkit_transfer.log
            rm -rf ${LOG_SOURCE_PATH}/*
        fi
    fi
}

function traceTransferState() {
    if [ ! -d ${SDCARD_LOG_BASE_PATH} ]; then
        mkdir -p ${SDCARD_LOG_BASE_PATH}
        chmod 770 ${SDCARD_LOG_BASE_PATH} -R
        echo "${CURTIME_FORMAT} TRACETRANSFERSTATE:${SDCARD_LOG_BASE_PATH} " >> ${SDCARD_LOG_BASE_PATH}/logkit_transfer.log
    fi

    content=$1
    currentTime=`date "+%Y-%m-%d %H:%M:%S"`
    echo "${currentTime} ${content} " >> ${SDCARD_LOG_BASE_PATH}/logkit_transfer.log
}

#ifdef OPLUS_FEATURE_EAP
#Haifei.Liu@ANDROID.RESCONTROL, 2020/08/18, Add for copy binder_info
function copyEapBinderInfo() {
    destBinderInfoPath=`getprop sys.eap.binderinfo.path`
    echo ${destBinderInfoPath}
    if [ -f "/dev/binderfs/binder_logs/state" ]; then
        cat /dev/binderfs/binder_logs/state > ${destBinderInfoPath}
    else
        cat /sys/kernel/debug/binder/state > ${destBinderInfoPath}
    fi
}
#endif /* OPLUS_FEATURE_EAP */

# ifdef OPLUS_FEATURE_THEIA
# Yangkai.Yu@ANDROID.STABILITY, Add hook for TheiaBinderBlock
function copyTheiaBinderInfo() {
    destBinderFile=`getprop sys.theia.binderpath`
    echo "copy binder infomation to ${destBinderFile}"
    if [ -f "/dev/binderfs/binder_logs/transactions" ]; then
        cat /dev/binderfs/binder_logs/transactions > ${destBinderFile}
    else
        cat /sys/kernel/debug/binder/transactions > ${destBinderFile}
    fi
}
# endif /*OPLUS_FEATURE_THEIA*/

function customdmesg() {
    echo "customdmesg begin"
    chmod 777 -R ${DATA_DEBUGGING_PATH}
    echo "customdmesg end"
}

function checkAeeLogs() {
    echo "checkAeeLogs begin"
    setprop sys.move.aeevendor.ready 0
    cp -rf /data/vendor/aee_exp/db.* /data/aee_exp/
    rm -rf /data/vendor/aee_exp/db.*
    restorecon -RF /data/aee_exp/
    chmod 777 -R /data/aee_exp/
    setprop sys.move.aeevendor.ready 1
    echo "checkAeeLogs end"
}

function DumpEnvironment(){
    rm  -rf /cache/environment
    umask 000
    mkdir -p /cache/environment
    dumpsys activity intents > /cache/environment/intents.txt &
    chmod 777 cache/environment/*
    wait
    setprop sys.dumpenvironment.finished 1
    umask 077
}

# Kun.Hu@TECH.BSP.Stability.Phoenix, 2019/4/17, fix the core domain limits to search hang_oplus dirent
function remount_oplusreserve2() {
    HANGOPLUS_DIR_REMOUNT_POINT="/data/persist_log/oplusreserve/media/log/hang_oplus"
    if [ ! -d ${HANGOPLUS_DIR_REMOUNT_POINT} ]; then
        mkdir -p ${HANGOPLUS_DIR_REMOUNT_POINT}
    fi
    chmod -R 0770 /data/persist_log/oplusreserve
    chgrp -R system /data/persist_log/oplusreserve
    chown -R system /data/persist_log/oplusreserve
    mount /mnt/vendor/oplusreserve/media/log/hang_oplus ${HANGOPLUS_DIR_REMOUNT_POINT}
}

#ifdef OPLUS_FEATURE_SHUTDOWN_DETECT
#Liang.Zhang@TECH.Storage.Stability.OPLUS_SHUTDOWN_DETECT, 2019/04/28, Add for shutdown detect
function remount_oplusreserve2_shutdown() {
    OPLUSRESERVE2_REMOUNT_POINT="/data/persist_log/oplusreserve/media/log/shutdown"
    if [ ! -d ${OPLUSRESERVE2_REMOUNT_POINT} ]; then
        mkdir ${OPLUSRESERVE2_REMOUNT_POINT}
    fi
    chmod 0770 /data/persist_log/oplusreserve
    chgrp system /data/persist_log/oplusreserve
    chown system /data/persist_log/oplusreserve
    mount /mnt/vendor/oplusreserve/media/log/shutdown ${OPLUSRESERVE2_REMOUNT_POINT}
}
#endif

#Xuefeng.Peng@PSW.AD.Performance.Storage.1721598, 2018/12/26, Add for customize version to control sdcard
#Kang.Zou@PSW.AD.Performance.Storage.1721598, 2019/10/17, Add for customize version to control sdcard with new methods
function exstorage_support() {
    exStorage_support=`getprop persist.sys.exStorage_support`
    if [ x"${exStorage_support}" == x"1" ]; then
        #echo 1 > /sys/class/mmc_host/mmc0/exStorage_support
        echo 1 > /sys/bus/mmc/drivers_autoprobe
        mmc_devicename=$(ls /sys/bus/mmc/devices | grep "mmc0:")
        if [ -n "$mmc_devicename" ];then
            echo "$mmc_devicename" > /sys/bus/mmc/drivers/mmcblk/bind
        fi
        #echo "fsck test start" >> /data/media/0/fsck.txt

        #DATE=`date +%F-%H-%M-%S`
        #echo "${DATE}" >> /data/media/0/fsck.txt
        #echo "fsck test end" >> /data/media/0/fsck.txt
    fi
    if [ x"${exStorage_support}" == x"0" ]; then
        #echo 0 > /sys/class/mmc_host/mmc0/exStorage_support
        echo 0 > /sys/bus/mmc/drivers_autoprobe
        mmc_devicename=$(ls /sys/bus/mmc/devices | grep "mmc0:")
        if [ -n "$mmc_devicename" ];then
            echo "$mmc_devicename" > /sys/bus/mmc/drivers/mmcblk/unbind
        fi
        #echo "fsck test111 start" >> /data/media/0/fsck.txt

        #DATE=`date +%F-%H-%M-%S`
        #echo "${DATE}" >> /data/media/0/fsck.txt
        #echo "fsck test111 end" >> /data/media/0/fsck.txt
    fi
}

#Xiaomin.Yang@PSW.CN.BT.Basic.Customize.1586031,2018/12/02, Add for updating wcn firmware by sau_res
function wcnfirmwareupdate(){

    saufwdir="/data/oplus/common/sau_res/res/SAU-AUTO_LOAD_FW-10/"
    pushfwdir="/data/misc/firmware/push/"
    if [ -f ${saufwdir}/ROMv4_be_patch_1_0_hdr.bin ]; then
        cp  ${saufwdir}/ROMv4_be_patch_1_0_hdr.bin  ${pushfwdir}
        chown system:system ${pushfwdir}/ROMv4_be_patch_1_0_hdr.bin
        chmod 666 ${pushfwdir}/ROMv4_be_patch_1_0_hdr.bin
    fi

    if [ -f ${saufwdir}/ROMv4_be_patch_1_1_hdr.bin ]; then
        cp  ${saufwdir}/ROMv4_be_patch_1_1_hdr.bin  ${pushfwdir}
        chown system:system ${pushfwdir}/ROMv4_be_patch_1_1_hdr.bin
        chmod 666 ${pushfwdir}/ROMv4_be_patch_1_1_hdr.bin
    fi

    if [ -f ${saufwdir}/WIFI_RAM_CODE_6759 ]; then
       cp  ${saufwdir}/WIFI_RAM_CODE_6759  ${pushfwdir}
       chown system:system ${pushfwdir}/WIFI_RAM_CODE_6759
       chmod 666 ${pushfwdir}/WIFI_RAM_CODE_6759
    fi

    if [ -f ${saufwdir}/soc2_0_patch_mcu_3_1_hdr.bin ]; then
       cp  ${saufwdir}/soc2_0_patch_mcu_3_1_hdr.bin  ${pushfwdir}
       chown system:system ${pushfwdir}/soc2_0_patch_mcu_3_1_hdr.bin
       chmod 666  ${pushfwdir}/soc2_0_patch_mcu_3_1_hdr.bin
    fi

    if [ -f ${saufwdir}/soc2_0_ram_mcu_3_1_hdr.bin ]; then
       cp  ${saufwdir}/soc2_0_ram_mcu_3_1_hdr.bin  ${pushfwdir}
       chown system:system ${pushfwdir}/soc2_0_ram_mcu_3_1_hdr.bin
       chmod 666  ${pushfwdir}/soc2_0_ram_mcu_3_1_hdr.bin
    fi

    if [ -f ${saufwdir}/soc2_0_ram_bt_3_1_hdr.bin ]; then
       cp  ${saufwdir}/soc2_0_ram_bt_3_1_hdr.bin  ${pushfwdir}
       chown system:system ${pushfwdir}/soc2_0_ram_bt_3_1_hdr.bin
       chmod 666 ${pushfwdir}/soc2_0_ram_bt_3_1_hdr.bin
    fi

    if [ -f ${saufwdir}/soc2_0_ram_wifi_3_1_hdr.bin ]; then
       cp  ${saufwdir}/soc2_0_ram_wifi_3_1_hdr.bin  ${pushfwdir}
       chown system:system ${pushfwdir}/soc2_0_ram_wifi_3_1_hdr.bin
       chmod 666 ${pushfwdir}/soc2_0_ram_wifi_3_1_hdr.bin
    fi

    if [ -f ${saufwdir}/WIFI_RAM_CODE_soc2_0_3_1.bin ]; then
       cp  ${saufwdir}/WIFI_RAM_CODE_soc2_0_3_1.bin  ${pushfwdir}
       chown system:system ${pushfwdir}/WIFI_RAM_CODE_soc2_0_3_1.bin
       chmod 666 ${pushfwdir}/WIFI_RAM_CODE_soc2_0_3_1.bin
    fi

    if [ -f ${saufwdir}/soc2_0_patch_mcu_3a_1_hdr.bin ]; then
       cp  ${saufwdir}/soc2_0_patch_mcu_3a_1_hdr.bin  ${pushfwdir}
       chown system:system ${pushfwdir}/soc2_0_patch_mcu_3a_1_hdr.bin
       chmod 666  ${pushfwdir}/soc2_0_patch_mcu_3a_1_hdr.bin
    fi

    if [ -f ${saufwdir}/soc2_0_ram_mcu_3a_1_hdr.bin ]; then
       cp  ${saufwdir}/soc2_0_ram_mcu_3a_1_hdr.bin  ${pushfwdir}
       chown system:system ${pushfwdir}/soc2_0_ram_mcu_3a_1_hdr.bin
       chmod 666  ${pushfwdir}/soc2_0_ram_mcu_3a_1_hdr.bin
    fi

    if [ -f ${saufwdir}/soc2_0_ram_bt_3a_1_hdr.bin ]; then
       cp  ${saufwdir}/soc2_0_ram_bt_3a_1_hdr.bin  ${pushfwdir}
       chown system:system ${pushfwdir}/soc2_0_ram_bt_3a_1_hdr.bin
       chmod 666 ${pushfwdir}/soc2_0_ram_bt_3a_1_hdr.bin
    fi

    if [ -f ${saufwdir}/soc2_0_ram_wifi_3a_1_hdr.bin ]; then
       cp  ${saufwdir}/soc2_0_ram_wifi_3a_1_hdr.bin  ${pushfwdir}
       chown system:system ${pushfwdir}/soc2_0_ram_wifi_3a_1_hdr.bin
       chmod 666 ${pushfwdir}/soc2_0_ram_wifi_3a_1_hdr.bin
    fi

    if [ -f ${saufwdir}/WIFI_RAM_CODE_soc2_0_3a_1.bin ]; then
       cp  ${saufwdir}/WIFI_RAM_CODE_soc2_0_3a_1.bin  ${pushfwdir}
       chown system:system ${pushfwdir}/WIFI_RAM_CODE_soc2_0_3a_1.bin
       chmod 666 ${pushfwdir}/WIFI_RAM_CODE_soc2_0_3a_1.bin
    fi

    if [ -f ${saufwdir}/push.log ]; then
       cp  ${saufwdir}/push.log  ${pushfwdir}
    fi

}

function wcnfirmwareupdatedump(){

    logfwdir="/data/misc/firmware/"
    wifidir="/data/misc/wifi/"
    if [ -f ${logfwdir}/wcn_fw_update_result.conf ]; then
       cp  ${logfwdir}/wcn_fw_update_result.conf  ${wifidir}
       chown wifi:wifi ${wifidir}/wcn_fw_update_result.conf
       chmod 777  ${wifidir}/wcn_fw_update_result.conf
    fi
}

#ifdef OPLUS_DEBUG_SSLOG_CATCH
#Asiga@NETWORK.POWER 2021/03/11,add for mtk catch ss log
function logcatSsLog(){
    LOG_TYPE=`getprop persist.sys.debuglog.config`
    if [ "${LOG_TYPE}" == "call" ] || [ "${LOG_TYPE}" == "network" ] || [ "${LOG_TYPE}" == "wifi" ] || [ "${LOG_TYPE}" == "thermal" ] || [ "${LOG_TYPE}" == "power" ] || [ "${LOG_TYPE}" == "other" ]; then
        echo "logcatSsLog start"
        SSLOG_PATH=${MTK_DEBUG_PATH}/sslog
        if [[ ! -d ${SSLOG_PATH} ]];then
            mkdir -p ${SSLOG_PATH}
        fi
        LOG_RUNNING=`getprop vendor.mtklog.netlog.Running`
        while [ "${LOG_RUNNING}" == "1" ]
        do
            ss -ntp -o state established >> ${SSLOG_PATH}/sslog.txt
            sleep 15 #Sleep 15 seconds
            LOG_RUNNING=`getprop vendor.mtklog.netlog.Running`
        done
    fi
}
#endif

function transferTombstone() {
    srcpath=`getprop sys.tombstone.file`
    subPath=`getprop persist.sys.com.oplus.debug.time`
    cp ${srcpath} ${DATA_DEBUGGING_PATH}/${subPath}/tombstone/tomb_${CURTIME}
}

function transferAnr() {
    srcpath=`getprop sys.anr.srcfile`
    subPath=`getprop persist.sys.com.oplus.debug.time`
    destfile=`getprop sys.anr.destfile`

    cp ${srcpath} ${DATA_DEBUGGING_PATH}/${subPath}/anr/${destfile}
}

#ifdef OPLUS_FEATURE_WIFI_LOG
#Chuanye.Xu@OPLUS_FEATURE_WIFI_LOG, 2022/06/29 , add for collect wifi log
function captureTcpdumpLog(){
    COLLECT_LOG_PATH="${DATA_DEBUGGING_PATH}/wifi_log_temp/"
    if [ -d  ${COLLECT_LOG_PATH} ];then
        rm -rf ${COLLECT_LOG_PATH}
    fi
    if [ ! -d  ${COLLECT_LOG_PATH} ];then
        mkdir -p ${COLLECT_LOG_PATH}
        chown system:system ${COLLECT_LOG_PATH}
        chmod -R 777 ${COLLECT_LOG_PATH}
    fi
    tcpdump -i any -p -s 0 -W 4 -C 5 -w ${COLLECT_LOG_PATH}/tcpdump -Z system
}
function tcpDumpLog(){
    DATA_LOG_TCPDUMPLOG_PATH=`getprop sys.oplus.logkit.netlog`
    #limit the tcpdump size to 300M and packet size 100 byte for power log type and other log type
    traceTransferState "tcpDumpLog tcpdumpSize=${tcpdumpSize} tcpdumpCount=${tcpdumpCount} tcpdumpPacketSize=${tcpdumpPacketSize}"
    if [ "${tmpTcpdump}" != "" ]; then
        #limit the tcpdump size to 300M and packet size 100 byte for power log type and other log type
        tcpdump -i any -p -s ${tcpdumpPacketSize} -W ${tcpdumpCount} -C ${tcpdumpSize} -w ${DATA_LOG_TCPDUMPLOG_PATH}/tcpdump -R -Z system
    fi
}
function initLogSizeAndNums() {
    FreeSize=`df /data | grep -v Mounted | awk '{print $4}'`
    GSIZE=`echo | awk '{printf("%d",2*1024*1024)}'`
    traceTransferState "data FreeSize:${FreeSize} and GSIZE:${GSIZE}"

    tmpTcpdump=`getprop persist.sys.log.tcpdump`
    if [ "${tmpTcpdump}" != "" ]; then
        tmpTcpdumpSize=`set -f;array=(${tmpTcpdump//|/ });echo "${array[0]}"`
        tmpTcpdumpCount=`set -f;array=(${tmpTcpdump//|/ });echo "${array[1]}"`
        tcpdumpSize=`echo ${tmpTcpdumpSize} | awk '{printf("%d",$1*1024)}'`
        tcpdumpCount=`echo ${FreeSize} 10 50 ${tcpdumpSize} | awk '{printf("%d",$1*$2/$3/$4)}'`
        ##tcpdump use MB in the order
        tcpdumpSize=${tmpTcpdumpSize}
        if [ ${tcpdumpCount} -ge ${tmpTcpdumpCount} ]; then
            tcpdumpCount=${tmpTcpdumpCount}
        fi
    fi

    #LiuHaipeng@NETWORK.DATA.2959182, modify for limit the tcpdump size to 300M and packet size 100 byte for power log type and other log type
    #YangQing@CONNECTIVITY.WIFI.DCS.4219844, only limit tcpdump total size to 300M for other log, not limit packet size.
    LOG_TYPE=`getprop persist.sys.debuglog.config`
    tcpdumpPacketSize=0
    if [ "${LOG_TYPE}" != "call" ] && [ "${LOG_TYPE}" != "network" ] && [ "${LOG_TYPE}" != "wifi" ]; then
        tcpdumpSizeTotal=300
        tcpdumpCount=`echo ${tcpdumpSizeTotal} ${tcpdumpSize} 1 | awk '{printf("%d",$1/$2)}'`
    fi
}
#endif /* OPLUS_FEATURE_WIFI_LOG */

#Guotian.Wu add for wifi p2p connect fail log
function collectWifiP2pLog() {
    boot_completed=`getprop sys.boot_completed`
    while [ x${boot_completed} != x"1" ];do
        sleep 2
        boot_completed=`getprop sys.boot_completed`
    done
    wifiP2pLogPath="${DATA_DEBUGGING_PATH}/wifi_p2p_log"
    if [ ! -d  ${wifiP2pLogPath} ];then
        mkdir -p ${wifiP2pLogPath}
    fi

    dmesg > ${wifiP2pLogPath}/dmesg.txt
    /system/bin/logcat -b main -b system -f ${wifiP2pLogPath}/android.txt -r10240 -v threadtime *:V
}

function packWifiP2pFailLog() {
    wifiP2pLogPath="${DATA_DEBUGGING_PATH}/wifi_p2p_log"
    DCS_WIFI_LOG_PATH=`getprop oplus.wifip2p.connectfail`
    logReason=`getprop oplus.wifi.p2p.log.reason`
    logFid=`getprop oplus.wifi.p2p.log.fid`
    version=`getprop ro.build.version.ota`

    if [ "w${logReason}" == "w" ];then
        return
    fi

    if [ ! -d ${DCS_WIFI_LOG_PATH} ];then
        mkdir -p ${DCS_WIFI_LOG_PATH}
        chown system:system ${DCS_WIFI_LOG_PATH}
        chmod -R 777 ${DCS_WIFI_LOG_PATH}
    fi

    if [ ! -d  ${wifiP2pLogPath} ];then
        return
    fi

    tar -czvf  ${DCS_WIFI_LOG_PATH}/${logReason}.tar.gz -C ${wifiP2pLogPath} ${wifiP2pLogPath}
    abs_file=${DCS_WIFI_LOG_PATH}/${logReason}.tar.gz

    fileName="wifip2p_connect_fail@${logFid}@${version}@${logReason}.tar.gz"
    mv ${abs_file} ${DCS_WIFI_LOG_PATH}/${fileName}
    chown system:system ${DCS_WIFI_LOG_PATH}/${fileName}
    setprop sys.oplus.wifi.p2p.log.stop 0
    rm -rf ${wifiP2pLogPath}
}

#Shuangquan.du@PSW.AD.Recovery.0, 2019/07/03, add for generate runtime prop
function generate_runtime_prop() {
    getprop | sed -r 's|\[||g;s|\]||g;s|: |=|' | sed 's|ro.cold_boot_done=true||g' > /cache/runtime.prop
    chown root:root /cache/runtime.prop
    chmod 600 /cache/runtime.prop
    sync
}
#endif

#add for oidt begin
#PanZhuan@BSP.Tools, 2020/10/21, modify for way of OIDT log collection changed, please contact me for new reqirement in the future
function oidtlogs() {
    # get this prop to remove specified path
    removed_path=`getprop sys.oidt.remove_path`
    if [ "$removed_path" ];then
        traceTransferState "remove path ${removed_path}"
        rm -rf ${removed_path}
        setprop sys.oidt.remove_path ''
        return
    fi

    traceTransferState "oidtlogs start... "
    setprop sys.oidt.log_ready 0

    log_path=`getprop sys.oidt.log_path`
    if [ "$log_path" ];then
        oidt_root=${log_path}
    else
        oidt_root="BASE_PATH/oidt/"
    fi

    mkdir -p ${oidt_root}
    traceTransferState "oidt root: ${oidt_root}"

    log_config_file=`getprop sys.oidt.log_config`
    traceTransferState "log config file: ${log_config_file} "

    if [ "$log_config_file" ];then
        POWERMONITOR_BACKUP_LOG=/data/oplus/psw/powermonitor_backup/
        chmod 774 ${POWERMONITOR_BACKUP_LOG} -R

        paths=`cat ${log_config_file}`

        for file_path in ${paths};do
            # create parent directory of each path
            dest_path=${oidt_root}${file_path%/*}
            # replace dunplicate character '//' with '/' in directory
            dest_path=${dest_path//\/\//\/}
            mkdir -p ${dest_path}
            traceTransferState "copy ${file_path} "
            cp -rf ${file_path} ${dest_path}
        done

        chmod 770 ${POWERMONITOR_BACKUP_LOG} -R
        chmod -R 777 ${oidt_root}

        setprop sys.oidt.log_config ''
    fi

    setprop sys.oidt.log_ready 1
    setprop sys.oidt.log_path ''
    traceTransferState "oidtlogs end "
}
#add for oidt end

#ifdef OPLUS_BUG_DEBUG
#Miao.Yu@ANDROID.WMS, 2019/11/25, Add for dump wm info
function dumpWm() {
    panicstate=`getprop persist.sys.assert.panic`
    dumpenable=`getprop debug.screencapdump.enable`
    LAYER_TRACE_DIR=/data/debugging/layertrace
    if [ "$panicstate" == "true" ] && [ "$dumpenable" == "true" ]
    then
        if [ ! -d ${DATA_DEBUGGING_PATH}/wm/ ];then
        mkdir -p ${DATA_DEBUGGING_PATH}/wm/
        fi

        if [ ! -d ${LAYER_TRACE_DIR} ]; then
            mkdir -p ${LAYER_TRACE_DIR}
        fi

        LOGTIME=`date +%F-%H-%M-%S`
        DIR=${DATA_DEBUGGING_PATH}/wm/${LOGTIME}
        mkdir -p ${DIR}
        dumpsys window -a > ${DIR}/windows.txt
        dumpsys activity a > ${DIR}/activities.txt
        dumpsys activity -v top > ${DIR}/top_activity.txt
        dumpsys SurfaceFlinger > ${DIR}/sf.txt
        dumpsys input > ${DIR}/input.txt
        ps -A > ${DIR}/ps.txt
        chmod 777 ${LAYER_TRACE_DIR}/layer_trace*
        setprop persist.sys.layertrace.dump true
        setprop persist.sys.layertrace.dump false
    fi
}
#endif /* OPLUS_BUG_DEBUG */

#zhaochengsheng@PSW.CN.WiFi.Basic.Custom.2204034, 2019/07/29
#add for Add for:solve camera interference ANT.
function iwprivswapant0(){
    iwpriv wlan0 driver 'SET_CHIP AntSwapManualCtrl 1 0'
    iwpriv wlan0 driver 'SET_CHIP AntSwapManualCtrl 0'
}

function iwprivswapant1(){
    iwpriv wlan0 driver 'SET_CHIP AntSwapManualCtrl 1 1'
}

function iwprivswitchswapant(){
    iwpriv wlan0 driver 'SET_CHIP AntSwapManualCtrl 1 0'
}

#genglin.lian@PSW.CN.WiFi.Connect.Network.2566837, 2019/9/23
#Add enable/disable interface for SmartGear
function disableSmartGear() {
    iwpriv wlan0 driver 'set_chip SmartGear 9 0'
}

function enableSmartGear() {
    iwpriv wlan0 driver 'set_chip SmartGear 9 1'
}

#Junhao.Liang 2020/01/02, Add for OTA to catch log
function resetlogfirstbootbuffer() {
    echo "resetlogfirstbootbuffer start"
    setprop sys.tranfer.finished "resetlogfirstbootbuffer start"
    echo "resetlogfirstbootbuffer end"
    setprop sys.tranfer.finished "resetlogfirstbootbuffer end"
}

function logfirstbootmain() {
    echo "logfirstbootmain begin"
    setprop sys.tranfer.finished "logfirstbootmain begin"
    path=${MTK_DEBUG_PATH}/firstboot
    mkdir -p ${path}
    /system/bin/logcat  -f ${path}/android.txt -r10240 -v threadtime *:V
    setprop sys.tranfer.finished "logfirstbootmain end"
    echo "logfirstbootmain end"
}

function logfirstbootevent() {
    echo "logfirstbootevent begin"
    setprop sys.tranfer.finished "logfirstbootevent begin"
    path=${MTK_DEBUG_PATH}/firstboot
    mkdir -p ${path}
    /system/bin/logcat -b events -f ${path}/event.txt -r10240 -v threadtime *:V
    setprop sys.tranfer.finished "logfirstbootevent end"
    echo "logfirstbootevent end"
}

function logfirstbootkernel() {
    echo "logfirstbootkernel begin"
    setprop sys.tranfer.finished "logfirstbootkernel begin"
    path=${MTK_DEBUG_PATH}/firstboot
    mkdir -p ${path}
    dmesg > ${path}/kinfo_boot.txt
    setprop sys.tranfer.finished "logfirstbootkernel end"
    echo "logfirstbootkernel end"
}

function chmodDcsEnPath() {
    DCS_EN_PATH=${DATA_OPLUS_LOG_PATH}/DCS/en
    chmod 777 -R ${DCS_EN_PATH}
}

function logcusmain() {
    echo "logcusmain begin"
    path=${DATA_OPLUS_LOG_PATH}/temp
    mkdir -p ${path}
    chown -R system:system ${path}
    chmod 755 -R ${path}
    /system/bin/logcat  -f ${path}/android.txt -r10240 -v threadtime *:V
    echo "logcusmain end"
}

function logcusevent() {
    echo "logcusevent begin"
    path=${DATA_OPLUS_LOG_PATH}/temp
    mkdir -p ${path}
    chown -R system:system ${path}
    chmod 755 -R ${path}
    /system/bin/logcat -b events -f ${path}/event.txt -r10240 -v threadtime *:V
    echo "logcusevent end"
}

function logcusradio() {
    echo "logcusradio begin"
    path=${DATA_OPLUS_LOG_PATH}/temp
    mkdir -p ${path}
    chown -R system:system ${path}
    chmod 755 -R ${path}
    /system/bin/logcat -b radio -f ${path}/radio.txt -r10240 -v threadtime *:V
    echo "logcusradio end"
}


#ifdef VENDOR_EDIT
#Hailong.Liu@ANDROID.MM, 2020/03/18, add for capture native malloc leak on aging_monkey test
function storeSvelteLog() {
    local dest_dir="/data/oplus/heapdump/svelte/"
    local log_file="${dest_dir}/svelte_log.txt"
    local log_dev="/dev/svelte_log"
    local err_file="${DATA_DEBUGGING_PATH}/svelte_err.txt"

    if [ ! -c ${log_dev} ]; then
        echo "svelte ${log_dev} does not exist." >> ${err_file}
        return 1
    fi

    if [ ! -d ${dest_dir} ]; then
        mkdir -p ${dest_dir}
        if [ "$?" -ne "0" ]; then
            echo "svelte mkdir failed." >> ${err_file}
            return 1
        fi
        chmod 0777 ${dest_dir}
    fi

    if [ ! -f ${log_file} ]; then
        echo --------Start `date` >> ${log_file}
        if [ "$?" -ne "0" ]; then
            echo "svelte create file failed." >> ${err_file}
            return 1
        fi
        chmod 0777 ${log_file}
    fi

    while true
    do
        echo --------`date` >> ${log_file}
        /system_ext/bin/svelte logger >> ${log_file}
    done
}
#endif

#ifdef OPLUS_BUG_STABILITY
#Tian.Pan@ANDROID.STABILITY.3054721.2020/08/31.add for fix debug system_server register too many receivers issue
function receiverinfocapture() {
    alreadycaped=`getprop sys.debug.receiverinfocapture`
    if [ "$alreadycaped" == "1" ] ;then
        return
    fi

    uuid=`cat /proc/sys/kernel/random/uuid`
    version=`getprop ro.build.version.ota`
    logtime=`date +%F-%H-%M-%S`
    logpath="${DATA_OPLUS_LOG_PATH}/DCS/de/stability_monitor"
    if [ ! -d "${logpath}" ]; then
        mkdir ${logpath}
        chown system:system ${logpath}
        chmod 777 ${logpath}
    fi
    filename="${logpath}/stability_receiversinfo@${uuid}@${version}@${logtime}.txt"
    dumpsys -t 60 activity broadcasts > ${filename}
    chown system:system ${filename}
    chmod 0666 ${filename}
    setprop sys.debug.receiverinfocapture 1
}
#endif /*OPLUS_BUG_STABILITY*/

#ifdef OPLUS_BUG_STABILITY
#Yongqiang.Du@ANDROID.Stability.Crash.0, 2022/08/08, Add for shutdown reason recorder
function rebootdetectcapture() {
    alreadycaped=`getprop sys.debug.rebootdetectcapture`
    normalaction=`getprop debug.rebootdetect.capture`
    if [ "${alreadycaped}" == "1" ] ;then
        return
    fi
    if [ x"${normalaction}" != x"true" ] ;then
       return
    fi

    dd if=/dev/zero of=/sdcard/zero5 bs=1m count=5
    #dd if=/dev/zero of=/data/persist_log/oplusreserve/media/log/shutdown/zero6 bs=1m count=5
    if [ -e /dev/block/by-name/oplusreserve3 ]; then
        dd if=/sdcard/zero5 of=/dev/block/by-name/oplusreserve3 bs=1m seek=16
        #dd if=/data/persist_log/oplusreserve/media/log/shutdown/zero6 of=/dev/block/by-name/oplusreserve3 bs=1m seek=16
        LOG_DEV="/dev/block/by-name/oplusreserve3"
        logcat --buffer-size=4M

    elif [ -e /dev/block/by-name/reserve3 ]; then
        dd if=/sdcard/zero5 of=/dev/block/by-name/reserve3 bs=1m seek=16
        LOG_DEV="/dev/block/by-name/reserve3"
        logcat --buffer-size=4M
    else
        dd if=/sdcard/zero5 of=/dev/block/by-name/opporeserve3 bs=1m seek=16
        LOG_DEV="/dev/block/by-name/opporeserve3"
        logcat --buffer-size=4M
    fi

    rm -rf /sdcard/zero5
    #rm -rf /data/persist_log/oplusreserve/media/log/shutdown/zero6

    #Handle the logcat at the place of 16M from beginning of reserve3
    logcat -b crash -b main -b system -d > /data/persist_log/oplusreserve/media/log/shutdown/temp_logcat
    dd if=/data/persist_log/oplusreserve/media/log/shutdown/temp_logcat of=${LOG_DEV} bs=1m count=4 seek=16
    rm -rf /data/persist_log/oplusreserve/media/log/shutdown/temp_logcat

    #clean 64bit at the place of 16M,to make a sign
    dd if=/dev/zero of=${LOG_DEV} bs=1 count=64
    echo "rebootdetectcapture at ${CURTIME_FORMAT}" > /data/persist_log/oplusreserve/media/log/shutdown/temp_notify
    dd if=/data/persist_log/oplusreserve/media/log/shutdown/temp_notify of=${LOG_DEV} bs=64 seek=256k
    rm -rf /data/persist_log/oplusreserve/media/log/shutdown/temp_notify

    # Handle kmsg dump at the place of 20M from beginning of reserve3
    dmesg |tail -c 1048576> /data/persist_log/oplusreserve/media/log/shutdown/temp_dmesg
    dd if=/data/persist_log/oplusreserve/media/log/shutdown/temp_dmesg of=${LOG_DEV} bs=1m count=1 seek=20
    rm -rf /data/persist_log/oplusreserve/media/log/shutdown/temp_dmesg

    setprop sys.debug.rebootdetectcapture 1
}
#endif /*OPLUS_BUG_STABILITY*/

#ifdef OPLUS_BUG_STABILITY
#Jason.Yu@ANDROID.STABILITY.3502573.2022/04/15.add for catch ps and binder infos when SWT happened
function catch_ps_binder_infos() {
    LOGTIME=`date +%F-%H-%M-%S`
    PS_BINDER_INFOS_DIR=${DATA_OPLUS_LOG_PATH}/DCS/de/ps_binder_infos/${LOGTIME}

    echo ${PS_BINDER_INFOS_DIR}
    if [ ! -d "${PS_BINDER_INFOS_DIR}" ]; then
        mkdir -p ${PS_BINDER_INFOS_DIR}
        chown system:system ${PS_BINDER_INFOS_DIR}
        chmod 777 ${PS_BINDER_INFOS_DIR}
    fi
    ps -A -T > ${PS_BINDER_INFOS_DIR}/ps_AT.txt
    cat /dev/binderfs/binder_logs/state > ${PS_BINDER_INFOS_DIR}/binder_info.txt

    wait
}
#endif /*OPLUS_BUG_STABILITY*/

function oplus_compact_memory() {
	echo 1 > "/proc/sys/vm/compact_memory"
}

#ifdef OPLUS_BUG_STABILITY
#Daibo.Le@ANDROID.STABILITY, 2023/06/30, add for BBDS collecting binder log
function binder_infos_capture() {
    REASON_NAME=`getprop sys.debug.bbdscollectbinderreason`
    if [ "${REASON_NAME}" == "" ]; then
        REASON_NAME="binderinfo"
    fi

    STABILITY_LOG_PATH="${DATA_OPLUS_LOG_PATH}/DCS/de/stability_monitor"
    BINDER_LOG_DIR="${STABILITY_LOG_PATH}/${REASON_NAME}"
    if [ ! -d "${BINDER_LOG_DIR}" ]; then
        mkdir -p ${BINDER_LOG_DIR}
        chown system:system ${BINDER_LOG_DIR}
        chmod 777 ${BINDER_LOG_DIR}
    fi
    if [ -f "/dev/binderfs/binder_logs/state" ]; then
        cat /dev/binderfs/binder_logs/state > ${BINDER_LOG_DIR}/state
        cat /dev/binderfs/binder_logs/stats > ${BINDER_LOG_DIR}/stats
        cat /dev/binderfs/binder_logs/transaction_log > ${BINDER_LOG_DIR}/transaction_log
        cat /dev/binderfs/binder_logs/transactions > ${BINDER_LOG_DIR}/transactions
    else
        cat /d/binder/state > ${BINDER_LOG_DIR}/state
        cat /d/binder/stats > ${BINDER_LOG_DIR}/stats
        cat /d/binder/transaction_log > ${BINDER_LOG_DIR}/transaction_log
        cat /d/binder/transactions > ${BINDER_LOG_DIR}/transactions
    fi

    debuggerd -j `pidof system_server` > ${BINDER_LOG_DIR}/system_server.txt &
    logcat -b crash -b events -b main -b system -d > ${BINDER_LOG_DIR}/logcat.txt &
    dmesg > ${BINDER_LOG_DIR}/dmesg.txt &
    #Jiaqi.Hao@Android.Stability,2024/11/19, add for get more ps info of BBDS binder log
    ps -AT -O NAME > ${BINDER_LOG_DIR}/ps.txt &

    logtime=`date +%F-%H-%M-%S`
    uuid=`cat /proc/sys/kernel/random/uuid`
    version=`getprop ro.build.version.ota`
    sleep 10

    filename="${STABILITY_LOG_PATH}/${REASON_NAME}@${uuid}@${version}@${logtime}.tar.gz"
    tar -czvf ${filename} -C ${STABILITY_LOG_PATH} ${REASON_NAME}
    chown system:system ${filename}
    chmod 0666 ${filename}
    rm -rf ${BINDER_LOG_DIR}
}
#endif /*OPLUS_BUG_STABILITY*/

#ifdef OPLUS_ANR_LOG_ENHANCEMENT_HELPER
#Jason.Yu@ANDROID.STABILITY, 2023/12/11, add for Anr Log Enhancement
function catch_nfw_info() {
    NFW_DIR=${DATA_OPLUS_LOG_PATH}/nfw_info
    if [ ! -d ${NFW_DIR} ];then
        mkdir -p ${NFW_DIR}
    fi

    FileNum=$(ls -l ${NFW_DIR} | grep "^d"| wc -l)
    if [ ${FileNum} -ge 10 ]; then
        oldDir=$(ls -rt ${NFW_DIR} | head -1)
        rm -rf ${NFW_DIR}/${oldDir}
    fi

    LOGTIME=`date +%F-%H-%M-%S`
    TIME_DIR=${NFW_DIR}/${LOGTIME}
    mkdir -p ${TIME_DIR}
    dumpsys -t 5  SurfaceFlinger > ${TIME_DIR}/sf.txt
    chmod -R 777 ${NFW_DIR}
    chown -R system:system ${NFW_DIR}
}
#endif /* OPLUS_ANR_LOG_ENHANCEMENT_HELPER */

case "$config" in
    "bugreportandtransfer")
        bugreportandtransfer
        ;;
#Shuangquan.du@PSW.AD.Recovery.0, 2019/07/03, add for generate runtime prop
    "generate_runtime_prop")
        generate_runtime_prop
        ;;
#endif
#Xuefeng.Peng@PSW.AD.Performance.Storage.1721598, 2018/12/26, Add for abnormal sd card shutdown long time
    "exstorage_support")
        exstorage_support
        ;;
    "gettpinfo")
        gettpinfo
    ;;
    "inittpdebug")
        inittpdebug
    ;;
    "settplevel")
        settplevel
    ;;
#Deliang.Peng, 2017/7/7,add for native watchdog
    "nativedump")
        nativedump
    ;;
#Jianping.Zheng 2017/04/04, Add for record performance
        "perf_record")
        perf_record
    ;;
    #Fei.Mo, 2017/09/01 ,Add for power monitor top info
    "thermal_top")
        thermalTop
    #end, Add for power monitor top info
    ;;
#Linjie.Xu@PSW.AD.Power.PowerMonitor.1104067, 2018/01/17, Add for OplusPowerMonitor get dmesg at O
        "kernelcacheforopm")
        kernelcacheforopm
    ;;
        "printMtkSleepState")
        printMtkSleepState
    ;;
#Jianfa.Chen@PSW.AD.PowerMonitor,add for powermonitor getting Xlog
        "catchWXlogForOpm")
        catchWXlogForOpm
    ;;
        "catchQQlogForOpm")
        catchQQlogForOpm
    ;;
# Qiurun.Zhou@ANDROID.DEBUG, 2022/6/17, copy wxlog for EAP
        "eapCopyWXlog")
        eapCopyWXlog
    ;;
#endif /* THIRD_PART_LOG_FOR_OPM */
        "psforopm")
        psforopm
    ;;
# WangMin@ANDROID.RESCONTROL, 2023/05/11, Add for save newest wxlog when wx memleak
        "copyWXlogForMemLeak")
        copyWXlogForMemLeak
    ;;
# WangMin@ANDROID.RESCONTROL, 2023/12/13, Add for save newest browser xlog when com.haytap.browser memleak
        "copyBrowserXlogForMemLeak")
        copyBrowserXlogForMemLeak
    ;;
# Zhurui2@ANDROID.STABILITY, 2023/11/17, add for save newest wxlog when theia anr\crash\nfw
        "copyXlogForTheia")
        copyXlogForTheia
    ;;
        "tranferPowerRelated")
        tranferPowerRelated
    ;;
        "startSsLogPower")
        startSsLogPower
    ;;
        "logcatMainCacheForOpm")
        logcatMainCacheForOpm
    ;;
        "logcatEventCacheForOpm")
        logcatEventCacheForOpm
    ;;
        "logcatRadioCacheForOpm")
        logcatRadioCacheForOpm
    ;;
        "catchBinderInfoForOpm")
        catchBinderInfoForOpm
    ;;
        "catchInterruptsInfoForOpm")
        catchInterruptsInfoForOpm
        "catchHfManagerForOpm"
        catchHfManagerForOpm
    ;;
        "catchBattertFccForOpm")
        catchBattertFccForOpm
    ;;
        "catchTopInfoForOpm")
        catchTopInfoForOpm
    ;;
          "dumpsysHansHistoryForOpm")
        dumpsysHansHistoryForOpm
    ;;
        "getPropForOpm")
        getPropForOpm
    ;;
        "dumpsysSurfaceFlingerForOpm")
        dumpsysSurfaceFlingerForOpm
    ;;
        "dumpsysSensorserviceForOpm")
        dumpsysSensorserviceForOpm
    ;;
        "dumpsysBatterystatsForOpm")
        dumpsysBatterystatsForOpm
    ;;
        "dumpsysBatterystatsOplusCheckinForOpm")
        dumpsysBatterystatsOplusCheckinForOpm
    ;;
        "dumpsysBatterystatsCheckinForOpm")
        dumpsysBatterystatsCheckinForOpm
    ;;
        "dumpsysMediaForOpm")
        dumpsysMediaForOpm
    ;;
        "clearMtkDebuglogger")
        clearMtkDebuglogger
    ;;
    "pwkdumpon")
        pwkdumpon
        ;;
    "pwkdumpoff")
        pwkdumpoff
        ;;
    "mrdumpon")
        mrdumpon
        ;;
    "mrdumpoff")
        mrdumpoff
        ;;
#Miao.Yu@ANDROID.WMS, 2019/11/25, Add for dump wm info
    "dumpWm")
        dumpWm
        ;;
    "tranfer_anr")
        transferAnr
        ;;
    "tranfer_tombstone")
        transferTombstone
        ;;
        "logcusmain")
        logcusmain
    ;;
        "logcusevent")
        logcusevent
    ;;
        "logcusradio")
        logcusradio
    ;;
        "customdmesg")
        customdmesg
    ;;
        "checkAeeLogs")
        checkAeeLogs
    ;;
        "dumpenvironment")
        DumpEnvironment
    ;;
        "slabinfoforhealth")
        slabinfoforhealth
    ;;
        "svelteforhealth")
        svelteforhealth
    ;;
        "meminfoforhealth")
        meminfoforhealth
    ;;
        "dmaprocsforhealth")
        dmaprocsforhealth
    ;;
    #ifdef OPLUS_FEATURE_EAP
    #Haifei.Liu@ANDROID.RESCONTROL, 2020/08/18, Add for copy binder_info
    "copyEapBinderInfo")
        copyEapBinderInfo
    ;;
    #endif /* OPLUS_FEATURE_EAP */
    # ifdef OPLUS_FEATURE_THEIA
    # Yangkai.Yu@ANDROID.STABILITY, Add hook for TheiaBinderBlock
    "copyTheiaBinderInfo")
        copyTheiaBinderInfo
    ;;
    # endif /*OPLUS_FEATURE_THEIA*/
#Xiaomin.Yang@PSW.CN.BT.Basic.Customize.1586031,2018/12/02, Add for updating wcn firmware by sau
    "wcnfirmwareupdate")
        wcnfirmwareupdate
        ;;
    "wcnfirmwareupdatedump")
        wcnfirmwareupdatedump
        ;;
# Kun.Hu@PSW.TECH.RELIABILTY, 2019/1/3, fix the core domain limits to search /mnt/vendor/oplusreserve
        "remount_oplusreserve2")
        remount_oplusreserve2
    ;;
#ifdef OPLUS_FEATURE_SHUTDOWN_DETECT
        "remount_oplusreserve2_shutdown")
        remount_oplusreserve2_shutdown
    ;;
#endif
    "cleanpcmdump")
        cleanpcmdump
    ;;
    "oidtlogs")
        oidtlogs
    ;;
#zhaochengsheng@PSW.CN.WiFi.Basic.Custom.2204034, 2019/07/29
#add for Add for:solve camera interference ANT.
    "iwprivswapant0")
        iwprivswapant0
    ;;
    "iwprivswapant1")
        iwprivswapant1
    ;;
    "iwprivswitchswapant")
        iwprivswitchswapant
    ;;

#genglin.lian@PSW.CN.WiFi.Connect.Network.23456788, 2019/9/23
#Add enable/disable interface for SmartGear
    "disableSmartGear")
        disableSmartGear
    ;;
    "enableSmartGear")
        enableSmartGear
    ;;
#add for firstboot log
        "resetlogfirstbootbuffer")
        resetlogfirstbootbuffer
    ;;
        "logfirstbootmain")
        logfirstbootmain
    ;;
        "logfirstbootevent")
        logfirstbootevent
    ;;
        "logfirstbootkernel")
        logfirstbootkernel
    ;;
    "testtransfersystem")
        testTransferSystem
    ;;
	"testtransferroot")
        testTransferRoot
    ;;
#ifdef OPLUS_DEBUG_SSLOG_CATCH
#Asiga@NETWORK.POWER 2021/03/11,add for mtk catch ss log
        "logcatSsLog")
        logcatSsLog
    ;;
#endif
#ifdef OPLUS_FEATURE_MEMLEAK_DETECT
        "storeSvelteLog")
        storeSvelteLog
    ;;
#endif /* OPLUS_FEATURE_MEMLEAK_DETECT */
    "chmoddcsenpath")
        chmodDcsEnPath
    ;;
    "backup_minidumplog")
        backupMinidump
    ;;
#ifdef OPLUS_FEATURE_WIFI_LOG
#Chuanye.Xu@OPLUS_FEATURE_WIFI_LOG, 2022/06/29 , add for collect wifi log
        "captureTcpdumpLog")
        captureTcpdumpLog
    ;;
    "tcpdumplog")
        initLogSizeAndNums
        tcpDumpLog
    ;;
#endif /* OPLUS_FEATURE_WIFI_LOG */
#ifdef OPLUS_BUG_STABILITY
#Tian.Pan@ANDROID.STABILITY.3054721.2020/08/31.add for fix debug system_server register too many receivers issue.
    "receiverinfocapture")
        receiverinfocapture
        ;;
#endif /*OPLUS_BUG_STABILITY*/

#ifdef OPLUS_BUG_STABILITY
#Yongqiang.Du@ANDROID.Stability.Crash.0, 2022/08/08, Add for shutdown reason recorder
    "rebootdetectcapture")
        rebootdetectcapture
        ;;
#endif /*OPLUS_BUG_STABILITY*/

#ifdef OPLUS_BUG_STABILITY
#Jason.Yu@ANDROID.STABILITY.3502573.2022/04/15.add for catch ps and binder infos when SWT happened
    "catch_ps_binder_infos")
        catch_ps_binder_infos
        ;;
#endif /*OPLUS_BUG_STABILITY*/
    "oplus_compact_memory")
        oplus_compact_memory
        ;;
#ifdef OPLUS_BUG_STABILITY
#Daibo.Le@ANDROID.STABILITY, 2023/06/30, add for BBDS collecting binder log
    "binder_infos_capture")
        binder_infos_capture
        ;;
#endif /*OPLUS_BUG_STABILITY*/
#ifdef OPLUS_ANR_LOG_ENHANCEMENT_HELPER
#Jason.Yu@ANDROID.STABILITY, 2023/12/11, add for Anr Log Enhancement
    "catch_nfw_info")
        catch_nfw_info
        ;;
#endif /* OPLUS_ANR_LOG_ENHANCEMENT_HELPER */
    "kpoc_init_log_cache")
        kpoc_collect_log
        ;;
    "kpoc_kernel_log_cache")
        kpoc_kernel_log_cache
        ;;
    "kpoc_kmsg_loop_cache")
        kpoc_kmsg_loop_cache
        ;;
    "kpoc_mainlog_cache")
        kpoc_mainlog_cache
        ;;
       *)

      ;;
esac
