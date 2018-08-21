#!/usr/bin/perl -w

use strict;
use DBM::Deep;
use Fcntl;
use CGI;
use Tie::File::AsHash;
use Time::HiRes qw (sleep);
use FindBin qw($Bin);

my $query = CGI->new;
print $query->header();

chomp(my $fullpath = $ARGV[3] || '');
my $maindir;
if ($fullpath) {
	$maindir = $fullpath;
	chomp($maindir);
} else {
	if ($Bin) {
                $maindir = $Bin;
                $maindir =~ s/\/\w+\/*$//;
        } else {
                chomp($maindir = (`cat homeDir.txt` || ''));
                $maindir =~ s/\/$//;
        }
}
die "Couldn't find where my main files are installed. No \"stbController\" directory was found on your system...\n" if (!$maindir);
my $filedir = $maindir . '/files/';
my $runningpids = $filedir . '/pidsRunning/';
my $stbDataFile = ($maindir . '/config/stbDatabase.db');
my $groupsfile = ($filedir . 'stbGroups.txt');
my $seqfile = ($filedir . 'commandSequences.txt');
my $pidfile = ($filedir . 'scheduler.pid');

#sleep 10;
#warn "Test Script finished\n";
#exit;
my $longscript = $maindir . '/scripts/waiter.pl';
system("perl $longscript &");
