#!/bin/sh -e

# Usage: $0 [sw [oid]]

dir=/dev/shm/snmp-topology/
if [ ! -d $dir ] ; then
	mkdir $dir
	ln -sv `pwd`/snmp-topology/.git $dir/
fi

. ./snmp.conf

ext=""
if [ ! -z "$2" ] ; then
	ext=".$2/"
	test ! -d "$dir/$ext" && mkdir "$dir/$ext"
fi

( test ! -z "$1" && echo $1 || ./sw-names ) | xargs -i echo \
"test ! -e $dir/{} && " \
"snmpbulkwalk -OX -v2c -Cc -c $COMMUNITY {} IF-MIB::ifPhysAddress        | tee -a $dir/{}     && "\
"snmpbulkwalk -OX -v2c -Cc -c $COMMUNITY {} Q-BRIDGE-MIB::dot1qTpFdbPort | tee -a $dir/$ext{} || "\
"snmpbulkwalk -OX -v2c -Cc -c $COMMUNITY {} BRIDGE-MIB::dot1dTpFdbPort   | tee -a $dir/{} " | sh -x


