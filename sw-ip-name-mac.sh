#!/bin/sh

./sw-names | fping -q
/usr/sbin/arp -a | grep 10.20.0 | awk '{ print $2 " " $1 " " $4 }' | tr -d \( | tr -d \) | sed 's/\.infosl//' | tee /dev/shm/sw-ip-name-mac

