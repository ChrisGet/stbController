#!/usr/bin/perl -w
use strict;

use DBM::Deep;

tie my %hash, 'DBM::Deep', '/home/stbController/config/stbDatabase.db';

for (sort keys %hash) {
	print "$_\n";
}
