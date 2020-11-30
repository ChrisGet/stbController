#!/usr/bin/perl -w

use strict;
use CGI;
use Tie::File::AsHash;
use JSON;

my $query = CGI->new;
print $query->header();

chomp(my $action = $query->param('action') // $ARGV[0] // '');
chomp(my $category = $query->param('category') // $ARGV[1] // '');
chomp(my $origname = $query->param('originalName') // $ARGV[2] // '');

die "No Action defined for " . __FILE__ . "\n" if (!$action);
die "No Category name given for " . __FILE__ . " \"$action\"" if (!$category);

chomp(my $maindir = (`cat homeDir.txt` // ''));
die "Couldn't find where my main files are installed. No \"stbController\" directory was found on your system...\n" if (!$maindir);
$maindir =~ s/\/$//;
my $filedir = $maindir . '/files/';
my $seqfile = $filedir . 'commandSequences.json';
my $catfile = $filedir . 'sequenceCategories.json';

##### Format the new category name
$category = uc($category);
$category =~ s/^\s+//g;		# Remove leading whitespace
$category =~ s/\s+$//g;		# Remove trailing whitespace
$category =~ s/\s+/ /g;		# Find all whitespace within the category name and replace it with a single space

##### Create new JSON object for later use
my $json = JSON->new->allow_nonref;
$json = $json->canonical('1');

##### Load the sequences in to %sequences
my %sequences;
if (-e $seqfile) {
        local $/ = undef;
        open my $fh, "<", $seqfile or die "ERROR: Unable to open $seqfile: $!\n";
        my $data = <$fh>;
        my $decoded = $json->decode($data);
        %sequences = %{$decoded};
}

##### Load the categories in to %categories
my %categories;
if (-e $catfile) {
        local $/ = undef;
        open my $fh, "<", $catfile or die "ERROR: Unable to open $catfile: $!\n";
        my $data = <$fh>;
        my $decoded = $json->decode($data);
        %categories = %{$decoded};
}

searchCategories() and exit if ($action =~ m/^Search$/i);
#showCategories() and exit if ($action =~ m/^Show$/i);
addCategory() and exit if ($action =~ m/^Add$/i);
deleteCategory() and exit if ($action =~ m/^Delete$/i);
addCategory() and exit if ($action =~ m/^Edit$/i);

#################### Sub Routines Below ####################

sub searchCategories {
	if (exists $categories{$category}) {
		print "Found";
	} else {
		print "Not Found";
	}
} # End of sub 'searchCategories'

#sub showSequences {
#	my ($seq) = @_;
#	if ($$seq =~ /^All$/i) {
#		#while (my ($key,$value) = each %sequences) {
#		foreach my $key (sort keys %sequences) {
#			print "$key -- " . $sequences{$key}{'commands'} . "\n";
#		}	
#	} else {
#		$$seq = uc($$seq);
#        	$$seq =~ s/^\s+//g;     # Remove leading whitespace
#        	$$seq =~ s/\s+$//g;     # Remove trailing whitespace
#        	$$seq =~ s/\s+/ /g;     # Find all whitespace within the sequence name and replace it with a single space
#		if (exists $sequences{$$seq}) {
#			print $sequences{$$seq}{'commands'};
#		} else {
#			print "\"$$seq\" not found";
#		} 
#	}
#} # End of sub 'showSequences'

sub addCategory {
	$categories{$category} = '1';
	
	##### Do this for 'Edit' Action
	if (($origname) and ($origname ne $category)) {
		foreach my $seq (sort keys %sequences) {
			if ($sequences{$seq}{'category'} eq $origname) {
				$sequences{$seq}{'category'} = $category;
			}
		}
		delete $categories{$origname};
		saveSequences();
	}
	##### Do this for 'Edit' Action

	saveCategories();
} # End of sub 'addCategory'

sub deleteCategory {
	if (exists $categories{$category}) {
		foreach my $seq (sort keys %sequences) {
			if ($sequences{$seq}{'category'} eq $category) {
				$sequences{$seq}{'category'} = '';
			}
		}
		delete $categories{$category};
		saveSequences();
		saveCategories();
	} else {
		die "Sequence Category \"$category\" cannot be deleted because it does not exist\n";
	}
} # End of sub 'deleteSequence'

sub saveSequences {
	my $encoded = $json->pretty->encode(\%sequences);
	if (open my $newfh, '+>', $seqfile) {
		print $newfh $encoded;
		close $newfh;
	} else {
		die "ERROR: Unable to open $seqfile for writing: $!\n";
	}
}

sub saveCategories {
	my $encoded = $json->pretty->encode(\%categories);
	if (open my $newfh, '+>', $catfile) {
		print $newfh $encoded;
		close $newfh;
	} else {
		die "ERROR: Unable to open $catfile for writing: $!\n";
	}
}

