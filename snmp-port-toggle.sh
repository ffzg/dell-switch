#!/bin/sh -e

sw=$1
PORT=$2

test -z "$sw" -o -z "$PORT" && echo "Usage: sw-name port" && exit 1

. ./snmp.conf

snmp="snmpget -v 2c -c $COMMUNITY -Cf -Ov -OQ $sw"

port_status() {

echo "$sw $PORT "`$snmp IF-MIB::ifName.$PORT IF-MIB::ifAlias.$PORT IF-MIB::ifType.$PORT IF-MIB::ifOperStatus.$PORT IF-MIB::ifHighSpeed.$PORT`

}

port_status

status=`$snmp IF-MIB::ifOperStatus.$PORT`
read -p "# Press ENTER to toggle port which is now $status" wait_for_key

if [ "$status" = 'up' ] ; then

	# down
	snmpset -v1 -c $COMMUNITY $sw IF-MIB::ifAdminStatus.$PORT i 2
else
	# up
	snmpset -v1 -c $COMMUNITY $sw IF-MIB::ifAdminStatus.$PORT i 1
fi

echo "# wait for port status change from $status"
while port_status | tee /dev/stderr | grep $status ; do
	sleep 1
done

