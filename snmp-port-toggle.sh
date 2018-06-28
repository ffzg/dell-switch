
sw=sw-a200
PORT=19

. ./snmp.conf

snmp="snmpget -v 2c -c $COMMUNITY -Cf -Ov -OQ $sw"

port_status() {

echo -n "$sw $PORT "`$snmp IF-MIB::ifName.$PORT IF-MIB::ifAlias.$PORT IF-MIB::ifType.$PORT IF-MIB::ifOperStatus.$PORT IF-MIB::ifHighSpeed.$PORT`

}

port_status

read -p "# Press ENTER to toggle port" wait_for_key

if [ "$status" = 'up' ] ; then

	# down
	snmpset -v1 -c $COMMUNITY $sw IF-MIB::ifAdminStatus.$PORT i 2
else
	# up
	snmpset -v1 -c $COMMUNITY $sw IF-MIB::ifAdminStatus.$PORT i 1
fi

port_status

