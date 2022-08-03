

sh link_resets.sh && sleep 37h


a=`ps aw | grep "link_resets.sh" | awk '{print $1}'`
ps aw
for line in ${a}; do
	echo $line
	kill -9 ${line}
done
ps aw 
