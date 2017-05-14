 grep ' Up ' log/*interface*.log | sed 's/Gigabit - Level/1G/' | grep -v 'Link Aggregate' | tee /dev/shm/log | awk '{ print $1 " \t" $6 }' | sed -e 's/_show//' -e 's/log.*_//' | sort | uniq -c 
