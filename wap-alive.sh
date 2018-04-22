grep '^\[wifi.ffzg;wap-' /etc/munin/munin.conf | cut -d\; -f2 | cut -d \] -f1 | xargs fping -a | grep -v wap-dekanat

