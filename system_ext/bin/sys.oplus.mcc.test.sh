#!/system/bin/sh
function mcc_test() {
    /system_ext/bin/mem_corruption_check -m 2048 -s 360 -l 0 -i 1000000 -t 8 -p 2>&1|tee /data/persist_log/cpu_test_result.txt
    /system_ext/bin/mem_corruption_check -m 2048 -s 360 -l 0 -i 2000 -t 8 -p 2>&1|tee  /data/persist_log/cpu_test_result.txt
    /system_ext/bin/mem_corruption_check -m 500 -s 360 -l 0 -i 20000 -t 6 -p 2>&1|tee  /data/persist_log/cpu_test_result.txt
    /system_ext/bin/mem_corruption_check -m 500 -s 360 -l 0 -i 100000 -t 6 -p -b 3F 2>&1|tee  /data/persist_log/cpu_test_result.txt
    /system_ext/bin/mem_corruption_check -m 128 -s 360 -l 0 -i 32000 -t 8 -r 50 -p  2>&1|tee /data/persist_log/cpu_test_result.txt
}

mcc_test
