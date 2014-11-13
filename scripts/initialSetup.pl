#!/usr/bin/perl -w
use strict;

chomp(my $pwd = `pwd`);
my ($maindir) = $pwd =~ /^(.*stbController\/)/;

my $dirfile = $maindir . 'files/homeDir.txt';
my $scriptfile = $maindir . 'scripts/homeDir.txt';
my $webpagesfile = $maindir . 'scripts/pages/homeDir.txt';
my $formsfile = $maindir . 'scripts/pages/forms/homeDir.txt';

my @files = ($dirfile , $scriptfile , $webpagesfile , $formsfile);

for (@files) {
	open FH, '+>', $_;
	print FH "$maindir";
	close FH;
	system("chmod 775 $_");
}
