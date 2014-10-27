#!/usr/bin/perl -w
use strict;

use CGI;
use DBM::Deep;

my $query = CGI->new;
print $query->header();

chomp(my $boxes = $query->param('boxes') || '');
chomp(my $maindir = (`cat ../files/homeDir.txt` || ''));
die "Couldn't find where my main files are installed. No \"stbController\" directory was found on your system...\n" if (!$maindir);
$maindir =~ s/\/$//;
my $stblog = $maindir . '/web/lastBoxes.txt';

open FH, '+>', $stblog;
print FH $boxes;
close FH;
