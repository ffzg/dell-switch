#!/bin/bash -e

# modified from https://gist.github.com/krokodilerian/a88b4ae992706c22e0b0
# see /var/lib/snmp/mibs/ietf/IF-MIB

if [ -z "$1" ]; then
	echo Usage: "$0" hostname ifAdminStatus BRIDGE-MIB::dot1dStpPortState ifInErrors ifOutErrors ifInDiscards
	exit 4
fi

dir=/dev/shm/port-status/
if [ ! -d $dir ] ; then
	mkdir $dir
	ln -sv `pwd`/port-status/.git $dir/
fi

sw="$1"
shift # rest of arguments are IfEntry SEQUENCE
. ./snmp.conf

extra=$*
snmpwalk="snmpwalk -Oqs -v2c -Cc -c $COMMUNITY $sw"

fping $sw 2>>/dev/shm/dead

:> $dir/$sw

for oid in ifName ifHighSpeed ifAdminStatus ifOperStatus $extra ifType ifAlias
do
	echo -n "# snmpwalk $sw [$oid] = " >/dev/stderr

	$snmpwalk $oid | cut -d. -f2- | tee $dir/$sw-$oid | wc -l >/dev/stderr

	# put [] around alias and remove empty ones
	if [ "$oid" = 'ifAlias' ] ; then
		cat $dir/$sw-$oid | sed -e 's/ / [/' -e 's/$/]/' -e 's/ \[\]$//' > $dir/$sw-$oid.new && mv $dir/$sw-$oid.new $dir/$sw-$oid
	fi

	if [ ! -s $dir/$sw ] ; then
		mv $dir/$sw-$oid $dir/$sw
	else
		join -a 1 $dir/$sw $dir/$sw-$oid > $dir/$sw.new && mv $dir/$sw.new $dir/$sw
		rm $dir/$sw-$oid
	fi
done

# add switch name prefix
cat $dir/$sw | sed "s/^/$sw /" > $dir/$sw.new && mv $dir/$sw.new $dir/$sw

cat $dir/$sw

test ! -z "$extra" && exit 0 # don't commit if we have custom oids

ports_changed=`cd $dir && git diff $sw | grep '^-' | awk '{ print $3 }' | tr '\n' ' '`
if [ ! -z "$ports_changed" ] ; then
	cd $dir && git commit -m "$sw : $ports_changed" $dir/$sw
fi
