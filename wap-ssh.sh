#!/bin/sh

log=/dev/shm/wap
test -d $log || mkdir $log
file=`echo $* | sed 's/  */_/g'`
ssh -i /home/dpavlin/.ssh/wifiadmin -o StrictHostKeyChecking=no root@$* | tee $log/$file
