#!/bin/sh -e

# display macs on port: mac-on-port sw-b300 8

./snmp-mac-port $1 > /dev/null
echo "# $1 port $2"
grep " $2$" /dev/shm/snmp-mac-port/$1
