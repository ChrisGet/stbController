#!/usr/bin/perl -w

use strict;
use CGI;
use Tie::File::AsHash;
use JSON;

my $query = CGI->new;
print $query->header();

chomp(my $action = $query->param('action') // $ARGV[0] // '');
chomp(my $sequence = $query->param('sequence') // $ARGV[1] // '');
chomp(my $commands = $query->param('commands') // $ARGV[2] // '');
chomp(my $origname = $query->param('originalName') // $ARGV[3] // '');
chomp(my $expformat = $query->param('exportFormat') // $ARGV[4] // '');
chomp(my $explist = $query->param('list') // $ARGV[5] // '');
chomp(my $desc = $query->param('description') // $ARGV[6] // '');
chomp(my $state = $query->param('state') // $ARGV[7] // '');

die "No Action defined for sequenceControl.pl\n" if (!$action);
die "No Sequence name given for sequenceControl.pl \"$action\"" if (!$sequence);

chomp(my $maindir = (`cat homeDir.txt` // ''));
die "Couldn't find where my main files are installed. No \"stbController\" directory was found on your system...\n" if (!$maindir);
$maindir =~ s/\/$//;
my $filedir = $maindir . '/files/';
my $stresscomsfile = $filedir . 'controllerToStressTable.json';
my $exportdir = $filedir . '/exports/';
my $seqfile = ($filedir . 'commandSequences.txt');
my $jsonfile = $filedir . 'commandSequences.json';

checkLegacy();  # Initial check to see if any old sequence files have been converted to the new JSON format

##### Create new JSON object for later use
my $json = JSON->new->allow_nonref;
$json = $json->canonical('1');

my %sequences;
if (-e $jsonfile) {
        local $/ = undef;
        open my $fh, "<", $jsonfile or die "ERROR: Unable to open $jsonfile: $!\n";
        my $data = <$fh>;
        my $decoded = $json->decode($data);
        %sequences = %{$decoded};
}

#tie my %sequences, 'Tie::File::AsHash', $seqfile, split => ':' or die "Problem tying \%sequences to $seqfile: $!\n"; 

searchSequences(\$sequence) and exit if ($action =~ m/^Search$/i);
showSequences(\$sequence) and exit if ($action =~ m/^Show$/i);
addSequence(\$sequence,\$commands) and exit if ($action =~ m/^Add$/i);
deleteSequence(\$sequence) and exit if ($action =~ m/^Delete$/i);
addSequence(\$sequence,\$commands,\$origname) and exit if ($action =~ m/^Edit$/i);
copySequence(\$sequence,\$origname) and exit if ($action =~ m/^Copy$/i);
exportSequence() and exit if ($action =~ m/^Export$/i);
stateChange() and exit if ($action =~ m/StateChange/i);

#untie %sequences;

#################### Sub Routines Below ####################

sub checkLegacy {
        if (!-e $jsonfile and !-e $seqfile) {
                ##### If no command sequence files exist, we can start off with JSON straight away
                $seqfile = $jsonfile;
                return;
        } elsif (-e $jsonfile) {
                ##### If the new file format already exists, update the $seqfile variable to use
                $seqfile = $jsonfile;
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
                                if (open my $newfh, '+>', $jsonfile) {
                                        print $newfh $encoded;
                                        close $newfh;
					} else {
                                        die "Failed to open file $jsonfile for writing in conversion in file " . __FILE__ . " :$!\n";
                                }
                        }
                }
        }
}

sub searchSequences {
	my ($seq) = @_;
	$$seq = uc($$seq);
	$$seq =~ s/^\s+//g;	# Remove leading whitespace
	$$seq =~ s/\s+$//g;	# Remove trailing whitespace
	$$seq =~ s/\s+/ /g;	# Find all whitespace within the sequence name and replace it with a single space

	if (exists $sequences{$$seq}) {
		print "Found";
	} else {
		print "Not Found";
	}
} # End of sub 'searchSequences'

sub showSequences {
	my ($seq) = @_;
	if ($$seq =~ /^All$/i) {
		#while (my ($key,$value) = each %sequences) {
		foreach my $key (sort keys %sequences) {
			print "$key -- " . $sequences{$key}{'commands'} . "\n";
		}	
	} else {
		$$seq = uc($$seq);
        	$$seq =~ s/^\s+//g;     # Remove leading whitespace
        	$$seq =~ s/\s+$//g;     # Remove trailing whitespace
        	$$seq =~ s/\s+/ /g;     # Find all whitespace within the sequence name and replace it with a single space
		if (exists $sequences{$$seq}) {
			print $sequences{$$seq}{'commands'};
		} else {
			print "\"$$seq\" not found";
		} 
	}
} # End of sub 'showSequences'

sub addSequence {
	my ($seq,$coms,$origname) = @_;

	##### Do this for 'Edit' Action
	if ($origname) {		##### Check that the actual reference is defined (It wont be for 'Add' Actions)
		if (($$origname) and ($$origname ne $$seq)) {
			delete $sequences{$$origname};
		}
	}
	##### Do this for 'Edit' Action

	$$seq = uc($$seq);
	$$seq =~ s/^\s+//g;     # Remove leading whitespace
        $$seq =~ s/\s+$//g;     # Remove trailing whitespace
        $$seq =~ s/\s+/ /g;     # Find all whitespace within the sequence name and replace it with a single space

	$sequences{$$seq}{'commands'} = $$coms;
	$sequences{$$seq}{'active'} = 'yes';
	$sequences{$$seq}{'description'} = $desc;

	saveSequences();
} # End of sub 'addSequence'

sub copySequence {
	my ($seq,$orig) = @_;
	$$seq = uc($$seq);
	$$seq =~ s/^\s+//g;     # Remove leading whitespace
        $$seq =~ s/\s+$//g;     # Remove trailing whitespace
        $$seq =~ s/\s+/ /g;     # Find all whitespace within the sequence name and replace it with a single space
	my %data = %{$sequences{$$orig}};
	if (%data) {
		%{$sequences{$$seq}} = %data;
	}	
	saveSequences();
}

sub deleteSequence {
	my ($seq) = @_;
	$$seq = uc($$seq);
        $$seq =~ s/^\s+//g;     # Remove leading whitespace
        $$seq =~ s/\s+$//g;     # Remove trailing whitespace
        $$seq =~ s/\s+/ /g;     # Find all whitespace within the sequence name and replace it with a single space

	if (exists $sequences{$$seq}) {
		delete $sequences{$$seq};
	} else {
		die "Sequence \"$$seq\" cannot be deleted because it does not exist\n";
	}
	saveSequences();
} # End of sub 'deleteSequence'

sub exportSequence {
	my $fname = '';
	if ($sequence) {
		my $friendly = $sequence;
		$friendly =~ s/\s+/_/g;
		#$fname = $friendly . '-' . $expformat . '.txt';
		$fname = $friendly . '-' . $expformat . '.json';
	}
	if ($explist) {
		#$fname = 'Multi_Export_Sequence_List-Native.txt';
		$fname = 'Multi_Export_Sequence_List-Native.json';
	}

	if ($expformat =~ /stress/) {
		my $content = convertToStress($sequence);
		if ($content) {
			$fname =~ s/\.json$/\.txt/;
			my $fullpath = $exportdir . $fname;
			if (open my $fh, '+>', $fullpath) {
				print $fh $content;
				close $fh;
				print "FILENAME=$fname";
			} else {
				print "ERROR: Could not open $fname for export: $!";
			}
		}
	} else {
		my %exports;
		my $fullpath = $exportdir . $fname;
		if ($explist) {
			my @seqs = split(',',$explist);
			foreach my $s (@seqs) {
				%{$exports{$s}} = %{$sequences{$s}};
			}
		} else {
			%{$exports{$sequence}} = %{$sequences{$sequence}};
		}
		
		my $encoded = $json->pretty->encode(\%exports);
		if (open my $newfh, '+>', $fullpath) {
			print $newfh $encoded;
			close $newfh;
			print "FILENAME=$fname";
		} else {
			die "ERROR: Unable to open $jsonfile: $!\n";
		}

	}
} # End of sub 'exportSequence'

sub convertToStress {
	my ($seq) = @_;
	my $stresscomms = `cat $stresscomsfile` // '';
	my $json = JSON->new->allow_nonref;
	$json = $json->canonical('1');
	my $decoded = $json->decode($stresscomms);
	my %stress = %{$decoded};
	my $description = "Exported sequence from Chilworth Reliability team - $sequence";
	if ($sequences{$seq}{'description'}) {
		$description = $sequences{$seq}{'description'};
	}
	
my $content = <<HEAD;
'Script: CH.01
'Name: $sequence
'Functionality: Unspecified
'Description: $description

HEAD

	my $seqcomms = $sequences{$seq}{'commands'};
	my @comms = split(',',$seqcomms);
	foreach my $com (@comms) {
		if ($com =~ /^t(\d+)$/) {
			$content .= "($1)\n";
		} else {
			if (exists $stress{$com}) {
				$content .= "{G1} " . $stress{$com} . "\n";
			} elsif ($com =~ /^(\d)$/) {
				$content .= "{G1} " . $1 . "\n";
			}
		}
	}
	
	return $content;
}

sub saveSequences {
	my $encoded = $json->pretty->encode(\%sequences);
	if (open my $newfh, '+>', $jsonfile) {
		print $newfh $encoded;
		close $newfh;
	} else {
		die "ERROR: Unable to open $jsonfile: $!\n";
	}
}

sub stateChange {
	my $active = 'yes';
	if ($state eq 'inactive') {
		$active = 'no';
	}
	if (exists $sequences{$sequence}) {
		$sequences{$sequence}{'active'} = $active;
	} else {
		print "ERROR: Sequence $sequence could not be found! Please try again";
		exit;
	}
	print "Success";
	saveSequences();
}
