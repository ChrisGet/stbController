#!/usr/bin/perl -w
use strict;

my $orig = 'dragDropController.html';
my $new = 'sequenceController.html';

open FH, '<', $orig;
my @lines = <FH>;
close FH;

open FH2, '+>', $new;
foreach my $line (@lines) {
	$line =~ s/stbControl\(\'control\'\,/seqTextUpdate\(/;
	print FH2 $line;
}
close FH2;
