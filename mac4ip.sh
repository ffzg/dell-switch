#!/bin/sh -e

ip=$1

ping -c 1 $ip >&2 && \
/usr/sbin/arp -an | grep "\($ip\)" | awk '{ print $4 }'
