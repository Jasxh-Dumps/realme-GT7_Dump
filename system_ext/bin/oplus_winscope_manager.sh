#! /system/bin/sh
##################################################################################
### Copyright (C), 2008-2021, OPLUS Mobile Comm Corp., Ltd.
### Description: XXXXXXXXXXXXXXXXXXXXX.
### Author: <Weijianjun>
###
### ---------------------Revision History: ---------------------
###  <author>        <data>      <version>       <desc>
###  <Weijianjun>   2024/05/20      1.0         build this module
##################################################################################

config="$1"
TRACE_CONFIG_DIR=/system_ext/etc
PERFETTO_CONFIG_FILE=$TRACE_CONFIG_DIR/oplus_perfetto.conf
TRACE_DATA_DIR=/data/misc/perfetto-traces/oplus
TARGET_DATA_DIR=/data/debugging/layertrace
OPLUS_WINSCOPE_TRACING_SESSION="OPLUS_WINSCOPE_TRACING_SESSION"
UNIQUE_SESSION_NAME="winscope proxy perfetto tracing oplus"

function deleteExtraTracesIfNeeded() {
    trace_dir=$1
    file_limit=2
    curBakCount=`ls ${trace_dir} | wc -l`
    #can only save 2 trace files at most
    while [ ${curBakCount} -gt $file_limit ]
    do
        rm ${trace_dir}/$(ls -t ${trace_dir} | tail -1)
        curBakCount=`ls ${trace_dir} | wc -l`
    done
}

function startLayerTrace() {
    perfetto --attach=$OPLUS_WINSCOPE_TRACING_SESSION --stop
    rm ${TRACE_DATA_DIR}/*
    LOGTIME=`date +%F-%H-%M-%S`
    local trace_file="${TRACE_DATA_DIR}/layer_trace-${LOGTIME}.perfetto-trace"
    perfetto --out ${trace_file} --txt --detach=$OPLUS_WINSCOPE_TRACING_SESSION  --config  ${PERFETTO_CONFIG_FILE}
}


function dumpLayerTrace() {
    layertrace_enable=`getprop persist.sys.debug.layer_trace.enable`
    logkit_logging_type=`getprop persist.sys.debuglog.config`
    if [ "$layertrace_enable" == "true" ] && [ "$logkit_logging_type" == "other" ]
    then
      perfetto --attach=$OPLUS_WINSCOPE_TRACING_SESSION --stop
      cp ${TRACE_DATA_DIR}/* ${TARGET_DATA_DIR}/layer_trace-$(date +%F-%H-%M-%S).perfetto-trace
      deleteExtraTracesIfNeeded ${TARGET_DATA_DIR}
      startLayerTrace
    fi
}

function stopLayerTrace() {
  perfetto --attach=$OPLUS_WINSCOPE_TRACING_SESSION --stop
  rm ${TRACE_DATA_DIR}/*
}

case "$config" in
    "startLayerTrace")
        startLayerTrace
        ;;
    "dumpLayerTrace")
        dumpLayerTrace
        ;;
    "stopLayerTrace")
        stopLayerTrace
        ;;
    *)
        ;;
esac

