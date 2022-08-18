./vlans.pl | tee /dev/shm/vlans
../mikrotik-switch/vlans.pl | tee -a /dev/shm/vlans
git -C /dev/shm/ add vlans
git -C /dev/shm/ commit -m vlans vlans
