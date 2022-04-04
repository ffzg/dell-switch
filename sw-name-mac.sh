#!/bin/sh -e

# we need to expand all values to two digits
grep IF-MIB::ifPhysAddress snmpbulkwalk/* | sed -e 's/\// /' -e 's/:/ /' | cut -d' ' -f2,6 | sort -u | sed -e 's/ 0:/ 00:/' \
-e 's/:\([0-9a-f]\):/:0\1:/gi' \
-e 's/:\([0-9a-f]\):/:0\1:/gi' \
-e 's/:\([0-9a-f]\):/:0\1:/gi' \
-e 's/:\([0-9a-f]\):/:0\1:/gi' \
-e 's/:\([0-9a-f]\)$/:0\1/i' | tee /dev/shm/sw-name-mac
