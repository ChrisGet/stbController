#!/usr/bin/perl -w

use strict;
use CGI;
use Tie::File::AsHash;

my $query = CGI->new;
print $query->header();

chomp(my $action = $query->param('action') || $ARGV[0] || '');
chomp(my $sequence = $query->param('sequence') || $ARGV[1] || '');
chomp(my $commands = $query->param('commands') || $ARGV[2] || '');
chomp(my $origname = $query->param('originalName') || $ARGV[3] || '');

die "No Action defined for sequenceControl.pl\n" if (!$action);
die "No Sequence name given for sequenceControl.pl \"$action\"" if (!$sequence);


chomp(my $maindir = (`cat homeDir.txt` || ''));
die "Couldn't find where my main files are installed. No \"stbController\" directory was found on your system...\n" if (!$maindir);
$maindir =~ s/\/$//;
my $filedir = $maindir . '/files/';
my $seqfile = ($filedir . 'commandSequences.txt');
tie my %sequences, 'Tie::File::AsHash', $seqfile, split => ':' or die "Problem tying \%sequences to $seqfile: $!\n"; 

searchSequences(\$sequence) and exit if ($action =~ m/^Search$/i);
showSequences(\$sequence) and exit if ($action =~ m/^Show$/i);
addSequence(\$sequence,\$commands) and exit if ($action =~ m/^Add$/i);
deleteSequence(\$sequence) and exit if ($action =~ m/^Delete$/i);
addSequence(\$sequence,\$commands,\$origname) and exit if ($action =~ m/^Edit$/i);
copySequence(\$sequence,\$origname) and exit if ($action =~ m/^Copy$/i);


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

