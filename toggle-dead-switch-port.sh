#!/bin/sh -e

if [ -z "$1" ] ; then
	#cat /dev/shm/sw.dead | while read sw ; do
	fping -u $( ./sw-names ) | tee /dev/shm/sw.dead | while read sw ; do
		./$0 $sw
	done
	exit 0
fi

sw=$1

echo "XXX $sw"
grep $sw /dev/shm/neighbors.tab | grep ^sw-dpc | sed 's/\t/ /g' | while read on_sw on_if mac to_port to_switch rest ; do
	echo "# [$on_sw] [$on_if]"

m=/home/dpavlin/mikrotik-switch

# cat << _MIKROTIK_
# # admin@sw-dpc-2] > /interface ethernet print where comment="sw-aula"
# # [admin@sw-dpc-2] > /interface ethernet print brief where comment="sw-aula"
# # [admin@sw-dpc-2] > /interface ethernet disable 0
# #[admin@sw-dpc-2] > /interface ethernet enable  0
# _MIKROTIK_
	#echo "/interface ethernet print where comment=\"$sw\""
	#echo "/interface ethernet disable"
	#echo ~/mikrotik-switch/m-ssh $on_sw
	
	$m/m-ssh-out $on_sw '/interface ethernet print' | grep $sw'.$'
	# cr/lf line endings, so end of line is .$
	port_nr=$( grep $sw'.$' ../mikrotik-switch/out/$on_sw*ethernet*print | awk '{ print $1 }' )
	echo "## $on_sw $port_nr -> $sw"
	test -z "$port_nr" && echo "no port for $sw on $on_sw" && exit 1

	$m/m-ssh $on_sw "/interface ethernet disable $port_nr"
	sleep 5
	$m/m-ssh $on_sw "/interface ethernet enable $port_nr"
	echo "XXX if ping $sw doesn't work, try"
	echo "XXX $m/m-ssh $on_sw '/interface bridge port set 2 edge=yes'"
	echo "XXX ./ssh.sh $sw # show spanning-tree active # and fix it"
	echo "XXX $m/m-ssh $on_sw '/interface bridge port set 2 edge=auto'"
done


grep ^$sw /dev/shm/neighbors.tab | sed 's/\t/ /g' | while read sw if mac on_port on_switch rest ; do
	echo "# [$on_switch] [$on_port]"
# # [sw-aula] [g22]
# dpavlin@black:~/dell-switch$ ./ssh.sh sw-aula
# configure
# interface ethernet g22
# shutdown
# no shutdown
# exit
# exit
# exit

# # [sw-lib] [Gi1/0/51]
# configure
# interface Gigabitethernet 1/0/51
#
	sh -x ./ssh-switch-port-down-up $on_switch $on_port
done






