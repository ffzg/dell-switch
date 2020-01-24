#!/bin/sh -xe

cat /dev/shm/snmp-mac-port/sw-* | awk '{ print $2 " " $3 }' | sort | uniq -c | sort -k 3 | column -t | less
