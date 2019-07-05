#!/usr/bin/perl -w

use strict;
use CGI;
use Tie::File::AsHash;
use JSON;

my $query = CGI->new;
print $query->header();

chomp(my $action = $query->param('action') || $ARGV[0] || '');
chomp(my $sequence = $query->param('sequence') || $ARGV[1] || '');
chomp(my $commands = $query->param('commands') || $ARGV[2] || '');
chomp(my $origname = $query->param('originalName') || $ARGV[3] || '');
chomp(my $expformat = $query->param('exportFormat') || $ARGV[4] || '');
chomp(my $explist = $query->param('list') || $ARGV[5] || '');

die "No Action defined for sequenceControl.pl\n" if (!$action);
die "No Sequence name given for sequenceControl.pl \"$action\"" if (!$sequence);


chomp(my $maindir = (`cat homeDir.txt` || ''));
die "Couldn't find where my main files are installed. No \"stbController\" directory was found on your system...\n" if (!$maindir);
$maindir =~ s/\/$//;
my $filedir = $maindir . '/files/';
my $stresscomsfile = $filedir . 'controllerToStressTable.json';
my $exportdir = $filedir . '/exports/';
my $seqfile = ($filedir . 'commandSequences.txt');
tie my %sequences, 'Tie::File::AsHash', $seqfile, split => ':' or die "Problem tying \%sequences to $seqfile: $!\n"; 

searchSequences(\$sequence) and exit if ($action =~ m/^Search$/i);
showSequences(\$sequence) and exit if ($action =~ m/^Show$/i);
addSequence(\$sequence,\$commands) and exit if ($action =~ m/^Add$/i);
deleteSequence(\$sequence) and exit if ($action =~ m/^Delete$/i);
addSequence(\$sequence,\$commands,\$origname) and exit if ($action =~ m/^Edit$/i);
copySequence(\$sequence,\$origname) and exit if ($action =~ m/^Copy$/i);
exportSequence() and exit if ($action =~ m/^Export$/i);

untie %sequences;

#################### Sub Routines Below ####################

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
		while (my ($key,$value) = each %sequences) {
			print "$key -- $value\n";
		}	
	} else {
		$$seq = uc($$seq);
        	$$seq =~ s/^\s+//g;     # Remove leading whitespace
        	$$seq =~ s/\s+$//g;     # Remove trailing whitespace
        	$$seq =~ s/\s+/ /g;     # Find all whitespace within the sequence name and replace it with a single space
		if (exists $sequences{$$seq}) {
			print $sequences{$$seq};
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

	$sequences{$$seq} = $$coms;
} # End of sub 'addSequence'

sub copySequence {
	my ($seq,$orig) = @_;
	$$seq = uc($$seq);
	$$seq =~ s/^\s+//g;     # Remove leading whitespace
        $$seq =~ s/\s+$//g;     # Remove trailing whitespace
        $$seq =~ s/\s+/ /g;     # Find all whitespace within the sequence name and replace it with a single space
	my $data = $sequences{$$orig};
	if ($data) {
		$sequences{$$seq} = $data;
	}	
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
} # End of sub 'deleteSequence'

sub exportSequence {
	my $fname = '';
	if ($sequence) {
		my $friendly = $sequence;
		$friendly =~ s/\s+/_/g;
		$fname = $friendly . '-' . $expformat . '.txt';
	}
	if ($explist) {
		$fname = 'Multi_Export_Sequence_List-Native.txt';
	}
	my $fullpath = $exportdir . $fname;
	if (open my $fh, '+>', $fullpath) {
		if ($expformat =~ /stress/) {
			my $content = convertToStress($sequence);
			print $fh $content;
		} else {
			if ($explist) {
				my @seqs = split(',',$explist);
				foreach my $s (@seqs) {
					print $fh $s . ':' . $sequences{$s} . "\n";
				}
			} else {
				print $fh $sequence . ':' . $sequences{$sequence};
			}
		}
		close $fh;
		print "FILENAME=$fname";
	} else {
		print "ERROR: Could not open $fname for export: $!";
	}
} # End of sub 'exportSequence'

sub convertToStress {
	my ($seq) = @_;
	my $stresscomms = `cat $stresscomsfile` // '';
	my $json = JSON->new->allow_nonref;
	$json = $json->canonical('1');
	my $decoded = $json->decode($stresscomms);
	my %stress = %{$decoded};
	
my $content = <<HEAD;
'Script: CH.01
'Name: $sequence
'Functionality: Unspecified
'Description: Exported sequence from Chilworth Reliability team - $sequence

HEAD

	my $seqcomms = $sequences{$seq};
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
