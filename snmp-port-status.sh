#!/bin/bash

# modified from https://gist.github.com/krokodilerian/a88b4ae992706c22e0b0
# see /var/lib/snmp/mibs/ietf/IF-MIB

if [ -z "$1" ]; then
	echo Usage: "$0" hostname
	exit 4
fi

sw="$1"
. ./snmp.conf
snmp="snmpget -v 2c -c $COMMUNITY -Cf -Ov -OQ $sw"

numports=`$snmp IF-MIB::ifNumber.0`

for i in `seq 1 $numports`; do
	name=`$snmp IF-MIB::ifAlias.$i`
	if [ "$name" = "No Such Instance currently exists at this OID" ]; then
		continue
	fi

	iftype=`$snmp IF-MIB::ifType.$i`

#	if [ "$iftype" = "other" ] || [ "$iftype" = propVirtual ] || [ "$iftype" = softwareLoopback ]; then
#		continue
#	fi 
	
	status=`$snmp IF-MIB::ifOperStatus.$i`
	if [ "$status" = "notPresent" ] ; then
		continue;
	fi

	#descr=`$snmp IF-MIB::ifDescr.$i`
	speed=`$snmp IF-MIB::ifSpeed.$i | sed 's/000000//'`

#	echo "## $sw [$name] $iftype $status $descr $speed"
	echo "$sw $i $speed $status [$name]"
done
