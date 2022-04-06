#!/bin/sh -e

sw=$1

config=$( basename $0 | sed -e 's/^sw-//' -e 's/.sh$//' )

NO_LOG=1 ./dell-switch.pl $sw "copy $config tftp://10.20.0.216/$sw"
cd running-config
git add $sw
git commit -m "$sw $config"
