#!/bin/sh

test -e /dev/shm/.git || ln -sv $( pwd )/shm/.git /dev/shm/.git

# seed arp
./wap-names | xargs fping -q
# extract mac
/usr/sbin/arp -a | grep wap | awk '{ print $1" "$4 }' | sed 's/\.infosl//' | tee /dev/shm/wap-name-mac

git -C /dev/shm commit -m $( date +%Y-%m-%d ) -a
