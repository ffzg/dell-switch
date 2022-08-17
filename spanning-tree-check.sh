#!/bin/sh -e

# check for files older than day

find log -name '*active*' -ctime +1  | cut -d_ -f2 | while read sw ; do
	echo "# /dell-switch.pl $sw 'show spanning-tree active'"
	./dell-switch.pl $sw 'show spanning-tree active'
done

find ../mikrotik-switch/out -name '*bridge monitor 0 once' -ctime +1 | cut -d/ -f4 | cut -d. -f1 | while read sw ; do
	echo "# ../mikrotik-switch/m-ssh-out $sw 'interface bridge monitor 0 once'"
	../mikrotik-switch/m-ssh-out $sw 'interface bridge monitor 0 once'
done

(

#git -C out grep STP | grep -v RSTP | grep 'spanning-tree active' | sed -e 's/_/ /g'  | awk '{ print $2" .*"$6 }' > /tmp/st.1.patt

echo "# active roots"
git -C out grep -B 2 root '*active*'
git -C out grep -C 1 'root-bridge: yes'

echo "# root bridge"
(
git -C ../mikrotik-switch/out grep root-bridge-id | cut -d. -f 1,3 | sed 's/\./ /'
git -C out grep -A 4 'Root ID' '*active*' | grep Address | sed 's/_/ /g' | awk '{ print $2 " " $7 }'
) | sort -k 2 | column -t

echo "# STP only (RSTP ignored) -- should be empty if OK"
git -C out grep STP | grep -v RSTP | grep 'spanning-tree active' | tee /tmp/st.2.full | sed -e 's/_/ /g'  | awk '{ print $6"\t"$2"[ \t$]" }' > /tmp/st.2.patt
grep -f /tmp/st.2.patt /dev/shm/neighbors.tab | column -t

) | ./filter_mac_add_hostname | tee /dev/shm/$( basename $0 ).out
git -C /dev/shm commit -m "$( date +%Y-%m-%d ) $( basename $0 )" $( basename $0 ).out
