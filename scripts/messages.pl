#!/usr/bin/perl -w
use strict;
use CGI;

my $query = CGI->new;
print $query->header();

chomp(my $maindir = (`cat homeDir.txt` || ''));
die "Couldn't find where my main files are installed. No \"stbController\" directory was found on your system...\n" if (!$maindir);
$maindir =~ s/\/$//;
my $filedir = $maindir . '/files/';
my $schedpidfile = $filedir . 'scheduler.pid';
my $statefile = $filedir . 'schedulerState.txt';
my $runningdir = $filedir . 'pidsRunning/';
my $pauseddir = $filedir . 'pidsPaused/';
my $bullet = "&\#8226";
chomp(my $schedpid = `cat $schedpidfile` || ''); 

if ($schedpid) {
	chomp(my $schedstate = `cat $statefile` || '');
	if ($schedstate =~ /^Disabled$/i) {
		print "<font color=\"red\">> Scheduler is currently Disabled</font>";
		exit;
	}
	chomp(my $res = `ps ax | grep $schedpid | grep -v grep` || '');
	chomp(my $runningtotal = `ls -l $runningdir | grep -v total | wc -l` || '');
	chomp(my $pausedtotal = `ls -l $pauseddir | grep -v total | wc -l` || '');
	my @parts = split(/MainLoop\s*-\s*/,$res);
	my $wanted = $parts[1];
	$wanted =~ s/next:/\<font color\=\"\#267A94\"\>$bullet Next scheduled event -- \<\/font\>\<font color\=\"white\"\>/;
        print $wanted . '</font><br>';

	if ($runningtotal) {
		$runningtotal =~ s/\s+//g;
		if ($runningtotal > 1) {
			print "\<font color\=\"red\"\>$bullet !! Warning !! There are currently $runningtotal events running\<\/font\>";
		} else {
			print "\<font color\=\"red\"\>$bullet !! Warning !! There is currently $runningtotal event running\<\/font\>";
		}
	} else {
		print "\<font color\=\"green\"\>$bullet No events currently running\<\/font\>";
	}

	if ($pausedtotal) {
		print "\<br\>\<font color\=\"orange\"\>$bullet Alert! You have paused events\<\/font\>";
	} else {
		print "\<br\>\<font color\=\"green\"\>$bullet No events currently paused\<\/font\>";
	}

} else {
	print "<font color=\"red\">$bullet Event scheduler is not running</font>";
}
