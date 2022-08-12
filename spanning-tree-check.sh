#!/bin/sh -e

#git -C out grep STP | grep -v RSTP | grep 'spanning-tree active' | sed -e 's/_/ /g'  | awk '{ print $2" .*"$6 }' > /tmp/st.1.patt

# active roots
git -C out grep root '*active*'

git -C ../mikrotik-switch/out grep root-bridge-id


echo "# STP only (RSTP ignored)"
git -C out grep STP | grep -v RSTP | grep 'spanning-tree active' | tee /tmp/st.2.full | sed -e 's/_/ /g'  | awk '{ print $6"\t"$2"[ \t$]" }' > /tmp/st.2.patt
grep -f /tmp/st.2.patt /dev/shm/neighbors.tab | column -t
