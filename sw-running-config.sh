#!/bin/sh -xe

sw=$1

NO_LOG=1 ./dell-switch.pl $sw "copy running-config tftp://10.20.0.216/$sw"
cd running-config
git add $sw
git commit -m $sw
