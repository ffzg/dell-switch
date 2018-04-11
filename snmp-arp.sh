. ./snmp.conf 
snmpwalk -v2c -Cc -c $COMMUNITY $1 1.3.6.1.2.1.4.22 # (ipNetToMediaTable)
