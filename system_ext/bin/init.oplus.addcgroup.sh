#! /system/bin/sh
# Set memory related threads into mem cpuctl group

config="$1"

function oplus_addcgroup_normal() {
  echo "oplus_addcgroup_normal: kswapd0/shrink_lruvecd/oom_reaper/kcompactd0" > /dev/kmsg
  echo `ps -elf | grep -v grep | grep kswapd0 | awk '{print $2}'` > /dev/cpuctl/mem/tasks
  echo `ps -elf | grep -v grep | grep shrink_lruvecd | awk '{print $2}'` > /dev/cpuctl/mem/tasks
  echo `ps -elf | grep -v grep | grep oom_reaper | awk '{print $2}'` > /dev/cpuctl/mem/tasks
  echo `ps -elf | grep -v grep | grep kcompactd0 | awk '{print $2}'` > /dev/cpuctl/mem/tasks
  echo `pidof logd` > /dev/cpuctl/log/cgroup.procs
  # push audioserver/audiohal into multimedia cgroup
  echo `pidof audioserver` > /dev/cpuctl/multimedia/cgroup.procs
  echo `pidof android.hardware.audio.service_64` > /dev/cpuctl/multimedia/cgroup.procs
  # push touchDaemon into touch cgroup
  echo `pidof touchDaemon` > /dev/cpuctl/touch/cgroup.procs
  # push surfaceflinger/hwc into display cgroup
  echo `pidof surfaceflinger` > /dev/cpuctl/display/cgroup.procs
  echo `pidof vendor.qti.hardware.display.composer-service` > /dev/cpuctl/display/cgroup.procs
}

function oplus_addcgroup_special() {
  echo "oplus_addcgroup_special: hybridswapd0" > /dev/kmsg
  echo `ps -elf | grep -v grep | grep hybridswap | awk '{print $2}'` > /dev/cpuctl/mem/tasks
  echo `pidof com.oplus.midas` > /dev/cpuctl/log/cgroup.procs
}

function main() {
    case "$config" in
        "oplus_addcgroup_normal")
            echo "Execute oplus_addcgroup_normal"
            oplus_addcgroup_normal
            ;;
        "oplus_addcgroup_special")
            echo "Execute oplus_addcgroup_special"
            oplus_addcgroup_special
            ;;
    esac
}

main "$@"
