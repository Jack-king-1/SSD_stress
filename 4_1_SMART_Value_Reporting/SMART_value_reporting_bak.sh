#!/bin/bash

mkdir /opt/smart_value_reporting_log
#====================== Create Folder to Save Logs ======================

path=/opt/smart_value_reporting_log
mkdir -p ${path}/smart_log/error
mkdir ${path}/fio_log
mkdir ${path}/job_file
mkdir -p ${path}/self_test/error
#====================== Clear Log ======================
ipmitool sel clear
dmesg -C
echo > /var/log/messages

#====================== Start Test ======================
#while :; do
nvme=`nvme -list | awk '{print$1}' | grep -v -E "Node|-"`

for qo in 1 2; do
	echo -e "[global]\nnorandommap\nrandrepeat=0\ngroup_reporting\ntime_based\nruntime=12h\nclocksource=gettimeofday\nrw=randrw\nrwmixwrite=75\niodepth=${qo}\nnumjobs=4\nioengine=libaio\nbs=16k\ndirect=1\npercentile_list=1:5:10:20:50:90:99.99:99.9999:99.999999\n" > ${path}/job_file/fio_16k_75rw_${qo}io.job


for line in ${nvme}; do
	echo -e "[${line}]\nfilename=$line\nnew_group" >> ${path}/job_file/fio_16k_75rw_${qo}io.job
done
done

echo "======= Start time =======" | tee -a ${path}/total_time.log
date | tee -a ${path}/total_time.log
/usr/local/bin/fio --output=${path}/fio_log/fio_16k_75rw_1io.log  ${path}/job_file/fio_16k_75rw_1io.job &
#		wait
#====================== Check Smart Log ======================
for i in {1..144}; do
	sleep 300
	echo "======== ${i} ========" | tee -a ${path}/record_time.log
	date | tee -a ${path}/record_time.log
        for SSD in {0..12}; do
		echo -e "\033[46;30m==========${i}==========\033[0m" >> ${path}/smart_log/smart_nvme${SSD}n1.log  
                smartctl -x /dev/nvme${SSD}n1 >> ${path}/smart_log/smart_nvme${SSD}n1.log
		if [[ `smartctl -x /dev/nvme${SSD}n1|grep -i "Media and Data Integrity Errors"|awk '{print $6}'` -gt 0 ]]; then
			echo  -e "\033[46;30m==========${i}==========\033[0m" | tee -a ${path}/smart_log/error/nvme${SSD}n1_smart_error.log
                        smartctl -x /dev/nvme${SSD}n1|tee -a ${path}/smart_log/error/nvme${SSD}n1_smart_error.log
		fi
                if [[ `smartctl -x /dev/nvme${SSD}n1|grep -i "Error Information Log Entries"|awk '{print $5}'` -gt 0 ]]; then
			echo  -e "\033[46;30m==========${i}==========\033[0m" | tee -a ${path}/smart_log/error/nvme${SSD}n1_smart_error.log
                        smartctl -x /dev/nvme${SSD}n1|tee -a ${path}/smart_log/error/nvme${SSD}n1_smart_error.log
		fi
                if [[ `smartctl -x /dev/nvme${SSD}n1|grep -i "Warning  Comp. Temperature Time"|awk '{print $5}'` -gt 0 ]]; then
			echo  -e "\033[46;30m==========${i}==========\033[0m" | tee -a ${path}/smart_log/error/nvme${SSD}n1_smart_error.log
                        smartctl -x /dev/nvme${SSD}n1|tee -a ${path}/smart_log/error/nvme${SSD}n1_smart_error.log
		fi
                if [[ `smartctl -x /dev/nvme${SSD}n1|grep -i "Critical Comp. Temperature Time"|awk '{print $5}'` -gt 0 ]]; then
			echo -e "\033[46;30m==========${i}==========\033[0m" | tee -a ${path}/smart_log/error/nvme${SSD}n1_smart_error.log
                        smartctl -x /dev/nvme${SSD}n1|tee -a ${path}/smart_log/error/nvme${SSD}n1_smart_error.log
                fi
	done
done
	wait
#====================== Self Test ======================
	for SSD in {0..12}; do
		nvme device-self-test /dev/nvme${SSD}n1 -s 1h &
	done
		wait
	sleep 120
	for SSD in {0..12}; do
		nvme self-test-log /dev/nvme${SSD}n1 > ${path}/self_test/nvme${SSD}n1_self_test.log
		check=`nvme self-test-log /dev/nvme${SSD}n1 | grep "Operation Result" | awk -F: '{print $2}' | grep -v "0xf" | tail -n 1`
	        if [ ${check} != 0 ]; then
			echo -e "\033[46;30m==========Self test error!!!==========\033[0m" | tee -a ${path}/self_test/error/nvme${SSD}n1_self_test_error.log
                	nvme self-test-log /dev/nvme${SSD}n1 > ${path}/self_test/error/nvme${SSD}n1_self_test_error.log
                fi
	done
#===================== Secure erase ====================
	for SSD in {0..12}; do
		nvme format -s 1 -f /dev/nvme${SSD}n1 &
	done
		wait	
#==================== Modify job file ==================
#param=`cat FIO_RandomRW.job | grep iodepth | awk -F= '{print $2}'`
#if [ ${param} == "1" ];then
#	sed -i 's/iodepth=1/iodepth=2/g' /opt/4_1_SMART_Value_Reporting/FIO_RandomRW.job
#else
#	sed -i 's/iodepth=2/iodepth=1/g' /opt/4_1_SMART_Value_Reporting/FIO_RandomRW.job
#fi

echo "======= End time =======" | tee -a ${path}/total_time.log
date | tee -a ${path}/total_time.log
