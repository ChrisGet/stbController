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
	$schedpid =~ s/\s+//g;
	chomp(my $schedstate = `cat $statefile` || '');
	chomp(my $res = `ps ax | grep \"\^\\s\*$schedpid\" | grep -v grep` || '');
	if ($schedstate =~ /^Disabled$/i) {
		print "<font color=\"red\">> Scheduler is currently Disabled</font>";
		exit;
	} else {
		if (!$res) {
			print "<font color=\"red\">$bullet Event scheduler is not running</font>";
			exit;
		}
	}

	#chomp(my $runningtotal = `ls -l $runningdir | grep -v total | wc -l` || '');
	chomp(my $runningtotal = `ps ax | grep "(Scheduler-$schedpid)" | grep -v grep | wc -l` || '');
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

	### Run the cleanUp sub routine
        my $pid = fork;
        if ($pid==0) {
                cleanUp(\$schedpid);
                exit;
        }

} else {
	print "<font color=\"red\">$bullet Event scheduler is not running</font>";
}

######### The cleanUp subroutine is run each time this script is run. It will compare the output
######### of the list of events that are actually running (via the "ps ax" system command) to the
######### list of PIDs in the "pidsRunning" directory. Any PIDs listed in the "pidsRunning" directory
######### which are not in the real time list from "ps ax" will be deleted from the directory.
sub cleanUp {
        my($schedpid) = @_;
        opendir(my $run, $runningdir) || die "Can't opendir $runningdir: $!\n";
        my @running = grep { !/^\./ } readdir($run);
        closedir $run;

        foreach my $log (@running) {
                chomp $log;
                chomp(my $valid = `ps ax | grep $log | grep "(Scheduler-$$schedpid)" | grep -v grep` // '');
                if (!$valid) {
                        system("rm $runningdir$log");
                }
        } 
}
