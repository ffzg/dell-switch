#!/bin/sh -e

# Usage: $0 [sw [oid]]

dir=/dev/shm/snmpbulkwalk/
test ! -d $dir && mkdir $dir

. ./snmp.conf

ext=""
if [ ! -z "$2" ] ; then
	ext=".$2/"
	test ! -d "$dir/$ext" && mkdir "$dir/$ext"
fi

( test ! -z "$1" && echo $1 || ./sw-names ) | xargs -i sh -c \
"snmpbulkwalk -OX -v2c -Cc -c $COMMUNITY {} $2 | tee $dir/$ext{} && test -z "$ext" && cd $dir && git add $dir/$ext{} && git commit -m {} $dir/$ext{}" #| parallel 

