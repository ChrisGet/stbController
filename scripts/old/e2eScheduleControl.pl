#!/usr/bin/env perl

use strict;
use warnings;
use Tie::File;
use CGI;
my $query = CGI->new;
print $query->header();

chomp(my $input = $ARGV[0] || $query->param('action'));

my $cronscript = '/var/www/cgi-bin/Scripts/e2eEventScheduler.pl';
my $cronfile = '/var/www/cgi-bin/Scripts/Messages/eventScheduleE2E.txt';
my $pausefile = '/var/www/cgi-bin/Scripts/Messages/pausedProcessPids.txt';
my $statusfile = '/var/www/cgi-bin/Scripts/Messages/automationStatus.txt';

if ($input) {
	running("killall") if ($input =~ /^killall$/i);
	running("pauseall") if ($input =~ /^pauseall$/i);
	running("resumeall") if ($input =~ /^resumeall$/i);
	disable() if ($input =~ /^disable$/i);
	enable() if ($input =~ /^enable$/i);
	restart_cron() if ($input =~ /^restart$/i);
}


sub running {
	my $action = shift;
	chomp $action;
	my @processes = `ps ax | grep "\\.pl"`;
	my (%proc,@pidstouse);
	
	foreach my $process (@processes) {
		chomp $process;
		#if ($process =~ m/^\s*(\d+)\s+.+\d+\:\d+\s*(.*perl)\s+.+\/(\S+[^(?:\"|\\|grep|e2eScheduleControl|e2eEventScheduler)]\.pl)\s*(.*)$/) {
		if ($process =~ m/^\s*(\d+)\s+.+\d+\:\d+\s*(.*perl)\s+.+\/(\S+\.pl)\s*(.*)$/) {
			if ($3 =~ m/e2eScheduleControl\.pl|e2eEventScheduler\.pl/) {
				
			} else {
				#print "Found $3 with PID $1 to be paused\n";
				$proc{$3} = { 'PID' => "$1",
					'Runner' => "$2",
					'Script' => "$3",
					'Args' => "$4",
					};
				push(@pidstouse,"$1");
			}
		}
	}

	killer(\@pidstouse) if ($action =~ /^killall$/);
	pause(\@pidstouse) if ($action =~ /^pauseall$/);
	resume() if ($action =~ /^resumeall$/);

	sub killer {
		my @pidstokill = @{+shift};
		my $check = @pidstokill;
		if ($check !~ m/^0$/) {
			foreach my $tokill (@pidstokill) {
				system("sudo su -c \'kill $tokill\'");
			}
			my $text = "\<p style\=\"color\:DarkRed\"\>AUTOMATION KILLED\<\/p\>";
			file(\$text);
			system('> /home/Lobby/Messages/eventsRunning.txt');
		}
	}

	sub pause {
		my @pidstopause = @{+shift} || '';
		my $check = "@pidstopause";
                if ($check =~ m/\S+/) {
		#if (@pidstopause) {
			open PAUSE, "+>>$pausefile";
			foreach my $topause (@pidstopause) {
				system("sudo su -c \'kill -STOP $topause\'");
				print PAUSE "$topause\n";
			}
			close PAUSE;
			my $text = "\<p style\=\"color\:DarkOrange\"\>AUTOMATION INTERRUPTED\<\/p\>";
			file(\$text);
		}
	}
	sub resume {
		#system('echo resumed > /home/Lobby/check.txt');
		open RESUME, "<$pausefile";
		my @pidstoresume = <RESUME>;
		close RESUME;
		my $check = "@pidstoresume";
                if ($check =~ m/\S+/) {
			foreach my $toresume (@pidstoresume) {
				chomp $toresume;
					system("sudo su -c \'kill -CONT $toresume\'");
				}
			open RESUME, "+>$pausefile";
			close RESUME;
			my $text = "\<p style\=\"color\:ForestGreen\"\>AUTOMATION ENABLED\<\/p\>";
			file(\$text);
		}
	}	
}

sub disable {
	chomp(my $state = `cat /home/Lobby/Messages/lastAutoState.txt`);
	if ($state eq 'disabled') {					# Return error message if the last action was "disable"
		print "Automation has already been Disabled\n";
	} else {
		tie my @array, 'Tie::File', $cronfile;
		my @newarray;
		foreach my $entry (@array) {
			#if ($entry =~ /^\#/) {
			#	push(@newarray,$entry);
			#} else {
			my $newentry = "\#$entry";
			push(@newarray,$newentry);
			#}
		}
		@array = @newarray;
		restart_cron();
		my $text = "\<p style\=\"color\:DarkRed\"\>AUTOMATION DISABLED\<\/p\>";
       		file(\$text);	
		open STAT, "+>/home/Lobby/Messages/lastAutoState.txt";
		print STAT "disabled";
		close STAT;
	}
}

sub enable {
	chomp(my $state = `cat /home/Lobby/Messages/lastAutoState.txt`);
	if ($state eq 'enabled') {					# Return error message if the last action was "enable"
		print "Automation has already been Enabled\n";
	} else {
		tie my @array, 'Tie::File', $cronfile;
		my @newarray;
		foreach my $entry (@array) {
			#if ($entry =~ /^\#/) {
				$entry =~ s/^\#//;
				push(@newarray,$entry);
			#} else {
			#push(@newarray,$entry);
			#}
		}
		@array = @newarray;
		restart_cron();
		my $text = "\<p style\=\"color\:ForestGreen\"\>AUTOMATION ENABLED\<\/p\>";
		file(\$text);
		open STAT, "+>/home/Lobby/Messages/lastAutoState.txt";
		print STAT "enabled";
		close STAT;
	}
}

sub restart_cron {
	my @processes = `ps ax | grep "Schedule\:\:Cron"`;
	foreach my $process (@processes) {
		if ($process =~ /^\s*(\d+)\s+.+(Schedule::Cron\s+(?:Main|Dispatch).+)/) {
			system("sudo su -c \'kill $1\'");
		}
	}
	system("sudo su -c \'perl $cronscript\'");
}

sub file {
	my $text = ${+shift};
	open STATUS,"+>$statusfile";
	print STATUS "$text";
	close STATUS;		
}
