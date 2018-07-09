./sw-names | xargs -i echo ./snmp-port-status.sh {} $* | parallel
