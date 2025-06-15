#!/bin/bash

output=$(lpdump | grep sectors | awk '!/-cow/ && !/scratch/ {gsub("\\(", "", $6); sum += $6} END {print sum}')
result=$(echo "$output * 512" | bc)

setprop ro.oplus.storage.super_size "$result"