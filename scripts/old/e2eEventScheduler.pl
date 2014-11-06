#!/usr/bin/env perl

BEGIN { use lib "/usr/local/lib/perl5/site_perl/5.18.0/" }
use strict;
use warnings;

use Schedule::Cron;

sub dispatcher {
	my $run = shift;
	print "ID:   ",$run,"\n"; 
	print "Args: ","@_","\n";
}

my $cron = new Schedule::Cron(\&dispatcher);

open JOBS, "</var/www/cgi-bin/Scripts/Messages/eventScheduleE2E.txt";
my @jobs = <JOBS>;
close JOBS;

foreach my $job (@jobs) {
	if ($job =~ /^\#/) {
	} else {
		my @bits = split('\|',$job);
		my $time = shift @bits;
		my $do = 'test_runner';
		my $id = shift @bits;
		$cron->add_entry($time,\&$do,$id,$cron);
	}
}

$cron->run(detach=>1); # Change value to 1 to make the jobs background tasks rather than the script hanging on to them

sub test_runner {
	my @parts = split('\+',shift);
	my $script = shift @parts;
	$script =~ s/'//g;
	chomp $script;
	my $args = shift @parts;
	
	if ($args) {
		$args =~ s/'$//;
		chomp $args;
		my @inputs = split('_',$args);
		system("/usr/local/bin/perl","$script",@inputs);
	} else {
		system("/usr/local/bin/perl","$script");
	}
}
