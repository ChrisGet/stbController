#!/usr/bin/perl -w

use strict;
use CGI;
use Tie::File::AsHash;
use JSON;

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
my $confdir = ($maindir . '/config/');
my $groupfile = ($filedir . 'stbGroups.txt');
my $groupsjsonfile = $filedir . 'stbGroups.json';
#tie my %groups, 'Tie::File::AsHash', $groupfile, split => ':' or die "Problem tying \%groups to $groupfile: $!\n"; 

checkLegacy(); # Initial check to see if any old STB group files have been converted to the new JSON format

my $json = JSON->new->allow_nonref;
$json = $json->canonical('1');
##### Load the groups data
my %groups;
if (-e $groupsjsonfile) {
        local $/ = undef;
        open my $fh, "<", $groupsjsonfile or die "ERROR: Unable to open $groupsjsonfile: $!\n";
        my $data = <$fh>;
        my $decoded = $json->decode($data);
        %groups = %{$decoded};
}

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
		#while (my ($key,$value) = each %groups) {
		foreach my $key (sort keys %groups) {
			#print "$key -- $value\n";
			print "$key -- " . $groups{$key}{'stbs'};
		}	
	} else {
		$$grp = uc($$grp);
        	$$grp =~ s/^\s+//g;     # Remove leading whitespace
        	$$grp =~ s/\s+$//g;     # Remove trailing whitespace
        	$$grp =~ s/\s+/ /g;     # Find all whitespace within the group name and replace it with a single space
		if (exists $groups{$$grp}) {
			use JSON;
			my $stbdatafile = $confdir . 'stbData.json';
			my $json = JSON->new->allow_nonref;
			$json = $json->canonical('1');
			
			my %stbdata;
			if (-e $stbdatafile) {
        			local $/ = undef;
        			open my $fh, "<", $stbdatafile or die "ERROR: Unable to open $stbdatafile: $!\n";
        			my $data = <$fh>;
        			my $decoded = $json->decode($data);
        			%stbdata = %{$decoded};
			}

			##### This bit of formatting allows the front end GUI to handle the data
			my @members = split(',', $groups{$$grp}{'stbs'});
			my @resforgui;		# Response for GUI (res for gui) 
			foreach my $box (@members) {
				my $name = $stbdata{$box}{'Name'} || '';
				if (!$name) {
					$name = '-';
				}
				push(@resforgui,"$box~$name");
			}
			my $string = join(',',@resforgui);
			print $string;
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

	$groups{$$grp}{'stbs'} = $$stbs;
	saveGroups();
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
	saveGroups();
} # End of sub 'deleteGroup'

sub checkLegacy {
        if (!-e $groupsjsonfile and !-e $groupfile) {
                ##### If no command sequence files exist, we can start off with JSON straight away
                $groupfile = $groupsjsonfile;
                return;
        } elsif (-e $groupsjsonfile) {
                ##### If the new file format already exists, update the $seqfile variable to use
                $groupfile = $groupsjsonfile;
                return;
        }

        ##### If the checks get this far, we need to convert old sequence files to the new JSON format
        if (-e $groupfile) {
                my %newjson;
                tie my %temp, 'Tie::File::AsHash', $groupfile, split => ':' or die "Problem tying \%temp to $groupfile for conversion in " . __FILE__ . ": $!\n";
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

sub saveGroups {
	my $encoded = $json->pretty->encode(\%groups);
        if (open my $newfh, '+>', $groupsjsonfile) {
                print $newfh $encoded;
                close $newfh;
        } else {
                die "ERROR: Unable to open $groupsjsonfile: $!\n";
        }
}
