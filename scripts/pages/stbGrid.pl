#!/usr/bin/perl -w
use strict;

use CGI;
use DBM::Deep;
use Tie::File::AsHash;

my $query = CGI->new;
print $query->header();

chomp(my $maindir = (`cat homeDir.txt` || ''));
die "Couldn't find where my main files are installed. No \"stbController\" directory was found on your system...\n" if (!$maindir);
$maindir =~ s/\/$//;
my $confdir = $maindir . '/config/';
my $filedir = $maindir . '/files/';
my $lastboxfile = $filedir . 'lastBoxes.txt';
my $contbtnfile = $maindir . '/scripts/pages/controlButtons.html';
my $confs = `ls -1 $confdir`;
my %laststbs;
chomp(my $lastboxstring = `cat $lastboxfile` || '');
my @lastboxes = split(',',$lastboxstring);
for (@lastboxes) {
	$laststbs{$_}++;
}

if ($confs !~ m/stbGrid.conf/) {
	createConf();
} else {
	loadGrid(\$confdir);
}

sub createConf {
	my $rows = $query->textfield(-id=>'rows',-name=>'rows',-size=>'10');
	my $columns = $query->textfield(-id=>'columns',-name=>'columns',-size=>'10');
	my $fontformat = '<font size="4" color="#267A94">';
	print '<div class="wrapLeft shaded">';
	print '<div class="userForm"><body>';
	print "<p style=\"color:red;font-size:20px;margin-bottom:3px;margin-top:5px;\">No configuration files found for the STB grid:</p>";

print <<FORM;
<form id="createGridConfig" name="createGridConfig">
<p style="color:white;font-size:20px;margin-bottom:3px;margin-top:3px;">Set the following options to create your STB grid</p>
<p style="color:red;font-size:20px;margin-bottom:3px;">NOTE: Once you have chosen the size of the grid it cannot be changed.</p>
<p style="color:red;font-size:20px;margin-bottom:10px;margin-top:1px;">Ensure the grid size will be big enough to accommodate ALL STBS you wish to control, allowing for grid spacers as well.</p>
<p style="color:#267A94;font-size:18px;margin-bottom:10px;margin-top:1px;">Select the number of columns:</p>
$columns<br><br>
<p style="color:#267A94;font-size:18px;margin-bottom:10px;margin-top:1px;">Select the number of rows:</p>
$rows<br>
<br><br>
</form>
<button class="newSeqSubmit" style="float:none;" onclick="validate()">Create New Grid</button><br>
</body>
</div>
</div>
FORM
} 
#################################################### End of sub createConf ####################################################

sub loadGrid {
	my ($confdir) = @_;
	my $conffile = $$confdir . 'stbGrid.conf';
	open FH,"<",$conffile or die "Couldn't open $conffile for reading: $!\n";
	chomp(my @confdata = <FH>);
	close FH;
	my $confdata = join("\n", @confdata);
	my ($columns) = $confdata =~ m/columns\s*\=\s*(\d+)/;
	my ($rows) = $confdata =~ m/rows\s*\=\s*(\d+)/;
	my $stbdatabase = $$confdir . 'stbDatabase.db';
	my $seqfile = $filedir . 'commandSequences.txt';
	tie my %stbdata, 'DBM::Deep', {file => $stbdatabase,   locking => 1, autoflush => 1, num_txns => 100};

	##### Load the STB grid
print <<TOP;
<div id="stbGrid">
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

		if ($buttontext =~ /^\s*\:\s*$/) {
print <<BOX;
<td></td>
BOX
		} else {
print <<BOX;
<td><button name="$name" id="$id" class="stbButton deselect" type="button" onClick="colorToggle('$id')">$buttontext</button></td>
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
</tr></table>
<input type="hidden" id="matrixLoaded" />
<input type="hidden" id="totalRows" value="$rows"/></div>
LAST

	##### Load the control buttons
	open FH, '<', $contbtnfile or die "Unable to open $contbtnfile: $!\n";
	my @control = <FH>;
	close FH;
print <<CONTROL;
<div id="controllerSection">
	<div id="controllerTitle">
		<p>Control</p>
	</div>
	@control
</div>
CONTROL
	##### Load the control buttons

	##### Load the sequences buttons
	tie my %sequences, 'Tie::File::AsHash', $seqfile, split => ':' or die "Problem tying \%sequences to $seqfile: $!\n";
	my $seqlist = '';
	foreach my $seq (sort keys %sequences) {
		$seqlist .= "<button id=\"$seq\" class=\"sequenceButton\" onclick=\"stbControl('Event','$seq')\">$seq</button>";
	}


print <<SEQSEC;
<div id="sequenceButtons">
	<div id="sequencesHead" class="masterTooltip" value="Below are your custom built sequences. Go to the Sequences page to make more or edit the current ones">
		<p>Sequences</p>
	</div>
	<div id="sequencesBody">
		$seqlist
	</div>
</div>
SEQSEC


	untie %sequences;
	##### Load the sequences buttons
	
	untie %stbdata;
} ########## End of sub loadGrid ##########
