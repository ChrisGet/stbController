#!/usr/bin/perl -w
use strict;
use CGI;

my $query = CGI->new;
print $query->header();

chomp(my $title = $ARGV[0] || $query->param('title') || '');
chomp(my $maindir = (`cat homeDir.txt` || ''));
die "Couldn't find where my main files are installed. No \"stbController\" directory was found on your system...\n" if (!$maindir);
$maindir =~ s/\/$//;
my $titlefile = $maindir . '/web/dynamicTitle.txt';
open FH, '+>', $titlefile or die "Unable to open $titlefile for editing: $!\n";
print FH $title;
close FH;
