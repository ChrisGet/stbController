#!/usr/bin/perl -w
use strict;

use CGI;
use DBM::Deep;
use Tie::File::AsHash;

my $query = CGI->new;
print $query->header();

#chomp(my $maindir = `sudo find / -type d -name stbController` || '');
#chomp(my $maindir = (`cat ../files/homeDir.txt` || ''));
chomp(my $maindir = (`cat homeDir.txt` || ''));
die "Couldn't find where my main files are installed. No \"stbController\" directory was found on your system...\n" if (!$maindir);
$maindir =~ s/\/$//;
my $confdir = $maindir . '/config/';
my $filedir = $maindir . '/files/';
my $lastboxfile = $filedir . 'lastBoxes.txt';
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
	print '<div class="userForm"><body>';
	print '<font size="5" color="#E60000">No configuration files found for the STB grid:</font><br>';

print <<FORM;
<form id="createGridConfig" name="createGridConfig">
<font size="5" color="white">Set the following options to create your STB grid</font><br><br>
$fontformat\ Select the number of columns:</font><br>
$columns<br><br>
$fontformat\ Select the number of rows:</font><br>
$rows<br>
<br><br>
</form>
<button type="submit" onclick="validate()">Create New Grid</button><br>
</body>
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

	print '<div class="wrapLeft">';
	##### Load the control buttons
	open FH, '<', '/home/stbController/scripts/pages/controlButtons.html' or die "Unable to open controlButtons.html: $!\n";
	my @control = <FH>;
	close FH;
	print @control;
	##### Load the control buttons

	print '<div id="middleBar">';		# Create the div for the middle bar that sits between the controller and the STB grid

	##### Load the sequences buttons
	tie my %sequences, 'Tie::File::AsHash', $seqfile, split => ':' or die "Problem tying \%sequences to $seqfile: $!\n";
	print '<div id="sequenceButtons"><p style="font-size:25px;margin-top:0em;margin-bottom:0em;" value="Below are your custom built sequences. Go to the Sequences page to make more or edit the current ones" onmouseover="tooltip()" class="masterTooltip">Sequences</p>';

	foreach my $seq (sort keys %sequences) {
print <<BUTTON;
<button id="$seq" class="sequenceButton" onclick="stbControl('Event','$seq')">$seq</button>
BUTTON
	}

	print '<br></div>';
	untie %sequences;
	##### Load the sequences buttons

	print '</div>';				# End of the middleBar div

	##### Load the STB grid
print <<TOP;
<div id="stbGrid">
<table style="border-spacing:0;">     
<tr id="columns">
TOP

my $c = '1';
while ($c <= $columns) {
print <<COL;
<td scope="col" width="80px"><button class="gridButton">Column $c</button></td>
COL
$c++;
}

print <<DESELECT;
<td scope="col" width="60px"><button class="gridButton deselect" onClick="deselect()">Deselect</button></td></tr>
DESELECT

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
			%{$stbdata{$id}} = {};
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
#<td ><button name="$name" id="$id" class="stbButton inactive" type="button"></button></td>
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
</tr></table><input type="hidden" id="matrixLoaded" />
<input type="hidden" id="totalRows" value="$rows"/></div>
LAST

print '</div>';		# End of the "wrapLeft" div

untie %stbdata;
} ########## End of sub loadGrid ##########
