#!/usr/bin/perl -w

use strict;
use CGI;

my $query = CGI->new;
print $query->header();

chomp(my $maindir = (`cat homeDir.txt` || ''));
die "Couldn't find where my main files are installed. No \"stbController\" directory was found on your system...\n" if (!$maindir);
$maindir =~ s/\/$//;
my $confdir = $maindir . '/config/';
my $controlremotelog = $confdir . 'controllerRemote.txt';
my $filedir = $maindir . '/files/';
my $pagedir = $maindir . '/scripts/pages/';

my $choice = $query->param('remote');
if (!$choice) {
	die "No remote selection given\n";
}

my $remotefile = $pagedir . $choice . '.html';
if (-e $remotefile) {
	if (open my $fh, '<', $remotefile) {
		local $/;
		my $html = <$fh>;
		print $html;
		close $fh;
		if ($choice =~ /seq/i) {
			$controlremotelog = $confdir . 'sequencesRemote.txt';
		}
		if (open my $fh2, '+>', $controlremotelog) {
			print $fh2 $choice;
			close $fh2;
		} else {
			die "Unable to open $controlremotelog for writing: $!\n";
		}
	} else {
		die "Unable to open $remotefile for reading: $!\n";
	}
} else {
	die "Could not find remote page file $remotefile\n";
}
