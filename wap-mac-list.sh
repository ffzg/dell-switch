#!/bin/sh

# seed arp
./wap-names | xargs fping -q
# extract mac
sudo arp -a | grep wap | awk '{ print $4" "$1 }' | sed 's/\.infosl$//' | tee /dev/shm/mac.wap
