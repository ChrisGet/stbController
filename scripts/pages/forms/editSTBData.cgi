#!/usr/bin/perl -w
use strict;

use DBM::Deep;
use CGI;
use CGI::Carp qw ( fatalsToBrowser );
use File::Basename;

my $query = new CGI;

print $query->header();
my @params = $query->param;
my $stbname = $query->param('stbname');

chomp(my $maindir = `cat homeDir.txt` || '');
my $confdir = $maindir . 'config/';
my $dbfile = $confdir . 'stbDatabase.db';
tie my %stbdata, 'DBM::Deep', {file => $dbfile,   locking => 1, autoflush => 1, num_txns => 100};

foreach my $param (@params) {
	next if ($param =~ /stbname/);
	my $value = $query->param($param);
	$value =~ s/^\s+//g;
	$value =~ s/\s+$//g;
	if (exists $stbdata{$stbname}{$param}) {
		if ($stbdata{$stbname}{$param} ne $value) {
			$stbdata{$stbname}{$param} = $value;
		}
	} else {
		$stbdata{$stbname}{$param} = $value;
	}
}

untie %stbdata;
