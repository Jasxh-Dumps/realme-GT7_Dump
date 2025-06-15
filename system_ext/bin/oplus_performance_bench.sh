#! /system/bin/sh
cmd="$1"

function thp_enable() {
    if [ ! -f "/proc/cont_pte_hugepage/stat" ]; then
        echo always > /sys/kernel/mm/transparent_hugepage/enabled
    fi
}

function thp_disable() {
    if [ ! -f "/proc/cont_pte_hugepage/stat" ]; then
        echo never > /sys/kernel/mm/transparent_hugepage/enabled
    fi
}

function random_read_cpuset_sm8550() {
   if [ -f /dev/cpuset/top-app/cpus ]; then
       echo 5-7 > /dev/cpuset/top-app/cpus
   fi
}

function random_write_cpuset_sm8550() {
   if [ -f /dev/cpuset/top-app/cpus ]; then
       echo 5-7 > /dev/cpuset/top-app/cpus
   fi
}

function random_read_cpuset_mt6895() {
   if [ -f /dev/cpuset/top-app/cpus ]; then
       echo 4-7 > /dev/cpuset/top-app/cpus
   fi
}

function random_write_cpuset_mt6895() {
   if [ -f /dev/cpuset/top-app/cpus ]; then
       echo 4-7 > /dev/cpuset/top-app/cpus
   fi
}

function random_read_cpuset_sm6225() {
   if [ -f /dev/cpuset/top-app/cpus ]; then
       echo 4-7 > /dev/cpuset/top-app/cpus
   fi
}

function random_write_cpuset_sm6225() {
   if [ -f /dev/cpuset/top-app/cpus ]; then
       echo 4-7 > /dev/cpuset/top-app/cpus
   fi
}

function random_read_cpuset_sm6375() {
   if [ -f /dev/cpuset/top-app/cpus ]; then
       echo 6-7 > /dev/cpuset/top-app/cpus
   fi
}

function random_write_cpuset_sm6375() {
   if [ -f /dev/cpuset/top-app/cpus ]; then
       echo 6-7 > /dev/cpuset/top-app/cpus
   fi
}

function random_read_cpuset_mt6983() {
   if [ -f /dev/cpuset/top-app/cpus ]; then
       echo 6-7 > /dev/cpuset/top-app/cpus
   fi
}

function random_write_cpuset_mt6983() {
   if [ -f /dev/cpuset/top-app/cpus ]; then
       echo 6-7 > /dev/cpuset/top-app/cpus
   fi
}

function random_read_cpuset_sm8250() {
   if [ -f /dev/cpuset/top-app/cpus ]; then
       echo 6-7 > /dev/cpuset/top-app/cpus
   fi
}

function random_write_cpuset_sm8250() {
   if [ -f /dev/cpuset/top-app/cpus ]; then
       echo 6-7 > /dev/cpuset/top-app/cpus
   fi
}

function random_read_cpuset_sm7325() {
   if [ -f /dev/cpuset/top-app/cpus ]; then
       echo 4-7 > /dev/cpuset/top-app/cpus
   fi
}

function random_write_cpuset_sm7325() {
   if [ -f /dev/cpuset/top-app/cpus ]; then
       echo 4-7 > /dev/cpuset/top-app/cpus
   fi
}

function random_read_cpuset_sm7675() {
   if [ -f /dev/cpuset/top-app/cpus ]; then
       echo 4-7 > /dev/cpuset/top-app/cpus
   fi
}

function random_write_cpuset_sm7675() {
   if [ -f /dev/cpuset/top-app/cpus ]; then
       echo 4-7 > /dev/cpuset/top-app/cpus
   fi
}

function bmcpu_openmp_enable() {
   if [ -f /proc/sys/bmcpu/multi_thread ]; then
       echo 1 > /proc/sys/bmcpu/multi_thread
   fi
}

function bmcpu_openmp_disable() {
   if [ -f /proc/sys/bmcpu/multi_thread ]; then
       echo 0 > /proc/sys/bmcpu/multi_thread
   fi
}

function default_cpuset() {
   if [ -f /dev/cpuset/top-app/cpus ]; then
       echo 0-7 > /dev/cpuset/top-app/cpus
   fi
}

case "$cmd" in
    "thp_enable")
        thp_enable
        ;;
    "thp_disable")
        thp_disable
        ;;
    "random_read_cpuset_sm8550")
        random_read_cpuset_sm8550
        ;;
    "random_write_cpuset_sm8550")
        random_write_cpuset_sm8550
        ;;
    "random_read_cpuset_mt6895")
        random_read_cpuset_mt6895
        ;;
    "random_write_cpuset_mt6895")
        random_write_cpuset_mt6895
        ;;
    "random_read_cpuset_sm6225")
        random_read_cpuset_sm6225
        ;;
    "random_write_cpuset_sm6225")
        random_write_cpuset_sm6225
        ;;
    "random_read_cpuset_sm6375")
        random_read_cpuset_sm6375
        ;;
    "random_write_cpuset_sm6375")
        random_write_cpuset_sm6375
        ;;
    "random_read_cpuset_mt6983")
        random_read_cpuset_mt6983
        ;;
    "random_write_cpuset_mt6983")
        random_write_cpuset_mt6983
        ;;
    "random_read_cpuset_sm8250")
        random_read_cpuset_sm8250
        ;;
    "random_write_cpuset_sm8250")
        random_write_cpuset_sm8250
        ;;
    "random_read_cpuset_sm7325")
        random_read_cpuset_sm7325
        ;;
    "random_write_cpuset_sm7325")
        random_write_cpuset_sm7325
        ;;
    "random_read_cpuset_sm7675")
        random_read_cpuset_sm7675
        ;;
    "random_write_cpuset_sm7675")
        random_write_cpuset_sm7675
        ;;
    "bmcpu_openmp_enable")
        bmcpu_openmp_enable
        ;;
    "bmcpu_openmp_disable")
        bmcpu_openmp_disable
        ;;
    "default_cpuset")
        default_cpuset
        ;;
    *)
        ;;
esac
