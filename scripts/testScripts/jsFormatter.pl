#!/usr/bin/perl -w
use strict;

my $file = '/home/stbController/web/resources/dragDrop.js';
my $newfile = '/home/stbController/web/resources/dragDropNew.js';

open FH1, '<', $file;
my @stuff = <FH1>;
close FH1;

open FH2, '+>', $newfile;

foreach my $line (@stuff) {
	$line =~ s/^\d+//;
	print FH2 $line;
}

close FH2;
