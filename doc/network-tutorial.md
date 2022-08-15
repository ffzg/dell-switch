# switch configuration change

```
dpavlin@black:~/dell-switch$
./git-log-merge.pl -p
```

# see network connections from lldp

```
./neighbours.pl 2>&1 | less

less /dev/shm/neighbors.tab
```

# check spanning tree

```
dpavlin@black:~/dell-switch$
./spanning-tree-check.sh | less
```

# network connectivity as connected graph

run neigbours.pl before this

```
./sbw-parse.pl
```

https://black.ffzg.hr/network.svg

# see all devices on switch ports

```
cat /dev/shm/snmp-mac-port/sw-fond | sort -k 4 -n | ./filter_mac_add_hostname | less
```
