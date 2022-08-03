#!/bin/bash

mkdir /opt/performance_test_log
mkdir /opt/performance_test_log/precondition_log
mkdir /opt/performance_test_log/precondition_file
mkdir /opt/performance_test_log/fio_log
mkdir /opt/performance_test_log/job_file
path=/opt/performance_test_log
pm9a3_nvme=`nvme -list | grep "MZQL215THBLA" | awk '{print$1}'`
pm9a7_nvme=`nvme -list | grep "MZQL2960HCLS" | awk '{print$1}'`
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
	for blocksize in 4 16; do
	echo -e "[global]\nsize=1%\nloops=2\nioengine=libaio\niodepth=32\ngroup_reporting\nnumjobs=1\ndirect=1\nblockalign=4k\nrw=randwrite\nbs=${blocksize}k\n" > ${path}/precondition_file/fio_${blocksize}k_rand${i}_precondition.cfg
	done
done	
#====================== Add Nvme Portion to Precondition.cfg ========
        a=1
        for line in ${pm9a3_nvme}; do
                for file_name in seq1 4k_rand1 16k_rand1; do
                echo -e "[nvme_"$a"]\nfilename=$line\nnew_group" >> ${path}/precondition_file/fio_${file_name}_precondition.cfg
                done
                a=$(($a+1))
        done
        k=1
        for line in ${pm9a7_nvme}; do
                for file_name in seq2 4k_rand2 16k_rand2; do
                echo -e "[nvme_"$k"]\nfilename=$line\nnew_group" >> ${path}/precondition_file/fio_${file_name}_precondition.cfg
                done
                k=$(($k+1))
        done
#====================== Start 4k Random preconditioning  =======================
echo "==================== 4k seq pre ===================="
fio --output=${path}/precondition_log/fio_4k_seq1_precondition.log ${path}/precondition_file/fio_seq1_precondition.cfg &
fio --output=${path}/precondition_log/fio_4k_seq2_precondition.log ${path}/precondition_file/fio_seq2_precondition.cfg &
wait
echo "==================== 4k rand pre ==================="
fio --output=${path}/precondition_log/fio_4k_rand1_precondition.log ${path}/precondition_file/fio_4k_rand1_precondition.cfg &
fio --output=${path}/precondition_log/fio_4k_rand2_precondition.log ${path}/precondition_file/fio_4k_rand2_precondition.cfg &
wait
secure_erase	
#====================== 4k_randrw_job ===========================
for rw in 0 25 50 75 100; do
		for qo in 1 2 4 8 16 32 64 128; do
	echo -e "[global]\nnorandommap\nrandrepeat=0\ngroup_reporting\ntime_based\nruntime=10\nclocksource=gettimeofday\nrw=randrw\nrwmixwrite=${rw}\niodepth=${qo}\nnumjobs=4\nioengine=libaio\nbs=4k\ndirect=1\nramp_time=10\npercentile_list=1:5:10:20:50:90:99.99:99.9999:99.999999\n" > ${path}/job_file/fio_4k_${rw}rw_${qo}io.job		
#====================== Add Nvme Portion to Job =====================
			i=1
			for line in ${nvme}; do
				echo -e "[nvme_"$i"]\nfilename=$line\nnew_group" >> ${path}/job_file/fio_4k_${rw}rw_${qo}io.job
				i=$(($i+1)) 
			done
#====================== Start to test ===============================
			echo "====================== 4k ====================="
			fio --output=${path}/fio_log/fio_4k_${rw}rw_${qo}io.log ${path}/job_file/fio_4k_${rw}rw_${qo}io.job
			wait
#====================== Secure Erase ================================
#		secure_erase
		done
	done
secure_erase

#====================== Start 16k Random preconditioning  =======================
echo "==================== 16k seq pre ===================="
fio --output=${path}/precondition_log/fio_16k_seq1_precondition.log ${path}/precondition_file/fio_seq1_precondition.cfg &
fio --output=${path}/precondition_log/fio_16k_seq2_precondition.log ${path}/precondition_file/fio_seq2_precondition.cfg &
wait
echo "==================== 16k rand pre ==================="
fio --output=${path}/precondition_log/fio_16k_rand1_precondition.log ${path}/precondition_file/fio_16k_rand1_precondition.cfg &
fio --output=${path}/precondition_log/fio_16k_rand2_precondition.log ${path}/precondition_file/fio_16k_rand2_precondition.cfg &
wait
secure_erase
#====================== 16k_randrw_job ===========================
for rw in 0 25 50 75 100; do
                for qo in 1 2 4 8 16 32 64 128; do
        echo -e "[global]\nnorandommap\nrandrepeat=0\ngroup_reporting\ntime_based\nruntime=10\nclocksource=gettimeofday\nrw=randrw\nrwmixwrite=${rw}\niodepth=${qo}\nnumjobs=4\nioengine=libaio\nbs=16k\ndirect=1\nramp_time=10\npercentile_list=1:5:10:20:50:90:99.99:99.9999:99.999999\n" > ${path}/job_file/fio_16k_${rw}rw_${qo}io.job
#====================== Add Nvme Portion to Job =====================
                        i=1
                        for line in ${nvme}; do
                                echo -e "[nvme_"$i"]\nfilename=$line\nnew_group" >> ${path}/job_file/fio_4k_${rw}rw_${qo}io.job
                                i=$(($i+1))
                        done
#====================== Start to test ===============================
                        echo "====================== 16k ====================="
                        fio --output=${path}/fio_log/fio_16k_${rw}rw_${qo}io.log ${path}/job_file/fio_4k_${rw}rw_${qo}io.job
                        wait
#====================== Secure Erase ================================
#                secure_erase
                done
        done
secure_erase


#====================== Start 128k Sequential Preconditioning =======================
echo "===================== seq 128k pre ====================" 
fio --output=${path}/precondition_log/fio_128k_seq1_precondition.log ${path}/precondition_file/fio_seq1_precondition.cfg &
fio --output=${path}/precondition_log/fio_128k_seq2_precondition.log ${path}/precondition_file/fio_seq2_precondition.cfg &
wait
secure_erase
#====================== 128k_seqrw_job ==============================
for qo1 in 1 2 32; do
	for rw1 in 0 100; do
		echo -e "[global]\nrandrepeat=0\ngroup_reporting\ntime_based\nruntime=10\nclocksource=gettimeofday\nrw=write\niodepth=${qo1}\nnumjobs=1\nioengine=libaio\nbs=128k\ndirect=1\nramp_time=10\npercentile_list=1:5:10:20:50:90:99.99:99.9999:99.999999\n" > ${path}/job_file/fio_128k_${rw1}seqw_${qo1}io.job
#====================== Add Nvme Portion to Job =====================
		i=1
		for line in ${nvme}; do
			echo -e "[nvme_"$j"]\nfilename=$line\nnew_group" >> ${path}/job_file/fio_128k_${rw1}seqw_${qo1}io.job
			i=$(($i+1))
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
