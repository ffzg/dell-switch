#!/bin/sh -xe
patt=$*
test -z "$patt" && patt='.'
grep -r -i $patt /dev/shm/sw.mac.port/ | sed -e 's/^.*snmp.//' -e 's/:[^:]*: / /' -e 's/\].*: / /'
