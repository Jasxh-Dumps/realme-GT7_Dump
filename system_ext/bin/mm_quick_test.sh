#!/system/bin/sh

##### script information
script_name="multi-media quick on/off stress script"
script_version=1.0.1
script_owner=yanghui.li@mediatek.com

#### test times
ntest=5

#### step internal sleep unit s
step_internal=1

##### test mode setting
test_serial_mode=0
test_random_mode=1

##### test pattern setting
test_camera_review_flag=1
test_video_play_flag=1
test_system_suspend_flag=0
test_cpu_idle_flag=1
test_display_onoff_flag=1
test_video_record_flag=1

test_all_case_count=6

### show basic script information
function show_basic_infor(){
	echo $script_name, version=$script_version, script creater=$script_owner
}


### test camera review
function test_camera_review(){
	if [ $test_camera_review_flag -eq 0 ]; then
		return
	fi
	
	## start camera review
	am start -S -a android.media.action.IMAGE_CAPTURE
	
	sleep 2
	
	## back to home screen
	am start -a android.intent.action.MAIN -c android.intent.category.HOME
}

### test video play
function test_video_play(){
	if [ $test_video_play_flag -eq 0 ]; then
		return
	fi
	
	## start idle test app
	am start -n com.mediatek.screenflash/.MainActivity
	
	## record 5s screen 
	screenrecord --time-limit 5 /sdcard/DCIM/Camera/test_mm.mp4
	
	## wait a little
	sleep 0.1
	
	## video play
	am start -a android.intent.action.VIEW  -t video/mp4 -d file:/sdcard/DCIM/Camera/test_mm.mp4
	sleep 5
	
	## back to home screen
	am start -a android.intent.action.MAIN -c android.intent.category.HOME
	rm /sdcard/DCIM/Camera/test_mm.mp4
}

### test suspend
function test_system_suspend(){
	if [ $test_system_suspend_flag -eq 0 ]; then
		return
	fi

	#sleep duration, default 5s
	duration=5
	#try sleep with 5s, each 0.1s, 10times
	try_time=5
	try_count=$(($try_time*10))	
	
	#set wake alarm
	echo +$duration > /sys/class/rtc/rtc0/wakealarm
	
	#set wake alarm fail, may have old alarm.
	if [ $? -ne 0 ]; then
		echo +=$duration > /sys/class/rtc/rtc0/wakealarm
	fi
	
	# press powerkey to sleep
	input keyevent 26
	
	# record before sustem wall time.
	before_time=$(cat /sys/class/rtc/rtc0/since_epoch)

	# usb set to off, system will goto suspend.
	setprop vendor.usb.charging yes

	# sleep $try_times s to wait system goto suspend, need using very small pace to try.
	index=0
	interval=0
	while [ $index -lt $try_count ]
	do
		after_time=$(cat /sys/class/rtc/rtc0/since_epoch)
		interval=$(($after_time - $before_time))
		# echo interval=$interval, index=$index
		# if wall interval is bigger than real time, may have sleep.
		if [ interval -gt 4 ]; then
			break
		fi
		
		index=$(($index+1))
		sleep 0.1

	done
	
	# press powerkey when system resume
	input keyevent 26
	
	# usb set to on
	setprop vendor.usb.charging no
	
	sleep 0.2
	
	# unlock screen
	input keyevent 82
	
	# wait usb on 
	sleep 2
}

### test cpu idle
function test_cpu_idle(){
	if [ $test_cpu_idle_flag -eq 0 ]; then
		return
	fi
	
	## start idle test app
	am start -n com.mediatek.screenflash/.MainActivity
	
	## sleep 5s
	sleep 5
	
	## back to home screen
	am start -a android.intent.action.MAIN -c android.intent.category.HOME
}

### test display on/off
function test_display_onoff(){

	if [ $test_display_onoff_flag -eq 0 ]; then
		return
	fi

	## first eat a wakelock
	echo test_display_onoff > /sys/power/wake_lock

	## call power key to off screen
	input keyevent 26
	
	## sleep 1s
	sleep 1
	
	## call power key to on screen
	input keyevent 26
	
	sleep 0.2
	
	# unlock screen
	input keyevent 82
	
	## release the wakelock
	echo test_display_onoff > /sys/power/wake_unlock
}

### test video record
function test_video_record(){
	if [ $test_video_record_flag -eq 0 ]; then
		return
	fi
	
	## start camera video review
	am start -S -a android.media.action.VIDEO_CAPTURE
	
	sleep 2
	
	## back to home screen
	am start -a android.intent.action.MAIN -c android.intent.category.HOME

}

function do_random_test_flow(){

	echo "mm quick on/off random test"
	
	for rotate in $(seq 1 ${test_all_case_count})
	do
		select_test=$(($RANDOM%$test_all_case_count))

		if [ $select_test -eq 0 ]; then
			test_camera_review
		elif [ $select_test -eq 1 ]; then
			test_video_play
		elif [ $select_test -eq 2 ]; then
			test_system_suspend
		elif [ $select_test -eq 3 ]; then
			test_cpu_idle
		elif [ $select_test -eq 4 ]; then
			test_display_onoff
		elif [ $select_test -eq 5 ]; then
			test_video_record
		else
			echo test_all_case_count=$test_all_case_count, is not match setting, exit.
			exit 1
		fi

		sleep $step_internal

	done 
}

function do_serial_test_flow(){

	echo "mm quick on/off serial test"

	test_camera_review
	sleep $step_internal
	
	test_video_play
	sleep $step_internal
	
	test_system_suspend
	sleep $step_internal
	
	test_video_record
	sleep $step_internal
	
	test_cpu_idle
	sleep $step_internal
	
	test_display_onoff
	sleep $step_internal
	
}


########## main test flow

show_basic_infor

## first start to cpu idle test scenes, to disable keyguard.
am start -n com.mediatek.screenflash/.MainActivity

for i in $(seq 1 ${ntest})
do

	echo test-loop:$i

	if [ $test_serial_mode -eq 1 ]; then
		do_serial_test_flow
	else
		do_random_test_flow
	fi
done

echo "exit mm quick onoff stress test"
