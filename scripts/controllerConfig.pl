#!/usr/bin/perl -w
use strict;

use CGI;
use DBM::Deep;

my $query = CGI->new;
print $query->header();

chomp(my $maindir = (`cat ../files/homeDir.txt` || ''));
die "Couldn't find where my main files are installed. No \"stbController\" directory was found on your system...\n" if (!$maindir);
$maindir =~ s/\/$//;
my $confdir = $maindir . '/config/';
my $confs = `ls -1 $confdir`;

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
<button type="button" onclick="validate()">Create New Grid</button><br>
</body>
</div>
FORM
} ########## End of sub createConf ##########

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
	tie my %stbdata, 'DBM::Deep', {file => $stbdatabase,   locking => 1, autoflush => 1, num_txns => 100};

print <<TOP;
<div id="stbMatrix">
<table>     
<tr id="columns">
TOP

	my $c = '1';
	while ($c <= $columns) {
print <<COL;
<td scope="col"><button id="columnButton" type="button">Column $c</button></td>
COL
		$c++;
	}

print <<DESELECT;
<td scope="col"><button id="deselectButton" type="button" onClick="deselect()">Deselect</button></td></tr>
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

			if (exists $stbdata{$id}{'Name'}) {
				$buttontext = $stbdata{$id}{'Name'};
			} else {
				$buttontext = "STB $stbno";
			}

print <<BOX;
<td ><button name="$name" id="$id" type="button" style="width:100%;" onClick="colorToggle('$id')" class="deselect">$buttontext</button></td>
BOX
			$stbno++;
			$c++;
		}

print <<ROWEND;
<th><button id="rowButton" type="button" onClick="rows('Row$r')">Row $r</button></th></tr>
ROWEND

		$r++;

	}

	print '</tr></table></div>';

print <<CONTROL;
<div id="controlButtons">
</div>
CONTROL

	untie %stbdata;

} ########## End of sub loadGrid ##########
