#!/bin/sh -xe

sudo id ; sudo tail -f /var/log/switch/*.log | DUMP=1 ./syslog-count-link.pl
