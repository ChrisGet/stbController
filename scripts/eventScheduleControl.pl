#!/usr/bin/perl -w

use strict;
use CGI;
use Tie::File::AsHash;
use JSON;

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
my $confdir = $maindir . '/config/';
my $runningdir = $filedir . 'pidsRunning/';
my $pauseddir = $filedir . 'pidsPaused/';
my $statefile = $filedir . 'schedulerState.txt';
my $schedfile = ($filedir . 'eventSchedule.txt');
my $eventsjsonfile = $filedir . 'eventSchedule.json';
my $sequencefile = ($filedir . 'commandSequences.txt');
my $seqsjsonfile = $filedir . 'commandSequences.json';
my $pidfile = $filedir . 'scheduler.pid';
my $processdebugfile = $filedir . 'scheduledEventDebug.txt';
my $stbdatafile = $confdir . 'stbData.json';
my $groupsfile = $filedir . 'stbGroups.json';

checkLegacy(); # Initial check to see if any old STB event schedule file has been converted to the new JSON format

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

##### Load the events schedule data
my %events;
if (-e $eventsjsonfile) {
        local $/ = undef;
        open my $fh, "<", $eventsjsonfile or die "ERROR: Unable to open $eventsjsonfile: $!\n";
        my $data = <$fh>;
	if ($data) {
        	my $decoded = $json->decode($data);
        	%events = %{$decoded};
	}
}

##### Load the sequences data
my %sequences;
if (-e $seqsjsonfile) {
        local $/ = undef;
        open my $fh, "<", $seqsjsonfile or die "ERROR: Unable to open $seqsjsonfile: $!\n";
        my $data = <$fh>;
        if ($data) {
		my $decoded = $json->decode($data);
        	%sequences = %{$decoded};
	}
}

##### Load the STB groups data
my %groups;
if (-e $groupsfile) {
        local $/ = undef;
        open my $fh, "<", $groupsfile or die "ERROR: Unable to open $groupsfile: $!\n";
        my $data = <$fh>;
        if ($data) {
		my $decoded = $json->decode($data);
        	%groups = %{$decoded};
	}
}

#tie my %events, 'Tie::File::AsHash', $schedfile, split => ':' or die "Problem tying \%events to $schedfile: $!\n"; 
#tie my %sequencedata, 'Tie::File::AsHash', $sequencefile, split => ':' or die "Problem tying \%sequences to $sequencefile: $!\n"; 

showData(\$eventID) and exit if ($action =~ m/^Show$/i);
startScheduler() and exit if ($action =~ m/^Start$/i);
stopScheduler() and exit if ($action =~ m/^Stop$/i);
reloadScheduler() and exit if ($action =~ m/^Reload$/i);
addEvent(\$eventID,\$details) and exit if ($action =~ m/^Add$|^Edit$/i);
deleteEvent(\$eventID) and exit if ($action =~ m/^Delete$/i);
copyEvent() and exit if ($action eq 'Copy');
enableEvent(\$eventID) and exit if ($action =~ m/^Enable$/i);
disableEvent(\$eventID) and exit if ($action =~ m/^Disable$/i);
disableScheduler() and exit if ($action =~ m/^DisableSchedule$/i);
enableScheduler() and exit if ($action =~ m/^EnableSchedule$/i);
killAll() and exit if ($action =~ m/^KillAll$/i);
pauseAll() and exit if ($action =~ m/^PauseAll$/i);
resumeAll() and exit if ($action =~ m/^ResumeAll$/i);

#untie %events;

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
			#$events{$$eventID} = $newdetails;
			%{$events{$$eventID}} = ('active' => $state,
						'commands' => $event,
						'schedule' => "$min $hour $dom $month $days",
						'stbs' => $targets
						);
						
			saveSchedule();			
			reloadScheduler();
			return;
		}
	}
	##### Do this for 'Edit' Action

	my $newid = '';
	my @range = (1000 .. 9999);
	until ($newid) {
		my $no = $range[int rand(@range)];
		if (!exists $events{$no}) {
			$newid = $no;
		}
	}

	#$events{$newid} = $newdetails;
	%{$events{$newid}} = (	'active' => $state,
				'commands' => $event,
				'schedule' => "$min $hour $dom $month $days",
				'stbs' => $targets
				);

	saveSchedule();
	chomp(my $schedstate = `cat $statefile` || '');
        if (!$schedstate) {
                enableScheduler();
        } else {
                reloadScheduler();
        }

	return;
} ### End of sub 'addEvent'

sub copyEvent {
	if (exists $events{$eventID}) {
		my %tocopy = %{$events{$eventID}};
		my $newid = '';
		my @range = (1000 .. 9999);
		until ($newid) {
			my $no = $range[int rand(@range)];
			if (!exists $events{$no}) {
				$newid = $no;
			}
		}
		%{$events{$newid}} = %tocopy;
	}
	saveSchedule();
	return;	
}

sub deleteEvent {
	my ($eventID) = @_;

	if (exists $events{$$eventID}) {
		delete $events{$$eventID};
		saveSchedule();
		reloadScheduler();
	} else {
		die "Event \"$$eventID\" cannot be deleted because it does not exist\n";
	}
} ### End of sub 'deleteEvent'

sub startScheduler {
	use Schedule::Cron;

	chomp(my $state = `cat $statefile` || '');
	if (!$state) {
		die "Could not determine scheduler state\n";
	} else {
		if ($state =~ /^Disabled/) {
			die "Scheduler is currently disabled so will not start\n";
		}
	}

	sub dispatcher {
        	my $run = shift;
        	print "ID:   ",$run,"\n";
        	print "Args: ","@_","\n";
	}
	
	my $cron = new Schedule::Cron(\&dispatcher);

	my $added = '0';
	#while (my ($key,$value) = each %events) {
	foreach my $event (sort keys %events) {
		my %data = %{$events{$event}};
		if ($data{'active'} eq 'y') {		
			#my @parts = split('\|',$value);
			my @parts = split(/\s+/,$data{'schedule'});
			my $crontime = "$parts[0] $parts[1] $parts[2] $parts[3] $parts[4]";
			my $commands = $data{'commands'};
			my $stbs = $data{'stbs'};
			my $do = 'testRunner';
			$cron->add_entry($crontime,\&$do,\$commands,\$stbs);
			$added++;
		}
	}	

	if ($added==0) {
		system(">$pidfile");
		die "No point in starting the scheduler as no scheduled events are currently enabled\n";
	}

	$cron->run(detach=>1,pid_file=>$pidfile); # Change value to 1 to make the jobs background tasks rather than the script hanging on to them

	sub testRunner {
		my ($event,$stbs) = @_;
		my $debugfile = $filedir . 'schedulerdebug.txt';
		system("$controlscript Event \"$$event\" \"$$stbs\" \"$maindir\" logpid >> $processdebugfile 2>&1");

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
	if (!$schedpid) {
		#warn "Failed to identify the process ID for the event scheduler\n";
		return;
	}
	chomp(my $isrunning = `ps ax | grep $schedpid` || '');
	if ($isrunning) {
		system("kill $schedpid");
		system(">$pidfile");
	} else {
		warn "Can't stop the scheduler as it is not running\n";
	}
} ### End of sub 'stopScheduler'

sub reloadScheduler {
	stopScheduler();
	startScheduler();
	system("> $processdebugfile");
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
		#$events{$$eventID} =~ s/^n/y/i;
		$events{$$eventID}{'active'} = 'y';
		saveSchedule();
		reloadScheduler();
	} else {
		die "Cannot enable event $$eventID as it was not found in the list\n";
	}
} ### End of sub 'enableEvent'

sub disableEvent {
	my ($eventID) = @_;
	if (exists $events{$$eventID}) {
		$events{$$eventID}{'active'} = 'n';
		saveSchedule();
		reloadScheduler();
	} else {
		die "Cannot disable event $$eventID as it was not found in the list\n";
	}
} ### End of sub 'disableEvent'

sub showData {
	my ($eventID) = @_;
	if (exists $events{$$eventID}) {
		#my @splits = split /\Q|/, $events{$$eventID};	# We use \Q to quote the | symbol otherwise it is treated as a metachar and the split fails
		my $targets = $events{$$eventID}{'stbs'};
		my @stbs = split(',',$targets);
		my $resforgui = 'Boxes{';
		foreach my $stb (@stbs) {
			if (exists $stbdata{$stb}) {
				my $name = $stbdata{$stb}{'Name'} || '';
				if ($name) {
					$resforgui .= "$stb~$name,";
				} else {
					$resforgui .= "$stb~-,";
				}
			} else {
				if (exists $groups{$stb}) {
					$resforgui .= "$stb~$stb,";
				} else {
					$resforgui .= "$stb~groupmissing,";
				}
			}
		}
		$resforgui =~ s/,$//;
		$resforgui .= '}Sequences{';

		my $coms = $events{$$eventID}{'commands'};
		my @seqs = split(',',$coms);
		foreach my $seq (@seqs) {
			if (exists $sequences{$seq}) {
				$resforgui .= "$seq~$seq,";
			} else {
				$resforgui .= "$seq~-,";
			}
		}
		$resforgui =~ s/,$//;
		$resforgui .= '}';

		print $resforgui;
	} else {
		die "Cannot show the boxes for event $$eventID as it was not found in the list\n";
	}
} ### End of sub 'showBoxes'

sub disableScheduler {
	open FH, '+>', $statefile;
	print FH 'Disabled';
	close FH;	
	killAll();
	stopScheduler();	
} ### End of sub 'disableScheduler'

sub enableScheduler {
	open FH, '+>', $statefile;
	print FH 'Enabled';
	close FH;
	reloadScheduler();	
} ### End of sub 'enableScheduler'

sub killAll {
	# Kill all running processes
	opendir(my $run, $runningdir) || die "Can't opendir $runningdir: $!\n";
	my @running = grep { !/^\./ } readdir($run);
	closedir $run;
	foreach my $runpid (@running) {
		chomp $runpid;
		system("kill $runpid");
		chomp(my $notdead = `ps ax | grep $runpid` || '');
		if ($notdead) {
			system("kill -9 $runpid");			
		}
		system("rm $runningdir$runpid");
	}

	# Kill all paused processes
	opendir(my $pause, $pauseddir) || die "Can't opendir $pauseddir: $!\n";
	my @paused = grep { !/^\./ } readdir($pause);
	closedir $pause;
	foreach my $pausepid (@paused) {
		chomp $pausepid;
		system("kill $pausepid");
		chomp(my $notdead = `ps ax | grep $pausepid` || '');
		if ($notdead) {
			system("kill -9 $pausepid");			
		}
		system("rm $pauseddir$pausepid");
	}
} ### End of sub 'killAll'

sub pauseAll {
	opendir(my $run, $runningdir) || die "Can't opendir $runningdir: $!\n";
	my @running = grep { !/^\./ } readdir($run);
	closedir $run;
	foreach my $runpid (@running) {
		chomp $runpid;
		system("kill -STOP $runpid");
		system("mv $runningdir$runpid $pauseddir$runpid");
	}
} ### End of sub 'pauseAll'

sub resumeAll {
	opendir(my $pause, $pauseddir) || die "Can't opendir $pauseddir: $!\n";
	my @paused = grep { !/^\./ } readdir($pause);
	closedir $pause;
	foreach my $pausepid (@paused) {
		chomp $pausepid;
		system("kill -CONT $pausepid");
		system("mv $pauseddir$pausepid $runningdir$pausepid");
	}
} ### End of sub 'resumeAll'

sub checkLegacy {
        if (!-e $eventsjsonfile and !-e $schedfile) {
                ##### If no event schedule files exist, we can start off with JSON straight away
                $schedfile = $eventsjsonfile;
                return;
        } elsif (-e $eventsjsonfile) {
                ##### If the new file format already exists, update the $eventsfile variable to use
                $schedfile = $eventsjsonfile;
                return;
        }

        ##### If the checks get this far, we need to convert the old event schedule to the new JSON format
        if (-e $schedfile) {
                my %newjson;
                tie my %temp, 'Tie::File::AsHash', $schedfile, split => ':' or die "Problem tying \%temp to $schedfile for conversion in " . __FILE__ . ": $!\n";
                if (%temp) {
                        foreach my $old (sort keys %temp) {
                                my @bits = split('\|',$temp{$old});
                                my ($active,$mins,$hours,$dom,$month,$dow,$commands,$stbs) = @bits;
                                %{$newjson{$old}} = (   'active' => $active,
                                                        'schedule' => "$mins $hours $dom $month $dow",
                                                        'commands' => $commands,
                                                        'stbs' => $stbs
                                                        );
                        }

                        if (%newjson) {
                                my $json = JSON->new->allow_nonref;
                                $json = $json->canonical('1');
                                my $encoded = $json->pretty->encode(\%newjson);
                                if (open my $newfh, '+>', $eventsjsonfile) {
                                        print $newfh $encoded;
                                        close $newfh;
                                } else {
                                        die "Failed to open file $eventsjsonfile for writing in conversion in file " . __FILE__ . " :$!\n";
                                }
                        }
                }
                untie %temp;
        }
}

sub saveSchedule {
	my $encoded = $json->pretty->encode(\%events);
	if (open my $newfh, '+>', $eventsjsonfile) {
		print $newfh $encoded;
		close $newfh;
	} else {
		die "ERROR: Unable to open $eventsjsonfile: $!\n";
	}
}
