#!/bin/sh

if [ ! -z "$1" ] ; then
	./snmp-port-status.sh $@
	exit 0
fi

./sw-names | xargs -i echo ./snmp-port-status.sh {} $* | parallel
