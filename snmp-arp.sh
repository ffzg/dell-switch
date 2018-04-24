#!/bin/sh -xe

. ./snmp.conf 

log=/dev/shm/snmp-mac
test -d $log || mkdir $log

# (ipNetToMediaTable)
snmpbulkwalk -v2c -Cc -c $COMMUNITY $1 1.3.6.1.2.1.4.22 | tee $log/$1
