#!/usr/bin/perl -w
use strict;

chomp(my $pwd = `pwd`);
my ($maindir) = $pwd =~ /^(.*stbController\/)/;

my $filedir = $maindir . 'files/';
my $webdir = $maindir . 'web/';
my $configdir = $maindir . 'config/';
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

system("chmod -R 775 $maindir");
system("chmod -R 777 $filedir");
system("chmod 777 $webdir/dynamicTitle.txt");
system("chmod -R 777 $configdir");
