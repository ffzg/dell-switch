#!/bin/sh

test -z "$1" && echo "Usage: $0 switch port" && exit 1

./snmp-mac-port $1

regex=$( grep " $2\$" /dev/shm/snmp-mac-port/$1 | awk '{ print $3 }' )
regex=$( echo $regex | sed -e 's/ /|/g' -e 's/^/(/' -e 's/$/)/' )

echo "# $regex"

ssh enesej egrep \"$regex\" /var/log/bro/current/conn.log | tee /dev/shm/bro-conn-$1-$2
