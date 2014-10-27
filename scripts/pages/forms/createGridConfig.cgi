#!/usr/bin/perl -w

use strict;
use CGI;
use CGI::Carp qw ( fatalsToBrowser );
use File::Basename;

my $query = new CGI;
#$CGI::POST_MAX = 1024 * 16000;

#print $query->header();

my $rows = $query->param("rows") || '';
my $columns = $query->param("columns") || '';

chomp(my $maindir = `cat homeDir.txt` || '');

my $confdir = $maindir . 'config/';
#open FH, '+>', "/home/stbController/scripts/pageForms/testFormOutput.txt" or die "Couldn't open file: $!\n";
#print FH "Columns = $columns\nRows = $rows\n";
#close FH;
my $conffile = $confdir . 'stbGrid.conf';
open my $conf, '+>', $conffile or die "Couldn't open $conffile: $!\n";
print $conf "columns = $columns\nrows = $rows\n";
close $conf;
