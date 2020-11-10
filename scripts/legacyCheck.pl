#!/usr/bin/perl -w

use strict;
use CGI;
use Tie::File::AsHash;
use JSON;

my $query = CGI->new;
print $query->header();

chomp(my $maindir = (`cat homeDir.txt` || ''));
die "Couldn't find where my main files are installed. No \"stbController\" directory was found on your system...\n" if (!$maindir);
$maindir =~ s/\/$//;
my $confdir = $maindir . '/config/';
my $filedir = $maindir . '/files/';
my $seqfile = $filedir . 'commandSequences.txt';
my $seqjson = $filedir . 'commandSequences.json';
my $groupsfile = $filedir . 'stbGroups.txt';
my $groupsjsonfile = $filedir . 'stbGroups.json';
my $eventsfile = $filedir . 'eventSchedule.txt';
my $eventsjsonfile = $filedir . 'eventSchedule.json';

##### Check the sequences file
checkSequences();
checkGroups();
checkSchedule();

sub checkSequences {
	if (!-e $seqjson and !-e $seqfile) {
	        ##### If no command sequence files exist, we can start off with JSON straight away
		return;
	} elsif (-e $seqjson) {
	        ##### If the new file format already exists, return
		return;
	}

	##### If the checks get this far, we need to convert old sequence files to the new JSON format
	if (-e $seqfile) {
	        my %newjson;
	        tie my %temp, 'Tie::File::AsHash', $seqfile, split => ':' or die "Problem tying \%sequences to $seqfile for conversion in " . __FILE__ . ": $!\n";
	        if (%temp) {
	                foreach my $old (sort keys %temp) {
	                        $newjson{$old}{'commands'} = $temp{$old};
	                        $newjson{$old}{'description'} = '';
	                        $newjson{$old}{'active'} = 'yes';
	                }

	                if (%newjson) {
	                        my $json = JSON->new->allow_nonref;
	                        $json = $json->canonical('1');
	                        my $encoded = $json->pretty->encode(\%newjson);
	                        if (open my $newfh, '+>', $seqjson) {
	                                print $newfh $encoded;
	                                close $newfh;
	                        } else {
					die "Failed to open file $seqjson for writing in conversion in file " . __FILE__ . " :$!\n";
	                        }
	                }
	        }
	}
}

sub checkGroups {
	if (!-e $groupsjsonfile and !-e $groupsfile) {
                ##### If no command sequence files exist, we can start off with JSON straight away
                return;
        } elsif (-e $groupsjsonfile) {
                ##### If the new file format already exists, return
                return;
        }

        ##### If the checks get this far, we need to convert old sequence files to the new JSON format
        if (-e $groupsfile) {
                my %newjson;
                tie my %temp, 'Tie::File::AsHash', $groupsfile, split => ':' or die "Problem tying \%temp to $groupsfile for conversion in " . __FILE__ . ": $!\n";
                if (%temp) {
                        foreach my $old (sort keys %temp) {
                                $newjson{$old}{'stbs'} = $temp{$old};
                        }

                        if (%newjson) {
                                my $json = JSON->new->allow_nonref;
                                $json = $json->canonical('1');
                                my $encoded = $json->pretty->encode(\%newjson);
                                if (open my $newfh, '+>', $groupsjsonfile) {
                                        print $newfh $encoded;
                                        close $newfh;
                                } else {
                                        die "Failed to open file $groupsjsonfile for writing in conversion in file " . __FILE__ . " :$!\n";
                                }
                        }
                }
                untie %temp;
        }
}

sub checkSchedule {
	if (!-e $eventsjsonfile and !-e $eventsfile) {
                ##### If no event schedule files exist, we can start off with JSON straight away
                return;
        } elsif (-e $eventsjsonfile) {
                ##### If the new file format already exists, return
                return;
        }

        ##### If the checks get this far, we need to convert the old event schedule to the new JSON format
        if (-e $eventsfile) {
                my %newjson;
                tie my %temp, 'Tie::File::AsHash', $eventsfile, split => ':' or die "Problem tying \%temp to $eventsfile for conversion in " . __FILE__ . ": $!\n";
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
