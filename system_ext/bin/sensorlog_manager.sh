#! /system/bin/sh

config="$1"

function logOn() {
    # set log on command
    echo "sensor log on"

    platform=`getprop ro.soc.manufacturer`
    if [ x"${platform}" = x"QTI" ]; then
        setprop ctl.stop sensor_logger_qxdm_start
        setprop ctl.start sensor_logger_qxdm_start
        return
    fi
}

function logOff() {
    # set log off command
    echo "sensor log off"

    platform=`getprop ro.soc.manufacturer`
    if [ x"${platform}" = x"QTI" ]; then
        setprop ctl.start sensor_logger_qxdm_stop
        return
    fi
}

function logDump() {
    # set log dump command
    echo "sensor log dump"

    platform=`getprop ro.soc.manufacturer`
    if [ x"${platform}" = x"QTI" ]; then
        setprop ctl.start sensor_logger_qxdm_drain
        return
    fi
}

case "$config" in
    "logon")
        logOn
        ;;
    "logoff")
        logOff
        ;;
    "logdump")
        logDump
        ;;
    *)
        ;;
esac
