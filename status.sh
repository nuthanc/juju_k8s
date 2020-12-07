n20_status=$(juju status|grep noden20)
n29_status=$(juju status|grep noden29)
n19_status=$(juju status|grep noden19)
i34_status=$(juju status|grep nodei34)
c9_status=$(juju status|grep nodec9)

while [[ ${n20_status} != *"Deployed"* ]] || [[ ${n29_status} != *"Deployed"* ]] || [[ ${i34_status} != *"Deployed"* ]] || [[ ${n19_status} != *"Deployed"* ]] || [[ ${c9_status} != *"Deployed"* ]]; do
	echo "Deploying"
	n20_status=$(juju status|grep noden20)
	n29_status=$(juju status|grep noden29)
	#i34_status=$(juju status|grep nodei34)
	i34_status=$(juju status|grep nodei34)
	c9_status=$(juju status|grep nodec9)
	n19_status=$(juju status|grep noden19)

	# c61_status=$(juju status|grep nodec61)
	echo $n20_status
	echo $n29_status
	echo $i34_status
	echo $c9_status
	echo $n19_status
	# echo $c61_status
	sleep 5
done
