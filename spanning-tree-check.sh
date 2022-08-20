#!/bin/sh

# check for files older than day

find log -name '*active*' -ctime +1  | cut -d_ -f2 | while read sw ; do
	echo "# /dell-switch.pl $sw 'show spanning-tree active'"
	./dell-switch.pl $sw 'show spanning-tree active'
done

m_path=../mikrotik-switch
find $m_path/out -name '*bridge monitor 0 once' -ctime +1 | cut -d/ -f4 | cut -d. -f1 | while read sw ; do
	echo "# $m_path/m-ssh-out $sw 'interface bridge monitor 0 once'"
	$m_path/m-ssh-out $sw 'interface bridge monitor 0 once'
done

(

#git -C log grep STP | grep -v RSTP | grep 'spanning-tree active' | sed -e 's/_/ /g'  | awk '{ print $2" .*"$6 }' > /tmp/st.1.patt

echo "# active roots"
#git -C log grep -B 2 root '*active*'
git -C log grep -B 4 'switch is' '*active*'
#git -C log grep -B 4 'regional Root' '*active*'
#git -C log grep -B 3 'CST ROOT' '*active*'
git -C $m_path/out grep -C 1 'root-bridge: yes'

echo "# root bridge"
(
git -C $m_path/out grep root-bridge-id | cut -d. -f 1,3 | sed 's/\./ /'
git -C log grep -A 4 -i 'Root ID' '*active*' | grep Address | sed 's/_/ /g' | awk '{ print $2 " " $7 }'
) | sort -k 2 | column -t

echo "# STP only (RSTP ignored) -- should be empty if OK"
git -C log grep STP | grep -v RSTP | grep 'spanning-tree active' | tee /tmp/st.2.full | sed -e 's/_/ /g'  | awk '{ print $6"\t"$2"[ \t$]" }' > /tmp/st.2.patt
grep -f /tmp/st.2.patt /dev/shm/neighbors.tab | column -t

) | ./filter_mac_add_hostname | ./filter_log | tee /dev/shm/$( basename $0 ).out
test -z "$DEBUG" && git -C /dev/shm commit -m "$( date +%Y-%m-%d ) $( basename $0 )" $( basename $0 ).out
