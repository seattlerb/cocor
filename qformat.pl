#!/usr/bin/perl -pi.bak

BEGIN {
    $i = 0;
}

s/^/\# / if /lastNr/;

$i++ if /^\s*\+/;
$i-- if /^\s*\-/;

$s = sprintf("%4d : ", $i);
s/^/$s/;

