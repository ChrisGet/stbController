#!/usr/bin/perl -w

use strict;
use CGI;
use CGI::Carp qw ( fatalsToBrowser );
use File::Basename;

my $query = new CGI;

print $query->header();

my $rows = $query->param("rows") // $ARGV[0] // '';
my $columns = $query->param("columns") // $ARGV[1] // '';

chomp(my $maindir = `cat homeDir.txt` || '');
my $confdir = $maindir . 'config/';
my $conffile = $confdir . 'stbGrid.conf';
open my $conf, '+>', $conffile or die "Couldn't open $conffile: $!\n";
print $conf "columns = $columns\nrows = $rows\n";
close $conf;
