#!/bin/sh -e

name=$1

ip=$( ping -c 1 $name | grep '^PING' | cut -d' ' -f3 )
/usr/sbin/arp -an | grep "\($ip\)" | awk '{ print $4 }'
