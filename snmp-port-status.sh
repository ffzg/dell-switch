#!/bin/bash -e

# modified from https://gist.github.com/krokodilerian/a88b4ae992706c22e0b0
# see /var/lib/snmp/mibs/ietf/IF-MIB

if [ -z "$1" ]; then
	echo Usage: "$0" hostname ifAdminStatus BRIDGE-MIB::dot1dStpPortState ifInErrors ifOutErrors ifInDiscards
	exit 4
fi

log=/dev/shm/port-status/
test -d $log || mkdir $log

sw="$1"
shift # rest of arguments are IfEntry SEQUENCE
. ./snmp.conf

extra=$*
snmpwalk="snmpwalk -Oqs -v2c -Cc -c $COMMUNITY $sw"

fping $sw 2>>/dev/shm/dead

:> $log/$sw

for oid in ifName ifHighSpeed ifOperStatus $extra ifType ifAlias
do
	echo -n "# snmpwalk $sw [$oid] = " >/dev/stderr

	$snmpwalk $oid | cut -d. -f2- | tee $log/$sw-$oid | wc -l >/dev/stderr

	# put [] around alias and remove empty ones
	if [ "$oid" = 'ifAlias' ] ; then
		cat $log/$sw-$oid | sed -e 's/ / [/' -e 's/$/]/' -e 's/ \[\]$//' > $log/$sw-$oid.new && mv $log/$sw-$oid.new $log/$sw-$oid
	fi

	if [ ! -s $log/$sw ] ; then
		mv $log/$sw-$oid $log/$sw
	else
		join -a 1 $log/$sw $log/$sw-$oid > $log/$sw.new && mv $log/$sw.new $log/$sw
		rm $log/$sw-$oid
	fi
done

# add switch name prefix
cat $log/$sw | sed "s/^/$sw /" > $log/$sw.new && mv $log/$sw.new $log/$sw

cat $log/$sw

test ! -z "$extra" && exit 0 # don't commit if we have custom oids

ports_changed=`cd $log && git diff $sw | grep '^-' | awk '{ print $3 }' | tr '\n' ' '`
if [ ! -z "$ports_changed" ] ; then
	cd $log && git commit -m "$sw : $ports_changed" $log/$sw
fi
