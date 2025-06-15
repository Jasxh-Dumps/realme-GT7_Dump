#!/system/bin/sh

function kswapd_load_stat_ctrl()
{
	version_str=`getprop ro.build.version.ota`
	prefix="PRE"
	if [[ "$version_str" == *"$prefix"* ]]; then
		if [ -e /proc/oplus_mem/kswapd_load_stat ]; then
			echo 1 > /proc/oplus_mem/kswapd_load_stat
		fi
	fi
}

function clear_log()
{
	if [ -d /data/opluscvtmanager/memory/kswapdstat ]; then
		rm -rf /data/opluscvtmanager/memory/kswapdstat/*
	fi

	if [ -d /data/persist_log/DCS/de/mm/high_order_kswapd_load ]; then
		rm -rf /data/persist_log/DCS/de/mm/high_order_kswapd_load/*
	fi
}

function main()
{
	# enable_kswapd_load_stat_if_needed
	kswapd_load_stat_ctrl

	# clear kswapdstatd log if exist
	clear_log
}

main
