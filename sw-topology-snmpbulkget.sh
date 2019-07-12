#!/bin/sh -e

# Usage: $0 [sw [oid]]

dir=/dev/shm/snmp-topology/
if [ ! -d $dir ] ; then
	mkdir $dir
	ln -sv `pwd`/snmp-topology/.git $dir/
fi

. ./snmp.conf

( test ! -z "$1" && echo $1 || ./sw-names ) | xargs -i echo \
"snmpbulkwalk -OX -v2c -Cc -c $COMMUNITY {} Q-BRIDGE-MIB::dot1qTpFdbPort > $dir/{} ; "\
'test `cat '$dir'/{} | wc -l` -le 1 && ' \
"snmpbulkwalk -OX -v2c -Cc -c $COMMUNITY {} BRIDGE-MIB::dot1dTpFdbPort   >> $dir/{} ; " \
"snmpbulkwalk -OX -v2c -Cc -c $COMMUNITY {} IF-MIB::ifPhysAddress        >> $dir/{} "\
| tee /dev/shm/snmp-topology-snmpbulkwalk.sh | sh -x


# ./wap-mac-list.sh
./snmp-topology.pl

dot -Tsvg -o /var/www/snmp-topology-2.svg /tmp/snmp-topology.dot
