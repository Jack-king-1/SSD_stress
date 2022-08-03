#!/bin/bash

mkdir /opt/link_reset_log
mkdir /opt/link_reset_log/job_file
mkdir /opt/link_reset_log/fio_log
path=/opt/link_reset_log

link_reset()
{
#================ Link Reset =================
pcie_address=`lspci -vvv | grep "NVMe SSD" | awk '{print $1}'`
count=1
while [ 1 ]
do
	sleep 120
	while [ 1 ]
	do
		format_number=`ps aw | grep "format" | wc -l`
		if [[ ${format_number}	== 1 ]];then
			break
		else
			sleep 5
		fi
	done
	
	echo "============== ${count} ==============" | tee -a ${path}/lnksta.log
	for SSD in {0..12}; do
		nvme reset /dev/nvme${SSD} &
	done
	wait
	for line in ${pcie_address}; do
		lnksta=`lspci -vvv -s ${line} | grep "LnkSta" | grep -v "LnkSta2" | awk -F: '{print $2}' | sed 's/^[ \t]*//g'`
		speed=`lspci -vvv -s ${line} | grep "LnkSta" | grep -v "LnkSta2" | awk '{print $3}'`
		width=`lspci -vvv -s ${line} | grep "LnkSta" | grep -v "LnkSta2" | awk '{print $6}'`
		echo "${line}: ${lnksta}" | tee -a ${path}/lnksta.log
		if [[ ${speed} != "8GT/s" ]]; then
			echo "============== ${count} ==============" >> ${path}/lnksta_error.log
			echo "${line}: ${linksta}" | tee -a ${path}/lnksta_error.log
		elif [[ ${width} != "x4" ]]; then
			echo "============== ${count} ==============" >> ${path}/lnksta_error.log
                        echo "${line}: ${linksta}" | tee -a ${path}/lnksta_error.log
		fi
	done
	count=$(($count+1))
done
}

fio()
{
#=============== FIO job file create and Test ===================
nvme=`nvme -list | awk '{print$1}' | grep -v -E "Node|-"`
for qo in 1 2 32; do
        echo -e "[global]\nnorandommap\nrandrepeat=0\ngroup_reporting\ntime_based\nruntime=12h\nclocksource=gettimeofday\nrw=randrw\nrwmixwrite=50\niodepth=${qo}\nnumjobs=4\nioengine=libaio\nbs=16k\ndirect=1\npercentile_list=1:5:10:20:50:90:99.99:99.9999:99.999999\n" > ${path}/job_file/fio_16k_50randw_${qo}io.job
        for line in ${nvme}; do
                echo -e "[${line}]\nfilename=$line\nnew_group" >> ${path}/job_file/fio_16k_50randw_${qo}io.job
        done
        /usr/local/bin/fio --output=${path}/fio_log/fio_16k_50randw_${qo}io.log ${path}/job_file/fio_16k_50randw_${qo}io.job
	wait
#=============== Secure Erase ===================================
	for SSD in {0..12}; do
        	 nvme format -s 1 -f /dev/nvme${SSD}n1 &
	done
       	wait
done
}

link_reset &
fio &  
