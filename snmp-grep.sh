#!/bin/sh -xe
patt=$*
test -z "$patt" && patt='.'
grep -r -i $patt /dev/shm/snmp-mac-port/
