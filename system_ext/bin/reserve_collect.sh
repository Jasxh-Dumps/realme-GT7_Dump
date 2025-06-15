#!/system/bin/sh

DATA_OPLUS_LOG_PATH=/data/persist_log

function print_log() {
    content=$1
    currentTime=`date "+%Y-%m-%d %H:%M:%S"`
    echo "${currentTime} ${content} "
}

#mtk expdb
if [ -L /dev/block/by-name/expdb ]; then
    print_log "collect op expdb expdblog:start"
    DATA_EXPDB_LOG=${DATA_OPLUS_LOG_PATH}/expdb

    if [[ ! -d ${DATA_EXPDB_LOG} ]];then
        mkdir -p ${DATA_EXPDB_LOG}
    fi

    touch ${DATA_EXPDB_LOG}/expdb.bin
    #/data/persist_log/expdb
    dd if=/dev/block/by-name/expdb of=${DATA_EXPDB_LOG}/expdb.bin bs=1M skip=$(($(blockdev --getsize64 /dev/block/by-name/expdb) / 1024 / 1024 - 2 )) count=2

    print_log "collect op expdb expdblog:end"
else
    print_log "expdb is not exist"
fi

#oplusreserve1
if [ -L /dev/block/by-name/oplusreserve1 ]; then
    print_log "collect op oplusreserve1 bootlog:start"
    DATA_RESERVE_ONE_LOG=${DATA_OPLUS_LOG_PATH}/oplusreserve1

    if [[ ! -d ${DATA_RESERVE_ONE_LOG} ]];then
        mkdir -p ${DATA_RESERVE_ONE_LOG}
    fi

    touch ${DATA_RESERVE_ONE_LOG}/bootlog.bin
    touch ${DATA_RESERVE_ONE_LOG}/shutdown.bin
    #/data/persist_log/oplusreserve1
    dd if=/dev/block/by-name/oplusreserve1 of=${DATA_RESERVE_ONE_LOG}/bootlog.bin bs=32k skip=135 count=4
    if [ -f /proc/devinfo/ufs ]; then
        dd if=/dev/block/by-name/oplusreserve1 of=${DATA_RESERVE_ONE_LOG}/shutdown.bin bs=512 skip=9440 count=4
    else
        dd if=/dev/block/by-name/oplusreserve1 of=${DATA_RESERVE_ONE_LOG}/shutdown.bin bs=512 skip=9076 count=4
    fi

    print_log "collect op oplusreserve1 bootlog:end"
else
    print_log "oplusreserve1 is not exist"
fi

#oplusreserve5
if [ -L /dev/block/by-name/oplusreserve5 ]; then
    print_log "collect op oplusreserve5 kernellog:start"
    DATA_RESERVE_FIVE_LOG=${DATA_OPLUS_LOG_PATH}/oplusreserve5

    if [[ ! -d ${DATA_RESERVE_FIVE_LOG} ]];then
        mkdir -p ${DATA_RESERVE_FIVE_LOG}
    fi

    touch ${DATA_RESERVE_FIVE_LOG}/kernel.bin
    #/data/persist_log/oplusreserve5
    dd if=/dev/block/by-name/oplusreserve5 of=${DATA_RESERVE_FIVE_LOG}/kernel.bin bs=4k skip=1024 count=4097

    print_log "collect op oplusreserve5 kernellog:end"
else
    print_log "oplusreserve5 is not exist"
fi

#oplusreserve3
if [ -L /dev/block/by-name/oplusreserve3 ]; then
    print_log "collect op oplusreserve3 shutdown detect log:start"
    DATA_RESERVE_THREE_LOG=${DATA_OPLUS_LOG_PATH}/oplusreserve3

    if [[ ! -d ${DATA_RESERVE_THREE_LOG} ]];then
        mkdir -p ${DATA_RESERVE_THREE_LOG}
    fi

    touch ${DATA_RESERVE_THREE_LOG}/shutdown_detect.bin
    #/data/persist_log/oplusreserve3
    dd if=/dev/block/by-name/oplusreserve3 of=${DATA_RESERVE_THREE_LOG}/shutdown_detect.bin bs=512k skip=32 count=10

    print_log "collect op oplusreserve3 shutdown detect log:end"
else
    print_log "oplusreserve3 is not exist"
fi

print_log "reserve_collect:end...."
