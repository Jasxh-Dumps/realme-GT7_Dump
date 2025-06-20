#! /system/bin/sh

CURTIME=`date +%F_%H-%M-%S`
CURTIME_FORMAT=`date "+%Y-%m-%d %H:%M:%S"`

DEFAULT_LOG_BASE_PATH=/sdcard/Android/data/com.oplus.olc/files/Log
TEMP_LOG_PATH=/sdcard/Android/data/com.oplus.olc/files/Log/tempLog
SDCARD_LOG_BASE_PATH=`getprop persist.sys.olc.log.path ${DEFAULT_LOG_BASE_PATH}`
BASE_PATH=$(dirname $(dirname ${SDCARD_LOG_BASE_PATH}))
SDCARD_LOG_TRIGGER_PATH=${BASE_PATH}/trigger

DATA_DEBUGGING_PATH=/data/debugging
DATA_OPLUS_LOG_PATH=/data/persist_log
ANR_BINDER_PATH=${DATA_DEBUGGING_PATH}/anr_binder_info
CACHE_PATH=${DATA_DEBUGGING_PATH}/cache

config="$1"
LOG_USER_MODE=`getprop  persist.sys.log.user 0`
#================================== COMMON LOG =========================

function mkdirInSpecificPermission() {
    MKDIR_PATH=$1
    MKDIR_PERMISSION=$2
    if [ ! -d ${MKDIR_PATH} ]; then
        mkdir -p ${MKDIR_PATH}
    fi
    chmod ${MKDIR_PERMISSION} ${MKDIR_PATH} -R
    traceTransferState "chmod ${MKDIR_PERMISSION} ${MKDIR_PATH}"
}

function transfer_log() {
    traceTransferState "TRANSFER_LOG3:start...."

    chmod 2777 ${BASE_PATH} -R

    #define for new path
    stoptime=`getprop sys.oplus.log.stoptime`
    newpath="${SDCARD_LOG_BASE_PATH}/log@stop@${stoptime}"

    EXISTED_FILE=`ls ${SDCARD_LOG_BASE_PATH} | grep -v logkit_transfer.log | grep -v log@stop@${stoptime}`
    for SUB_DIR in ${EXISTED_FILE};do
        if [ -d ${SDCARD_LOG_BASE_PATH}/${SUB_DIR} ] ; then
            rm -rf ${SDCARD_LOG_BASE_PATH}/${SUB_DIR}
            traceTransferState "rm Existed Log Dir: ${SUB_DIR}"
        fi
    done

    LOG_TYPE=`getprop persist.sys.debuglog.config`

    # mkdir for newpath
    traceTransferState "TRANSFER_LOG3: make new directory ${newpath}"
    mkdirInSpecificPermission ${newpath} 2770

    #Custom transferModule
    if echo "$LOG_TYPE" | grep -q '[^0-9]';then
        transfer_logtype_${LOG_TYPE}
        reset_debuglogger_chmod_mtk
    else
        chmod_common_path
        transfer_logtype_digital
        reset_debuglogger_chmod_mtk
    fi
    setprop sys.tranfer.finished 1

    chmod 2777 ${BASE_PATH} -R
    SDCARDFS_ENABLED=`getprop external_storage.sdcardfs.enabled 1`
    traceTransferState "TRANSFER_LOG:SDCARDFS_ENABLED is ${SDCARDFS_ENABLED}"
    if [ "${SDCARDFS_ENABLED}" == "0" ]; then
        chown system:ext_data_rw ${BASE_FILES_PATH} -R
    fi

    #Zhangxueqiang@ANDROID.UPDATABILITY, 2020/11/24, add for save update_engine log
    mv ${SDCARD_LOG_BASE_PATH}/recovery_log/ ${newpath}/recovery

    #delete empty directory start
    traceTransferState "delete ${newpath} empty directory start"
    find ${newpath} -maxdepth 2 -type d -empty >> ${SDCARD_LOG_BASE_PATH}/logkit_transfer.log
    find ${newpath} -maxdepth 2 -type d -empty -exec rmdir --ignore-fail-on-non-empty {} \;
    traceTransferState "find ${newpath} empty directory again"
    find ${newpath} -maxdepth 1 -type d -empty >> ${SDCARD_LOG_BASE_PATH}/logkit_transfer.log
    find ${newpath} -maxdepth 1 -type d -empty -exec rmdir --ignore-fail-on-non-empty {} \;
    traceTransferState "delete ${newpath} empty directory end"
    #delete empty directory end

    # mv ap_log to minilog when alwayson enable
    move_aplog_to_minilog

    traceTransferState "TRANSFER_LOG:done...."
    mv ${SDCARD_LOG_BASE_PATH}/logkit_transfer.log ${newpath}/
    traceTransferState "TRANSFER_LOG3:done...."

    #reset olc log default path
    setprop persist.sys.olc.log.path ${DEFAULT_LOG_BASE_PATH}
}

function chmod_common_path() {
    chmod -R 777 ${DATA_DEBUGGING_PATH}
    chmod -R 777 ${DATA_OPLUS_LOG_PATH}
    MTK_DEBUGLOGGER_PATH=/data/debuglogger
    chmod -R 777 ${MTK_DEBUGLOGGER_PATH}
}

function reset_debuglogger_chmod_mtk() {
    is_qcom='getprop ro.hardware'
    if [ x"${is_qcom}" != x"qcom" ]; then
        MTK_DEBUGLOGGER_PATH=/data/debuglogger
        chmod -R 770 ${MTK_DEBUGLOGGER_PATH}
    fi
}

function move_aplog_to_minilog() {
    ALWAYSON_ENABLE=`getprop persist.sys.alwayson.enable`
    AP_LOG_PATH=${newpath}/common/ap_log
    if [ -d ${AP_LOG_PATH} ] && [ "x${ALWAYSON_ENABLE}" = x"true" ]; then
        # mv ap_log to minilog
        mv ${AP_LOG_PATH} ${newpath}/common/minilog
        traceTransferState "TRANSFERDEBUGGINGLOG:mv ap_log to minilog done"
    fi
}

function transfer_logtype_digital() {
    setprop sys.olc.transfer.running 1
    setprop sys.olc.dump.running 1
    setprop sys.olc.transfer.path ${newpath}

    #start dump log according to log_cmd_config.xml in transfer3_dumpSystem
    setprop ctl.start transfer3_dumpSystem

    #start transfer log according to log_path_config.xml
    transferLog ${LOG_TYPE}

    traceTransferState "check transferLog and dumpLog done"
    transferRunningFlag=1
    dumpRunningFlag=`getprop init.svc.transfer3_dumpSystem`
    timeCount=0
    while (([ ${transferRunningFlag} -eq 1 ] || [ "${dumpRunningFlag}" == "running" ]) && [ timeCount -le 30 ])
    do
        transferRunningFlag=`getprop sys.olc.transfer.running 0`
        dumpRunningFlag=`getprop init.svc.transfer3_dumpSystem`
        timeCount=$((timeCount + 1))
        traceTransferState "${CURTIME_FORMAT} ${LOGTAG}:count=$timeCount"
        sleep 1
    done
    setprop sys.olc.transfer.path ${TEMP_LOG_PATH}

    TRANSFER_MODULE=common
    collect_function_common_screenshots
}

function transferModules() {
    for element in "${moduleConfig[@]}"
    do
        traceTransferState "${element} Business transfer start..."
        mkdirInSpecificPermission ${newpath}/${element} 2770
        TRANSFER_MODULE=${element}
        collect_modulelog_${element}
    done

    checkStartServicesDone
    mv ${SDCARD_LOG_BASE_PATH}/bugreports/ ${newpath}/common/
}

function traceTransferState() {
    content=$1

    if [[ -d ${BASE_PATH} ]]; then
        if [[ ! -d ${SDCARD_LOG_BASE_PATH} ]]; then
            mkdir -p ${SDCARD_LOG_BASE_PATH}
            chmod 2770 ${BASE_PATH} -R
            echo "${CURTIME_FORMAT} TRACETRANSFERSTATE:${SDCARD_LOG_BASE_PATH} " >> ${SDCARD_LOG_BASE_PATH}/logkit_transfer.log
        fi

        currentTime=`date "+%Y-%m-%d %H:%M:%S"`
        echo "${currentTime} ${content} " >> ${SDCARD_LOG_BASE_PATH}/logkit_transfer.log
    fi

    LOG_LEVEL=$2
    if [[ "${LOG_LEVEL}" == "" ]]; then
        LOG_LEVEL=d
    fi
    log -p ${LOG_LEVEL} -t Debuglog ${content}
}

function checkNumberSizeAndCopy(){
    LOG_SOURCE_PATH="$1"
    LOG_TARGET_PATH="$2"
    LIMIT_SIZE="$3"
    LIMIT_NUM=500
    if [[ "${LIMIT_SIZE}" == "" ]]; then
        #500*1024KB
        LIMIT_SIZE="512000"
    fi
    traceTransferState "CNSAC:FROM ${LOG_SOURCE_PATH}"

    LOG_TYPE=`getprop persist.sys.debuglog.config`
    if [ "${LOG_TYPE}" == "aging" ]; then
       traceTransferState "copy log for aging" "i"
       cp -rf ${LOG_SOURCE_PATH}/* ${LOG_TARGET_PATH}
       traceTransferState "CNSAC:${LOG_SOURCE_PATH} done" "i"
       return
    fi

    if [[ -d "${LOG_SOURCE_PATH}" ]] && [[ ! "`ls -A ${LOG_SOURCE_PATH}`" = "" ]]; then
        TMP_LOG_NUM=`ls -lR ${LOG_SOURCE_PATH} |grep "^-"|wc -l | awk '{print $1}'`
        TMP_LOG_SIZE=`du -s -k ${LOG_SOURCE_PATH} | awk '{print $1}'`
        traceTransferState "CNSAC:NUM:${TMP_LOG_NUM}/${LIMIT_NUM} SIZE:${TMP_LOG_SIZE}/${LIMIT_SIZE}"
        if [[ ${TMP_LOG_NUM} -le ${LIMIT_NUM} ]] && [[ ${TMP_LOG_SIZE} -le ${LIMIT_SIZE} ]]; then
            if [[ ! -d ${LOG_TARGET_PATH} ]];then
                mkdir -p ${LOG_TARGET_PATH}
            fi

            cp -rf ${LOG_SOURCE_PATH}/* ${LOG_TARGET_PATH}
            traceTransferState "CNSAC:${LOG_SOURCE_PATH} done" "i"
        else
            traceTransferState "CNSAC:${LOG_SOURCE_PATH} NUM:${TMP_LOG_NUM}/${LIMIT_NUM} SIZE:${TMP_LOG_SIZE}/${LIMIT_SIZE}" "e"
            rm -rf ${LOG_SOURCE_PATH}/*
        fi
    fi
}
# Jiaqi.Hao@ANDROID.Stability,2022/08/25, add for logkit copy data/persist_log/hprofdump
function checkAgingAndMove(){
    LOG_SOURCE_PATH="$1"
    LOG_TARGET_PATH="$2"
    LOG_LIMIT_NUM="$3"
    LOG_LIMIT_SIZE="$4"
    traceTransferState "CHECKAGINGANDMOVE:FROM ${LOG_SOURCE_PATH}"
    LIMIT_NUM=500

    if [[ -d "${LOG_SOURCE_PATH}" ]] && [[ ! "`ls -A ${LOG_SOURCE_PATH}`" = "" ]]; then
        TMP_LOG_NUM=`ls -lR ${LOG_SOURCE_PATH} |grep "^-"|wc -l | awk '{print $1}'`
        traceTransferState "CHECKAGINGANDMOVE:NUM:${TMP_LOG_NUM}/${LIMIT_NUM}"
        if [[ ${TMP_LOG_NUM} -le ${LIMIT_NUM} ]]; then
            if [[ ! -d ${LOG_TARGET_PATH} ]];then
                mkdir -p ${LOG_TARGET_PATH}
            fi

            mv ${LOG_SOURCE_PATH}/* ${LOG_TARGET_PATH}
            traceTransferState "CHECKAGINGANDMOVE:${LOG_SOURCE_PATH} done"
        else
            traceTransferState "CHECKAGINGANDMOVE:${LOG_SOURCE_PATH} NUM:${TMP_LOG_NUM}/${LIMIT_NUM}"
            rm -rf ${LOG_SOURCE_PATH}/*
        fi
    fi
}

# Jiaqi.Hao@ANDROID.Stability,2023/07/12, add for logkit copy data/persist_log/hprofdump after that keep sourceFile
function checkAgingAndCopy(){
    LOG_SOURCE_PATH="$1"
    LOG_TARGET_PATH="$2"
    LOG_LIMIT_NUM="$3"
    LOG_LIMIT_SIZE="$4"
    traceTransferState "CHECKAGINGANDCOPY:FROM ${LOG_SOURCE_PATH}"
    LIMIT_NUM=500

    if [[ -d "${LOG_SOURCE_PATH}" ]] && [[ ! "`ls -A ${LOG_SOURCE_PATH}`" = "" ]]; then
        TMP_LOG_NUM=`ls -lR ${LOG_SOURCE_PATH} |grep "^-"|wc -l | awk '{print $1}'`
        traceTransferState "CHECKAGINGANDCOPY:NUM:${TMP_LOG_NUM}/${LIMIT_NUM}"
        if [[ ${TMP_LOG_NUM} -le ${LIMIT_NUM} ]]; then
            if [[ ! -d ${LOG_TARGET_PATH} ]];then
                mkdir -p ${LOG_TARGET_PATH}
            fi

            cp -rf ${LOG_SOURCE_PATH}/* ${LOG_TARGET_PATH}
            traceTransferState "CHECKAGINGANDCOPY:${LOG_SOURCE_PATH} done"
        else
            traceTransferState "CHECKAGINGANDCOPY:${LOG_SOURCE_PATH} NUM:${TMP_LOG_NUM}/${LIMIT_NUM}"
            rm -rf ${LOG_SOURCE_PATH}/*
        fi
    fi
}

function checkSmallSizeAndCopy(){
    LOG_SOURCE_PATH="$1"
    LOG_TARGET_PATH="$2"
    traceTransferState "CSSAC:from ${LOG_SOURCE_PATH}"
    # 10M
    LIMIT_SIZE="10240"

    LOG_TYPE=`getprop persist.sys.debuglog.config`
    if [ "${LOG_TYPE}" == "aging" ]; then
       traceTransferState "copy log for aging" "i"
       cp -rf ${LOG_SOURCE_PATH}/* ${LOG_TARGET_PATH}
       traceTransferState "CSSAC:${LOG_SOURCE_PATH} done" "i"
       return
    fi

    if [[ -d "${LOG_SOURCE_PATH}" ]] && [[ ! "`ls -A ${LOG_SOURCE_PATH}`" = "" ]]; then
        TMP_LOG_SIZE=`du -s -k ${LOG_SOURCE_PATH} | awk '{print $1}'`
        if [ ${TMP_LOG_SIZE} -le ${LIMIT_SIZE} ]; then  #log size less then 10M
            mkdir -p ${newpath}/${LOG_TARGET_PATH}
            cp -rf ${LOG_SOURCE_PATH}/* ${newpath}/${LOG_TARGET_PATH}
            traceTransferState "CSSAC:${LOG_SOURCE_PATH} SIZE_KB:${TMP_LOG_SIZE} done"
        else
            traceTransferState "CSSAC:${LOG_SOURCE_PATH} SIZE_KB:${TMP_LOG_SIZE}/${LIMIT_SIZE}"
        fi
    fi
}

function checkNumberSizeAndMove(){
    LOG_SOURCE_PATH="$1"
    LOG_TARGET_PATH="$2"
    LIMIT_SIZE="$3"
    LIMIT_NUM=500
    if [[ "${LIMIT_SIZE}" == "" ]]; then
        #500*1024KB
        LIMIT_SIZE="512000"
    fi
    traceTransferState "CNSAM::FROM ${LOG_SOURCE_PATH},LIMIT_SIZE=${LIMIT_SIZE}"

    LOG_TYPE=`getprop persist.sys.debuglog.config`
    if [ "${LOG_TYPE}" == "aging" ]; then
       traceTransferState "mv log for aging" "i"
       cp -rf ${LOG_SOURCE_PATH}/* ${LOG_TARGET_PATH}
       traceTransferState "CNSAM:${LOG_SOURCE_PATH} done" "i"
       return
    fi

    if [[ -d "${LOG_SOURCE_PATH}" ]] && [[ ! "`ls -A ${LOG_SOURCE_PATH}`" = "" ]]; then
        TMP_LOG_NUM=`ls -lR ${LOG_SOURCE_PATH} |grep "^-"|wc -l | awk '{print $1}'`
        TMP_LOG_SIZE=`du -s -k ${LOG_SOURCE_PATH} | awk '{print $1}'`
        traceTransferState "CNSAM:NUM:${TMP_LOG_NUM}/${LIMIT_NUM} SIZE:${TMP_LOG_SIZE}/${LIMIT_SIZE}"
        if [[ ${TMP_LOG_NUM} -le ${LIMIT_NUM} ]] && [[ ${TMP_LOG_SIZE} -le ${LIMIT_SIZE} ]]; then
            if [[ ! -d ${LOG_TARGET_PATH} ]];then
                mkdir -p ${LOG_TARGET_PATH}
            fi

            mv ${LOG_SOURCE_PATH}/* ${LOG_TARGET_PATH}
            traceTransferState "CNSAM:${LOG_SOURCE_PATH} done" "i"
        else
            traceTransferState "CNSAM:${LOG_SOURCE_PATH} NUM:${TMP_LOG_NUM}/${LIMIT_NUM} SIZE:${TMP_LOG_SIZE}/${LIMIT_SIZE}" "e"
            rm -rf ${LOG_SOURCE_PATH}/*
        fi
    else
        if [ -f "${LOG_SOURCE_PATH}" ]; then
            mv ${LOG_SOURCE_PATH} ${LOG_TARGET_PATH}
            traceTransferState "CNSAM:${LOG_SOURCE_PATH} done" "i"
        else
            traceTransferState "CNSAM:${LOG_SOURCE_PATH} is not a original File" "e"
        fi
    fi
}

#=============================TYPES=============================#

function transfer_logtype_call() {
    moduleConfig=(audio common power wifi thirdpart)
    transferModules
}

function transfer_logtype_display() {
    moduleConfig=(common display gps)
    transferModules
}

function transfer_logtype_brightness() {
    moduleConfig=(common display performance)
    transferModules
}

function transfer_logtype_media() {
    moduleConfig=(audio bluetooth common performance stability wifi)
    transferModules
}

function transfer_logtype_video() {
    moduleConfig=(audio common display performance stability thirdpart video wifi)
    transferModules
}

function transfer_logtype_bluetooth() {
    moduleConfig=(audio bluetooth common performance power stability thirdpart wifi)
    transferModules
}

function transfer_logtype_gps() {
    moduleConfig=(common gps thirdpart)
    transferModules
}

function transfer_logtype_network() {
    moduleConfig=(audio common power wifi thirdpart)
    transferModules
}

function transfer_logtype_wifi() {
    moduleConfig=(common performance power stability thirdpart wifi bluetooth)
    transferModules
}

function transfer_logtype_interconnection() {
    moduleConfig=(common bluetooth thirdpart wifi)
    transferModules
}

function transfer_logtype_inputmethod() {
    moduleConfig=(common display performance stability)
    transferModules
}

function transfer_logtype_stability() {
    moduleConfig=(audio bluetooth camera common display gps nfc performance power recovery stability theia thirdpart touch video wifi)
    transferModules
}

function transfer_logtype_heat() {
    moduleConfig=(common performance power systemapp)
    transferModules
}

function transfer_logtype_power() {
    moduleConfig=(audio bluetooth common display gps nfc power thirdpart video wifi systemapp)
    transferModules
}

function transfer_logtype_charge() {
    moduleConfig=(common performance power recovery stability)
    transferModules
}

function transfer_logtype_thirdpart() {
    moduleConfig=(audio common display performance power stability theia thirdpart touch video)
    transferModules
}

function transfer_logtype_camera() {
    moduleConfig=(camera common display gps performance stability touch)
    transferModules
}

function transfer_logtype_sensor() {
    moduleConfig=(camera common performance stability security)
    transferModules
}

function transfer_logtype_touch() {
    moduleConfig=(common display performance recovery stability thirdpart touch video)
    transferModules
}

function transfer_logtype_fingerprint() {
    moduleConfig=(common performance touch security)
    transferModules
}

function transfer_logtype_other() {
    moduleConfig=(audio bluetooth camera common display gps nfc performance power recovery stability theia thirdpart touch video wifi systemapp storage security)
    transferModules
}

function transfer_logtype_aging() {
    moduleConfig=(audio bluetooth camera common display gps nfc performance power recovery stability theia thirdpart touch video wifi systemapp storage security)
    transferModules
}

function transfer_logtype_junk() {
    moduleConfig=(audio common display performance stability theia thirdpart touch video wifi systemapp)
    transferModules
}

function transfer_logtype_storage() {
    moduleConfig=(common storage)
    transferModules
}

#=============================MODULES=============================#

function collect_modulelog_common() {
    #dumpsys /data/debugging/SI_stop
    collect_function_common_dumpSystem

    #anr
    collect_function_common_anrTomb

    #bugreport
    collect_function_common_bugreport

    #/data/debugging
    collect_function_common_debugging
    #tranferUser
    collect_function_common_user
    #/sdcard/Android/data/com.oplus.logkit/files/Log/trigger
    collect_function_common_trigger
    #/data/media/${m}/Pictures/Screenshots
    collect_function_common_screenshots
    #mv wm
    collect_function_common_wm
    #/data/persist_log
    collect_function_common_persistLog
    #/data/persist_log/TMP/OTRTA
    collect_function_common_OTRTA
}

function collect_modulelog_performance() {
    #/data/local/traces
    collect_function_performance_systemTrace
}

function collect_modulelog_bluetooth() {
    #bluetooth log
    traceTransferState "start collect_modulelog_bluetooth"
    collect_function_bluetooth_default
    #/data/persist_log/DCS/de/network_logs/bt_switch_log
    checkNumberSizeAndCopy "/data/persist_log/DCS/de/network_logs/bt_switch_log" "${newpath}/${TRANSFER_MODULE}/DCS/bt_switch_log"
    #/data/persist_log/DCS/de/network_logs/bt_fw_dump
    checkNumberSizeAndCopy "/data/persist_log/DCS/de/network_logs/bt_fw_dump" "${newpath}/${TRANSFER_MODULE}/DCS/bt_fw_dump"
    #/data/persist_log/DCS/de/network_logs/bt_hci_log
    checkNumberSizeAndCopy "/data/persist_log/DCS/de/network_logs/bt_hci_log" "${newpath}/${TRANSFER_MODULE}/DCS/bt_hci_log"
}

function collect_modulelog_power() {
    #copy thermalrec and powermonitor log
    collect_function_power_default
}

#Bin.Lv@BSP.Security.Basic, 2022/10/9, Add for security
function collect_modulelog_security() {
    #fingerprint log
    collect_function_security_default
}

function collect_modulelog_thirdpart() {
    #copy third-app log
    collect_function_thirdpart_default
    #Hongchao.Li@ANDROID.DEBUG, 2021/11/2, Add for copy wxlog and qlog
    collect_function_thirdpart_wx
    collect_function_thirdpart_q
    collect_function_thirdpart_problematicApp
}

function collect_modulelog_stability() {
    #/data/persist_log/hprofdump
    collect_function_stability_hprofDump
    #/data/aee_exp, only for MTK
    collect_function_stability_aee
    #/data/persist_log/DCS/de/AEE_DB
    checkNumberSizeAndCopy "/data/persist_log/DCS/de/AEE_DB" "${newpath}/${TRANSFER_MODULE}/DCS/AEE_DB"
    #/data/persist_log/DCS/de/stability_monitor/
    checkNumberSizeAndCopy "/data/persist_log/DCS/de/stability_monitor/" "${newpath}/${TRANSFER_MODULE}/DCS/stability_monitor"
    #/data/persist_log/oplusreserve
    checkNumberSizeAndCopy "/data/persist_log/oplusreserve" "${newpath}/${TRANSFER_MODULE}/oplusreserve2"
    #Jiaqi.Hao@ANDROID.Stability,2023/05/18, add for logkit copy minidump
    #/data/persist_log/de/minidump for QCOM
    checkNumberSizeAndCopy "/data/persist_log/DCS/de/minidump/" "${newpath}/${TRANSFER_MODULE}/minidump"
    #Zhurui2@ANDROID.STABILITY, 2023/05/24, add for reserve,such as expdb\oplusreserve1\oplusreserve5\oplusreserve3
    collect_op_reserve_info
}

function collect_op_reserve_info() {
    setprop ctl.start reserve_collect
}

function reserve_collect() {
    traceTransferState "reserve_collect:start...."
    stoptime=`getprop sys.oplus.log.stoptime`
    parent_path="${SDCARD_LOG_BASE_PATH}/log@stop@${stoptime}"
    TMP_PATH="${parent_path}/stability"

    #mtk expdb
    if [ -L /dev/block/by-name/expdb ]; then
        traceTransferState "collect op expdb expdblog:start"
        DATA_EXPDB_LOG=${DATA_OPLUS_LOG_PATH}/expdb
        TARGET_EXPDB_LOG=${TMP_PATH}/expdb

        if [[ ! -d ${DATA_EXPDB_LOG} ]];then
            mkdir -p ${DATA_EXPDB_LOG}
        fi

        touch ${DATA_EXPDB_LOG}/expdb.bin

        dd if=/dev/block/by-name/expdb of=${DATA_EXPDB_LOG}/expdb.bin bs=1M skip=$(($(blockdev --getsize64 /dev/block/by-name/expdb) / 1024 / 1024 - 2 )) count=2

        #/data/persist_log/expdb
        checkNumberSizeAndCopy "${DATA_EXPDB_LOG}" "${TARGET_EXPDB_LOG}"

        rm -rf ${DATA_EXPDB_LOG}

        traceTransferState "collect op expdb expdblog:end"
    else
        traceTransferState "expdb is not exist"
    fi

    #oplusreserve1
    if [ -L /dev/block/by-name/oplusreserve1 ]; then
        traceTransferState "collect op oplusreserve1 bootlog:start"
        DATA_RESERVE_ONE_LOG=${DATA_OPLUS_LOG_PATH}/oplusreserve1
        TARGET_RESERVE_ONE_LOG=${TMP_PATH}/oplusreserve1

        if [[ ! -d ${DATA_RESERVE_ONE_LOG} ]];then
            mkdir -p ${DATA_RESERVE_ONE_LOG}
        fi

        touch ${DATA_RESERVE_ONE_LOG}/bootlog.bin
        touch ${DATA_RESERVE_ONE_LOG}/shutdown.bin

        dd if=/dev/block/by-name/oplusreserve1 of=${DATA_RESERVE_ONE_LOG}/bootlog.bin bs=32k skip=135 count=4
        if [ -f /proc/devinfo/ufs ]; then
            dd if=/dev/block/by-name/oplusreserve1 of=${DATA_RESERVE_ONE_LOG}/shutdown.bin bs=512 skip=9440 count=4
        else
            dd if=/dev/block/by-name/oplusreserve1 of=${DATA_RESERVE_ONE_LOG}/shutdown.bin bs=512 skip=9076 count=4
        fi
        #/data/persist_log/oplusreserve1
        checkNumberSizeAndCopy "${DATA_RESERVE_ONE_LOG}" "${TARGET_RESERVE_ONE_LOG}"

        rm -rf ${DATA_RESERVE_ONE_LOG}
        traceTransferState "collect op oplusreserve1 bootlog:end"
    else
        traceTransferState "oplusreserve1 is not exist"
    fi

    #oplusreserve5
    if [ -L /dev/block/by-name/oplusreserve5 ]; then
        traceTransferState "collect op oplusreserve5 kernellog:start"
        DATA_RESERVE_FIVE_LOG=${DATA_OPLUS_LOG_PATH}/oplusreserve5
        TARGET_RESERVE_FIVE_LOG=${TMP_PATH}/oplusreserve5

        if [[ ! -d ${DATA_RESERVE_FIVE_LOG} ]];then
            mkdir -p ${DATA_RESERVE_FIVE_LOG}
        fi

        touch ${DATA_RESERVE_FIVE_LOG}/kernel.bin

        dd if=/dev/block/by-name/oplusreserve5 of=${DATA_RESERVE_FIVE_LOG}/kernel.bin bs=512k skip=8 count=32

        #/data/persist_log/oplusreserve5
        checkNumberSizeAndCopy "${DATA_RESERVE_FIVE_LOG}" "${TARGET_RESERVE_FIVE_LOG}"

        rm -rf ${DATA_RESERVE_FIVE_LOG}
        traceTransferState "collect op oplusreserve5 kernellog:end"
    else
        traceTransferState "oplusreserve5 is not exist"
    fi

    #oplusreserve3
    if [ -L /dev/block/by-name/oplusreserve3 ]; then
        traceTransferState "collect op oplusreserve3 shutdown detect log:start"
        DATA_RESERVE_THREE_LOG=${DATA_OPLUS_LOG_PATH}/oplusreserve3
        TARGET_RESERVE_THREE_LOG=${TMP_PATH}/oplusreserve3

        if [[ ! -d ${DATA_RESERVE_THREE_LOG} ]];then
            mkdir -p ${DATA_RESERVE_THREE_LOG}
        fi

        touch ${DATA_RESERVE_THREE_LOG}/shutdown_detect.bin

        dd if=/dev/block/by-name/oplusreserve3 of=${DATA_RESERVE_THREE_LOG}/shutdown_detect.bin bs=512k skip=32 count=10

        #/data/persist_log/oplusreserve3
        checkNumberSizeAndCopy "${DATA_RESERVE_THREE_LOG}" "${TARGET_RESERVE_THREE_LOG}"

        rm -rf ${DATA_RESERVE_THREE_LOG}
        traceTransferState "collect op oplusreserve3 shutdown detect log:end"
    else
        traceTransferState "oplusreserve3 is not exist"
    fi

    traceTransferState "reserve_collect:end...."
}

function collect_modulelog_recovery() {
    #recovery
    collect_function_recovery_default
}

function collect_modulelog_audio() {
    #/data/persist_log/TMP/pcm_dump
    collect_function_audio_pcm_dump
    #/data/persist_log/DCS/de/audio
    checkNumberSizeAndCopy "/data/persist_log/DCS/de/audio" "${newpath}/${TRANSFER_MODULE}/DCS/audio"
}

function collect_modulelog_touch() {
    #/sdcard/tp_debug_info.txt
    collect_function_touch_default
}

function collect_modulelog_video() {
    #/data/persist_log/TMP/videodump
    collect_function_video_videodump
    #/data/persist_log/DCS/de/video
    checkNumberSizeAndCopy "/data/persist_log/DCS/de/video" "${newpath}/${TRANSFER_MODULE}/DCS/video"
    #/data/persist_log/video
    checkNumberSizeAndCopy "/data/persist_log/video" "${newpath}/${TRANSFER_MODULE}"
}

function collect_modulelog_display() {
    #/Android/data/<package>/*.skp
    collect_function_display_skpfile
    #/data/persist_log/sf/raw
    collect_function_display_rawfile
    #/data/persist_log/DCS/de/psw_multimedia_perf
    checkNumberSizeAndCopy "/data/persist_log/DCS/de/psw_multimedia_perf" "${newpath}/${TRANSFER_MODULE}/DCS/psw_multimedia_perf"
    #/data/persist_log/DCS/de/psw_multimedia_display
    checkNumberSizeAndCopy "/data/persist_log/DCS/de/psw_multimedia_display" "${newpath}/${TRANSFER_MODULE}/DCS/psw_multimedia_display"
}

function collect_modulelog_camera() {
    #/data/persist_log/DCS/de/camera
    checkNumberSizeAndCopy "/data/persist_log/DCS/de/camera" "${newpath}/${TRANSFER_MODULE}/DCS/camera"
    #/data/persist_log/DCS/de/camera_hal
    checkNumberSizeAndCopy "/data/persist_log/DCS/de/camera_hal" "${newpath}/${TRANSFER_MODULE}/DCS/camera_hal"
}

function collect_modulelog_gps() {
    #/data/persist_log/DCS/de/gps
    checkNumberSizeAndCopy "/data/persist_log/DCS/de/gps" "${newpath}/${TRANSFER_MODULE}/DCS/gps"
}

function collect_modulelog_wifi() {
    #/data/persist_log/DCS/de/network_logs/wifi
    checkNumberSizeAndCopy "/data/persist_log/DCS/de/network_logs/wifi" "${newpath}/${TRANSFER_MODULE}/DCS/wifi"
    #/data/persist_log/DCS/de/network_logs/wifiSwitch
    checkNumberSizeAndCopy "/data/persist_log/DCS/de/network_logs/wifiSwitch" "${newpath}/${TRANSFER_MODULE}/DCS/wifiSwitch"
    #/data/persist_log/DCS/de/network_logs/wifi_dump
    checkNumberSizeAndCopy "/data/persist_log/DCS/de/network_logs/wifi_dump" "${newpath}/${TRANSFER_MODULE}/DCS/wifi_dump"
    #/data/persist_log/DCS/de/network_logs/stp_dump
    checkNumberSizeAndCopy "/data/persist_log/DCS/de/network_logs/stp_dump" "${newpath}/${TRANSFER_MODULE}/DCS/stp_dump"
    #/data/debugging/netconfig
    checkNumberSizeAndMove "/data/debugging/netconfig" "${newpath}/${TRANSFER_MODULE}/netconfig"
}

function collect_modulelog_nfc() {
    #/data/persist_log/DCS/de/nfc
    checkNumberSizeAndCopy "/data/persist_log/DCS/de/nfc" "${newpath}/${TRANSFER_MODULE}/DCS/nfc"
}

function collect_modulelog_theia() {
    #/data/persist_log/DCS/de/theia
    checkNumberSizeAndCopy "/data/persist_log/DCS/de/theia" "${newpath}/${TRANSFER_MODULE}/DCS/theia"
}

function collect_modulelog_systemapp() {
    #Pictorial
    PICTORIAL_LOG=/sdcard/Android/data/com.heytap.pictorial/files/xlog
    checkSmallSizeAndCopy "${PICTORIAL_LOG}" "${TRANSFER_MODULE}/com.heytap.pictorial"

    #Browser
    BROWSER_LOG=/sdcard/Android/data/com.heytap.browser/files/xlog
    checkSmallSizeAndCopy "${BROWSER_LOG}" "${TRANSFER_MODULE}/com.heytap.browser"

    #OBRAIN
    OBRAIN_LOG=/data/misc/midas/xlog
    checkNumberSizeAndMove "${OBRAIN_LOG}" "${newpath}/${TRANSFER_MODULE}/com.oplus.obrain" "51200"

    #YOLI
    YOLI_LOG1=/sdcard/Android/data/com.heytap.yoli/files/yoliVideo/xlog
    checkSmallSizeAndCopy "${YOLI_LOG1}" "${TRANSFER_MODULE}/com.heytap.yoli"

    #common path
    cp /sdcard/Documents/*/.dog/* "${TRANSFER_MODULE}"
    traceTransferState "transfer log:copy system app done"
}

function collect_modulelog_storage() {
    #data/system/abc.json
    traceTransferState "cp /data/persist_log/storage/* start"
    fs_mgr_log="/mnt/oplus/op2/fs_mgr_log"
    storage_files="/data/persist_log/storage"
    chmod 770 ${fs_mgr_log}
    if [ ! -d ${storage_files} ]; then
        traceTransferState "mkdir /data/persist_log/storage..."
        mkdir -p ${storage_files};
    fi
    chmod 770 ${storage_files}/*
    if [ -e ${fs_mgr_log} ]; then
        traceTransferState "cp /mnt/oplus/op2/fs_mgr_log..."
        cp -rf ${fs_mgr_log} ${storage_files}
    else
        traceTransferState "cp /mnt/oplus/op2/fs_mgr_log failed, because the log file does not exist"
    fi
    storage_file_dir=${newpath}/${TRANSFER_MODULE}
    mkdir -p ${storage_file_dir};
    chmod -R 777 ${storage_file_dir};
    if [ -d ${storage_files} ] && [ "`ls -A ${storage_files}`" != "" ]; then
        traceTransferState "cp /data/persist_log/storage/*..."
        cp -rf ${storage_files}/* ${storage_file_dir}
        traceTransferState "rm -f /data/persist_log/storage/*"
        rm -f ${storage_files}/*
    fi
}

#=============================FUNCTIONS=============================#

#/data/debugging
#/data/debuglogger
function collect_function_common_debugging() {
    chmod -R 777 ${DATA_DEBUGGING_PATH}
    ALWAYSON_ENABLE=`getprop persist.sys.alwayson.enable`
    # filter SI_stop/
    traceTransferState "TRANSFERDEBUGGINGLOG start "
    if [ -d ${DATA_DEBUGGING_PATH} ]; then
        if [[ "${ALWAYSON_ENABLE}" = "true" ]]; then
            # cp minilog
            MTK_MINILOG_PATH=${DATA_DEBUGGING_PATH}/minilog
            cp -rf ${MTK_MINILOG_PATH} ${newpath}/${TRANSFER_MODULE}
            traceTransferState "TRANSFERDEBUGGINGLOG:cp ${MTK_MINILOG_PATH} done"

            # cp ap_log
            AP_LOG_PATH=/data/log/ap_log
            if [ -d ${AP_LOG_PATH} ]; then
                cp -rf ${AP_LOG_PATH} ${newpath}/${TRANSFER_MODULE}
                traceTransferState "TRANSFERDEBUGGINGLOG:cp ${AP_LOG_PATH} done"
            fi

            ALL_SUB_DIR=`ls ${DATA_DEBUGGING_PATH} | grep -v SI_stop | grep -v minilog |grep -v netlog |grep -v netconfig | grep -v security`
            for SUB_DIR in ${ALL_SUB_DIR};do
                if [ -d ${DATA_DEBUGGING_PATH}/${SUB_DIR} ] || [ -f ${DATA_DEBUGGING_PATH}/${SUB_DIR} ]; then
                    mv -f ${DATA_DEBUGGING_PATH}/${SUB_DIR} ${newpath}/${TRANSFER_MODULE}
                    traceTransferState "TRANSFERDEBUGGINGLOG:mv ${DATA_DEBUGGING_PATH}/${SUB_DIR} done"
                fi
            done
            if [ ! -d "/data/debuglogger/netlog" ]; then
                checkNumberSizeAndCopy "${DATA_DEBUGGING_PATH}/netlog" "${newpath}/${TRANSFER_MODULE}/netlog"
            fi
        else
            ALL_SUB_DIR=`ls ${DATA_DEBUGGING_PATH} |grep -v netconfig | grep -v security`
            for SUB_DIR in ${ALL_SUB_DIR};do
                if [ -d ${DATA_DEBUGGING_PATH}/${SUB_DIR} ] || [ -f ${DATA_DEBUGGING_PATH}/${SUB_DIR} ]; then
                    mv -f ${DATA_DEBUGGING_PATH}/${SUB_DIR} ${newpath}/${TRANSFER_MODULE}
                    traceTransferState "TRANSFERDEBUGGINGLOG:mv ${DATA_DEBUGGING_PATH}/${SUB_DIR} done"
                fi
            done
        fi
    fi

    # MTK
    MTK_DEBUGLOGGER_PATH=/data/debuglogger
    chmod -R 777 ${MTK_DEBUGLOGGER_PATH}
    if [ -d ${MTK_DEBUGLOGGER_PATH} ]; then
        TARGET_DEBUGLOGGER_PATH=${newpath}/${TRANSFER_MODULE}/debuglogger
        mkdirInSpecificPermission ${TARGET_DEBUGLOGGER_PATH} 2770

        # mv debuglogger without mobilelog
        ALL_SUB_DIR=`ls ${MTK_DEBUGLOGGER_PATH} | grep -v mobilelog`
        for SUB_DIR in ${ALL_SUB_DIR};do
            if [[ -d ${MTK_DEBUGLOGGER_PATH}/${SUB_DIR} ]] || [[ -f ${MTK_DEBUGLOGGER_PATH}/${SUB_DIR} ]]; then
                mv ${MTK_DEBUGLOGGER_PATH}/${SUB_DIR} ${TARGET_DEBUGLOGGER_PATH}
                traceTransferState "TRANSFERDEBUGLOGGERLOG:mv ${MTK_DEBUGLOGGER_PATH}/${SUB_DIR} done"
            fi
        done

        # cp/mv mobilelog
        MTK_MOBILELOG_PATH=/data/debuglogger/mobilelog
        if [[ "${ALWAYSON_ENABLE}" = "true" ]] && [[ "${LOG_USER_MODE}" = "1" ]]; then
            cp -rf ${MTK_MOBILELOG_PATH} ${TARGET_DEBUGLOGGER_PATH}
            traceTransferState "TRANSFERDEBUGLOGGERLOG:cp ${MTK_MOBILELOG_PATH} done"
        else
            mv ${MTK_MOBILELOG_PATH} ${TARGET_DEBUGLOGGER_PATH}
            traceTransferState "TRANSFERDEBUGLOGGERLOG:mv ${MTK_MOBILELOG_PATH} done"
        fi
    fi
    traceTransferState "TRANSFERDEBUGGINGLOG done "
}

#dumpsys xxx > xxx.txt
function collect_function_common_dumpSystem() {
    setprop ctl.start transfer3_dumpSystem
}

#/data/anr /data/tombstones
function collect_function_common_anrTomb() {
    traceTransferState "collect_function_common_anrTomb:start...."
    setprop ctl.start transfer3_anrtomb
}

#
function collect_function_common_bugreport() {
    setprop ctl.start transfer_bugreport
}

#/Android/data/<package>/*.skp
function collect_function_display_skpfile() {
    total_size=0
    limte_size=204800
    skp_file_list="/data/persist_log/sf/skp_file_list.txt"
    skp_file_dir=${newpath}/${TRANSFER_MODULE}/SKP
    mkdir -p ${skp_file_dir};
    chmod -R 777 ${skp_file_dir};

    if [[ -f "${skp_file_list}" ]]; then
        for skpfile in $(cat ${skp_file_list});do
            if [[ -f "${skpfile}" ]] && [[ ${total_size} -le ${limte_size} ]]; then
                skpfile_size=`du -s -k ${skpfile} | awk '{print $1}'`
                let total_size+=${skpfile_size}
                if [[ ${total_size} -le ${limte_size} ]]; then
                    mv -f ${skpfile} ${skp_file_dir}
                    traceTransferState "CSSAC:${skpfile}-${skpfile_size} done"
                else
                    traceTransferState "CSSAC:${skpfile} SIZE:${total_size}/${limte_size}"
                fi
            else
                rm -f ${skpfile}
            fi
        done
        rm -f ${skp_file_list};
    fi
}

#/data/persist_log/sf/raw
function collect_function_display_rawfile() {
    raw_file_dir=${newpath}/${TRANSFER_MODULE}/RAW
    mkdir -p ${raw_file_dir};
    chmod -R 777 ${raw_file_dir};
    DATA_TMP_LOG=${DATA_OPLUS_LOG_PATH}/sf/raw
    checkNumberSizeAndMove "${DATA_TMP_LOG}" "${raw_file_dir}"
}

#/data/persist_log/hprofdump
function collect_function_stability_hprofDump() {
    DATA_HPROF_LOG=${DATA_OPLUS_LOG_PATH}
    # Jiaqi.Hao@ANDROID.Stability,2022/08/25, add for logkit copy data/persist_log/hprofdump
    TARGET_DATA_HPROF_LOG=${newpath}/${TRANSFER_MODULE}

    if [[ -d ${DATA_HPROF_LOG} ]]; then
        ALL_SUB_DIR=`ls ${DATA_HPROF_LOG} | grep hprofdump`
        for SUB_DIR in ${ALL_SUB_DIR};do
            if [[ -d ${DATA_HPROF_LOG}/${SUB_DIR} ]] || [[ -f ${DATA_HPROF_LOG}/${SUB_DIR} ]]; then
                checkAgingAndCopy "${DATA_HPROF_LOG}/${SUB_DIR}" "${TARGET_DATA_HPROF_LOG}/${SUB_DIR}"
            fi
        done
    fi
}

#/data/persist_log/TMP/OTRTA
function collect_function_common_OTRTA() {
    DATA_TMP_LOG=${DATA_OPLUS_LOG_PATH}/TMP/OTRTA
    TARGET_DATA_TMP_LOG=${newpath}/${TRANSFER_MODULE}/assistlog/OTRTA
    checkNumberSizeAndMove "${DATA_TMP_LOG}" "${TARGET_DATA_TMP_LOG}"
}

#/sdcard/Android/data/com.oplus.logkit/files/Log/trigger
function collect_function_common_trigger() {
    mv ${SDCARD_LOG_TRIGGER_PATH} ${newpath}/${TRANSFER_MODULE}
}

#/data/media/${m}/Pictures/Screenshots
function collect_function_common_screenshots() {
    MAX_NUM=5
    is_release=`getprop ro.build.release_type`
    if [ x"${is_release}" != x"true" ]; then
        #Zhiming.chen@ANDROID.DEBUG.BugID 2724830, 2019/12/17,The log tool captures child user screenshots
        ALL_USER=`ls -t /data/media/`
        for m in $ALL_USER;
        do
            IDX=0
            screen_shot="/data/media/${m}/Pictures/Screenshots/"
            if [ -d "${screen_shot}" ]; then
                mkdir -p ${newpath}/${TRANSFER_MODULE}/Screenshots/$m
                touch ${newpath}/${TRANSFER_MODULE}/Screenshots/${m}/.nomedia
                ALL_FILE=`ls -t ${screen_shot}`
                for index in ${ALL_FILE};
                do
                    let IDX=${IDX}+1;
                    if [ "$IDX" -lt ${MAX_NUM} ] ; then
                       cp $screen_shot/${index} ${newpath}/${TRANSFER_MODULE}/Screenshots/${m}/
                       traceTransferState "${IDX}: ${index} done"
                    fi
                done
                traceTransferState "copy /${m} screenshots done"
            fi
        done
    fi
}

#/data/misc/bluetooth/logs
#/data/misc/bluetooth/cached_hci
function collect_function_bluetooth_default() {
    checkNumberSizeAndCopy "/data/misc/bluetooth/logs" "${newpath}/${TRANSFER_MODULE}/btsnoop_hci"
    #Laixin@CONNECTIVITY.BT.Basic.Log.70745, modify for auto capture hci log
    checkNumberSizeAndCopy "/data/misc/bluetooth/cached_hci" "${newpath}/${TRANSFER_MODULE}/btsnoop_hci"
    #Xiongxing@CONNECTIVITY.BT.Basic.Log.5554397, modify for auto capture hci log
    checkNumberSizeAndCopy "/data/bt_log" "${newpath}/${TRANSFER_MODULE}/btsnoop_hci"
    #Chenliyun@CONNECTIVITY.BT.Basic.Log.5819244, modify for capture hci log
    checkNumberSizeAndCopy "/data/misc/bthci" "${newpath}/${TRANSFER_MODULE}/btsnoop_hci"

    #KeLiangwen@CONNECTIVITY.BT.Basic.Log.4931193, modify for auto capture oardump log
    chmod -R 777 "/data/misc/eardump"
    is_release=`getprop ro.build.release_type`
    if [ "${is_release}" = "true" ] ;then
        checkNumberSizeAndMove "/data/misc/eardump" "${newpath}/${TRANSFER_MODULE}/eardump"
    else
        checkNumberSizeAndMove "/data/misc/eardump" "${newpath}/${TRANSFER_MODULE}/eardump" 2560000
    fi
}

#/data/system/thermal/dcs
#/data/system/thermalstats.bin
#/data/oplus/psw/powermonitor
#/data/oplus/psw/powermonitor_backup/
function collect_function_power_default() {
    # Add for thermalrec log
    dumpsys batterystats --thermalrec
    thermalrec_dir="/data/system/thermal/dcs"
    thermalstats_file="/data/system/thermalstats.bin"
    if [ -f ${thermalstats_file} ] || [ -d ${thermalrec_dir} ]; then
        mkdir -p ${newpath}/${TRANSFER_MODULE}/thermalrec/
        chmod 770 ${thermalstats_file}
        cp -rf ${thermalstats_file} ${newpath}/${TRANSFER_MODULE}/thermalrec/

        echo "copy Thermalrec..."
        chmod 770 /data/system/thermal/ -R
        cp -rf ${thermalrec_dir}/* ${newpath}/${TRANSFER_MODULE}/thermalrec/
    fi

    #Add for powermonitor log
    POWERMONITOR_DIR="/data/oplus/psw/powermonitor"
    chmod 770 ${POWERMONITOR_DIR} -R
    checkNumberSizeAndCopy "${POWERMONITOR_DIR}" "${newpath}/${TRANSFER_MODULE}/powermonitor"

    POWERMONITOR_BACKUP_LOG=/data/oplus/psw/powermonitor_backup/
    chmod 770 ${POWERMONITOR_BACKUP_LOG} -R
    checkNumberSizeAndCopy "${POWERMONITOR_BACKUP_LOG}" "${newpath}/${TRANSFER_MODULE}/powermonitor_backup"
}

#Bin.Lv@BSP.Security.Basic, 2022/10/9, Add for security
function collect_function_security_default() {
    DATA_TMP_LOG=${DATA_DEBUGGING_PATH}/security
    TARGET_DATA_TMP_LOG=${newpath}/${TRANSFER_MODULE}
    checkNumberSizeAndMove "${DATA_TMP_LOG}" "${TARGET_DATA_TMP_LOG}"
}

#/sdcard/Android/data/com.tencent.tmgp.pubgmhd/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Logs
function collect_function_thirdpart_default() {
    #Chunbo.Gao@ANDROID.DEBUG.NA, 2019/6/21, Add for pubgmhd.ig
    app_pubgmhd_dir="/sdcard/Android/data/com.tencent.tmgp.pubgmhd/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Logs"
    if [ -d ${app_pubgmhd_dir} ]; then
        mkdir -p ${newpath}/${TRANSFER_MODULE}/os/Tencentlogs/pubgmhd
        echo "copy pubgmhd..."
        cp -rf ${app_pubgmhd_dir} ${newpath}/${TRANSFER_MODULE}/os/Tencentlogs/pubgmhd
    fi

    #Add for thirdpart app log : kugou qqlive yx yy wework tmgp.cf
    LOG_TYPE=`getprop persist.sys.debuglog.config`
    if [ "${LOG_TYPE}" != "thirdpart" ]; then
       return
    fi

    traceTransferState "${CURTIME_FORMAT} THIRDAPP:copy thirdapp start..."
    app_kugou_dir="/sdcard/kugou/log"
    if [ -d ${app_kugou_dir} ]; then
        echo "copy kogou..."
        checkSmallSizeAndCopy "${app_kugou_dir}" "${TRANSFER_MODULE}/kugou"
    fi

    app_qqlive_dir="/sdcard/Android/data/com.tencent.qqlive/files/log"
    if [ -d ${app_qqlive_dir} ]; then
        echo "copy qqlive..."
        checkSmallSizeAndCopy "${app_qqlive_dir}" "${TRANSFER_MODULE}/qqlive"
    fi

    app_yx_dir="/sdcard/Android/data/com.yx"
    if [ -d ${app_yx_dir} ]; then
        echo "copy yx..."
        checkSmallSizeAndCopy "${app_yx_dir}" "${TRANSFER_MODULE}/yx"
    fi

    app_yymobile_dir="/sdcard/Android/data/com.duowan.mobile/files/yymobile/logs"
    if [ -d ${app_yymobile_dir} ]; then
        echo "copy yymobile..."
        checkSmallSizeAndCopy "${app_yymobile_dir}" "${TRANSFER_MODULE}/yymobile"
    fi

    app_wework_dir="sdcard/Tencent/WeixinWor/src_clog"
    if [ -d ${app_wework_dir} ]; then
        echo "copy WeixinWor..."
        checkSmallSizeAndCopy "${app_wework_dir}" "${TRANSFER_MODULE}/wework"
    fi

    app_tmgpcf_dir="/sdcard/Android/data/com.tencent.tmgp.cf/cache/Cache/Log/"
    if [ -d ${app_tmgpcf_dir} ]; then
        echo "copy tmgp cf..."
        checkSmallSizeAndCopy "${app_tmgpcf_dir}" "${TRANSFER_MODULE}/tmgpcf"
    fi
    traceTransferState "${CURTIME_FORMAT} THIRDAPP:copy thirdapp done"
}

#/sdcard/Android/data/com.tencent.mm/MicroMsg/xlog
#/sdcard/Android/data/com.tencent.mm/MicroMsg/crash
#/storage/emulated/999/Android/data/com.tencent.mm/MicroMsg/xlog
#Hongchao.Li@ANDROID.DEBUG, 2021/11/2, Add for copy wxlog
function collect_function_thirdpart_wx() {
  currentDateWXlog=$(date "+%Y%m%d")
  LOG_TYPE=$(getprop persist.sys.debuglog.config)
  if [ "${LOG_TYPE}" != "thirdpart" ]; then
    return
  fi

  XLOG_DIR="/sdcard/Android/data/com.tencent.mm/MicroMsg/xlog"
  CRASH_DIR="/sdcard/Android/data/com.tencent.mm/MicroMsg/crash"
  SUB_XLOG_DIR="/storage/emulated/999/Android/data/com.tencent.mm/MicroMsg/xlog"

  #wxlog/xlog
  mkdir -p ${newpath}/${TRANSFER_MODULE}/wxlog/xlog
  if [ -d "${XLOG_DIR}" ]; then
    ALL_FILE=$(find ${XLOG_DIR} | grep -E ${currentDateWXlog} | xargs ls -t)
    for i in $ALL_FILE; do
      echo "now we have Xlog file $i"
      #echo  $i >> ${newpath}/xlog/.xlog.txt
      cp $i ${newpath}/${TRANSFER_MODULE}/wxlog/xlog/
    done
  fi

  setprop sys.tranfer.finished cp:xlog

  #wxlog/crash
  mkdir -p ${newpath}/${TRANSFER_MODULE}/wxlog/crash
  if [ -d "${CRASH_DIR}" ]; then
    ALL_FILE=$(find ${CRASH_DIR} | grep -E ${currentDateWXlog} | xargs ls -t)
    for i in $ALL_FILE; do
      cp $i ${newpath}/${TRANSFER_MODULE}/wxlog/crash/
    done
  fi

  #sub_wxlog/xlog
  mkdir -p ${newpath}/${TRANSFER_MODULE}/sub_wxlog/xlog
  if [ -d "${SUB_XLOG_DIR}" ]; then
    ALL_FILE=$(find ${SUB_XLOG_DIR} | grep -E ${currentDateWXlog} | xargs ls -t)
    for i in $ALL_FILE; do
      echo "now we have Xlog file $i"
      #echo  $i >> ${newpath}/sub_wxlog/.xlog.txt
      cp $i ${newpath}/${TRANSFER_MODULE}/sub_wxlog/xlog/
    done
  fi

  XLOG_SIZE=`du -s -k ${newpath}/wxlog/ | awk '{print $1}'`
  SUB_XLOG_SIZE=`du -s -k ${newpath}/sub_wxlog/ | awk '{print $1}'`
  ALL=`expr ${XLOG_SIZE} + ${SUB_XLOG_SIZE}`
  traceTransferState "XLOG SIZE: XLOG:${XLOG_SIZE}KB SUB_XLOG:${SUB_XLOG_SIZE}KB ALL:${ALL}KB"
  setprop sys.tranfer.finished cp:sub_wxlog
}

#/sdcard/Android/data/com.tencent.mobileqq/files/tencent/msflogs/com/tencent/mobileqq/
#/storage/emulated/999/Android/data/com.tencent.mobileqq/files/tencent/msflogs/com/tencent/mobileqq
#Hongchao.Li@ANDROID.DEBUG, 2021/11/2, Add for copy qlog
function collect_function_thirdpart_q() {
  currentDateQlog=$(date "+%y.%m.%d")
  LOG_TYPE=$(getprop persist.sys.debuglog.config)
  if [ "${LOG_TYPE}" != "thirdpart" ]; then
    return
  fi

  QLOG_DIR="/sdcard/Android/data/com.tencent.mobileqq/files/tencent/msflogs/com/tencent/mobileqq/"
  SUB_QLOG_DIR="/storage/emulated/999/Android/data/com.tencent.mobileqq/files/tencent/msflogs/com/tencent/mobileqq"

  #qlog
  mkdir -p ${newpath}/${TRANSFER_MODULE}/qlog
  if [ -d "${QLOG_DIR}" ]; then
    Q_FILE=$(find ${QLOG_DIR} | grep -E ${currentDateQlog} | xargs ls -t)
    for i in $Q_FILE; do
      echo "now we have Qlog file $i"
      cp $i ${newpath}/${TRANSFER_MODULE}/qlog
    done
  fi

  setprop sys.tranfer.finished cp:qlog

  #sub_qlog
  mkdir -p ${newpath}/${TRANSFER_MODULE}/sub_qlog
  if [ -d "${SUB_QLOG_DIR}" ]; then
    Q_FILE=$(find ${SUB_QLOG_DIR} | grep -E ${currentDateQlog} | xargs ls -t)
    for i in $Q_FILE; do
      echo "now we have Qlog file $i"
      cp $i ${newpath}/${TRANSFER_MODULE}/sub_qlog
    done
  fi

  QLOG_SIZE=`du -s -k ${newpath}/qlog/ | awk '{print $1}'`
  SUB_QLOG_SIZE=`du -s -k ${newpath}/sub_qlog/ | awk '{print $1}'`
  ALL=`expr ${QLOG_SIZE} + ${SUB_QLOG_SIZE}`
  traceTransferState "QLOG SIZE: QLOG:${QLOG_SIZE}KB SUB_QLOG:${SUB_QLOG_SIZE}KB ALL:${ALL}KB"
  setprop sys.tranfer.finished cp:sub_qlog
}

function collect_function_thirdpart_problematicApp() {
    local pathNum=`getprop sys.thirdpart.path_num`
    if [[ "${pathNum}" == "" ]]; then
        traceTransferState  "thridpart pathNum:null"
        return
    fi
    setprop sys.thirdpart.path_num ""
    local pathProperty="sys.thirdpart.path_name"
    traceTransferState  "problematicApp num: ${pathNum}"
    for i in `seq 1 ${pathNum}`
    do
        checkNumberSizeAndCopy "`getprop ${pathProperty}$i`" "${newpath}/${TRANSFER_MODULE}/problematicApp/path$i"
        setprop ${pathProperty}$i ""
    done
}

#/data/aee_exp
function collect_function_stability_aee() {
    mkdir -p ${newpath}/${TRANSFER_MODULE}/data_aee/
    cp -rf /data/aee_exp/* ${newpath}/${TRANSFER_MODULE}/data_aee/
}

#/cache/recovery
function collect_function_recovery_default() {
    rm -rf ${SDCARD_LOG_BASE_PATH}/recovery_log/
    mkdir -p ${SDCARD_LOG_BASE_PATH}/recovery_log
    enable_ab=`getprop ro.build.ab_update`
    if [ "${enable_ab}" = "true" ] ;then
        mkdir -p ${SDCARD_LOG_BASE_PATH}/recovery_log/recovery
        mkdir -p ${SDCARD_LOG_BASE_PATH}/recovery_log/factory
        mkdir -p ${SDCARD_LOG_BASE_PATH}/recovery_log/update_engine_log
        setprop sys.oplus.copyrecoverylog 1
    else
        mv /cache/recovery/* ${SDCARD_LOG_BASE_PATH}/recovery_log
    fi
}

#/sdcard/tp_debug_info.txt
function collect_function_touch_default() {
    checkNumberSizeAndMove "/sdcard/tp_debug_info" "${newpath}/touch/tp_debug_info"
    checkNumberSizeAndMove "/sdcard/tp_debug_info1" "${newpath}/touch/tp_debug_info1"
    #cp test cvs file
    LOG_TPTEST_PATH=/sdcard/TpTestReport
    if [ -d "${LOG_TPTEST_PATH}" ]; then
        traceTransferState "INITOPLUSLOG:TpTestReport copy..."
        cp -rf /sdcard/TpTestReport ${newpath}/touch/
    fi
}

#/data/local/traces
function collect_function_performance_systemTrace() {
    SYSTRACE_PATH=/data/local/traces
    checkNumberSizeAndMove "${SYSTRACE_PATH}" "${newpath}/${TRANSFER_MODULE}/systrace"
}

#/data/debugging/wm/*
function collect_function_common_wm() {
    mkdir -p ${newpath}/${TRANSFER_MODULE}/wm
    mv -f ${DATA_DEBUGGING_PATH}/wm/* ${newpath}/${TRANSFER_MODULE}/wm
}

#/data/system/users/0
function collect_function_common_user() {
    DATA_USER_LOG=/data/system/users/0
    TARGET_DATA_USER_LOG=${newpath}/${TRANSFER_MODULE}/user_0

    checkNumberSizeAndCopy "${DATA_USER_LOG}" "${TARGET_DATA_USER_LOG}"
}

#/data/persis_log
function collect_function_common_persistLog() {
    TARGET_DATA_OPLUS_LOG=${newpath}/${TRANSFER_MODULE}/assistlog
    chmod 777 ${DATA_OPLUS_LOG_PATH}/ -R

    #filter persist_log
    if [ -d  ${DATA_OPLUS_LOG_PATH} ]; then
        ALL_SUB_DIR=`ls ${DATA_OPLUS_LOG_PATH} | grep -e criticallog -e pstore -e stamp -e OTRTA -e crashbox -e modem_log -e ovmsAudio`
        for SUB_DIR in ${ALL_SUB_DIR};do
            if [ -d ${DATA_OPLUS_LOG_PATH}/${SUB_DIR} ] || [ -f ${DATA_OPLUS_LOG_PATH}/${SUB_DIR} ]; then
                checkNumberSizeAndCopy "${DATA_OPLUS_LOG_PATH}/${SUB_DIR}" "${TARGET_DATA_OPLUS_LOG}/${SUB_DIR}"
            fi
        done
    fi

    #/data/persist_log/backup
    DATA_OPLUS_BACKUP_LOG_PATH=${DATA_OPLUS_LOG_PATH}/backup
    if [ -d  ${DATA_OPLUS_BACKUP_LOG_PATH} ]; then
        ALL_SUB_DIR=`ls ${DATA_OPLUS_BACKUP_LOG_PATH} | grep -v OTRTA`
        for SUB_DIR in ${ALL_SUB_DIR};do
            if [ -d ${DATA_OPLUS_BACKUP_LOG_PATH}/${SUB_DIR} ] || [ -f ${DATA_OPLUS_BACKUP_LOG_PATH}/${SUB_DIR} ]; then
                checkNumberSizeAndCopy "${DATA_OPLUS_BACKUP_LOG_PATH}/${SUB_DIR}" "${TARGET_DATA_OPLUS_LOG}/backup/${SUB_DIR}"
            fi
        done
    fi

    #/data/persist_log/backup/OTRTA
    DATA_OPLUS_BACKUP_OTRTA_LOG_PATH=${DATA_OPLUS_LOG_PATH}/backup/OTRTA
    if [ -d  ${DATA_OPLUS_BACKUP_OTRTA_LOG_PATH} ]; then
        ALL_SUB_DIR=`ls ${DATA_OPLUS_BACKUP_OTRTA_LOG_PATH} | grep -v manually_traces`
        for SUB_DIR in ${ALL_SUB_DIR};do
            if [ -d ${DATA_OPLUS_BACKUP_OTRTA_LOG_PATH}/${SUB_DIR} ] || [ -f ${DATA_OPLUS_BACKUP_OTRTA_LOG_PATH}/${SUB_DIR} ]; then
                checkNumberSizeAndCopy "${DATA_OPLUS_BACKUP_OTRTA_LOG_PATH}/${SUB_DIR}" "${TARGET_DATA_OPLUS_LOG}/backup/OTRTA/${SUB_DIR}"
            fi
        done
    fi

    #/data/persist_log/backup/OTRTA/manually_traces
    DATA_OPLUS_BACKUP_OTRTA_LOG_PATH=${DATA_OPLUS_LOG_PATH}/backup/OTRTA/manually_traces
    if [ -d  ${DATA_OPLUS_BACKUP_OTRTA_LOG_PATH} ]; then
        #remove Obrain
        ALL_SUB_DIR=`ls ${DATA_OPLUS_BACKUP_OTRTA_LOG_PATH} | grep -v Obrain`
        for SUB_DIR in ${ALL_SUB_DIR};do
            if [ -d ${DATA_OPLUS_BACKUP_OTRTA_LOG_PATH}/${SUB_DIR} ] || [ -f ${DATA_OPLUS_BACKUP_OTRTA_LOG_PATH}/${SUB_DIR} ]; then
                checkNumberSizeAndCopy "${DATA_OPLUS_BACKUP_OTRTA_LOG_PATH}/${SUB_DIR}" "${TARGET_DATA_OPLUS_LOG}/backup/OTRTA/manually_traces/${SUB_DIR}"
            fi
        done
    fi

    #/data/persist_log/launcher*
    if [ -d  ${DATA_OPLUS_LOG_PATH} ]; then
        ALL_SUB_DIR=`ls ${DATA_OPLUS_LOG_PATH} | grep launcher`
        for SUB_DIR in ${ALL_SUB_DIR};do
            if [ -d ${DATA_OPLUS_LOG_PATH}/${SUB_DIR} ] || [ -f ${DATA_OPLUS_LOG_PATH}/${SUB_DIR} ]; then
                checkNumberSizeAndCopy "${DATA_OPLUS_LOG_PATH}/${SUB_DIR}" "${TARGET_DATA_OPLUS_LOG}/launcher/${SUB_DIR}"
            fi
        done
    fi
}

#/data/persist_log/TMP/pcm_dump
function collect_function_audio_pcm_dump() {
    DATA_TMP_LOG=${DATA_OPLUS_LOG_PATH}/TMP/pcm_dump
    TARGET_DATA_TMP_LOG=${newpath}/${TRANSFER_MODULE}/pcm_dump
    chmod -R 777 ${DATA_TMP_LOG}
    checkNumberSizeAndMove "${DATA_TMP_LOG}" "${TARGET_DATA_TMP_LOG}" "1300000"
}

#/data/persist_log/TMP/videodump
function collect_function_video_videodump() {
    DATA_TMP_LOG=${DATA_OPLUS_LOG_PATH}/TMP/videodump
    TARGET_DATA_TMP_LOG=${newpath}/${TRANSFER_MODULE}/videodump
    checkNumberSizeAndMove "${DATA_TMP_LOG}" "${TARGET_DATA_TMP_LOG}"
}

function checkStartServicesDone(){
    traceTransferState "check ctl.start services done"
    checkServicesList=(transfer3_dumpSystem transfer3_anrtomb transfer_bugreport reserve_collect)
    allSerivcesDoneFlag=1
    timeCount=0
    while [ ${allSerivcesDoneFlag} -eq 1 ] && [ timeCount -le 30 ]
    do
        allSerivcesDoneFlag=0
        for i in "${!checkServicesList[@]}"
        do
            serviceStatus=`getprop init.svc.${checkServicesList[$i]}`
            traceTransferState "${checkServicesList[$i]} state:${serviceStatus}"
            if [[ "${serviceStatus}" == "running" ]];then
                allSerivcesDoneFlag=1
            else
                unset checkServicesList[i]
            fi
        done
        traceTransferState "${CURTIME_FORMAT} ${LOGTAG}:count=$timeCount"
        timeCount=$((timeCount + 1))
        sleep 1
    done
}

function transfer3_dumpSystem() {
    traceTransferState "transfer3_dumpSystem:start...."
    LOG_TYPE=`getprop persist.sys.debuglog.config`

    if echo "$LOG_TYPE" | grep -q '[^0-9]';then
        boot_completed=`getprop sys.boot_completed`

        stoptime=`getprop sys.oplus.log.stoptime`
        parent_path="${SDCARD_LOG_BASE_PATH}/log@stop@${stoptime}"
        if [[ x${boot_completed} == x"1" ]]; then
            outputPath="${parent_path}/common/SI_stop"

            traceTransferState "dumpSystem:${outputPath}"
            if [ ! -d ${outputPath} ]; then
                mkdir -p ${outputPath}
            fi
            rm -f ${outputPath}/finish_system
            dumpsys -t 30 meminfo -S > ${outputPath}/dumpsys_mem.txt &
            osvelte meminfo > ${outputPath}/osvelte_meminfo.txt

            setprop sys.tranfer.finished mv:meminfo

            traceTransferState "dumpSystem:ps,top"
            ps -T -A > ${outputPath}/ps.txt
            top -n 1 -s 10 > ${outputPath}/top.txt
            cat /proc/meminfo > ${outputPath}/proc_meminfo.txt
            cat /proc/interrupts > ${outputPath}/interrupts.txt
            cat /sys/kernel/debug/wakeup_sources > ${outputPath}/wakeup_sources.log
            traceTransferState "dumpSystem:getprop"
            getprop > ${outputPath}/prop.txt
            traceTransferState "dumpSystem:df"
            df > ${outputPath}/df.txt
            traceTransferState "dumpSystem:mount"
            mount > ${outputPath}/mount.txt
            traceTransferState "dumpSystem:cat"
            cat data/system/packages.xml  > ${outputPath}/packages.txt
            cat data/system/appops.xml  > ${outputPath}/appops.xml
            traceTransferState "dumpSystem:dumpsys appops"
            dumpsys appops > ${outputPath}/dumpsys_appops.xml
            cat /proc/zoneinfo > ${outputPath}/zoneinfo.txt
            cat /proc/slabinfo > ${outputPath}/slabinfo.txt
            cp -rf /sys/kernel/debug/ion ${outputPath}/
            cp -rf /sys/kernel/debug/dma_buf ${outputPath}/
            logcat -S > ${outputPath}/logStatistics_${CURTIME}.txt

            traceTransferState "dumpSystem:dumpsys notification"
            dumpsys notification > ${outputPath}/dumpsys_notification.xml
            cat /data/system/notification_policy.xml > ${outputPath}/notification_policy.xml
            traceTransferState "dumpSystem:notification done"

            #Jiaqi.Hao@ANDROID.Stability,2023/05/18, add for logkit copy critical_event.log
            traceTransferState "copy critical_eventl.log begin"
            cp /data/system/critical_event.log ${outputPath}/critical_event.log
            traceTransferState "copy critical_eventl.log end"

            traceTransferState "dumpSystem:user"
            dumpsys user > ${outputPath}/dumpsys_user.txt
            dumpsys power > ${outputPath}/dumpsys_power.txt
            dumpsys cpuinfo > ${outputPath}/dumpsys_cpuinfo.txt
            dumpsys alarm > ${outputPath}/dumpsys_alarm.txt
            dumpsys batterystats > ${outputPath}/dumpsys_batterystats.txt
            dumpsys batterystats -c > ${outputPath}/dumpsys_battersystats_for_bh.txt
            dumpsys activity exit-info > ${outputPath}/dumpsys_exit_info.txt
            dumpsys location > ${outputPath}/dumpsys_location.txt
            dumpsys nfc > ${outputPath}/dumpsys_nfc.txt
            dumpsys secure_element > ${outputPath}/dumpsys_secure_element.txt
            traceTransferState "dumpSystem:package"
            dumpsys -t 20 package > ${outputPath}/dumpsys_package.txt
            traceTransferState "dumpSystem:dropbox"
            dumpsys dropbox --print > ${outputPath}/dumpsys_dropbox_all.txt
            #philip.huang@NETWORK.CFG, 2021/08/04, Add for dumpsys CarrierConfig info [OCR.1717966.1.OM.ALL]
            dumpsys carrier_config > ${outputPath}/dumpsys_carrier_config.txt
            #Zhangpeng@NETWORK.DATA, 2023.03.06, Add for dumpsys network info
            LOG_TYPE=`getprop persist.sys.debuglog.config`
            if [ "${LOG_TYPE}" == "wifi" ] || [ "${LOG_TYPE}" == "call" ] || [ "${LOG_TYPE}" == "network" ] || [ "${LOG_TYPE}" == "bluetooth" ]; then
                transfer3_network_conf ${outputPath}
            fi

            #guofu.yang@ANDROID.AMS, 2023/04/15, Add for dumpsys window info
            if [ "${LOG_TYPE}" == "other" ] || [ "${LOG_TYPE}" == "thirdpart" ] || [ "${LOG_TYPE}" == "touch" ] || [ "${LOG_TYPE}" == "brightness" ]; then
                dumpsys activity activities > ${outputPath}/dumpsys_activities.txt
                dumpsys activity top > ${outputPath}/dumpsys_activitie_top.txt
                dumpsys window -a > ${outputPath}/dumpsys_window.txt
                dumpsys oplusscreenmode > ${outputPath}/dumpsys_oplusscreenmode.txt
                dumpsys SurfaceFlinger  > ${outputPath}/dumpsys_SurfaceFlinger.txt
            fi

            traceTransferState "dumpSystem:settings"
            dumpsys settings --no-config --all-history > ${outputPath}/dumpsys_settings_no_config_all_history.txt
            traceTransferState "dumpSystem:settings done"

            #yong8.huang@ANDROID.AMS, 2020/12/30, Add for dumpsys activity info
            dumpsys activity processes > ${outputPath}/dumpsys_processes.txt
            dumpsys activity broadcasts > ${outputPath}/dumpsys_broadcasts.txt
            dumpsys activity providers > ${outputPath}/dumpsys_providers.txt
            dumpsys activity services > ${outputPath}/dumpsys_services.txt

            #Bin.Lv@BSP.Security.Basic, 2023/01/30, Add for record key status to logtool
            dumpsys engineer --execute_check_key_status2 > ${outputPath}/security_key_status.txt

            #Hun.Xu@ANDROID.SENSOR,2021/07/16, Add for dumpsys sensorservice info
            dumpsys sensorservice > ${outputPath}/dumpsys_sensorservice.txt

            #Qianyou.Chen@Android.MULTIUSER, 2021/12/13, Add for dumpsys accessibility services
            dumpsys accessibility > ${outputPath}/dumpsys_accessibility.txt
            #Qianyou.Chen@Android.MULTIUSER, 2021/12/13, Add for dumpsys device/profile owner
            dumpsys device_policy > ${outputPath}/dumpsys_devicepolicy.txt

            ##kevin.li@ROM.Framework, 2019/11/5, add for hans freeze manager(for protection)
            hans_enable=`getprop persist.sys.enable.hans`
            if [ "$hans_enable" == "true" ]; then
                dumpsys activity hans history > ${outputPath}/dumpsys_hans_history.txt
            fi
            #kevin.li@ROM.Framework, 2019/12/2, add for hans cts property
            hans_enable=`getprop persist.vendor.enable.hans`
            if [ "$hans_enable" == "true" ]; then
                dumpsys activity hans history > ${outputPath}/dumpsys_hans_history.txt
            fi

            #chao.zhu@ROM.Framework, 2020/04/17, add for preload
            preload_enable=`getprop persist.vendor.enable.preload`
            if [ "$preload_enable" == "true" ]; then
                dumpsys activity preload > ${outputPath}/dumpsys_preload.txt
            fi

            #qingxin.guo@ROM.Framework, 2022/04/25, add for cpulimit
            cpulimit_enable=`getprop persist.vendor.enable.cpulimit`
            if [ "$cpulimit_enable" == "true" ]; then
                dumpsys activity cpulimit history > ${outputPath}/dumpsys_cpulimit_history.txt
            fi

            #liqiang3@ANROID.RESCONTROL, 2021/12/14, add for jobscheduler
            dumpsys jobscheduler > ${outputPath}/dumpsys_jobscheduler.txt

            #kevin.li@ANDROID.RESCONTROL, 2021/10/18, add for Osense
            dumpsys osensemanager log > ${outputPath}/dumpsys_osense_log.txt

            #fanhonglin@ANDROID.PMS, 2022/6/23, add for AppPlatform
            dumpsys activity provider com.oplus.appplatform/com.oplus.epona.ipc.remote.DispatcherProvider record > ${outputPath}/dumpsys_appplatform_record_log.txt

            #wangjianbo@ANDROID.PMS, 2022/7/13, add for AppFeature and OplusFeature
            dumpsys package oplus-features > ${outputPath}/dumpsys_oplusFeature_config.txt
            dumpsys activity provider com.oplus.appplatform/com.oplus.customize.appfeature.configprovider.AppFeatureProvider > ${outputPath}/dumpsys_appfeature_config.txt

            #kevin.li@ANDROID.RESCONTROL, 2022/06/28, add for activity preload
            dumpsys activity actpreload > ${outputPath}/dumpsys_activity_preload_log.txt

            #CaiLiuzhuang@MULTIMEDIA.AUDIODRIVER.FEATURE, 2021/01/18, Add for dump media log
            dumpMedia ${outputPath}

            #Aohui.Wang@Android, 2022/05/10, Add for ion log
            dumpIon

            #Haijie.Wu@ANDROID.MEDIAPROVIDER, 2023/11/16, Add for dump mediaprovider
            dumpsys activity provider mediaprovider > ${outputPath}/dumpsys_mediaprovider.txt

            #Jianrong.Zheng@ANDROID.VIBRATOR,2024/01/22, Add for dumpsys vibrator_manager info
            dumpsys vibrator_manager > ${outputPath}/dumpsys_vibrator_manager.txt

            wait
            getMemoryMap;

            touch ${outputPath}/finish_system
            traceTransferState "transfer3_dumpSystem:done...."
        fi
    else
        traceTransferState "dumpLog : ${LOG_TYPE}"
        dumpLog ${LOG_TYPE}
    fi
}

#Zhangpeng@NETWORK.DATA.5377969, 2023.03.20, Add for dumpsys network info
function transfer3_network_conf() {
    traceTransferState "transfer3_network_conf:start...."
    local outputPath=$1
    local networkPath="${outputPath}/network"
    mkdir -p ${networkPath}
    dumpsys netd > ${networkPath}/dumpsys_netd.txt
    dumpsys netd tcp_socket_info > ${networkPath}/dumpsys_tcp_socket_info.txt
    dumpsys oplusnetd > ${networkPath}/dumpsys_oplusnetd.txt
    dumpsys oplusnetd datalimit > ${networkPath}/dumpsys_oplusnetd_datalimit.txt
    dumpsys oplusnetd oplustraffic > ${networkPath}/dumpsys_oplusnetd_oplustraffic.txt
    dumpsys oplusnetd firewall > ${networkPath}/dumpsys_oplusnetd_firewall.txt
    dumpsys connectivity > ${networkPath}/dumpsys_connectivity.txt
    dumpsys connectivity tethering > ${networkPath}/dumpsys_connectivity_tethering.txt
    dumpsys connectivity trafficcontroller > ${networkPath}/dumpsys_connectivity_trafficcontroller.txt
    dumpsys oplusnetworkstats olk bpfmap > ${networkPath}/dumpsys_oplusnetworkstats_olk_bpfmap.txt
    ip -s addr > ${networkPath}/ip_addr.txt
    ip -s link > ${networkPath}/ip_link.txt
    ip -s neigh > ${networkPath}/ip_neigh.txt
    ip -s ntable > ${networkPath}/ip_ntable.txt
    ip -s tunnel > ${networkPath}/ip_tunnel.txt
    ip -s tuntap > ${networkPath}/ip_tuntap.txt
    ip -s maddress > ${networkPath}/ip_maddress.txt
    ip -s mroute > ${networkPath}/ip_mroute.txt
    iptables -nvL > ${networkPath}/iptables.txt
    iptables-save > ${networkPath}/iptables_save.txt
    ip6tables -nvL > ${networkPath}/ip6tables.txt
    ip6tables-save > ${networkPath}/ip6tables_save.txt
    traceTransferState "transfer3_network_conf:done...."
}

#Aohui.Wang@Android, 2022/05/10, Add for ion log
function dumpIon() {
    traceTransferState "dumpSystem:dumpsys ION/DMA_BUF"
    # ION/DMA_BUF
    # qcom kernel 4.14/4.19/5.4
    if [ -f /proc/dma_buf/dmaprocs ]; then
        cat /proc/dma_buf/dmaprocs > ${outputPath}/dma_buf_dmaprocs.txt
    fi
    if [ -f /proc/dma_buf/bufinfo ]; then
        cat /proc/dma_buf/bufinfo > ${outputPath}/dma_buf_bufinfo.txt
    fi
    # mtk kernel 4.14/4.19
    if [ -f /proc/ion/ion_mm_heap ]; then
        cat /proc/ion/ion_mm_heap > ${outputPath}/ion_mm_heap.txt
    fi
    if [ -f /proc/ion/clients/clients_summary ]; then
        cat /proc/ion/clients/clients_summary > ${outputPath}/ion_clients_summary.txt
    fi
    # qcom/mtk kernel 5.10
    if [ -f /proc/osvelte/dma_buf/procinfo ]; then
        cat /proc/osvelte/dma_buf/procinfo > ${outputPath}/dma_buf_procinfo.txt
    fi
    if [ -f /proc/osvelte/dma_buf/bufinfo ]; then
        cat /proc/osvelte/dma_buf/bufinfo > ${outputPath}/dma_buf_bufinfo.txt
    fi
    if [ -f /proc/dma_heap/stats ]; then
        cat /proc/dma_heap/stats > ${outputPath}/dma_heap_stats.txt
    fi
    traceTransferState "dumpSystem:ION/DMA_BUF done"
}

function transfer3_anrtomb(){
    traceTransferState "transfer3_anrtomb:start...."
    stoptime=`getprop sys.oplus.log.stoptime`
    parent_path="${SDCARD_LOG_BASE_PATH}/log@stop@${stoptime}"
    TMP_PATH="${parent_path}/common"
    chmod 2770 ${parent_path}

    ANR_LOG=/data/anr
    TARGET_ANR_LOG=${TMP_PATH}/anr
    TOMBSTONE_LOG=/data/tombstones
    TARGET_TOMBSTONE_LOG=${TMP_PATH}/tombstones

    checkNumberSizeAndCopy "${ANR_LOG}" "${TARGET_ANR_LOG}"
    checkNumberSizeAndCopy "${TOMBSTONE_LOG}" "${TARGET_TOMBSTONE_LOG}"

    traceTransferState "transfer3_anrtomb:done...."
    wait
}

#CaiLiuzhuang@MULTIMEDIA.AUDIODRIVER.FEATURE, 2021/01/18, Add for dump media log
function dumpMedia() {
    local outputPath=$1
    local mediaPath="${outputPath}/media"
    mkdir -p ${mediaPath}
    traceTransferState "${CURTIME_FORMAT} dumpMedia:start...."
    dumpsys media.audio_flinger > ${mediaPath}/audio_flinger.txt
    dumpsys media.audio_policy > ${mediaPath}/audio_policy.txt
    dumpsys media.metrics > ${mediaPath}/media_metrics.txt
    dumpsys media_session > ${mediaPath}/media_session.txt
    dumpsys media_router > ${mediaPath}/media_router.txt
    dumpsys audio > ${mediaPath}/audioservice.txt
    dumpsys media.player > ${mediaPath}/media_player.txt
    pid_audioserver=`pgrep -f audioserver`
    debuggerd -b ${pid_audioserver} > ${mediaPath}/audioserver.txt
    pid_audiohal=`pgrep -f audio.service`
    debuggerd -b ${pid_audiohal} > ${mediaPath}/audiohal.txt
    atlasservice=`pgrep -f atlasservice`
    debuggerd -b ${atlasservice} > ${mediaPath}/atlasservice.txt
    system_server=`pgrep -f system_server`
    debuggerd -j ${system_server} > ${mediaPath}/system_server.txt
    multimedia=`pgrep -f persist.multimedia`
    debuggerd -j ${multimedia} > ${mediaPath}/multimedia.txt
    traceTransferState "${CURTIME_FORMAT} dumpMedia:done...."
}

#Zhiming.chen@ANDROID.DEBUG 2724830, 2020/01/04,
function getMemoryMap() {
    traceTransferState " dumpSystem:memory map start...."
    LI=0
    LMI=4
    LMM=0
    MEMORY=921600
    PROCESS_MEMORY=819200
    RESIDUE_MEMORY=`cat proc/meminfo | grep MemAvailable | tr -cd "[0-9]"`
    if [ $RESIDUE_MEMORY -lt $MEMORY ] ; then
        while read -r line
        do
            if [ $LI -gt $LMM -a $LI -lt $LMI ] ; then
                let LI=$LI+1;
                echo $line
                PROMEM=`echo $line | grep -o '.*K' | tr -cd "[0-9]"`
                echo $PROMEM
                PID=`echo $line | grep -o '(.*)' | tr -cd "[0-9]"`
                echo $PID
                if [ $PROMEM -gt $PROCESS_MEMORY ] ; then
                    cat proc/$PID/smaps > ${outputPath}/pid$PID-smaps.txt
                    dumpsys meminfo $PID > ${outputPath}/pid$PID-dumpsysmen.txt
                fi
                if [ $LI -eq $LMI ] ; then
                    break
                fi
            fi
            if [ "$line"x = "Total PSS by process:"x ] ; then
                echo $line
                let LI=$LI+1;
            fi
        done < ${outputPath}/dumpsys_mem.txt
    fi
    traceTransferState "dumpSystem:memory map done...."
}

case "$config" in
    "transfer_log")
        transfer_log
        ;;
    "transfer3_dumpSystem")
        transfer3_dumpSystem
        ;;
    "transfer3_anrtomb")
        transfer3_anrtomb
        ;;
    "reserve_collect")
        reserve_collect
        ;;
       *)

      ;;
esac
