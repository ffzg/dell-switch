#!/bin/sh

grep : log/*bridge* | awk '{ print $1 " " $6 }' | sed -e 's,^.*/,,' -e 's/_/  /' -e 's/_[a-z]* /\t/' | sort | uniq -c
