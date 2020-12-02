#!/usr/bin/perl -w

use strict;
use CGI;
use Tie::File::AsHash;
use JSON;

my $query = CGI->new;
print $query->header();

chomp(my $maindir = (`cat homeDir.txt` || ''));
die "Couldn't find where my main files are installed. No \"stbController\" directory was found on your system...\n" if (!$maindir);
$maindir =~ s/\/$//;
my $confdir = $maindir . '/config/';
my $conffile = $confdir . 'stbGrid.conf';
my $filedir = $maindir . '/files/';
my $stbdatafile = $confdir . 'stbData.json';
my $lastboxfile = $filedir . 'lastBoxes.txt';
my $seqfile = $filedir . 'commandSequences.txt';
my $seqjsonfile = $filedir . 'commandSequences.json';
my $groupsfile = $filedir . 'stbGroups.json';
my $orderfile = $confdir . 'controllerPageOrder.conf';
my $remfile = $confdir . 'controllerRemote.txt';
my $catlistfile = $filedir . 'sequenceCategories.json';
my $confs = `ls -1 $confdir`;
my %laststbs;
chomp(my $lastboxstring = `cat $lastboxfile` || '');
my @lastboxes = split(',',$lastboxstring);
for (@lastboxes) {
	$laststbs{$_}++;
}

chomp(my $wholepage = $query->param('wholepage') // $ARGV[0] // ''); # A param passed from the web ui to indicate we want the whole page loaded
chomp(my $mode = $query->param('mode') // $ARGV[1] // '');

checkLegacy();  # Initial check to see if any old sequence files have been converted to the new JSON format

##### Create new JSON object for later use
my $json = JSON->new->allow_nonref;
$json = $json->canonical('1');

##### Load the STB data
my %stbdata;
if (-e $stbdatafile) {
	local $/ = undef;
	open my $fh, "<", $stbdatafile or die "ERROR: Unable to open $stbdatafile: $!\n";
	my $data = <$fh>;
	my $decoded = $json->decode($data);
	%stbdata = %{$decoded};
}

##### Load the sequences data
my %sequences;
if (-e $seqjsonfile) {
	local $/ = undef;
	open my $fh, "<", $seqjsonfile or die "ERROR: Unable to open $seqjsonfile: $!\n";
	my $data = <$fh>;
	my $decoded = $json->decode($data);
	%sequences = %{$decoded};
}

##### Load the sequence categories data
my %categories;
if (-e $catlistfile) {
	local $/ = undef;
	open my $fh, "<", $catlistfile or die "ERROR: Unable to open $catlistfile: $!\n";
	my $data = <$fh>;
	my $decoded = $json->decode($data);
	%categories = %{$decoded};
}
                                        
##### Load the STB Groups data
my %groups;
if (-e $groupsfile) {
	local $/ = undef;
	open my $fh, "<", $groupsfile or die "ERROR: Unable to open $groupsfile: $!\n";
	my $data = <$fh>;
	my $decoded = $json->decode($data);
	%groups = %{$decoded};
}

if (!-e $conffile) {
	createConf();
	exit;
}

open my $cfh,"<",$conffile or die "Couldn't open $conffile for reading: $!\n";
chomp(my @confdata = <$cfh>);
close $cfh;
my $confdata = join("\n", @confdata);
my ($columns) = $confdata =~ m/columns\s*\=\s*(\d+)/;
my ($rows) = $confdata =~ m/rows\s*\=\s*(\d+)/;
if (!$columns or !$rows) {
	createConf();
	exit;
}

if ($mode and !$wholepage) {
	loadSTBSelection() and exit if ($mode =~ /stbgrid/i);
	loadGroupSelection() and exit if ($mode =~ /stbgroups/i);
} else {
	loadPage();
}

sub createConf {
	my $rows = $query->textfield(-id=>'gridRowsText',-name=>'rows',-size=>'10',-maxlength=>'2');
	my $columns = $query->textfield(-id=>'gridColumnsText',-name=>'columns',-size=>'10',-maxlength=>'2');
	my $fontformat = '<font size="4" color="#267A94">';
	print '<div class="errorDiv">';
	print '<div class="userForm"><body>';
	print "<p style=\"color:orange;font-size:25px;margin:1% 0;\">! No configuration files found for the STB grid !</p>";

print <<FORM;
<form id="createGridConfig" name="createGridConfig">
	<p style="color:white;font-size:20px;margin-bottom:3px;margin-top:3px;">Set the following options to create your STB grid</p>
	<p style="color:red;font-size:20px;margin-bottom:3px;">Once you have chosen the size of the grid it cannot be changed.</p>
	<p style="color:#cccccc;font-size:17px;margin-bottom:10px;margin-top:1px;">Ensure the grid size will be big enough to accommodate ALL STBS you wish to control, allowing for grid spacers as well.</p>
	<p style="color:white;font-size:18px;margin-bottom:10px;margin-top:15px;">Enter the number of columns (Recommended max is 24):</p>
	$columns
	<p style="color:white;font-size:18px;margin-bottom:10px;margin-top:10px;">Enter the number of rows (Recommended max is 50):</p>
	$rows
</form>
<button class="newSeqSubmit createGrid" onclick="validate()">Create New Grid</button><br>
</body>
</div>
</div>
FORM
} 
#################################################### End of sub createConf ####################################################

sub loadPage {
	my @order;
	if ($mode eq 'stbgroups') {
		@order = ('loadGroupSelection','loadControl','loadSequences');	# This is the default order if there are issues with the config file
	} else {
		@order = ('loadSTBSelection','loadControl','loadSequences');	# This is the default order if there are issues with the config file
	}
	
	chomp(my $orderconf = `cat $orderfile` // '');
	if ($orderconf) {
		my @bits = split('->',$orderconf);
		if ($bits[0] and $bits[1] and $bits[2]) {
			@order = ();
			foreach my $bit (@bits) {
				if ($bit =~ /^STBSelection|Control|Sequences$/) {
					push(@order,'load' . $bit);
				}
			}
		}
	}

	foreach my $load (@order) {
		if ($load =~ /STBSelection/ and $mode eq 'stbgroups') {
			$load = 'loadGroupSelection';
		}
		my $subref = \&$load;
		&$subref();
	}
}

sub loadSTBSelection {
	my $conffile = $confdir . 'stbGrid.conf';
	open FH,"<",$conffile or die "Couldn't open $conffile for reading: $!\n";
	chomp(my @confdata = <FH>);
	close FH;
	my $confdata = join("\n", @confdata);
	my ($columns) = $confdata =~ m/columns\s*\=\s*(\d+)/;
	my ($rows) = $confdata =~ m/rows\s*\=\s*(\d+)/;
	
	my $divwidth = '200';
	my $widcnt = '1';
	until ($widcnt == $columns or $divwidth >= 1200) {
		$divwidth = $divwidth + 110;
		$widcnt++;
	}
	if ($divwidth > 1200) {
		$divwidth = '1250';
	} else {
		$divwidth = $divwidth + 50;
	}
	
	my $fullcoll = $columns+42;
	my $btnwidth = ($divwidth-$fullcoll)/$columns;
	my $btnstyle = 'width:' . $btnwidth . 'px;';
	$divwidth .= 'px';

	##### Load the STB grid
print <<TOP;
<div id="stbGrid" class="controllerPageSection">
	<div id="gridTitle">
		<p>STB Selection</p>
	</div>
	<div id="gridModeSwitch">
		<div class="gridModeDiv selected" id="gridModeSTBs"><p>STB GRID</p></div>
		<div class="gridModeDiv" id="gridModeGroups"><p>STB GROUPS</p></div>
	</div>
	<div id="stbGridTable" style="width:$divwidth;">
		<div class="stbGridRow">
TOP

	my $c = '1';
	while ($c <= $columns) {
print <<COL;
<button class="gridButton" style="$btnstyle">$c</button>
COL
		$c++;
	}

print <<CLEAR;
<button class="gridButton clear" onclick="deselect()">CLEAR</button></div>
CLEAR

my $r = '1';		# Set the Row count to 1
my $stbno = '1';	# Set the STB count to 1

while ($r <= $rows) {
	$c = '1';		# Reset the Column count to 1
	print "<div id=\"Row$r\" class=\"stbGridRow\">";
	while ($c <= $columns) {
		my $id = "STB$stbno";
		my $name = "col$c"."stb$stbno";
		my $buttontext;
		if (exists $stbdata{$id}) {
		} else {
			$stbdata{$id} = {};
		}

		if ((exists $stbdata{$id}{'Name'}) and ($stbdata{$id}{'Name'} =~ /\S+/)) {
			$buttontext = $stbdata{$id}{'Name'};
		} else {
			$buttontext = "-";
		}
		my $style = 'style="';
		if (exists $stbdata{$id}{'ButtonColour'}) {
			$style .= 'background-color:' . $stbdata{$id}{'ButtonColour'} . ';';
		}
		if (exists $stbdata{$id}{'ButtonTextColour'}) {
			$style .= 'color:' . $stbdata{$id}{'ButtonTextColour'} . ';';
		}
		$style .= $btnstyle;
		$style .= '"';
		
		if ($buttontext =~ /^\s*\:\s*$/) {
print <<BOX;
<button class="spacerBtn" $style></button>
BOX
		} else {
print <<BOX;
<button name="$name" id="$id" class="stbButton deselect" onclick="colorToggle('$id')" $style>$buttontext</button>
BOX
		}

		$stbno++;
		$c++;
	}

print <<ROWEND;
<button id="Row $r" class="gridButton row" onclick="rows('Row$r')">$r</button></div>
ROWEND

$r++;

}

print <<LAST;
	</div>
	<input type="hidden" id="matrixLoaded" />
	<input type="hidden" id="totalRows" value="$rows"/>
</div>
LAST
	##### Print the STB grid row selection restriction stuff
	my $restrictfile = $confdir . 'gridRowRestriction.conf';
	if (-e $restrictfile) {
		chomp(my $opt = `cat $restrictfile` // '');
		if ($opt) {
			if ($opt =~ /^on$/i) {
				print '<input type="hidden" id="restrictSTBGridRows" value="on">';
			}
		}
	}
} ########## End of sub loadGrid ##########

sub loadControl {
	my $choice = 'universalRemote';
	if (open my $fh, '<', $remfile) {
		local $/;
		$choice = <$fh>;
		close $fh;
	}
	chomp $choice;	
	if ($choice) {
		my $file = $maindir . '/scripts/pages/' . $choice . '.html';
		if (-e $file) {
			##### Load the control buttons
			open FH, '<', $file or die "Unable to open $file: $!\n";
			my @control = <FH>;
			close FH;
print <<CONTROL;
<div id="controllerSection" class="controllerPageSection">
	<div id="controllerTitle">
		<p>Control</p>
	</div>
	<div id="controllerButtons">
		@control
	</div>
</div>
CONTROL
		} else {
			die "ERROR: Could not locate remote file $file\n";
		}
	}
}

sub loadSequences {
	my $seqlist = '';

	##### Sort the sequences by their categories
	my %seqsbycat;
	foreach my $seq (keys %sequences) {
		next if ($sequences{$seq}{'active'} eq 'no');
		my $cat = $sequences{$seq}{'category'} // '';
		if ($cat) {
			$seqsbycat{$cat}{$seq} = 1;
		} else {
			$seqsbycat{'zzzzzUnassigned'}{$seq} = 1;
		}
	}

	foreach my $cat (sort keys %seqsbycat) {
		my $catname = $cat;
		if ($cat eq 'zzzzzUnassigned') {
                        $catname = 'Unassigned';
                }
		$seqlist .= '<div class="seqCatTitleGridDiv"><p>' . $catname . '</p></div>';
                my %catseqs = %{$seqsbycat{$cat}};
		foreach my $seq (sort keys %catseqs) {
			if ($sequences{$seq}{'active'} eq 'yes') {
				my $seqdesc = $sequences{$seq}{'description'};
				my $val = 'No description';
				if ($seqdesc =~ /\S+/) {
					$val = $seqdesc;
				}
				$seqlist .= "<button id=\"$seq\" class=\"sequenceButton masterTooltip\" value=\"$val\" onclick=\"stbControl('Event','$seq')\">$seq</button>";
			}
		}
	}
	if (!$seqlist) {
		$seqlist = '<p style="font-size:1.5vh;">No active sequences</p>';
	}

print <<SEQSEC;
<div id="sequenceButtons" class="controllerPageSection">
	<div id="sequencesHead" class="masterTooltip" value="Below are your custom built sequences. Go to the Sequences page to make more or edit the current ones">
		<p>Sequences</p>
	</div>
	<div id="sequencesBody">
		$seqlist
	</div>
</div>
SEQSEC


	untie %sequences;
}

sub loadSettings {
	my %orders = (	'STBSelection->Control->Sequences' => '1',
			'STBSelection->Sequences->Control' => '1',
			'Sequences->STBSelection->Control' => '1',
			'Sequences->Control->STBSelection' => '1',
			'Control->STBSelection->Sequences' => '1',
			'Control->Sequences->STBSelection' => '1',
		);
	chomp(my $currentorder = `cat $orderfile` // '');

	my $layoutdata = '';
	foreach my $layout (sort keys %orders) {
		my $sel = '';
		if ($layout eq $currentorder) {
			$sel = 'checked="checked"';
		}
		(my $pretty = $layout) =~ s/\-\>/ - /g;
		$pretty =~ s/STBSelection/STB Selection/;
$layoutdata .= <<INFO;
<div class="layoutRow">
	<div class="layoutTextHolder">
		<p>$pretty</p>
	</div>
	<div class="layoutRadioHolder">
		<input class="layoutRadio" type="radio" name="layoutRadios" value="$layout" $sel/>
	</div>
</div>
INFO
	}

print <<DATA;
<div id="controllerPageSettingsButton" onclick="ctrlSettings('show')">
</div>
<div id="controllerPageSettingsHolder">
	<h1>Settings...</h1>
	<button id="closeSettingsBtn" onclick="ctrlSettings('close')">CLOSE</button>
	<div class="settingSection layout">
		<div class="setSecHead">
			<h2>Layout</h2>
			<h3>Choose which order you would like the <span class='highlightSpan'>STB Selection</span>, <span class='highlightSpan'>Sequences</span>, and <span class='highlightSpan'>Control</span> sections to appear on the page.</h3>
		</div>
		<div class="setSecDetail">
			<div class="layoutHolder">
			$layoutdata
			</div>
			<div class="layoutSaveDiv">
				<button id="saveLayoutBtn" onclick="saveLayoutChoice()">SAVE</button>
			</div>
		</div>
	</div>
</div>
DATA
}

sub loadGroupSelection {
	my $groupcontent = '';
	foreach my $grp (sort keys %groups) {
		my $stbs = $groups{$grp}{'stbs'};
		my @members = split(',',$stbs);
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
		my $idname = $grp;
		$idname =~ s/\s+/_/g;

$groupcontent .= <<GRP;
	<div class="groupSTBControlRow" id="groupControlRow_$idname">
		<div class="groupControlRowSection"><p>$grp</p></div>
		<div class="groupControlRowSection members">
			<div class="memStringHolder">
				$memberstring
			</div>
		</div>
	</div>
GRP
	}

print <<TOP;
<div id="stbGrid" class="controllerPageSection">
	<div id="gridTitle">
		<p>STB Selection</p>
	</div>
	<div id="gridModeSwitch">
		<div class="gridModeDiv" id="gridModeSTBs"><p>STB GRID</p></div>
		<div class="gridModeDiv selected" id="gridModeGroups"><p>STB GROUPS</p></div>
	</div>
	<div id="groupControlHolder">
		<div id="groupControlHeader">
			<div class="groupControlRowSection"><p>Group Name</p></div>
			<div class="groupControlRowSection members"><p>STB Members</p></div>
		</div>
		<div id="groupControlListHolder">
			$groupcontent
		</div>

	</div>
</div>
TOP
}

sub checkLegacy {
        if (!-e $seqjsonfile and !-e $seqfile) {
                ##### If no command sequence files exist, we can start off with JSON straight away
                $seqfile = $seqjsonfile;
                return;
        } elsif (-e $seqjsonfile) {
                ##### If the new file format already exists, update the $seqfile variable to use
                $seqfile = $seqjsonfile;
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
                                if (open my $newfh, '+>', $seqjsonfile) {
                                        print $newfh $encoded;
                                        close $newfh;
                                } else {
                                        die "Failed to open file $seqjsonfile for writing in conversion in file " . __FILE__ . " :$!\n";
                                }
                        }
		}
	}
}
