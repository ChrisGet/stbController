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
my $lastboxfile = $filedir . 'lastBoxes.txt';
my $seqfile = $filedir . 'commandSequences.txt';
my $orderfile = $confdir . 'controllerPageOrder.conf';
my $remfile = $confdir . 'controllerRemote.txt';
my $confs = `ls -1 $confdir`;
my %laststbs;
chomp(my $lastboxstring = `cat $lastboxfile` || '');
my @lastboxes = split(',',$lastboxstring);
for (@lastboxes) {
	$laststbs{$_}++;
}

if (!-e $conffile) {
	createConf();
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
	<p style="color:white;font-size:18px;margin-bottom:10px;margin-top:15px;">Select the number of columns:</p>
	$columns
	<p style="color:white;font-size:18px;margin-bottom:10px;margin-top:10px;">Select the number of rows:</p>
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
	my @order = ('loadSTBSelection','loadControl','loadSequences');	# This is the default order if there are issues with the config file
	
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
		my $subref = \&$load;
		&$subref();
	}
	
	#loadSettings();
}

sub loadSTBSelection {
	my $conffile = $confdir . 'stbGrid.conf';
	open FH,"<",$conffile or die "Couldn't open $conffile for reading: $!\n";
	chomp(my @confdata = <FH>);
	close FH;
	my $confdata = join("\n", @confdata);
	my ($columns) = $confdata =~ m/columns\s*\=\s*(\d+)/;
	my ($rows) = $confdata =~ m/rows\s*\=\s*(\d+)/;
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

	##### Load the STB grid
print <<TOP;
<div id="stbGrid" class="controllerPageSection">
	<div id="gridTitle">
		<p>STB Selection</p>
	</div>
	<table id="stbGridTable">
		<tr id="columns">
TOP

	my $c = '1';
	while ($c <= $columns) {
print <<COL;
<td scope="col" width="80px"><button class="gridButton">Column $c</button></td>
COL
		$c++;
	}

print <<CLEAR;
<td scope="col" width="60px"><button class="gridButton clear" onClick="deselect()">CLEAR</button></td></tr>
CLEAR

my $r = '1';		# Set the Row count to 1
my $stbno = '1';	# Set the STB count to 1

while ($r <= $rows) {
	$c = '1';		# Reset the Column count to 1
	print "<tr id=\"Row$r\">";
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
		$style .= '"';
		
		if ($buttontext =~ /^\s*\:\s*$/) {
print <<BOX;
<td></td>
BOX
		} else {
print <<BOX;
<td><button name="$name" id="$id" class="stbButton deselect" type="button" onClick="colorToggle('$id')" $style>$buttontext</button></td>
BOX
		}

		$stbno++;
		$c++;
	}

print <<ROWEND;
<th><button id="Row $r" class="gridButton row" type="button" onClick="rows('Row$r')">Row $r</button></th></tr>
ROWEND

$r++;

}

print <<LAST;
		</tr>
	</table>
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
	tie my %sequences, 'Tie::File::AsHash', $seqfile, split => ':' or die "Problem tying \%sequences to $seqfile: $!\n";
	my $seqlist = '';
	foreach my $seq (sort keys %sequences) {
		$seqlist .= "<button id=\"$seq\" class=\"sequenceButton\" onclick=\"stbControl('Event','$seq')\">$seq</button>";
	}
	if (!$seqlist) {
		$seqlist = '<p style="font-size:1.5vh;">No sequences found</p>';
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
