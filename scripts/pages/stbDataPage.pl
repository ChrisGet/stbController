#!/usr/bin/perl -w
use strict;

use CGI;
use DBM::Deep;

my $query = CGI->new;
print $query->header();

chomp(my $maindir = (`cat homeDir.txt` || ''));
die "Couldn't find where my main files are installed. No \"stbController\" directory was found on your system...\n" if (!$maindir);
$maindir =~ s/\/$//;
my $confdir = $maindir . '/config/';
my $confs = `ls -1 $confdir`;

chomp(my $option = $query->param('option') || $ARGV[0] || '');
chomp(my $box = $query->param('stb') || $ARGV[1] || '');

stbSelect() if ($option =~ /chooseSTB/i);
stbConfig(\$box) if ($option =~ /configSTB/i);
printDuskyTable() and exit if ($option =~ /printDusky/i);
printBluetoothTable() and exit if ($option =~ /printBluetooth/i);
printIRTable() and exit if ($option =~ /printIR/i);

sub stbSelect {
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
<p class="narrow">Click on a box below to manage its control, video, and DUT details configuration</p><br>
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

print <<BOX;
<td><button name="$name" id="$id" class="stbButton data" type="button" onClick="perlCall('dynamicPage','scripts/pages/stbDataPage.pl','option','configSTB','stb','$id')">$buttontext</button></td>
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
	} else {
		print "<font size=\"5\" color=\"red\">No STB Database found. Have you setup your STB Controller Grid yet?<\/font>";
	}
}

sub stbConfig {
	my ($stb) = @_;
	my $dbfile = $confdir . 'stbDatabase.db';
	tie my %stbdata, 'DBM::Deep', {file => $dbfile,   locking => 1, autoflush => 1, num_txns => 100};

	my ($num) = $$stb =~ /STB(\d+)/i;
	my $name;
	my $titlename;
	if ((exists $stbdata{$$stb}{'Name'}) and ($stbdata{$$stb}{'Name'} =~ /\S+/)) {
		$name = $stbdata{$$stb}{'Name'};
		$titlename = $stbdata{$$stb}{'Name'};
	} else {
		$name = '';
		$titlename = 'Unconfigured STB';
	}

print <<HEAD;
<div class="wrapLeft shaded">
<form id="editSTBConfigForm" name="editSTBConfigForm">
<h2 class="narrow">Below are the configuration options for "<font color="#009933">$titlename</font>", as well as its DUT details.<br>
Any existing settings will be populated automatically.</h2>
<p class="narrow" style="color:white;font-size:18px;">Enter values in the corresponding fields and hit "Submit" to update the STBs config.</p><br>
<input type="hidden" id="stbname" name="stbname" value="$$stb">
HEAD

	##### STB Control and Video Data
	my $type = $stbdata{$$stb}{'Type'} || '';
	my $hdmiip1 = $stbdata{$$stb}{'HDMIIP1'} || '';
	my $hdmiport1 = $stbdata{$$stb}{'HDMIPort1'} || '';
	my $hdmiinput1 = $stbdata{$$stb}{'HDMIInput1'} || '';
	my $hdmioutput1 = $stbdata{$$stb}{'HDMIOutput1'} || '';
	my $hdmiip2 = $stbdata{$$stb}{'HDMIIP2'} || '';
	my $hdmiport2 = $stbdata{$$stb}{'HDMIPort2'} || '';
	my $hdmiinput2 = $stbdata{$$stb}{'HDMIInput2'} || '';
	my $hdmioutput2 = $stbdata{$$stb}{'HDMIOutput2'} || '';
	my $hdmiip3 = $stbdata{$$stb}{'HDMIIP3'} || '';
	my $hdmiport3 = $stbdata{$$stb}{'HDMIPort3'} || '';
	my $hdmiinput3 = $stbdata{$$stb}{'HDMIInput3'} || '';
	my $hdmioutput3 = $stbdata{$$stb}{'HDMIOutput3'} || '';
	my $sdip = $stbdata{$$stb}{'SDIP'} || '';
	my $sdport = $stbdata{$$stb}{'SDPort'} || '';
	my $sdinput = $stbdata{$$stb}{'SDInput'} || '';
	my $sdoutput = $stbdata{$$stb}{'SDOutput'} || '';
	my $duskymoxaip = $stbdata{$$stb}{'MoxaIP'} || '';
	my $duskymoxaport = $stbdata{$$stb}{'MoxaPort'} || '';
	my $duskyport = $stbdata{$$stb}{'DuskyPort'} || '';
	my $btcontip = $stbdata{$$stb}{'BTContIP'} || '';
	my $btcontport = $stbdata{$$stb}{'BTContPort'} || '';
	my $irip = $stbdata{$$stb}{'IRIP'} || '';
	my $irport = $stbdata{$$stb}{'IRPort'} || '';
	my $irout = $stbdata{$$stb}{'IROutput'} || '';
	##### STB Control and Video Data

	##### STB Information Data
	my $serial = $stbdata{$$stb}{'Serial'} || '';
	my $version = $stbdata{$$stb}{'Version'} || '';
	my $card = $stbdata{$$stb}{'CardNo'} || '';
	my $swv = $stbdata{$$stb}{'Software'} || '';
	my $mac = $stbdata{$$stb}{'MAC'} || '';
	##### STB Information Data

	my $font = '<font size="3" color="black">';
	my $fonthead = '<font size="3" color="#267A94">';
	my $font2 = '<font size="2" color="black">';
	
	my $fontend = '</font>';
	my @hdmiins = ('01'..'16');
	my @hdmiouts = ('01','02','Both');

	#### STB Details Table stuff
	my $serialtext = $query->textfield(-id=>'serial',-name=>'Serial',-size=>'15',-default=>"$serial",-maxlength=>11);
	my $versiontext = $query->textfield(-id=>'version',-name=>'Version',-size=>'15',-default=>"$version",-maxlength=>6);
	my $cardtext = $query->textfield(-id=>'card',-name=>'CardNo',-size=>'15',-default=>"$card",-maxlength=>9);
	my $swvtext = $query->textfield(-id=>'software',-name=>'Software',-size=>'15',-default=>"$swv");
	my $mactext = $query->textfield(-id=>'mac',-name=>'MAC',-size=>'15',-default=>"$mac",-maxlength=>17);
	#### STB Details Table stuff	

	my $nametext = $query->textfield(-id=>'name',-name=>'Name',-size=>'15',-default=>"$name",-maxlength=>6);
	my $typechoice = $query->popup_menu(-id=>'type',-name=>'Type',-values=>['Dusky (Sky+)','Bluetooth (Ethan)','IR (Any)'],-default=>"$type",-onchange=>"stbTypeChoice(this.value)");
	my $hdmiip1text = $query->textfield(-id=>'hdmiip1',-name=>'HDMIIP1',-size=>'15',-default=>"$hdmiip1",-maxlength=>15);
	my $hdmiport1text = $query->textfield(-id=>'hdmiport1',-name=>'HDMIPort1',-size=>'10',-default=>"$hdmiport1",-maxlength=>5);
	my $hdmiinput1text = $query->popup_menu(-id=>'hdmiinput1',-name=>'HDMIInput1',-values=>[@hdmiins],-default=>"$hdmiinput1");
	my $hdmioutput1text = $query->popup_menu(-id=>'hdmioutput1',-name=>'HDMIOutput1',-values=>[@hdmiouts],-default=>"$hdmioutput1");

	my $hdmiip2text = $query->textfield(-id=>'hdmiip2',-name=>'HDMIIP2',-size=>'15',-default=>"$hdmiip2",-maxlength=>15);
	my $hdmiport2text = $query->textfield(-id=>'hdmiport2',-name=>'HDMIPort2',-size=>'10',-default=>"$hdmiport2",-maxlength=>5);
	my $hdmiinput2text = $query->popup_menu(-id=>'hdmiinput2',-name=>'HDMIInput2',-values=>[@hdmiins],-default=>"$hdmiinput2");
	my $hdmioutput2text = $query->popup_menu(-id=>'hdmioutput2',-name=>'HDMIOutput2',-values=>[@hdmiouts],-default=>"$hdmioutput2");

	my $hdmiip3text = $query->textfield(-id=>'hdmiip3',-name=>'HDMIIP3',-size=>'15',-default=>"$hdmiip3",-maxlength=>15);
	my $hdmiport3text = $query->textfield(-id=>'hdmiport3',-name=>'HDMIPort3',-size=>'10',-default=>"$hdmiport3",-maxlength=>5);
	my $hdmiinput3text = $query->popup_menu(-id=>'hdmiinput3',-name=>'HDMIInput3',-values=>[@hdmiins],-default=>"$hdmiinput3");
	my $hdmioutput3text = $query->popup_menu(-id=>'hdmioutput3',-name=>'HDMIOutput3',-values=>[@hdmiouts],-default=>"$hdmioutput3");

	my $sdiptext = $query->textfield(-id=>'sdip',-name=>'SDIP',-size=>'15',-default=>"$sdip",-maxlength=>15);
	my $sdporttext = $query->textfield(-id=>'sdport',-name=>'SDPort',-size=>'10',-default=>"$sdport",-maxlength=>5);
	my $sdinputtext = $query->popup_menu(-id=>'sdinput',-name=>'SDInput',-values=>['01'..'12'],-default=>"$sdinput");
	my $sdoutputtext = $query->popup_menu(-id=>'sdoutput',-name=>'SDOutput',-values=>['01','02','Both'],-default=>"$sdoutput");

	print "<div class=\"wrapRight\">";

print <<DUTTABLE;
<table class="stbDataFormTable DUT">
<th colspan="2">$font STB DUT Details$fontend</th>
<tr><td>$font Serial Number:$fontend</td><td>$serialtext</td></tr>
<tr><td>$font Version Number:$fontend</td><td>$versiontext</td></tr>
<tr><td>$font Card Number:$fontend</td><td>$cardtext</td></tr>
<tr><td>$font MAC Address:$fontend</td><td>$mactext</td></tr>
<tr><td>$font Current Software:$fontend</td><td>$swvtext</td></tr>
</table>
DUTTABLE

print <<DATARIGHT;
<div id="typeChange">
DATARIGHT

	if ($type) {	# If the stb Type is already been selected from previous editing, load that type table
		printDuskyTable($duskymoxaip,$duskymoxaport,$duskyport) if ($type =~ /Dusky/i);
		printBluetoothTable($btcontip,$btcontport) if ($type =~ /Bluetooth/i);
		printIRTable($irip,$irport,$irout) if ($type =~ /IR/i);
	} else {
		printDuskyTable('','','');
	}

	print '</div>';	# End of 'typeChange' div

	print '</div>';	# End of 'wrapRight' div

print <<DATA;
<div class="wrapLeft">
<table class="stbDataFormTable First">
<tr><td>STB Name:</td><td>STB Control Type:</td></tr>
<tr><td>$nametext</td><td>$typechoice</td></tr>
</table><br>
<table class="stbDataFormTable">
<th colspan="4">HDMI Switch 1:</th>
<tr><td align="center">$font2 IP</td><td align="center">$font2 Control Port</td><td align="center">$font2 Input</td><td align="center">$font2 Output</td></tr>
<tr><td>$hdmiip1text</td><td>$hdmiport1text</td><td>$hdmiinput1text</td><td>$hdmioutput1text</td></tr>
</table>
<table class="stbDataFormTable">
<th colspan="4"><b>$font HDMI Switch 2:$fontend</b></th>
<tr><td align="center">$font2 IP</td><td align="center">$font2 Control Port</td><td align="center">$font2 Input</td><td align="center">$font2 Output</td></tr>
<tr><td>$hdmiip2text</td><td>$hdmiport2text</td><td>$hdmiinput2text</td><td>$hdmioutput2text</td></tr>
</table>
<table class="stbDataFormTable">
<th colspan="4"><b>$font HDMI Switch 3:$fontend</b></th>
<tr><td align="center">$font2 IP</td><td align="center">$font2 Control Port</td><td align="center">$font2 Input</td><td align="center">$font2 Output</td></tr>
<tr><td>$hdmiip3text</td><td>$hdmiport3text</td><td>$hdmiinput3text</td><td>$hdmioutput3text</td></tr>
</table>
<br>
<table class="stbDataFormTable">
<th colspan="4"><b>$font SD Video Switch:$fontend</b></th>
<tr><td align="center">$font2 IP</td><td align="center">$font2 Control Port</td><td align="center">$font2 Input</td><td align="center">$font2 Output</td></tr>
<tr><td>$sdiptext</td><td>$sdporttext</td><td>$sdinputtext</td><td>$sdoutputtext</td></tr>
</table><br>
DATA

print <<LASTBIT;
<button class="menuButton" style="margin-bottom:8px;" type="button" onclick="editSTBData('$name')">Submit STB Data</button>
</div>
</form>
</div>
LASTBIT
}

sub printDuskyTable {
	my ($duskymoxaip,$duskymoxaport,$duskyport) = @_;
	my $duskymoxaiptext = $query->textfield(-id=>'duskymoxaip',-name=>'MoxaIP',-size=>'15',-default=>$duskymoxaip,-maxlength=>15);
	my $duskymoxaporttext = $query->textfield(-id=>'duskymoxaport',-name=>'MoxaPort',-size=>'15',-default=>$duskymoxaport,-maxlength=>5);
	my $duskyporttext = $query->popup_menu(-id=>'duskyport',-name=>'DuskyPort',-values=>['01'..'15'],-default=>$duskyport);

print <<DUSKY;
<p class="narrow" style="font-size:20px;">Dusky Control:</p>
<table class="stbDataFormTable">
<tr><td>Dusky Moxa IP:</td><td>$duskymoxaiptext</td></tr>
<tr><td>Dusky Moxa Port:</td><td>$duskymoxaporttext</td></tr>
<tr><td>Dusky Port:</td><td>$duskyporttext</td></tr>
</table><br>
DUSKY
}

sub printBluetoothTable {
	my ($btcontip,$btcontport) = @_;
	my $btcontiptext = $query->textfield(-id=>'btcontip',-name=>'BTContIP',-size=>'15',-default=>$btcontip,-maxlength=>15);
	my $btcontporttext = $query->popup_menu(-id=>'btcontport',-name=>'BTContPort',-values=>['01'..'16'],-default=>$btcontport);

print <<BLUETOOTH;
<p class="narrow" style="font-size:20px;">Bluetooth Control:</p>
<table class="stbDataFormTable">
<tr><td>BT Server IP:</td><td>$btcontiptext</td></tr>
<tr><td>BT Server USB Port:</td><td>$btcontporttext</td></tr>
</table><br>
BLUETOOTH
}

sub printIRTable {
	my ($irip,$irport,$irout) = @_;
	my $iriptext = $query->textfield(-id=>'irip',-name=>'IRIP',-size=>'15',-default=>$irip,-maxlength=>15);
	my $irporttext = $query->textfield(-id=>'irport',-name=>'IRPort',-size=>'15',-default=>$irport);
	my $irouttext = $query->popup_menu(-id=>'irout',-name=>'IROutput',-values=>['01'..'05'],-default=>$irout);
print <<IR;
<p class="narrow" style="font-size:20px;">IR Control:</p>
<table class="stbDataFormTable">
<tr><td>IR Blaster IP:</td><td>$iriptext</td></tr>
<tr><td>IR Blaster Port:</td><td>$irporttext</td></tr>
<tr><td>IR Blaster Output:</td><td>$irouttext</td></tr>
</table><br>
IR
}
