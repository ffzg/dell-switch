#!/bin/sh -xe

sudo id ; sudo tail -f /var/log/switch/*.log | ./syslog-count-link.pl
