#!/usr/bin/perl -w

#BEGIN { use lib "/usr/local/lib/perl5/site_perl/5.18.0/" }
use strict;
use CGI;
use Tie::File;
use Tie::File::AsHash;

my $query = CGI->new;
print $query->header();

chomp(my $action = $query->param('action') || $ARGV[0] || '');
chomp(my $group = $query->param('group') || $ARGV[1] || '');
chomp(my $stbs = $query->param('stbs') || $ARGV[2] || '');
chomp(my $origname = $query->param('originalName') || $ARGV[3] || '');

die "No Action defined for stbGroupControl.pl\n" if (!$action);
die "No Sequence name given for stbGroupControl.pl \"$action\"" if (!$group);

chomp(my $maindir = (`cat homeDir.txt` || ''));
die "Couldn't find where my main files are installed. No \"stbController\" directory was found on your system...\n" if (!$maindir);
$maindir =~ s/\/$//;
my $filedir = ($maindir . '/files/');
my $groupfile = ($filedir . 'stbGroups.txt');
tie my %groups, 'Tie::File::AsHash', $groupfile, split => ':' or die "Problem tying \%groups to $groupfile: $!\n"; 

searchGroups(\$group) and exit if ($action =~ m/^Search$/i);
showGroups(\$group) and exit if ($action =~ m/^Show$/i);
addGroup(\$group,\$stbs) and exit if ($action =~ m/^Add$/i);
deleteGroup(\$group) and exit if ($action =~ m/^Delete$/i);
addGroup(\$group,\$stbs,\$origname) and exit if ($action =~ m/^Edit$/i);

untie %groups;

#################### Sub Routines Below ####################

sub searchGroups {
	my ($grp) = @_;
	$$grp = uc($$grp);
	$$grp =~ s/^\s+//g;	# Remove leading whitespace
	$$grp =~ s/\s+$//g;	# Remove trailing whitespace
	$$grp =~ s/\s+/ /g;	# Find all whitespace within the group name and replace it with a single space

	if (exists $groups{$$grp}) {
		print "Found";
	} else {
		print "Not Found";
	}
} # End of sub 'searchGroups'

sub showGroups {
	my ($grp) = @_;
	if ($$grp =~ /^All$/i) {
		while (my ($key,$value) = each %groups) {
			print "$key -- $value\n";
		}	
	} else {
		$$grp = uc($$grp);
        	$$grp =~ s/^\s+//g;     # Remove leading whitespace
        	$$grp =~ s/\s+$//g;     # Remove trailing whitespace
        	$$grp =~ s/\s+/ /g;     # Find all whitespace within the group name and replace it with a single space
		if (exists $groups{$$grp}) {
			use DBM::Deep;
			my $stbdatafile = $maindir . '/config/stbDatabase.db';
			tie my %stbdata, 'DBM::Deep', {file => $stbdatafile, locking => 1, autoflush => 1, num_txns => 100};
			##### This bit of formatting allows the front end GUI to handle the data
			my @members = split(',', $groups{$$grp});
			my @resforgui;		# Response for GUI (res for gui) 
			foreach my $box (@members) {
				my $name = $stbdata{$box}{'Name'} || '';
				if (!$name) {
					#print "$box\n";
					my ($one,$two) = $box =~ /(stb)(\d+)/i;
					$one = uc($one);
					$name = "$one $two";
				}
				push(@resforgui,"$box:$name");
			}
			my $string = join(',',@resforgui);
			print $string;
			untie %stbdata;
		} else {
			print "\"$$grp\" not found";
		} 
	}
} # End of sub 'showGroups'

sub addGroup {
	my ($grp,$stbs,$origname) = @_;

	##### Do this for 'Edit' Action
	if ($origname) {		##### Check that the actual reference is defined (It wont be for 'Add' Actions)
		if (($$origname) and ($$origname ne $$grp)) {
			delete $groups{$$origname};
		}
	}
	##### Do this for 'Edit' Action

	$$grp = uc($$grp);
	$$grp =~ s/^\s+//g;     # Remove leading whitespace
        $$grp =~ s/\s+$//g;     # Remove trailing whitespace
        $$grp =~ s/\s+/ /g;     # Find all whitespace within the sequence name and replace it with a single space

	$groups{$$grp} = $$stbs;
} # End of sub 'addGroup'

sub deleteGroup {
	my ($grp) = @_;
	$$grp = uc($$grp);
        $$grp =~ s/^\s+//g;     # Remove leading whitespace
        $$grp =~ s/\s+$//g;     # Remove trailing whitespace
        $$grp =~ s/\s+/ /g;     # Find all whitespace within the sequence name and replace it with a single space

	if (exists $groups{$$grp}) {
		delete $groups{$$grp};
	} else {
		die "Group \"$$grp\" cannot be deleted because it does not exist\n";
	}
} # End of sub 'deleteGroup'

