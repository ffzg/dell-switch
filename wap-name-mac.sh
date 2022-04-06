#!/bin/sh

# seed arp
./wap-names | xargs fping -q
# extract mac
/usr/sbin/arp -a | grep wap | awk '{ print $1" "$4 }' | sed 's/\.infosl//' | tee /dev/shm/wap-name-mac
