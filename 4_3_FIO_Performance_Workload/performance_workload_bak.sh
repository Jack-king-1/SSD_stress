#!/bin/bash

mkdir /opt/performance_test_log
mkdir /opt/performance_test_log/precondition
mkdir /opt/performance_test_log/precondition_file
mkdir /opt/performance_test_log/fio_log
mkdir /opt/performance_test_log/job_file
path=/opt/performance_test_log
nvme_16T=`nvme -list | grep "MZQL215THBLA" | awk '{print$1}'`
nvme_960G=`nvme -list | grep "MZQL2960HCLS" | awk '{print$1}'`
nvme=`nvme -list | awk '{print$1}' | grep -v -E "Node|-"`
secure_erase()
{
	for line in ${nvme}; do
		nvme format -s 1 -f ${line} &
	done
	wait
}
#====================== Precondition cfg create =====================
for i in {1..2}; do
	echo -e "[global]\nsize=1%\nloops=2\nioengine=libaio\niodepth=32\ngroup_reporting\nnumjobs=1\ndirect=1\nblockalign=4k\nrw=write\nbs=128k\n" > ${path}/precondition_file/fio_seq${i}_precondition.cfg
	echo -e "[global]\nsize=1%\nloops=2\nioengine=libaio\niodepth=32\ngroup_reporting\nnumjobs=4\ndirect=1\nblockalign=4k\nrw=randwrite\nbs=4k\n" > ${path}/precondition_file/fio_rand${i}_precondition.cfg
done
#====================== Add Nvme Portion to Precondition.cfg ========
k=1
for line in ${nvme_16T}; do
	echo -e "[nvme_"$k"]\nfilename=$line\nnew_group" >> ${path}/precondition_file/fio_seq1_precondition.cfg
	echo -e "[nvme_"$k"]\nfilename=$line\nnew_group" >> ${path}/precondition_file/fio_rand1_precondition.cfg
	k=$(($k+1))
done
for line in ${nvme_960G}; do
	echo -e "[nvme_"$k"]\nfilename=$line\nnew_group" >> ${path}/precondition_file/fio_seq2_precondition.cfg
        echo -e "[nvme_"$k"]\nfilename=$line\nnew_group" >> ${path}/precondition_file/fio_rand2_precondition.cfg
        k=$(($k+1))
done
#====================== Start Preconditioning =======================
echo "==================== 4k_16k seq pre ===================="
fio --output=${path}/precondition/fio_seq1_precondition.log ${path}/precondition_file/fio_seq1_precondition.cfg &
fio --output=${path}/precondition/fio_seq2_precondition.log ${path}/precondition_file/fio_seq2_precondition.cfg &
wait
echo "==================== 4k_16k rand pre ==================="
fio --output=${path}/precondition/fio_rand1_precondition.log ${path}/precondition_file/fio_rand1_precondition.cfg &
fio --output=${path}/precondition/fio_rand2_precondition.log ${path}/precondition_file/fio_rand2_precondition.cfg &
wait
secure_erase	
#====================== 4k_16k_randrw_job ===========================
for rw in 0 25 50 75 100; do
	for bs in 4 16; do
		for qo in 1 2 4 8 16 32 64 128; do
	echo -e "[global]\nnorandommap\nrandrepeat=0\ngroup_reporting\ntime_based\nruntime=10\nclocksource=gettimeofday\nrw=randrw\nrwmixwrite=${rw}\niodepth=${qo}\nnumjobs=4\nioengine=libaio\nbs=${bs}k\ndirect=1\nramp_time=10\npercentile_list=1:5:10:20:50:90:99.99:99.9999:99.999999\n" > ${path}/job_file/fio_${bs}k_${rw}rw_${qo}io.job		
#====================== Add Nvme Portion to Job =====================
			i=1
			for line in ${nvme}; do
				echo -e "[nvme_"$i"]\nfilename=$line\nnew_group" >> ${path}/job_file/fio_${bs}k_${rw}rw_${qo}io.job
				i=$(($i+1)) 
			done
#====================== Start to test ===============================
			echo "====================== 4k_16K ====================="
			fio --output=${path}/fio_log/fio_${bs}k_${rw}rw_${qo}io.log ${path}/job_file/fio_${bs}k_${rw}rw_${qo}io.job
			wait
#====================== Secure Erase ================================
#			secure_erase
		done
	done
done
secure_erase
#====================== Start Sequential Preconditioning =======================
echo "===================== before 128k pre ====================" 
fio --output=${path}/precondition/fio_128k_seq1_precondition.log ${path}/precondition_file/fio_seq1_precondition.cfg &
fio --output=${path}/precondition/fio_128k_seq2_precondition.log ${path}/precondition_file/fio_seq2_precondition.cfg &
wait
secure_erase
#====================== 128k_seqrw_job ==============================
for qo1 in 1 2 32; do
	for rw1 in 0 100; do
		echo -e "[global]\nrandrepeat=0\ngroup_reporting\ntime_based\nruntime=10\nclocksource=gettimeofday\nrw=write\niodepth=${qo1}\nnumjobs=1\nioengine=libaio\nbs=128k\ndirect=1\nramp_time=10\npercentile_list=1:5:10:20:50:90:99.99:99.9999:99.999999\n" > ${path}/job_file/fio_128k_${rw1}seqw_${qo1}io.job
#====================== Add Nvme Portion to Job =====================
		j=1
		for line in ${nvme}; do
			echo -e "[nvme_"$j"]\nfilename=$line\nnew_group" >> ${path}/job_file/fio_128k_${rw1}seqw_${qo1}io.job
			j=$(($j+1))
		done
#====================== Start to test ===============================
		echo "=============== 128k ================"
       		fio --output=${path}/fio_log/fio_128k_${rw1}seqw_${qo1}io.log ${path}/job_file/fio_128k_${rw1}seqw_${qo1}io.job
		wait
#====================== Secure Erase ================================
#	secure_erase
	done
done        
secure_erase	
