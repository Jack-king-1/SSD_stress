mkdir /opt/read_only_log
mkdir -p /opt/read_only_log/smart_log/error
mkdir /opt/read_only_log/job_file
mkdir /opt/read_only_log/fio_log
path=/opt/read_only_log

nvme=`nvme -list | awk '{print$1}' | grep -v -E "Node|-"`
record_smart_data()
{
#        for SSD in {0..12}; do
#                smartctl -x /dev/nvme${SSD}n1 >> ${path}/smart_log/smart_nvme${SSD}n1.log
#        done
        for SSD in {0..12}; do
                smartctl -x /dev/nvme${SSD}n1 >> ${path}/smart_log/smart_nvme${SSD}n1.log
                if [[ `smartctl -x /dev/nvme${SSD}n1|grep -i "Media and Data Integrity Errors"|awk '{print $6}'` -gt 0 ]]; then
			echo -e "\033[46;30m==========Media and Data Integrity Errors > 0 !!!==========\033[0m" | tee -a ${path}/error/nvme${SSD}n1_smart_error.log
                        smartctl -x /dev/nvme${SSD}n1|tee -a ${path}/smart_log/error/nvme${SSD}n1_smart_error.log
                fi
                if [[ `smartctl -x /dev/nvme${SSD}n1|grep -i "Error Information Log Entries"|awk '{print $5}'` -gt 0 ]]; then
			echo -e "\033[46;30m==========Error Information Log Entries > 0 !!!==========\033[0m" | tee -a ${path}/error/nvme${SSD}n1_smart_error.log
                        smartctl -x /dev/nvme${SSD}n1|tee -a ${path}/smart_log/error/nvme${SSD}n1_smart_error.log
                fi
                if [[ `smartctl -x /dev/nvme${SSD}n1|grep -i "Warning  Comp. Temperature Time"|awk '{print $5}'` -gt 0 ]]; then
                        echo  -e "\033[46;30m==========Warning  Comp. Temperature Time > 0 !!!==========\033[0m" | tee -a ${path}/error/nvme${SSD}n1_smart_error.log
                        smartctl -x /dev/nvme${SSD}n1|tee -a ${path}/smart_log/error/nvme${SSD}n1_smart_error.log
                fi
                if [[ `smartctl -x /dev/nvme${SSD}n1|grep -i "Critical Comp. Temperature Time"|awk '{print $5}'` -gt 0 ]]; then
                        echo -e "\033[46;30m==========Critical Comp. Temperature Time > 0 !!!==========\033[0m" | tee -a ${path}/error/nvme${SSD}n1_smart_error.log
                        smartctl -x /dev/nvme${SSD}n1|tee -a ${path}/smart_log/error/nvme${SSD}n1_smart_error.log
                fi
        done

}

echo "========== Start time ==========" | tee -a ${path}/total_time.log
date | tee -a ${path}/total_time.log

for SSD in {0..12}; do
        echo -e "\033[46;30m========== Before Test ===========\033[0m" >> ${path}/smart_log/smart_nvme${SSD}n1.log
done
record_smart_data
#====== 1k Random Write Only ======
for qo in 1 2; do
        echo -e "[global]\nnorandommap\nrandrepeat=0\ngroup_reporting\ntime_based\nruntime=5\nclocksource=gettimeofday\nrw=randrw\nrwmixwrite=100\niodepth=${qo}\nnumjobs=4\nioengine=libaio\nbs=1k\ndirect=1\npercentile_list=1:5:10:20:50:90:99.99:99.9999:99.999999\n" > ${path}/job_file/fio_1k_100randw_${qo}io.job
        i=1
        for line in ${nvme}; do
                echo -e "[nvme_"$i"]\nfilename=$line\nnew_group" >> ${path}/job_file/fio_1k_100randw_${qo}io.job
                i=$(($i+1))
        done
        fio --output=${path}/fio_log/fio_1k_100randw_${qo}io.log ${path}/job_file/fio_1k_100randw_${qo}io.job
        wait
done

#====== 4k Random Read Only ======
for qo1 in 1 2 4 8 16 32; do
        echo -e "[global]\nnorandommap\nrandrepeat=0\ngroup_reporting\ntime_based\nruntime=5\nclocksource=gettimeofday\nrw=randrw\nrwmixwrite=0\niodepth=${qo1}\nnumjobs=4\nioengine=libaio\nbs=4k\ndirect=1\npercentile_list=1:5:10:20:50:90:99.99:99.9999:99.999999\n" > ${path}/job_file/fio_4k_0randw_${qo1}io.job
        j=1
        for line in ${nvme}; do
                echo -e "[nvme_"$j"]\nfilename=$line\nnew_group" >> ${path}/job_file/fio_4k_0randw_${qo1}io.job
                j=$(($j+1))
        done
        fio --output=${path}/fio_log/fio_4k_0randw_${qo1}io.log ${path}/job_file/fio_4k_0randw_${qo1}io.job
        wait
done

for SSD in {0..12}; do
        echo -e "\033[46;30m========== After 1k write and 4k read Test ===========\033[0m" >> ${path}/smart_log/smart_nvme${SSD}n1.log
done
record_smart_data
sleep 10
#====== 16k Random Read Only ======
for qo2 in 1 2 4 8 16 32; do
        echo -e "[global]\nnorandommap\nrandrepeat=0\ngroup_reporting\ntime_based\nruntime=5\nclocksource=gettimeofday\nrw=randrw\nrwmixwrite=0\niodepth=${qo2}\nnumjobs=4\nioengine=libaio\nbs=16k\ndirect=1\npercentile_list=1:5:10:20:50:90:99.99:99.9999:99.999999\n" > ${path}/job_file/fio_16k_0randw_${qo2}io.job
        k=1
        for line in ${nvme}; do
                echo -e "[nvme_"$k"]\nfilename=$line\nnew_group" >> ${path}/job_file/fio_16k_0randw_${qo2}io.job
                k=$(($k+1))
        done
        fio --output=${path}/fio_log/fio_16k_0randw_${qo2}io.log ${path}/job_file/fio_16k_0randw_${qo2}io.job
        wait
done

for SSD in {0..12}; do
        echo -e "\033[46;30m========== After 16k read Test ===========\033[0m" >> ${path}/smart_log/smart_nvme${SSD}n1.log
done
record_smart_data

echo "========== End time ==========" | tee -a ${path}/total_time.log
date | tee -a ${path}/total_time.log

