#!/usr/bin/perl -w

use strict;
use CGI;
use Tie::File;
use Tie::File::AsHash;

my $query = CGI->new;
print $query->header();

chomp(my $action = $query->param('action') || $ARGV[0] || '');
chomp(my $eventID = $query->param('eventID') || $ARGV[1] || '');
chomp(my $details = $query->param('details') || $ARGV[2] || '');

die "No Action defined for eventScheduleControl.pl\n" if (!$action);
die "No Event ID given to be edited for eventScheduleControl.pl\n" if (($action =~ /^Edit$/i) and (!$eventID));

chomp(my $maindir = (`cat homeDir.txt` || ''));
die "Couldn't find where my main files are installed. No \"stbController\" directory was found on your system...\n" if (!$maindir);
$maindir =~ s/\/$//;
my $controlscript = $maindir . '/scripts/stbControl.pl';
my $filedir = $maindir . '/files/';
my $schedfile = ($filedir . 'eventSchedule.txt');
tie my %events, 'Tie::File::AsHash', $schedfile, split => ':' or die "Problem tying \%events to $schedfile: $!\n"; 

showBoxes(\$eventID) and exit if ($action =~ m/^Show$/i);
startScheduler() and exit if ($action =~ m/^Start$/i);
stopScheduler() and exit if ($action =~ m/^Stop$/i);
reloadScheduler() and exit if ($action =~ m/^Reload$/i);
addEvent(\$eventID,\$details) and exit if ($action =~ m/^Add$|^Edit$/i);
deleteEvent(\$eventID) and exit if ($action =~ m/^Delete$/i);
enableEvent(\$eventID) and exit if ($action =~ m/^Enable$/i);
disableEvent(\$eventID) and exit if ($action =~ m/^Disable$/i);

untie %events;

#################### Sub Routines Below ####################

sub addEvent {
	my ($eventID,$details) = @_;
	if ($$details !~ /^(y|n)\|/i) {
		$$details = 'y|' . $$details;
	}

	my @dets = split('\|',$$details);

	for (@dets) {
		if ($_ =~ /^Every/) {
			$_ = '*';
		}
	}

	my ($state,$min,$hour,$dom,$month,$days,$event,$targets) = @dets;
	$month = stringToNumbers(\$month,\'month');
	$month =~ s/,$//;
	$days = stringToNumbers(\$days,\'dow');
	$days =~ s/,$//;
	my $newdetails = "$state\|$min\|$hour\|$dom\|$month\|$days\|$event\|$targets";


	##### Do this for 'Edit' Action
	if ($eventID) {		##### Check that the actual reference is defined (It wont be for 'Add' Actions)
		if ($$eventID) {
			$events{$$eventID} = $newdetails;
			reloadScheduler();
			return;
		}
	}
	##### Do this for 'Edit' Action

	my $newID;
	my @nums = ('0'..'9');
	my $length = 4;
	my $number = '';

RANDOM: {
	for (1..$length) {
		$number .= $nums[int rand @nums];
	}
	if (exists $events{$number}) {
		$number = '';
		redo RANDOM;
	} 
} # End of 'RANDOM' code block

	$events{$number} = $newdetails;
	reloadScheduler();
	return;
} ### End of sub 'addEvent'

sub deleteEvent {
	my ($eventID) = @_;

	if (exists $events{$$eventID}) {
		delete $events{$$eventID};
		reloadScheduler();
	} else {
		die "Event \"$$eventID\" cannot be deleted because it does not exist\n";
	}
} ### End of sub 'deleteEvent'

sub startScheduler {
	use Schedule::Cron;

	sub dispatcher {
        	my $run = shift;
        	print "ID:   ",$run,"\n";
        	print "Args: ","@_","\n";
	}
	
	my $cron = new Schedule::Cron(\&dispatcher);

	while (my ($key,$value) = each %events) {
		if ($value =~ /^y/i) {		# If the $value starts with a 'y', the event is active, so we load it in to the scheduler
			my @parts = split('\|',$value);
			my $crontime = "$parts[1] $parts[2] $parts[3] $parts[4] $parts[5]";
			my $event = $parts[6];
			my $stbs = $parts[7];
			my $do = 'testRunner';
			$cron->add_entry($crontime,\&$do,\$event,\$stbs);
			#print "Added $crontime - $event - $stbs\n";
		}
		# else {
		#	print "Not Added - $value\n";
		#}
	}	

	my $pidfile = $filedir . 'scheduler.pid';
	$cron->run(detach=>1,pid_file=>$pidfile); # Change value to 1 to make the jobs background tasks rather than the script hanging on to them

	sub testRunner {
		my ($event,$stbs) = @_;
		my $debugfile = $filedir . 'schedulerdebug.txt';
		system("$controlscript Event \"$$event\" \"$$stbs\" \"$maindir\"");

		######### Uncomment below 4 lines to enable scheduled event logging #########
		#my $log = $filedir . 'schedulerLog.txt';
		#open FH, '+>>', $log or die "Couldn't open $log: $!\n";
		#print FH "$controlscript\nEvent = $$event\nSTBs = $$stbs\n";
		#close FH;
	}

} ### End of sub 'startScheduler'

sub stopScheduler {
	my $pidfile = $filedir . 'scheduler.pid';
	chomp(my $schedpid = `cat $pidfile` || '');
	die "Failed to identify the process ID for the event scheduler\n" if (!$schedpid);
	system("kill $schedpid");
} ### End of sub 'stopScheduler'

sub reloadScheduler {
	stopScheduler();
	startScheduler();
} ### End of sub 'reloadScheduler'

sub stringToNumbers {
        my ($string,$flag) = @_;
        my %days = qw( Sun '0' Mon 1 Tues 2 Weds 3 Thurs 4 Fri 5 Sat 6 Everyday * );
        my %months = qw( Jan 1 Feb 2 Mar 3 Apr 4 May 5 Jun 6 Jul 7 Aug 8 Sep 9 Oct 10 Nov 11 Dec 12 );

        my %ref;
        %ref = %days if ($$flag =~ /dow/i);
        %ref = %months if ($$flag =~ /month/i);

        my $result = '';
        my @parts = split(/(\w+)/,$$string);
        foreach my $bit (@parts) {
                my $res = $ref{$bit} || '';
                if ($res) {
			$res =~ s/'//g;
                        $result .= $res;
                } else {
                        $result .= $bit;
                }
        }
        return $result;
} ### End of sub 'stringToNumbers'

sub enableEvent {
	my ($eventID) = @_;
	if (exists $events{$$eventID}) {
		$events{$$eventID} =~ s/^n/y/i;
		reloadScheduler();
	} else {
		die "Cannot enable event $$eventID as it was not found in the list\n";
	}
} ### End of sub 'enableEvent'

sub disableEvent {
	my ($eventID) = @_;
	if (exists $events{$$eventID}) {
		$events{$$eventID} =~ s/^y/n/i;
		reloadScheduler();
	} else {
		die "Cannot disable event $$eventID as it was not found in the list\n";
	}
} ### End of sub 'disableEvent'

sub showBoxes {
	my ($eventID) = @_;
	if (exists $events{$$eventID}) {
		my ($targets) = $events{$$eventID} =~ /\|(.[^\|]+)$/;
		my @stbs = split(',',$targets);
		my $resforgui = '';
		use DBM::Deep;
                my $stbdatafile = $maindir . '/config/stbDatabase.db';
                tie my %stbdata, 'DBM::Deep', {file => $stbdatafile, locking => 1, autoflush => 1, num_txns => 100};
		foreach my $stb (@stbs) {
			if (exists $stbdata{$stb}) {
				my $name = $stbdata{$stb}{'Name'} || '';
				if ($name) {
					$resforgui .= "$stb~$name,";
				} else {
					$resforgui .= "$stb~-,";
				}
			} else {
				$resforgui .= "$stb~$stb,";
			}
		}

		$resforgui =~ s/,$//;
		print $resforgui;

	} else {
		die "Cannot show the boxes for event $$eventID as it was not found in the list\n";
	}
} ### End of sub 'showBoxes'
