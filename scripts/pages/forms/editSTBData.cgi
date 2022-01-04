#!/usr/bin/perl -w

use strict;
use CGI;
use CGI::Carp qw ( fatalsToBrowser );
use File::Basename;
use JSON;

my $query = new CGI;

print $query->header();
my @params = $query->param;
my $stbname = $query->param('stbname');

chomp(my $maindir = `cat homeDir.txt` || '');
my $confdir = $maindir . 'config/';
my $stbdatafile = $confdir . 'stbData.json';
my $json = JSON->new->allow_nonref;
$json = $json->canonical('1');

my %stbdata;
if (-e $stbdatafile) {
	local $/ = undef;
	open my $fh, "<", $stbdatafile or die "ERROR: Unable to open $stbdatafile: $!\n";
	my $data = <$fh>;
	if ($data) {
		my $decoded = $json->decode($data);
		%stbdata = %{$decoded};
	}
}

foreach my $param (@params) {
	next if ($param =~ /stbname/);
	my $value = $query->param($param);
	$value =~ s/^\s+//g;
	$value =~ s/\s+$//g;
	$value = '' if ($value =~ /Please Choose/i);
	if (exists $stbdata{$stbname}{$param}) {
		if ($stbdata{$stbname}{$param} ne $value) {
			$stbdata{$stbname}{$param} = $value;
		}
	} else {
		$stbdata{$stbname}{$param} = $value;
	}
}

my $encoded = $json->pretty->encode(\%stbdata);
if (open my $newfh, '+>', $stbdatafile) {
	print $newfh $encoded;
	close $newfh;
	print "Success";
} else {
	print "Fail";
	die "ERROR: Unable to open $stbdatafile: $!\n";
}
