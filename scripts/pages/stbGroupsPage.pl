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
my $htmldir = $maindir . '/scripts/pages/';
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

mainMenu() and exit if ($action =~ /^Menu$/i);
createGroup(\$group) and exit if ($action =~ /^Create$|^Edit$/i);

sub mainMenu {
	tie my %groups, 'Tie::File::AsHash', $groupsfile, split => ':' or die "Problem tying \%groups to $groupsfile: $!\n";
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
		my $mems = $groups{$key};
		my @members = split(',',$mems);
		my $memberstring = '';
		foreach my $item (@members) {
			my $name = $stbdata{$item}{'Name'} || '';
			if (!$name) {
				$name = 'Unconfigured STB';
			} else {
				if ($name !~ /\S+/ or $name =~ /^\s*\-\s*$/) {
					$name = 'Unconfigured STB';
				}
				if ($name =~ /^\s*\-\s*$/) {
					$name = 'Spacer';
				}
			}
			$memberstring .= "<div class=\"stbGroupIcon\"><p>$name</p></div>";
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
		tie my %groups, 'Tie::File::AsHash', $groupsfile, split => ':' or die "Problem tying \%groups to $groupsfile: $!\n";
		$members = $groups{$defname};
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

print <<HEAD;
<table style="border-spacing:0;" align="center">
<tr id="columns">
HEAD

                my $c = '1';
                while ($c <= $columns) {
print <<COL;
<td scope="col" width="80px"><button class="gridButton grpAdd" onclick="addGroupMulti('col$c')">Column $c</button></td>
COL
                        $c++;
                }

		my $r = '1';            # Set the Row count to 1
		my $stbno = '1';        # Set the STB count to 1

                while ($r <= $rows) {
                        $c = '1';               # Reset the Column count to 1
                        print "<tr id=\"Row$r\">";
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
print <<BOX;
<td><button name="$name" id="$id" class="stbButton data" $onclick data-loc="$location">$buttontext</button></td>
BOX

                                $stbno++;
                                $c++;
                        }

print <<ROWEND;
<th><button id="Row $r" class="gridButton row" onclick="addGroupMulti('row$r')" type="button">Row $r</button></th></tr>
ROWEND

                        $r++;
                }

print <<LAST;
			</tr>
			</table>
		</div>
	</div>
</div>
LAST
	} else {
		print "<font size=\"5\" color=\"red\">No STB Database found. Configure a STB on the \"STB Data\" page first<\/font>";
	}
} # End of sub 'createGroup'
