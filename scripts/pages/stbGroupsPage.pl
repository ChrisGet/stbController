#!/usr/bin/perl -w

use strict;
use CGI;
use Tie::File::AsHash;
use JSON;

my $query = CGI->new;
print $query->header();
chomp(my $action = $query->param('action') || $ARGV[0] || '');
chomp(my $group = $query->param('group') || $ARGV[1] || '');
die "No Action given for stbGroupsPage.pl\n" if (!$action);
die "Invalid Action \"$action\" given for stbGroupsPage.pl\n" if ($action !~ /^Menu$|^Create$|^Edit$/i);
die "No STB group given to be edited for stbGroupsPage.pl\n" if (($action =~ /^Edit$/i) and (!$group));

chomp(my $maindir = (`cat homeDir.txt` || ''));
die "Couldn't find where my main files are installed. No \"stbController\" directory was found on your system...\n" if (!$maindir);
$maindir =~ s/\/$//;
my $confdir = $maindir . '/config/';
my $filedir = $maindir . '/files/';
my $groupsfile = ($filedir . 'stbGroups.txt');
my $groupsjsonfile = $filedir . 'stbGroups.json';
my $htmldir = $maindir . '/scripts/pages/';
my $stbdatafile = $confdir . 'stbData.json';

checkLegacy(); # Initial check to see if any old STB group files have been converted to the new JSON format

my $json = JSON->new->allow_nonref;
$json = $json->canonical('1');

##### Load the STB data
my %stbdata;
if (-e $stbdatafile) {
        local $/ = undef;
        open my $fh, "<", $stbdatafile or die "ERROR: Unable to open $stbdatafile: $!\n";
        my $data = <$fh>;
	if ($data) {
	        my $decoded = $json->decode($data);
        	%stbdata = %{$decoded};
	}
}

##### Load the groups data
my %groups;
if (-e $groupsjsonfile) {
        local $/ = undef;
        open my $fh, "<", $groupsjsonfile or die "ERROR: Unable to open $groupsjsonfile: $!\n";
        my $data = <$fh>;
        if ($data) {
        	my $decoded = $json->decode($data);
	        %groups = %{$decoded};
	}
}

mainMenu() and exit if ($action =~ /^Menu$/i);
createGroup(\$group) and exit if ($action =~ /^Create$|^Edit$/i);

sub mainMenu {
	#tie my %groups, 'Tie::File::AsHash', $groupsfile, split => ':' or die "Problem tying \%groups to $groupsfile: $!\n";
	if (!%groups) {
		print '<font size="4" color="red">You currently have no STB Groups</font>';
		exit;
	}

print <<HEAD;
<div id="groupListHeader">
	<div class="groupListRowSec header"><h2>Group Name</h2></div>
	<div class="groupListRowSec memlist header"><h2>Members</h2></div>
	<div class="groupListRowSec manage header"><h2>Manage</h2></div>
</div>
<div id="groupListDiv">
HEAD
	my $colcount = '1';
	foreach my $key (sort keys %groups) {
		if ($colcount == '10') {
			print '</tr><tr>';
			$colcount = '1';
		}
		my $mems = $groups{$key}{'stbs'};
		my @members = split(',',$mems);
		my $memberstring = '';
		foreach my $item (@members) {
			my $name = $stbdata{$item}{'Name'} || '';
			my $errclass = '';
			if (!$name) {
				$name = 'Unconfigured STB';
				$errclass = 'problem';
			} else {
				if ($name !~ /\S+/ or $name =~ /^\s*\-\s*$/) {
					$name = 'Unconfigured STB';
					$errclass = 'problem';
				}
				if ($name =~ /^\s*\-\s*$/) {
					$name = 'Spacer';
					$errclass = 'problem';
				}
			}
			$memberstring .= "<div class=\"stbGroupIcon $errclass\"><p>$name</p></div>";
		}
		$memberstring =~ s/\,$//;

print <<GROUP;
<div class="groupListRow" onclick="groupRowHighlight(this)" title="Click to toggle highlight">
	<div class="groupListRowSec"><p>$key</p></div>
	<div class="groupListRowSec memlist"><div class="memStringHolder">$memberstring</div></div>
	<div class="groupListRowSec manage header">
		<button class="stbGroupBtn Edit" title="Edit" onclick="editGroupPage('$key')"></button>
		<button class="stbGroupBtn Del" title="Delete" onclick="deleteGroup('$key')"></button>
	</div>
</div>
GROUP
		$colcount++;
	}
	print '</div>'
} # End of sub 'mainMenu'

sub createGroup {
	my ($group,$boxes) = @_;
	my $headertext = 'STB Group &#8594; Create';
	my $defname;
	my $members;
	my $buttontext = 'Create!';
	my $onclick = 'groupValidate()';
	my $textfieldhead = 'Please give your new STB Group a name below';

	if ($$group) {
		$headertext = "STB Group \&\#8594; Edit \&\#8594; <font color\=\"#65a9d7\">\"$$group\"<\/font>";
		$defname = $$group;
		#tie my %groups, 'Tie::File::AsHash', $groupsfile, split => ':' or die "Problem tying \%groups to $groupsfile: $!\n";
		$members = $groups{$defname}{'stbs'} // '';
		$buttontext = "Update!";
		print "<input type=\"hidden\" name=\"originalName\" value=\"$defname\"\/>";
		$onclick = "groupValidate(\'$defname\')";
		$textfieldhead = 'Group Name';
	}

	my $namefield = $query->textfield(-id=>'groupName',-name=>'groupName',-size=>30,-maxlength=>25,-default=>$defname);

print <<MAIN;
<div id="stbGroupPageHolder">
	<div id="stbGroupHeaderDiv">
		<h1>$headertext</h1>
	</div>
	<div id="stbGroupInfoArea">
		<div id="stbGroupHeadHolder">
			<p class="seqInfo big">Select STBs from the grid on the right to add them to the Group area below</p>
			<p class="seqInfo med">Select the row number to add ALL STBs on that row to the group</p>
		</div>
		<div id="stbGroupContentHolder">
			<div id="stbGroupAreaTop">
				<p>STB Group Name</p>
				$namefield
			</div>
			<div id="stbGroupAreaMiddle">
				<p class="stbGroupInfo rem">Click on a button within the Group Area to remove it</p>
			</div>
			<div id="stbGroupAreaBottom">
				<button id="clearSTBGroupAreaBtn" onclick="clearSeqArea('sequenceArea')">Clear Group Area</button>
				<div id="sequenceArea" contenteditable="true"></div>
				<button id="createSTBGroupBtn" onclick="$onclick">$buttontext</button>
			</div>
		</div>
	</div>	
	<div id="stbGroupGridArea">
MAIN

	if (-e $stbdatafile) {
		my $conffile = $confdir . 'stbGrid.conf';
        	open FH,"<",$conffile or die "Couldn't open $conffile for reading: $!\n";
	        chomp(my @confdata = <FH>);
	        close FH;
	        my $confdata = join("\n", @confdata);
	        my ($columns) = $confdata =~ m/columns\s*\=\s*(\d+)/;
	        my ($rows) = $confdata =~ m/rows\s*\=\s*(\d+)/;

		my $btnwidth = 98/$columns;     ###
	        if ($btnwidth > 49) {
	                $btnwidth = 50;
	        } elsif ($btnwidth > 48) {
	                $btnwidth = 40;
	        }
	        my $btnstyle = 'width:' . $btnwidth . '%;';     ###
	        if ($columns > 25) {
	                $btnstyle .= 'font-size:1.1vh;';
	        }
	        my $divwidth = '100%';

		my $grheight = 90/$rows;
                if ($grheight > 18) {
                        $grheight = 20;
                }
                my $grstyle = 'height:' . $grheight . '%;';

print <<HEAD;
	<div id="stbGridTable" style="width:$divwidth;">
		<div class="stbGridRow">
HEAD

                my $c = '1';
                while ($c <= $columns) {
print <<COL;
<button class="gridButton grpAdd" onclick="addGroupMulti('col$c')" style="$btnstyle">$c</button>
COL
                        $c++;
                }

print <<EN;
<button class="gridButton row blank"></button>
</div>  
EN
		
		my $r = '1';            # Set the Row count to 1
		my $stbno = '1';        # Set the STB count to 1

                while ($r <= $rows) {
                        $c = '1';               # Reset the Column count to 1
			print "<div id=\"Row$r\" class=\"stbGridRow\" style=\"$grstyle\">";
                        while ($c <= $columns) {
                                my $id = "STB$stbno";
                                my $name = "col$c"."stb$stbno";
                                my $onclick;
                                my $buttontext;
                                if (exists $stbdata{$id}) {
                                } else {
                                        %{$stbdata{$id}} = ();
                                }

                                if ((exists $stbdata{$id}{'Name'}) and ($stbdata{$id}{'Name'} =~ /\S+/)) {
                                        $buttontext = $stbdata{$id}{'Name'};
                                        if ($buttontext =~ /^\s*(\:|\-)\s*$/) {		
                                                $onclick = '';
                                        } else {
                                                $onclick = "onClick\=\"seqTextUpdate\(\'$id\'\,\'$buttontext\'\)\"";
                                        }
                                } else {
                                        $buttontext = '-';
                                        $onclick = '';
                                }

				my $location = 'col' . $c . 'row' . $r;
				my $style = 'style="' . $btnstyle . '"';
				
print <<BOX;
<button name="$name" id="$id" class="stbButton data" $onclick data-loc="$location" $style>$buttontext</button>
BOX

                                $stbno++;
                                $c++;
                        }

print <<ROWEND;
<button id="Row $r" class="gridButton row" onclick="addGroupMulti('row$r')" type="button">$r</button></div>
ROWEND

                        $r++;
                }

print <<LAST;
			</div>
		</div>
	</div>
</div>
LAST
	} else {
		print "<font size=\"5\" color=\"red\">No STB Database found. Configure a STB on the \"STB Data\" page first<\/font>";
	}
} # End of sub 'createGroup'

sub checkLegacy {
	if (!-e $groupsjsonfile and !-e $groupsfile) {
                ##### If no command sequence files exist, we can start off with JSON straight away
                $groupsfile = $groupsjsonfile;
                return;
        } elsif (-e $groupsjsonfile) {
                ##### If the new file format already exists, update the $seqfile variable to use
                $groupsfile = $groupsjsonfile;
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
