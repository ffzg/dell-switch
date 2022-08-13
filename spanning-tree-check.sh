#!/bin/sh -e

# check for files older than day

find log -name '*active*' -ctime +1  | cut -d_ -f2 | while read sw ; do
	./dell-switch.pl $sw 'show spanning-tree active'
	echo -n '.'
done


#git -C out grep STP | grep -v RSTP | grep 'spanning-tree active' | sed -e 's/_/ /g'  | awk '{ print $2" .*"$6 }' > /tmp/st.1.patt

echo "# active roots"
git -C out grep -B 2 root '*active*'

echo "# root bridge"
(
git -C ../mikrotik-switch/out grep root-bridge-id | cut -d. -f 1,3 | sed 's/\./ /'
git -C out grep -A 4 'Root ID' '*active*' | grep Address | sed 's/_/ /g' | awk '{ print $2 " " $7 }'
) | sort -k 2 | column -t

echo "# STP only (RSTP ignored) -- should be empty if OK"
git -C out grep STP | grep -v RSTP | grep 'spanning-tree active' | tee /tmp/st.2.full | sed -e 's/_/ /g'  | awk '{ print $6"\t"$2"[ \t$]" }' > /tmp/st.2.patt
grep -f /tmp/st.2.patt /dev/shm/neighbors.tab | column -t
