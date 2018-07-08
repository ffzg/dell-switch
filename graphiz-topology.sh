#!/bin/sh -xe

(
echo "digraph topology {"

egrep '\[sw-' /dev/shm/port-status/* | cut -d: -f2- | tr -d '\[' | tr -d '\]' | awk '{ printf("  \"%s\" -> \"%s\";\n", $1,$7)}'

echo "}"
) | tee /tmp/topology.dot | dot -Tsvg -o /tmp/topology.svg

