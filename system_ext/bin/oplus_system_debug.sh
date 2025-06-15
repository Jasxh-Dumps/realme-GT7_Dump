#!/system/bin/sh

cmd="$1"

#init mount debugfs, sepolicy denied
#setprop ro.product.debugfs_restrictions.enabled false
#mount -t debugfs debugfs /sys/kernel/debug
#chmod 0755 /sys/kernel/debug
#setprop persist.dbg.keep_debugfs_mounted true

function enable_ftrace() {

}
#add bind mount to override some xml and props
function cf_overlay(){
   mkdir -p /tmp/cf_patch/etc/permissions/
   #oplus.software.fold_remap_display_disabled
   sed 's#<oplus-feature name="oplus.software.fold_remap_display_disabled"/>#<unavailable-feature name="oplus.software.fold_remap_display_disabled"/>#'\
      /my_product/etc/permissions/oplus.feature.android.xml > /tmp/cf_patch/etc/permissions/cf_feature_00.xml

   sed 's#<oplus-feature name="oplus.software.display.wm_size_resolution_switch_support"/>#<unavailable-feature name="oplus.software.display.wm_size_resolution_switch_support"/>#'\
     /my_product/etc/permissions/oplus.product.feature_multimedia_unique.xml > /tmp/cf_patch/etc/permissions/cf_feature_01.xml


   mount /tmp/cf_patch/etc/permissions/cf_feature_00.xml /my_product/etc/permissions/oplus.feature.android.xml --bind
   mount /tmp/cf_patch/etc/permissions/cf_feature_01.xml /my_product/etc/permissions/oplus.product.feature_multimedia_unique.xml --bind

   cp /my_engineering/build.prop /tmp/cf_patch/build.prop
   echo "persist.oplus.display.remap_disabled=0" >> /tmp/cf_patch/build.prop
   #cannot change ro prop here
   mount /tmp/cf_patch/build.prop /my_engineering/build.prop --bind
   setprop persist.oplus.display.remap_disabled 0
   #cpu boost
   for i in $(seq 0 16);do
     node=/sys/devices/system/cpu/cpufreq/policy$i/scaling_governor
     if [[  -e "$node" ]];then
       echo "performance" > $node
     fi
   done
   #
}

case "$cmd" in
    "enable_ftrace")
        enable_ftrace
        ;;
    "cf_overlay")
        cf_overlay
        ;;
    *)
        /system_ext/bin/oplus_system_debug "$cmd"
        ;;
esac
