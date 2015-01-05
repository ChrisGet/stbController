#!/usr/bin/perl -w

use strict;
use CGI;
use CGI::Carp qw ( fatalsToBrowser );
use File::Basename;

my $query = new CGI;

my $rows = $query->param("rows") || '';
my $columns = $query->param("columns") || '';

chomp(my $maindir = `cat homeDir.txt` || '');
my $confdir = $maindir . 'config/';
my $conffile = $confdir . 'stbGrid.conf';
open my $conf, '+>', $conffile or die "Couldn't open $conffile: $!\n";
print $conf "columns = $columns\nrows = $rows\n";
close $conf;
