for SSD in {0..12}; do
	nvme format -s 1 -f /dev/nvme${SSD}n1 &
done
	wait

