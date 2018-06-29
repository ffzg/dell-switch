#!/bin/bash -e

# modified from https://gist.github.com/krokodilerian/a88b4ae992706c22e0b0
# see /var/lib/snmp/mibs/ietf/IF-MIB

if [ -z "$1" ]; then
	echo Usage: "$0" hostname ifInErrors ifOutErrors ifInDiscards
	exit 4
fi

log=/dev/shm/port-status/
test -d $log || mkdir $log

sw="$1"
shift # rest of arguments are IfEntry SEQUENCE
. ./snmp.conf

snmpwalk="snmpwalk -Oqs -v2c -Cc -c $COMMUNITY $sw"


:> $log/$sw

for oid in ifName ifHighSpeed ifOperStatus ifType $* ifAlias
do
	echo -n "# snmpwalk $sw [$oid] = "

	$snmpwalk $oid | cut -d. -f2- | tee $log/$sw-$oid | wc -l

	# put [] around alias and remove empty ones
	if [ "$oid" = 'ifAlias' ] ; then
		cat $log/$sw-$oid | sed -e 's/ / [/' -e 's/$/]/' -e 's/ \[\]$//' > $log/$sw-$oid.new && mv $log/$sw-$oid.new $log/$sw-$oid
	fi

	if [ ! -s $log/$sw ] ; then
		mv $log/$sw-$oid $log/$sw
	else
		join -a 1 $log/$sw $log/$sw-$oid > $log/$sw.new && mv $log/$sw.new $log/$sw
		rm $log/$sw-$oid
	fi
done

# add switch name prefix
cat $log/$sw | sed "s/^/$sw /" > $log/$sw.new && mv $log/$sw.new $log/$sw

cat $log/$sw

exit 1

snmp="snmpget -v 2c -c $COMMUNITY -Cf -Ov -OQ $sw"

numports=`$snmp IF-MIB::ifNumber.0`
:> $log/$sw

for PORT in `seq 1 $numports`; do

##	name=`$snmp IF-MIB::ifName.$i`
##	alias=`$snmp IF-MIB::ifAlias.$i`
##	if [ "$name" = "No Such Instance currently exists at this OID" ]; then
##		continue
##	fi
##
##	iftype=`$snmp IF-MIB::ifType.$i`
##
###	if [ "$iftype" = "other" ] || [ "$iftype" = propVirtual ] || [ "$iftype" = softwareLoopback ]; then
###		continue
###	fi 
##	
##	status=`$snmp IF-MIB::ifOperStatus.$i`
##	if [ "$status" = "notPresent" ] ; then
##		continue;
##	fi
##
##	#descr=`$snmp IF-MIB::ifDescr.$i`
##	#speed=`$snmp IF-MIB::ifSpeed.$i | sed 's/000000//'`
##	speed=`$snmp IF-MIB::ifHighSpeed.$i`
##
##	extra=""
##	for add in "$@"; do
##		extra="$extra "`$snmp IF-MIB::$add.$i`
##	done
##
###	echo "## $sw [$name] $iftype $status $descr $speed"
##	#echo "$sw $i $name $speed $status $iftype$extra [$alias]" | tee -a $log/$sw

	echo "$sw $PORT "`$snmp IF-MIB::ifName.$PORT $* IF-MIB::ifHighSpeed.$PORT IF-MIB::ifOperStatus.$PORT IF-MIB::ifType.$PORT IF-MIB::ifAlias.$PORT` | grep -v 'No Such Instance currently exists at this OID' | sed 's/\(ethernetCsmacd\) \(..*\)$/\1 [\2]/' | tee -a $log/$sw
done

exit 1

ports_changed=`cd $log && git diff $sw | grep '^-' | awk '{ print $3 }' | tr '\n' ' '`
if [ ! -z "$ports_changed" ] ; then
	cd $log && git commit -m "$sw : $ports_changed" $log/$sw
fi
