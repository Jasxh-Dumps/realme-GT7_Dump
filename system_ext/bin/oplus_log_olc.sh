#! /system/bin/sh

OLC_COMMON_LOG_DEFAULT_PATH=/data/persist_log/olc/TMP/common_logs
OLC_COMMON_LOG_PATH=`getprop sys.olc.common.log.path ${OLC_COMMON_LOG_DEFAULT_PATH}`

CURTIME_FORMAT=`date "+%Y-%m-%d %H:%M:%S:%N"`
config="$1"
HARDWARE=$(getprop ro.hardware)

function traceLoggingState() {
    need_permission=0
    if [ ! -d ${OLC_COMMON_LOG_PATH} ]; then
        mkdir -p ${OLC_COMMON_LOG_PATH}
        echo "${CURTIME_FORMAT} traceLoggingState:${OLC_COMMON_LOG_PATH} " >> ${OLC_COMMON_LOG_PATH}/olc_get_log.txt
        need_permission=1
    fi

    if [ ! -f ${OLC_COMMON_LOG_PATH}/olc_get_log.txt ]; then
        need_permission=1
    fi
    content=$1
    echo "${CURTIME_FORMAT} ${content} " >> ${OLC_COMMON_LOG_PATH}/olc_get_log.txt

    if [ ${need_permission}==1 ]; then
       chown -R system:system ${OLC_COMMON_LOG_PATH}
           chmod 777 -R ${OLC_COMMON_LOG_PATH}
    fi
}

#================================== COMMON LOG =========================
function get_main_log(){
    rotateSize=`getprop sys.olc.log.rotate.kbytes 4096`;
    rotateCount=`getprop sys.olc.log.rotate.count 4`;

    traceLoggingState "logcat -d -b crash -f ${OLC_COMMON_LOG_PATH}/crash.txt -r${rotateSize} -n ${rotateCount}"
    /system/bin/logcat -d -b crash -f ${OLC_COMMON_LOG_PATH}/crash.txt -r${rotateSize} -n ${rotateCount}
    traceLoggingState "logcat -d -b main -f ${OLC_COMMON_LOG_PATH}/main.txt -r${rotateSize} -n ${rotateCount}"
    /system/bin/logcat -d -b main -f ${OLC_COMMON_LOG_PATH}/main.txt -r${rotateSize} -n ${rotateCount}

    chown -R system:system ${OLC_COMMON_LOG_PATH}
    chmod 777 -R ${OLC_COMMON_LOG_PATH}
    traceLoggingState "olc get main log done"
}

function get_radio_log(){
    rotateSize=`getprop sys.olc.log.rotate.kbytes 4096`;
    rotateCount=`getprop sys.olc.log.rotate.count 4`;

    traceLoggingState "logcat -d -b radio -f ${OLC_COMMON_LOG_PATH}/radio.txt -r ${rotateSize} -n ${rotateCount}"
    /system/bin/logcat -d -b radio -f ${OLC_COMMON_LOG_PATH}/radio.txt -r ${rotateSize} -n ${rotateCount}

    chown -R system:system ${OLC_COMMON_LOG_PATH}
    chmod 777 -R ${OLC_COMMON_LOG_PATH}
    traceLoggingState "olc get radio log done"
}

function get_storage_log(){
    dir=/data/persist_log/storage/storage_olc
    buf_log=/proc/storage/buf_log

    count=$(ls $dir|wc -l)
    if [ $count -ge 10 ]; then
        rmfile=$(ls $dir|head -n 1)
        rm -f $dir/$rmfile
    fi

    traceLoggingState "olc get storage log begin"

    /system/bin/mount > ${OLC_COMMON_LOG_PATH}/mount.txt
    /system/bin/df > ${OLC_COMMON_LOG_PATH}/df.txt
    /system/bin/cat $buf_log > ${OLC_COMMON_LOG_PATH}/buf_log.txt

    chown -R system:system ${OLC_COMMON_LOG_PATH}
    chmod 777 -R ${OLC_COMMON_LOG_PATH}

    traceLoggingState "olc get storage log done"
}

function get_events_log(){
    rotateSize=`getprop sys.olc.log.rotate.kbytes 4096`;
    rotateCount=`getprop sys.olc.log.rotate.count 4`;

    traceLoggingState "logcat -d -b events -f ${OLC_COMMON_LOG_PATH}/events.txt -r${rotateSize} -n ${rotateCount}"
    /system/bin/logcat -d -b events -f ${OLC_COMMON_LOG_PATH}/events.txt -r${rotateSize} -n ${rotateCount}

    chown -R system:system ${OLC_COMMON_LOG_PATH}
    chmod 777 -R ${OLC_COMMON_LOG_PATH}
    traceLoggingState "olc get events log done"
}

function get_system_log(){
    rotateSize=`getprop sys.olc.log.rotate.kbytes 4096`;
    rotateCount=`getprop sys.olc.log.rotate.count 4`;

    traceLoggingState "logcat -d -b system -f ${OLC_COMMON_LOG_PATH}/system.txt -r${rotateSize} -n ${rotateCount}"
    /system/bin/logcat -d -b system -f ${OLC_COMMON_LOG_PATH}/system.txt -r${rotateSize} -n ${rotateCount}

    chown  -R system:system ${OLC_COMMON_LOG_PATH}
    chmod 777 -R ${OLC_COMMON_LOG_PATH}
    traceLoggingState "olc get system log done"
}

function get_kernel_log(){
    traceLoggingState "dmesg > ${OLC_COMMON_LOG_PATH}/kernel.txt"
    dmesg > ${OLC_COMMON_LOG_PATH}/kernel.txt
    chown -R system:system ${OLC_COMMON_LOG_PATH}
    chmod 777 -R ${OLC_COMMON_LOG_PATH}
    traceLoggingState "olc get kernel log done"
}

function get_hci_log() {
    traceLoggingState "cp -rf data/misc/bluetooth/logs > dest path"
    DEFAULT_OPLUS_CACHE_BTSNOOP_PATH="/data/misc/bluetooth/cached_hci"
    cached_log_path=`getprop persist.sys.oplus.bt.cache_hcilog_path ${DEFAULT_OPLUS_CACHE_BTSNOOP_PATH}`
    cp -rf ${cached_log_path}/* ${OLC_COMMON_LOG_PATH}
    traceLoggingState "olc get hci log done"
}

function get_shutdown_detect_log() {
    traceLoggingState "cp -rf /data/oplusbootstats/shutdown_olc > dest path"
    DEFAULT_OPLUS_SHUTDOWN_DETECT_PATH="/data/oplusbootstats/shutdown_olc"
    cp -rf ${DEFAULT_OPLUS_SHUTDOWN_DETECT_PATH}/* ${OLC_COMMON_LOG_PATH}
    traceLoggingState "olc get shutdown detect log done"
}

function get_mtk_rebootdb_log() {
    traceLoggingState "cp -rf /data/persist_log/DCS/de/AEE_DB/aeeForOLC > dest path"
    DEFAULT_OPLUS_MTK_REBOOT_DB_PATH="/data/persist_log/DCS/de/AEE_DB/aeeForOLC"
    cp -rf ${DEFAULT_OPLUS_MTK_REBOOT_DB_PATH}/* ${OLC_COMMON_LOG_PATH}
    traceLoggingState "olc get mtk reboot db log done"
}

function get_theia_log() {
    traceLoggingState "mv /data/persist_log/theia/* > ${OLC_COMMON_LOG_PATH}"
    THEIA_LOG_PATH="/data/persist_log/theia/"
    mv ${THEIA_LOG_PATH}/* ${OLC_COMMON_LOG_PATH}
    chown -R system:system ${OLC_COMMON_LOG_PATH}
    chmod -R 777 ${OLC_COMMON_LOG_PATH}
    traceLoggingState "olc get theia log done"
}

function get_hecate_log() {
    traceLoggingState "mv /data/persist_log/sf/hecate/* > ${OLC_COMMON_LOG_PATH}"
    HECATE_LOG_PATH="/data/persist_log/sf/hecate/"
    mv ${HECATE_LOG_PATH}/* ${OLC_COMMON_LOG_PATH}
    chown -R system:system ${OLC_COMMON_LOG_PATH}
    chmod -R 777 ${OLC_COMMON_LOG_PATH}
    traceLoggingState "olc get hecate log done"
}

function get_nwatchcall_log() {
    traceLoggingState "mv /data/persist_log/sf/perf/* > ${OLC_COMMON_LOG_PATH}"
    PERF_LOG_PATH="/data/persist_log/sf/perf/"
    mv ${PERF_LOG_PATH}/* ${OLC_COMMON_LOG_PATH}
    chown -R system:system ${OLC_COMMON_LOG_PATH}
    chmod -R 777 ${OLC_COMMON_LOG_PATH}
    traceLoggingState "olc get nwatchcall log done"
}

function get_ssrdump_log() {
    cached_ssrdump_path="/data/misc/bluetooth/bt_fw_dump"
    traceLoggingState "cp -rf data/misc/bluetooth/bt_fw_dump > dest path"
    cp -rf ${cached_ssrdump_path}/* ${OLC_COMMON_LOG_PATH}
    rm  ${cached_ssrdump_path}/*
    traceLoggingState "olc get ssrdump log done"
}

function get_phoenix_log() {
    traceLoggingState "cp -rf /data/oplusbootstats/olc_phoenix > dest path"
    DEFAULT_OPLUS_PHOENIX_PATH="/data/oplusbootstats/olc_phoenix"
    cp -rf ${DEFAULT_OPLUS_PHOENIX_PATH}/* ${OLC_COMMON_LOG_PATH}
    rm -rf ${DEFAULT_OPLUS_PHOENIX_PATH}
    traceLoggingState "olc get phoenix log done"
}

function get_minidump_log() {
    traceLoggingState "cp -rf /data/persist_log/DCS/minidump/ > dest path"
    DEFAULT_OPLUS_QCOM_MINIDUMP_PATH="/data/persist_log/DCS/minidump/"
    cp -rf ${DEFAULT_OPLUS_QCOM_MINIDUMP_PATH}/* ${OLC_COMMON_LOG_PATH}
    traceLoggingState "olc get qcom minidump log done"
}

function get_audio_log() {
    traceLoggingState "olc get audio log start..."
    # get data/tombstones
    traceLoggingState "transfertomb:start...."
    tombstones_dir=/data/tombstones
    if [ -d ${tombstones_dir} ];then
        ALL_FILE=$(ls ${tombstones_dir} -t | head -2)
        for i in $ALL_FILE; do
            traceLoggingState "now we have tombstones file $i"
            if [ -f ${tombstones_file} ]; then
                traceLoggingState "${tombstones_dir}/${i} is exit!!"
                cp  ${tombstones_dir}/${i}  ${OLC_COMMON_LOG_PATH}/
            else
                traceLoggingState "${tombstones_dir}/${i} is not exit!!"
            fi
        done
    else
        traceLoggingState "${tombstones_dir} is not exit!!"
    fi
    traceLoggingState "transfertomb:done...."
    # get data/aee_exp/db.*.NE for MTK platform
    MTK_PREFIX = "mt"
    if [[ "x${HARDWARE}" == "${MTK_PREFIX}"* ]]; then
        traceLoggingState "transferaee:start...."
        aee_dir=data/aee_exp
        if [ -d "${aee_dir}" ];then
            traceLoggingState "${aee_dir} is a dir"
            LATEST_DIR=$(ls "${aee_dir}"/db.*.NE/ -dt | head -1)
            traceLoggingState "get ${LATEST_DIR}"
            if [ -d "${LATEST_DIR}" ]; then
                LAST_MODIFIED=$(stat -c %Y "${LATEST_DIR}")
                traceLoggingState "get modified time ${LAST_MODIFIED}"
                CURRENT_TIME=$(date +%s)
                traceLoggingState "get current time ${CURRENT_TIME}"
                TIME_DIFF=$((CURRENT_TIME - LAST_MODIFIED))
                traceLoggingState "get diff time ${TIME_DIFF}"
                if [ $TIME_DIFF -lt 30 ]; then
                    traceLoggingState "${LATEST_DIR} is exist!!"
                    cp -r "${LATEST_DIR}"  "${OLC_COMMON_LOG_PATH}/"
                else
                    traceLoggingState "${LATEST_DIR} last modified time is over 30s !!"
                fi
            else
                traceLoggingState "${aee_dir} path not have db* directory !!"
            fi
        else
            traceLoggingState "${aee_dir} is not exist!!"
        fi
        traceLoggingState "transferaee:done...."
    fi
    traceLoggingState "olc get audio log done"
}

function get_touchpanel_log(){
    tplogflag=`getprop vendor.touchdaemon.olc.type`
    traceLoggingState "$tplogflag"
    if [ "$tplogflag" == "" ]
    then
        traceLoggingState "tplogflag == error"
        # get data/tombstones
        traceLoggingState "transfertomb:start...."
        tombstones_dir=/data/tombstones
        if [ -d ${tombstones_dir} ];then
            ALL_FILE=$(ls ${tombstones_dir} -t | head -2)
            for i in $ALL_FILE; do
                traceLoggingState "now we have tombstones file $i"
                if [ -f ${tombstones_file} ]; then
                    traceLoggingState "${tombstones_dir}/${i} is exit!!"
                    cp  ${tombstones_dir}/${i}  ${OLC_COMMON_LOG_PATH}/
                else
                    traceLoggingState "${tombstones_dir}/${i} is not exit!!"
                fi
            done
        else
            traceLoggingState "${tombstones_dir} is not exit!!"
        fi
        traceLoggingState "transfertomb:done...."
        traceLoggingState "olc get touchpanel log done"
    else
        traceLoggingState "tplogflag == $tplogflag"
        subflag=$((1 << 0))
        traceLoggingState "1 << 0 subflag = $subflag"
        tpstate=$(($tplogflag & subflag))
        if [ $tpstate == "0" ]
        then
            traceLoggingState "switch tpstate off"
        else
            # get data/tombstones
            traceLoggingState "transfertomb:start...."
            tombstones_dir=/data/tombstones
            if [ -d ${tombstones_dir} ];then
                ALL_FILE=$(ls ${tombstones_dir} -t | head -2)
                for i in $ALL_FILE; do
                    traceLoggingState "now we have tombstones file $i"
                    if [ -f ${tombstones_file} ]; then
                        traceLoggingState "${tombstones_dir}/${i} is exit!!"
                        cp  ${tombstones_dir}/${i}  ${OLC_COMMON_LOG_PATH}/
                    else
                        traceLoggingState "${tombstones_dir}/${i} is not exit!!"
                    fi
                done
            else
                traceLoggingState "${tombstones_dir} is not exit!!"
            fi
            traceLoggingState "transfertomb:done...."
            traceLoggingState "olc get touchpanel log done"
        fi
        subflag=$((1 << 1))
        traceLoggingState "1 << 1 subflag = $subflag"
        tpstate=$(($tplogflag & subflag))
        if [ $tpstate == "0" ]
        then
            traceLoggingState "switch tpstate off"
        else
            traceLoggingState "debuggerd -b ${tp_pid}"
            traceLoggingState gettpserviceinfo  >> $subpath
            tp_pid=`getprop vendor.touchdaemon.pid`;
            if [ "tp_pid" ];then
                traceLoggingState "debuggerd -b ${tp_pid} tp crash.txt"
                /system/bin/debuggerd -b ${tp_pid}  >  ${OLC_COMMON_LOG_PATH}/touchDaemon_crash.txt
            fi
        fi
     fi
}

function get_aplog() {
    traceLoggingState "mv /data/log/ap_log/*.tgz and *.zst > dest path"
    DEFAULT_APLOG_PATH="/data/log/ap_log"
    mv ${DEFAULT_APLOG_PATH}/*.tgz ${OLC_COMMON_LOG_PATH}
    mv ${DEFAULT_APLOG_PATH}/*.zst ${OLC_COMMON_LOG_PATH}
    CURTIME=`date "+%Y%m%d_%H%M%S"`
    ps -A -T > ${OLC_COMMON_LOG_PATH}//ps_${CURTIME}.txt
    pm list packages -U > ${OLC_COMMON_LOG_PATH}//packages_${CURTIME}.txt
    chown -R system:system ${OLC_COMMON_LOG_PATH}
    chmod -R 777 ${OLC_COMMON_LOG_PATH}
    traceLoggingState "olc get aplog done"
}

function get_touchpanel_log(){
    tplogflag=`getprop vendor.touchdaemon.olc.type`
    traceLoggingState "$tplogflag"
    if [ "$tplogflag" == "" ]
    then
        traceLoggingState "tplogflag == error"
        # get data/tombstones
        traceLoggingState "transfertomb:start...."
        tombstones_dir=/data/tombstones
        if [ -d ${tombstones_dir} ];then
            ALL_FILE=$(ls ${tombstones_dir} -t | head -2)
            for i in $ALL_FILE; do
                traceLoggingState "now we have tombstones file $i"
                if [ -f ${tombstones_file} ]; then
                    traceLoggingState "${tombstones_dir}/${i} is exit!!"
                    cp  ${tombstones_dir}/${i}  ${OLC_COMMON_LOG_PATH}/
                else
                    traceLoggingState "${tombstones_dir}/${i} is not exit!!"
                fi
            done
        else
            traceLoggingState "${tombstones_dir} is not exit!!"
        fi
        traceLoggingState "transfertomb:done...."
        traceLoggingState "olc get touchpanel log done"
    else
        traceLoggingState "tplogflag == $tplogflag"
        subflag=$((1 << 0))
        traceLoggingState "1 << 0 subflag = $subflag"
        tpstate=$(($tplogflag & subflag))
        if [ $tpstate == "0" ]
        then
            traceLoggingState "switch tpstate off"
        else
            # get data/tombstones
            traceLoggingState "transfertomb:start...."
            tombstones_dir=/data/tombstones
            if [ -d ${tombstones_dir} ];then
                ALL_FILE=$(ls ${tombstones_dir} -t | head -2)
                for i in $ALL_FILE; do
                    traceLoggingState "now we have tombstones file $i"
                    if [ -f ${tombstones_file} ]; then
                        traceLoggingState "${tombstones_dir}/${i} is exit!!"
                        cp  ${tombstones_dir}/${i}  ${OLC_COMMON_LOG_PATH}/
                    else
                        traceLoggingState "${tombstones_dir}/${i} is not exit!!"
                    fi
                done
            else
                traceLoggingState "${tombstones_dir} is not exit!!"
            fi
            traceLoggingState "transfertomb:done...."
            traceLoggingState "olc get touchpanel log done"
        fi
        subflag=$((1 << 1))
        traceLoggingState "1 << 1 subflag = $subflag"
        tpstate=$(($tplogflag & subflag))
        if [ $tpstate == "0" ]
        then
            traceLoggingState "switch tpstate off"
        else
            traceLoggingState "debuggerd -b ${tp_pid}"
            traceLoggingState gettpserviceinfo  >> $subpath
            tp_pid=`getprop vendor.touchdaemon.pid`;
            if [ "tp_pid" ];then
                traceLoggingState "debuggerd -b ${tp_pid} tp crash.txt"
                /system/bin/debuggerd -b ${tp_pid}  >  ${OLC_COMMON_LOG_PATH}/touchDaemon_crash.txt
            fi
        fi
     fi
}

function copy_logs() {
    traceLoggingState "copylogs start... "
    setprop sys.olc.copy.log_ready 0

    log_path=`getprop sys.olc.copy.log_path`
    if [ "$log_path" ];then
        copy_root=${log_path}
    else
        copy_root="${OLC_COMMON_LOG_PATH}/copy/"
    fi

    mkdir -p ${copy_root}
    traceLoggingState "copy root: ${copy_root}"

    log_config_file=`getprop sys.olc.copy.log_config`
    traceLoggingState "log config file: ${log_config_file} "

    if [ "$log_config_file" ];then
        paths=`cat ${log_config_file}`

        for file_path in ${paths};do
            traceLoggingState "copy ${file_path} "
            cp -rf ${file_path} ${copy_root}
        done
        chown -R system:system ${copy_root}
        chmod -R 777 ${copy_root}

        setprop sys.olc.copy.log_config ''
    fi

    setprop sys.olc.copy.log_ready 1
    setprop sys.olc.copy.log_path ''
    traceLoggingState "copylogs end "
}

function deal_log_too_large() {
    LOG_CONFIG_FILE="/data/persist_log/config/log_config.log"
    LOG_COUNT_SIZE=0
    chmod -R 777 ${OLC_COMMON_LOG_PATH}
    echo "touch log_size_info" >> ${OLC_COMMON_LOG_PATH}/log_size_info.txt
    if [ -f "${LOG_CONFIG_FILE}" ]; then
        while read -r ITEM_CONFIG
        do
            if [ "" != "${ITEM_CONFIG}" ];then
                SOURCE_PATH=`echo ${ITEM_CONFIG} | awk '{print $2}'`
                if [ -d ${SOURCE_PATH} ];then
                    TEMP_SIZE=`du -s ${SOURCE_PATH} | awk '{print $1}'`
                    if [ "" != "${TEMP_SIZE}" ]; then
                        LOG_COUNT_SIZE=`expr ${LOG_COUNT_SIZE} + ${TEMP_SIZE}`
                        echo "${SOURCE_PATH}: ${TEMP_SIZE}" >> ${OLC_COMMON_LOG_PATH}/log_size_info.txt
                        du ${SOURCE_PATH} >> ${OLC_COMMON_LOG_PATH}/log_size_info.txt
                    else
                        echo "${SOURCE_PATH}:size is nan"
                    fi
                else
                    echo "$${SOURCE_PATH}: Not exist"
                fi
            fi
        done < ${LOG_CONFIG_FILE}
    else
        echo "${LOG_CONFIG_FILE} is not exist" >> ${OLC_COMMON_LOG_PATH}/log_size_info.txt
    fi
    echo "LOG_COUNT_SIZE is: ${LOG_COUNT_SIZE}\n" >> ${OLC_COMMON_LOG_PATH}/log_size_info.txt
    chmod 777 -R ${OLC_COMMON_LOG_PATH}
}

function get_qsee_log(){
    if [ "x${HARDWARE}" == "xqcom" ]; then
        state=`cat /proc/oplus_secure_common/secureSNBound`
        logEncrState=`cat /proc/oplus_secure_common/oemLogEncrypt`

        traceLoggingState "get_qsee_log in"
        if [ ${state} != "0" ] || [ ${state} = "0" -a ${logEncrState} != "0" ]
        then
            if [ -f /proc/tzdbg/qsee_log ]
            then
                cat /proc/tzdbg/qsee_log > ${OLC_COMMON_LOG_PATH}/qsee_log.txt &
            fi
        fi
        chown -R system:system ${OLC_COMMON_LOG_PATH}
        chmod 777 -R ${OLC_COMMON_LOG_PATH}
        traceLoggingState "get_qsee_log out"
    fi
}

function get_tz_log(){
    if [ "x${HARDWARE}" == "xqcom" ]; then
        state=`cat /proc/oplus_secure_common/secureSNBound`
        logEncrState=`cat /proc/oplus_secure_common/oemLogEncrypt`

        traceLoggingState "get_tz_log in"
        if [ ${state} != "0" ] || [ ${state} = "0" -a ${logEncrState} != "0" ]
        then
            if [ -f /proc/tzdbg/log ]
            then
                cat /proc/tzdbg/log > ${OLC_COMMON_LOG_PATH}/tz_log.txt &
            fi
        fi
        chown -R system:system ${OLC_COMMON_LOG_PATH}
        chmod 777 -R ${OLC_COMMON_LOG_PATH}
        traceLoggingState "get_tz_log out"
    fi
}

function main() {
    traceLoggingState "oplus_log_olc.sh ${config}"
    case "$config" in
        "get_main_log")
            get_main_log
            ;;
        "get_radio_log")
            get_radio_log
            ;;
        "get_events_log")
            get_events_log
            ;;
        "get_system_log")
            get_system_log
            ;;
        "get_kernel_log")
            get_kernel_log
            ;;
        "get_hci_log")
            get_hci_log
            ;;
        "get_shutdown_detect_log")
            get_shutdown_detect_log
            ;;
        "get_mtk_rebootdb_log")
            get_mtk_rebootdb_log
            ;;
        "get_ssrdump_log")
            get_ssrdump_log
            ;;
	"get_phoenix_log")
	    get_phoenix_log
	    ;;
        "copy_logs")
            copy_logs
            ;;
        "get_minidump_log")
            get_minidump_log
            ;;
       "get_touchpanel_log")
            get_touchpanel_log
            ;;
       "get_audio_log")
            get_audio_log
            ;;
        "get_theia_log")
            get_theia_log
            ;;
        "get_hecate_log")
            get_hecate_log
            ;;
        "get_nwatchcall_log")
            get_nwatchcall_log
            ;;
        "deal_log_too_large")
            deal_log_too_large
            ;;
        "get_aplog")
            get_aplog
            ;;
         "get_storage_log")
            get_storage_log
            ;;
        "get_tee_log")
            get_qsee_log
            get_tz_log
            ;;
        *)
          ;;
    esac
}

main "$@"
