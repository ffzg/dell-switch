#!/bin/sh -xe

# Current status of the product.This is a rollup for the entire product.
# https://www.dell.com/community/Networking-General/SNMP-monitoring-on-PowerConnect-5448/td-p/3635681

# FIXME doesn't report failed fans correctly!

. ./snmp.conf
./sw-names | xargs -i sh -c "echo -n '{} ' ; snmpget -v 2c -c $COMMUNITY -Cf -Ov -OQ {} 1.3.6.1.4.1.674.10895.3000.1.2.110.1.0 2>/dev/null" | sed --unbuffered -e 's/ 3$/ OK/' -e 's/ 4$/ Non-critical/' -e 's/ 5$/ Critical/' | tee /dev/shm/sw-failed
