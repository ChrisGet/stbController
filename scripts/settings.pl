#!/usr/bin/perl -w
use strict;

use CGI;

my $query = CGI->new;
print $query->header();

chomp(my $maindir = (`cat homeDir.txt` || ''));
die "Couldn't find where my main files are installed. No \"stbController\" directory was found on your system...\n" if (!$maindir);
$maindir =~ s/\/$//;
my $confdir = $maindir . '/config/';
my $filedir = $maindir . '/files/';

my $option = $query->param('option') // '';

if ($option eq 'savelayout') {
	saveLayout();
	exit;
}

sub saveLayout {
	my $orderfile = $confdir . 'controllerPageOrder.conf';
	my $layout = $query->param('data') // '';
	if ($layout) {
		if (open my $fh, '+>', $orderfile) {
			print $fh $layout;
			close $fh;
			print "SUCCESS: Page layout saved. Please reload the Controller page for the new layout to take effect.";
		}
	}
}
