#!/bin/sh -e

ssh enesej "cat /var/log/bro/current/conn.log | bro-cut -d id.orig_h vlan orig_l2_addr -F' ' | grep '^$1 ' | head -1"

