#!/bin/bash

r1i=$1; shift
r2i=$1; shift

if [ -z $r1i ]; then r1i=build/output ; fi
if [ -z $r2i ]; then r2i=build2/output; fi

r1o=/tmp/r1.$$
r2o=/tmp/r2.$$

perl -pe 's/^.*lastNr.*//' $r1i | cut -c 1 > $r1o
perl -pe 's/^.*lastNr.*//' $r2i | cut -c 1 > $r2o

cmp $r1o $r2o && echo "Same!"
