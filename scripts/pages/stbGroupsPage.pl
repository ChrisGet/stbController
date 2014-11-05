#!/usr/bin/perl -w
use strict;

use CGI;
use Tie::File::AsHash;
use DBM::Deep;

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

mainMenu() and exit if ($action =~ /^Menu$/i);
createGroup(\$group) and exit if ($action =~ /^Create$|^Edit$/i);

sub mainMenu {
	tie my %groups, 'Tie::File::AsHash', $groupsfile, split => ':' or die "Problem tying \%groups to $groupsfile: $!\n";
	if (!%groups) {
		print '<font size="4" color="red">You currently have no STB Groups</font>';
		exit;
	}

	#### Load the STB Database so we can get the 'Name' of each stb
	my $dbfile = $confdir . 'stbDatabase.db';
	tie my %stbdata, 'DBM::Deep', {file => $dbfile, locking => 1, autoflush => 1, num_txns => 100};


print <<STUFF;
<table>
<tr>
STUFF

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
			$memberstring .= "$name,";
		}
		$memberstring =~ s/\,$//;

print <<GROUP;
<td style="padding:3px;width:auto;">
 <table class="roundedTable" style="width:100%;">
  <tr>
   <td colspan="2" align="center" class="fancyCell" style="background-color:#C0C0C0;width:250px;height:40px;border-radius:4px;">
    <label class="seqLabel masterTooltip" onmouseover="tooltip()" value="Members: $memberstring">$key</label>
   </td>
  </tr>
  <tr>
   <td align="center" width="50%">
    <button class="seqListBtn" onclick="editGroupPage('$key')">Edit</button>
   </td>
   <td align="center" width="50%">
    <button class="seqListBtn Del" onclick="deleteGroup('$key')">Delete</button>
   </td>
  </tr>
 </table>
</td>
GROUP
	
		$colcount++;
	}

	untie %stbdata;
	print '</tr></table>'
} # End of sub 'mainMenu'

sub createGroup {
	my ($group,$boxes) = @_;
	print '<div class="wrapLeft shaded" style="width:650px;">';


	my $headertext = 'Create New STB Group:';
	my $defname;
	my $members;
	my $buttontext = 'Create New Group';
	my $onclick = 'groupValidate()';
	my $textfieldhead = 'Please give your new STB Group a name below';

	if ($$group) {
		$headertext = "Edit Group <font color\=\"#65a9d7\">\"$$group\"<\/font>:";
		$defname = $$group;
		tie my %groups, 'Tie::File::AsHash', $groupsfile, split => ':' or die "Problem tying \%groups to $groupsfile: $!\n";
		$members = $groups{$defname};
		$buttontext = "Update Group \"$defname\"";
		print "<input type=\"hidden\" name=\"originalName\" value=\"$defname\"\/>";
		$onclick = "groupValidate(\'$defname\')";
		$textfieldhead = 'Group Name';
	}

	my $namefield = $query->textfield(-id=>'groupName',-name=>'groupName',-size=>30,-maxlength=>25,-default=>$defname);

	

print <<MAIN;
<div id="seqMain">
<h1 style="margin-bottom:0em;"><u>$headertext</u></h1>
<p style="margin-top:2px;margin-bottom:5px;color:white;font-size:20px;">Click the STBs from the grid on the right to add them to the Group Members area below</p>
<p style="margin-top:2px;color:white;font-size:18px;">Click on a box within the Group Members Area to remove it</p>
<table style="width:100%;">
<tr><td><div style="float:left;">
	<font size="6"><u>Group Members Area</u></font><br><br>
	<table>
		<tr>
		<td><button class="menuButton" onclick="clearSeqArea()">Clear Group Members Area</button></td>
		</tr>
	</table>
	</div>
</td>
<td align="left" valign="bottom"><div style="margin-top:50px;">
	<table width="100%">
		<tr>
		<td colspan="2" align="center"><font color="white" size="3">$textfieldhead</font></td>
		</tr>
		<tr>
		<td><font size="5" color="#69ABBF">Name: </font></td>
		<td>$namefield</td>
		</tr>		
	</table>
</div>
</td>
</tr>
</table>
<div id="sequenceArea" contenteditable="true" style="width:100%;"></div>
<div class="grpSubmitBtnDiv">
	<button class="newSeqSubmit" onclick="$onclick">$buttontext</button>
</div>
</div>
</div>
MAIN

	my $dbfile = $confdir . 'stbDatabase.db';
	if (-e $dbfile) {
		my $conffile = $confdir . 'stbGrid.conf';
        	open FH,"<",$conffile or die "Couldn't open $conffile for reading: $!\n";
	        chomp(my @confdata = <FH>);
	        close FH;
	        my $confdata = join("\n", @confdata);
	        my ($columns) = $confdata =~ m/columns\s*\=\s*(\d+)/;
	        my ($rows) = $confdata =~ m/rows\s*\=\s*(\d+)/;

print <<HEAD;
<div id="stbSelect">
<p style="align:center;font-size:18px;margin-top:3px;margin-bottom:3px;">STB Selection Grid &nbsp&nbsp&nbsp<font color="red">( STBs named " - " or " : " cannot be selected )</font></p>
<table style="border-spacing:0;" align="center">
<tr id="columns">
HEAD

                my $c = '1';
                while ($c <= $columns) {
print <<COL;
<td scope="col" width="80px"><button class="gridButton">Column $c</button></td>
COL
                        $c++;
                }

                tie my %stbdata, 'DBM::Deep', {file => $dbfile,   locking => 1, autoflush => 1, num_txns => 100};

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
                                        %{$stbdata{$id}} = {};
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

print <<BOX;
<td><button name="$name" id="$id" class="stbButton data" type="button" $onclick >$buttontext</button></td>
BOX

                                $stbno++;
                                $c++;
                        }

print <<ROWEND;
<th><button id="Row $r" class="gridButton row inactive" type="button">Row $r</button></th></tr>
ROWEND

                        $r++;
                }

print <<LAST;
</tr></table>
</div>
LAST

                print '</div>';         # End of the "wrapLeft" div

                untie %stbdata;








#<table id="stbConfigGrid" class="stbConfigGrid"><tr>
#HEAD
#		tie my %stbdata, 'DBM::Deep', {file => $dbfile,   locking => 1, autoflush => 1, num_txns => 100};

#		my $c = '0';
				
#		foreach my $key (sort { ($a =~ /STB(\d+)/)[0] <=> ($b =~ /STB(\d+)/)[0] } keys %stbdata) {
#			if ($c >= $columns) {
#				print '</tr><tr>';
#				$c = '0';
#			}
#			my ($num) = $key =~ /STB(\d+)/;
#			my $name = 'STB ' . $num;
#			$name = $stbdata{$key}{'Name'} if ((exists $stbdata{$key}{'Name'}) and ($stbdata{$key}{'Name'} =~ /\S+/));
#print <<KEY;
#<td><button id="$key" class="configButton" onClick="seqTextUpdate('$key','$name')">$name</button></td>
#KEY
#			$c++;
#		}
#		print '</table></div>';
	} else {
		print "<font size=\"5\" color=\"red\">No STB Database found. Have you setup your STB Controller Grid yet?<\/font>";
	}



} # End of sub 'createGroup'
