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
if ($option eq 'rowrestrict') {
	rowRestrict();
	exit;
}
if ($option eq 'gridfullsize') {
	gridFullSize();
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

sub rowRestrict {
	my $restrictfile = $confdir . 'gridRowRestriction.conf';
	my $option = $query->param('state');
	if ($option) {
		if (open my $fh, '+>', $restrictfile) {
			print $fh $option;
			close $fh;
			print "SUCCESS: Row restriction was updated successfully.";
		}
	} else {
		print "ERROR: No option detected.";
	}
}

sub gridFullSize {
	my $gridfsfile = $confdir . 'gridFullSize.conf';
	my $option = $query->param('state');
	if ($option) {
		if (open my $fh, '+>', $gridfsfile) {
			print $fh $option;
			close $fh;
			print "SUCCESS: STB Grid sizing was updated successfully.";
		}
	} else {
		print "ERROR: No option detected.";
	}
}
