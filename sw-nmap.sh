#!/bin/sh -xe

ip="10.20.0.0/24"
test ! -z "$1" && ip=$1
file=/dev/shm/nmap.sw.$( echo $ip | cut -d/ -f1 )

nmap -oG - $ip | tee /dev/stderr | grep open > $file
