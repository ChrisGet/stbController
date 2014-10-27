#!/usr/bin/perl -w
use strict;

my $string = '1,36,5';

my @split = split(/(\d+)/,$string);

for (@split) {
	print "$_\n" if ($_);
}
