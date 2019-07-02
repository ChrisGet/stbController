#!/usr/bin/perl -w

use strict;
use CGI;
use Tie::File::AsHash;
use JSON;
use POSIX;

my $query = CGI->new;
print $query->header();

chomp(my $maindir = (`cat homeDir.txt` || ''));
die "Couldn't find where my main files are installed. No \"stbController\" directory was found on your system...\n" if (!$maindir);
$maindir =~ s/\/$//;
my $filedir = $maindir . '/files/';
my $importdir = $filedir . 'imports/';
my $seqfile = $filedir . 'commandSequences.txt';
tie my %sequences, 'Tie::File::AsHash', $seqfile, split => ':' or die "Problem tying \%sequences to $seqfile: $!\n"; 

chomp(my $importfile = $query->param('file') || $ARGV[0] || '');
chomp(my $name = $query->param('name') || $ARGV[1] || '');
chomp(my $type = $query->param('type') || $ARGV[2] || '');
chomp(my $format = $query->param('format') || $ARGV[3] || '');

if (!$importfile) {
	print "ERROR: No file was detected for the import!";
	exit;
}
my $fullpath = $importdir . $importfile;
if (open FILE, '+>', $fullpath) {
	binmode FILE;
	while (<$importfile>) {
		print FILE;
	}
	close FILE;
} else {
	print "ERROR: Unable to open $fullpath for writing: $!";
	exit;
}

if ($type =~ /sequence/i and $format =~ /stress/i) {
	importStressSequence();
}
if ($type =~ /sequence/i and $format =~ /native/i) {
	importNativeSequence();
}

untie %sequences;

#################### Sub Routines Below ####################
sub importStressSequence {
	my $seqname = $importfile;
	if ($name) {
		$seqname = $name;
	}
	$seqname =~ s/\.txt$//i;
	$seqname =~ s/[^a-zA-Z0-9]+/ /g;

	my $stresstocontfile = $filedir . 'stressToControllerTable.json';
	
	my $stresscomms = `cat $stresstocontfile` // '';
	my $json = JSON->new->allow_nonref;
	$json = $json->canonical('1');
	my $decoded = $json->decode($stresscomms);
	my %stress = %{$decoded};
	
	my $srcfile = $importdir . $importfile;

	##### Validate that the file is plain text #####
	if (!-f $srcfile or $srcfile !~ /\.txt$/) {
		print "ERROR: The file you uploaded ($srcfile) is not a plain text file. Import failed.";
		unlink $srcfile;
		exit;
	}
	##### Validate that the file is plain text #####

	my $infh;
	unless (open $infh, '<', $srcfile) {
		print "ERROR: Failed to open $srcfile for reading: $!\n";
		exit;
	}
	
	my %data;
	my $box;
	my $inloop = '';
	my $processed = '0';
	my $prev = '';		# This will store what the last element of the string was. Values will be either 'COM' for command or 'TO' for timeout.
	
	chomp (my @lines = <$infh>);
	until (!@lines) {
		my $line = shift @lines;
		$line =~ s/\n|\r//g;
		$processed++;
		if ($line =~ /^\{(\w+)\}\s*(\w+)/) {
			$box = $1;
			if (!exists $data{$box}{'PREV'}) {
				$data{$box}{'PREV'} = '';
			}
			my $cmd = $2;
			if ($cmd =~ /Hold/i) {
				my ($c,$num) = $line =~ /Hold\s+(\w+)\:(\d+)/i;
				if ($c and $num) {
					if (!exists $stress{$c} and $c !~ /\d/) {
						next;
					}
					if (exists $stress{$c}) {
						$c = $stress{$c};
					}
					if ($data{$box}{'PREV'} eq 'COM') {
						$data{$box}{'COM'} .= "t1,";
						$data{$box}{'PREV'} = 'TO';
					}
					my $cnt = '0';
					until ($cnt == $num) {
						$data{$box}{'COM'} .= "$c,t1,";
						$cnt++;
					}
					$data{$box}{'PREV'} = 'TO';
				}
			} else {
				if ($data{$box}{'PREV'} eq 'COM') {
					$data{$box}{'COM'} .= "t1,";
				}
				if (exists $stress{$cmd}) {
					$data{$box}{'COM'} .= $stress{$cmd} . ",";
					$data{$box}{'PREV'} = 'COM';
				}
				if ($cmd =~ /\d/) {
					$data{$box}{'COM'} .= $cmd . ",";
					$data{$box}{'PREV'} = 'COM';
				}
			}
		} elsif ($line =~ /^\(([0-9\.]+)\)/) {
			my $timeout = $1;
			$timeout = ceil($timeout);
			$data{$box}{'COM'} .= "t$timeout,";
			$data{$box}{'PREV'} = 'TO';
		} elsif ($line =~ /\[loop=(\d+)\]/i) {
			my $count = $1;
			my $endloop;
			my $comstring;
	
			if ($data{$box}{'PREV'} eq 'COM') {
				$comstring .= "t1,";
			}			
			
			until ($endloop) {
				my $loopline = shift @lines;
				$loopline =~ s/\n|\r//g;
				if (!$loopline or $loopline !~ /\S+/) {
					$endloop = '1';
				} elsif ($loopline =~ /^\(([0-9\.]+)\)/) {
					my $timeout = ceil($1);
					$comstring .= "t$timeout,";
					$data{$box}{'PREV'} = 'TO';
				} elsif ($loopline =~ /\[endloop\]/i) {
					$endloop = '1';
				} elsif ($loopline =~ /^\{(\w+)\}\s*(\w+)/) {
					my $cmd = $2;
					if (!exists $stress{$cmd} and $cmd !~ /\d/) {
						next;
					}
					if (exists $stress{$cmd}) {
						$cmd = $stress{$cmd};
					}
					if ($data{$box}{'PREV'} eq 'COM') {
						$comstring .= "t1,";
					}			
					$comstring .= "$cmd,";
					$data{$box}{'PREV'} = 'COM';
				} elsif ($loopline =~ /^(\S+)/) {
					my $com = $1;
					if ($data{$box}{'PREV'} eq 'COM') {
						$comstring .= "t1,";
					}
					if (!exists $stress{$com} and $com !~ /\d/) {
						next;
					}
					
					if (exists $stress{$com}) {
						$com = $stress{$com};
					}
					$comstring .= "$com,";
					$data{$box}{'PREV'} = 'COM';
				}
			}
			
			### We should now have all of the looped commands stored in $comstring
			my $loopcnt = '0';
			until ($loopcnt == $count) {
				$data{$box}{'COM'} .= $comstring;
				$loopcnt++;
			}
		}
	}
	
	if (!%data) {
		print "ERROR: No valid sequences were created after processing the file. Double check the contents of the file and try again.";
		unlink $srcfile;
		exit;
	}

	foreach my $box (sort keys %data) {
		my $commands = $data{$box}{'COM'};
		my $newseqname = $seqname . ' ' . $box;
		my $found = 'Found';
		my $cnt = '1';
		until ($found eq 'Not Found') {
			my $f = searchSequences(\$newseqname,'noprint');
			if ($f eq 'Found') {
				$newseqname =~ s/ \d+$//;
				$newseqname .= " $cnt";
				$cnt++;
			} else {
				$found = 'Not Found';
			}
		}
		addSequence(\$newseqname,\$commands);
	}
	
	unlink $srcfile;
	print "Success! The stress script was imported and sequences were created with the name/prefix of $seqname";
} # End of sub 'importStressSequence'

sub importNativeSequence {
	#my $seqname = $importfile;
	#if ($name) {
	#	$seqname = $name;
	#}
	#$seqname =~ s/\.txt$//i;
	#$seqname =~ s/[^a-zA-Z0-9]+/ /g;

	my $srcfile = $importdir . $importfile;

	##### Validate that the file is plain text #####
	if (!-f $srcfile or $srcfile !~ /\.txt$/) {
		print "ERROR: The file you uploaded ($srcfile) is not a plain text file. Import failed.";
		unlink $srcfile;
		exit;
	}
	##### Validate that the file is plain text #####

	my $infh;
	unless (open $infh, '<', $srcfile) {
		print "ERROR: Failed to open $srcfile for reading: $!\n";
		exit;
	}

	my $valid = '';
	while (my $line = <$infh>) {
		chomp $line;
		my @bits = split(':',$line);
		my $sequence = $bits[0] // '';
		my $commands = $bits[1] // '';
		
		if ($sequence and $commands) {
			$valid = 1;
			$sequence =~ s/[^a-zA-Z0-9]+/ /g;
			my $found = 'Found';
			my $cnt = '1';
			until ($found eq 'Not Found') {
				my $f = searchSequences(\$sequence,'noprint');
				if ($f eq 'Found') {
					$sequence =~ s/ \d+$//;
					$sequence .= " $cnt";
					$cnt++;
				} else {
					$found = 'Not Found';
				}
			}
			addSequence(\$sequence,\$commands);
		}
	}

	if (!$valid) {
		print "ERROR: No valid sequences were created after processing the file. Double check the contents of the file and try again.";
		unlink $srcfile;
		exit;
	}

	unlink $srcfile;
	print "Success! The sequence file was imported successfully";

} # End of sub 'importNativeSequence'

sub searchSequences {
	my ($seq,$noprint) = @_;
	$$seq = uc($$seq);
	$$seq =~ s/^\s+//g;	# Remove leading whitespace
	$$seq =~ s/\s+$//g;	# Remove trailing whitespace
	$$seq =~ s/\s+/ /g;	# Find all whitespace within the sequence name and replace it with a single space

	if (exists $sequences{$$seq}) {
		print "Found" if (!$noprint);
		return "Found" if ($noprint);
	} else {
		print "Not Found" if (!$noprint);
		return "Not Found" if ($noprint);
	}
} # End of sub 'searchSequences'

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
