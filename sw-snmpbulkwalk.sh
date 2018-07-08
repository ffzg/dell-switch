mkdir /dev/shm/snmpbulkwalk/

./sw-names | xargs -i echo "snmpbulkwalk -OX -v2c -Cc -c $COMMUNITY {} | tee /dev/shm/snmpbulkwalk/{}" | parallel 

