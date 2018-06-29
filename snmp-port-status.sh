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

	echo "$sw $PORT "`$snmp IF-MIB::ifName.$PORT IF-MIB::ifHighSpeed.$PORT IF-MIB::ifOperStatus.$PORT IF-MIB::ifType.$PORT IF-MIB::ifAlias.$PORT` | grep -v 'No Such Instance currently exists at this OID' | sed 's/\(ethernetCsmacd\) \(..*\)$/\1 [\2]/' | tee -a $log/$sw
done

