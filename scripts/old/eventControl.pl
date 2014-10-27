#!/usr/bin/perl -w
use strict;

if ($action =~ m/^Show$/i) {
        show_events();
        exit;
}

if ($action =~ m/^Add$/i) {
        add_event($command,$info);
        exit;
}

if ($action =~ m/^Delete$/i) {
        delete_event($command);
        exit;
}

sub add_event {
##########
	my (%events,%commands);
##########
	my $event = $_[0];
	my $eventupper = "\U$event\E";
	my $log = $_[1];
	my @commands = split(',', $log);
	my @raw;
	if (exists $events{"$eventupper"}) {
		my @cmdlist = '';
		my @found = @{ $events{"$eventupper"}};
		foreach my $code(@found) {
			push(@cmdlist, "$code");
		}
		my $list = join(',', @cmdlist);
		print "$event is already stored as $eventupper with commands - $list. Would you like to replace it? \<Y\/N\>\n";
		my $choice = <STDIN>;
		if ($choice) {
			chomp $choice;
			if ($choice =~ /^y$|^yes$/i) {
				my @empty;
				my @lot = ();
				$events{"$eventupper"} = [@empty];
				foreach my $cmd (@commands) {
					if ($cmd ne '') {
						chomp $cmd;
						if ($cmd =~ m/^t\d+$|^\d+$/i) {
							push (@lot, $cmd);
						} else {
							while (my($key,$value) = each %commands) {
								if ($key =~ m/^$cmd$/i) {
									push (@lot, $value);
								}
							}
						}
					}
				}
				@{ $events{"$eventupper"}} = @lot;
				my @cmdlist = '';
				my @found = @{ $events{"$eventupper"}};
				foreach my $code(@found) {
					push(@cmdlist, "$code");
				}
				my $list = join(',', @cmdlist);
				print "Existing event - $eventupper - has been successfully updated with controls - $list \n";
				my $eventfile;
				($eventfile = $eventupper) =~ s/\s/_/g;
				open EV, "+>$eventsdir$eventfile";
				print EV "$log\n";
				close EV;
			}
			if ($choice =~ /^n$|^no$/i) {
				exit;
			}
			if ($choice !~ /^n$|^y$|^no$|^yes$/i) {
				print "Invalid choice, exiting\n";
				exit;
			}
		} else {
			print "Invalid choice, exiting\n";
			exit;
		}
	} else {
		my @empty;
		my @lot = ();
		$events{"$eventupper"} = [@empty];
		foreach my $cmd (@commands) {
			if ($cmd ne '') {
				chomp $cmd;
				if ($cmd =~ m/^t\d+$/i) {
					push (@lot, $cmd);
				} else {
					while (my($key,$value) = each %commands) {
						if ($key =~ m/^$cmd$/i) {
							push (@lot, $value);
						}
					}
				}
			}
		}
		@{ $events{"$eventupper"}} = @lot;
		my @cmdlist = '';
		my @found = @{ $events{"$eventupper"}};
		foreach my $code(@found) {
			push(@cmdlist, "$code");
		}
		my $list = join(',', @cmdlist);
		my $eventfile;
		($eventfile = $eventupper) =~ s/\s/_/g;
		open EV, "+>$eventsdir$eventfile";
		print EV "$log\n";
		close EV;
		print "New event - $eventupper - with controls - $list - was added successfully\n";
	}
} # End of sub 'add_event'

sub delete_event {
	my %events;
	my $eventdel = $_[0];
	$eventdel = "\U$eventdel\E";
	my $eventfile;
	($eventfile = $eventdel) =~ s/\s/_/g;
	if (exists $events{"$eventdel"}) {
		delete $events{"$eventdel"};
		system("rm $eventsdir$eventfile");
		#print "$eventdel deleted successfully\n";
	} else {
		#print "Could not find event \"$eventdel\"\n";
	}
} # End of sub 'delete_event'

sub show_events {
	my %events;
	foreach my $key (sort keys %events) { 
		if ($key =~ /\S+/) {
			print "Event $key -- Commands:- ";
			foreach my $value (@{ $events{"$key"}}) {;
				print "$value\,";
			}
			print "\n";
		}
	} 
} # End of sub 'show'
