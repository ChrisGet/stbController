#!/usr/bin/perl -w

use strict;
use CGI;
use JSON;

my $query = CGI->new;
print $query->header();

chomp(my $maindir = (`cat homeDir.txt` || ''));
die "Couldn't find where my main files are installed. No \"stbController\" directory was found on your system...\n" if (!$maindir);
$maindir =~ s/\/$//;
my $confdir = $maindir . '/config/';
my $confs = `ls -1 $confdir`;
my $stbdatafile = $confdir . 'stbData.json';
##### Create the JSON object for later use
my $json = JSON->new->allow_nonref;
$json = $json->canonical('1');

chomp(my $option = $query->param('option') || $ARGV[0] || '');
chomp(my $box = $query->param('stb') || $ARGV[1] || '');

stbSelect() if ($option =~ /chooseSTB/i);
stbConfig(\$box) if ($option =~ /configSTB/i);
stbConfig(\$box,\'printDuskyTable') and exit if ($option =~ /printDusky/i);
stbConfig(\$box,\'printBluetoothTable') and exit if ($option =~ /printBluetooth/i);
stbConfig(\$box,\'printNetworkTable') and exit if ($option =~ /printNetwork/i);
stbConfig(\$box,\'printIRTable') and exit if ($option =~ /printIR/i);

sub stbSelect {
	my %stbdata;
	my $conffile = $confdir . 'stbGrid.conf';
	if (!-e $conffile) {
		print '<div class="errorDiv"><h1>No STB Grid configuration found!<br><br>Select "Controller" from the top menu to get setup</h1></div>';
		exit;
	}
	
	if (-e $stbdatafile) {
	        local $/ = undef;
		open my $fh, "<", $stbdatafile or die "ERROR: Unable to open $stbdatafile: $!\n";
		my $data = <$fh>;
		my $decoded = $json->decode($data);
		%stbdata = %{$decoded};
	}
	
	open FH,"<",$conffile or die "Couldn't open $conffile for reading: $!\n";
	chomp(my @confdata = <FH>);
	close FH;
	my $confdata = join("\n", @confdata);
	my ($columns) = $confdata =~ m/columns\s*\=\s*(\d+)/;
	my ($rows) = $confdata =~ m/rows\s*\=\s*(\d+)/;

	my $divwidth = '200';
        my $widcnt = '1';
        until ($widcnt == $columns or $divwidth >= 1400) {
                $divwidth = $divwidth + 110;
                $widcnt++;
        }
        if ($divwidth > 1400) {
                $divwidth = '1450';
        } else {
                $divwidth = $divwidth + 50;
        }

        my $fullcoll = $columns+42;
        my $btnwidth = ($divwidth-$fullcoll)/$columns;
        my $btnstyle = 'width:' . $btnwidth . 'px;';
        $divwidth .= 'px';

print <<HEAD;
<div id="stbSelect">
	<div id="stbDataTextDiv">
		<h1>STB Data Control</h1>
		<h2>Click on a box to manage its control and video switching parameters</h2>
	</div>
	<div id="stbDataGridDiv">
		<div id="stbGridTable" style="width:$divwidth;">
			<div class="stbGridRow">		
HEAD

	my $c = '1';
	while ($c <= $columns) {
print <<COL;
<button class="gridButton inactive" style="$btnstyle">$c</button>
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
		print "<div id=\"Row$r\" class=\"stbGridRow\">";
		while ($c <= $columns) {
			my $id = "STB$stbno";
			my $name = "col$c"."stb$stbno";
			my $buttontext;
			if (!exists $stbdata{$id}) {
				%{$stbdata{$id}} = ();
			}

			if ((exists $stbdata{$id}{'Name'}) and ($stbdata{$id}{'Name'} =~ /\S+/)) {
				$buttontext = $stbdata{$id}{'Name'};
			} else {
				$buttontext = "-";
			}

			my $style = 'style="' . $btnstyle . '"';
print <<BOX;
<button $style name="$name" id="$id" class="stbButton data" onclick="perlCall('dynamicPage','scripts/pages/stbDataPage.pl','option','configSTB','stb','$id')">$buttontext</button>
BOX
	               	$stbno++;
                	$c++;
        	}

print <<ROWEND;
<button id="Row $r" class="gridButton row inactive" type="button">$r</button></div>
ROWEND

		$r++;
	}

print <<LAST;
		</div>
	</div>
</div>
LAST

	print '</div>';
}

sub stbConfig {
	my ($stb,$option) = @_;
	my %stbdata;
	if (-e $stbdatafile) {
        	local $/ = undef;
                open my $fh, "<", $stbdatafile or die "ERROR: Unable to open $stbdatafile: $!\n";
		my $data = <$fh>;
		my $decoded = $json->decode($data);
		%stbdata = %{$decoded};
	}

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

	unless ($option) {
print <<HEAD;
<div id="stbDataDivHolder">
	<div id="stbDataDivHead">
		<p>STB Data &#8594; Edit &#8594; <font color="green">"$titlename"</font></p>
	</div>
	<div id="stbDataDivBody">
		<button class="stbDataBtn submit" onclick="editSTBData('$name')">Submit STB Data</button>
		<button class="stbDataBtn clear" onclick="clearSTBDataForm()">Clear All STB Data</button>
		<form id="editSTBConfigForm" name="editSTBConfigForm">
			<input type="hidden" id="stbname" name="stbname" value="$$stb">
HEAD
	}

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
	my $networkip = $stbdata{$$stb}{'VNCIP'} || '';
	my $btnclr = $stbdata{$$stb}{'ButtonColour'} || '';
	my $btntextclr = $stbdata{$$stb}{'ButtonTextColour'} || '';
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
	my @hdmiins = ('01'..'50');
	my @hdmiouts = ('01','02','Both');

	#### STB Details Table stuff
	my $serialtext = $query->textfield(-id=>'serial',-name=>'Serial',-size=>'15',-default=>"$serial",-maxlength=>11,-class=>'stbDataTextField');
	my $versiontext = $query->textfield(-id=>'version',-name=>'Version',-size=>'15',-default=>"$version",-maxlength=>6,-class=>'stbDataTextField');
	my $cardtext = $query->textfield(-id=>'card',-name=>'CardNo',-size=>'15',-default=>"$card",-maxlength=>9,-class=>'stbDataTextField');
	my $swvtext = $query->textfield(-id=>'software',-name=>'Software',-size=>'15',-default=>"$swv",-class=>'stbDataTextField');
	my $mactext = $query->textfield(-id=>'mac',-name=>'MAC',-size=>'15',-default=>"$mac",-maxlength=>17,-class=>'stbDataTextField');
	#### STB Details Table stuff	

	my $nametext = $query->textfield(-id=>'name',-name=>'Name',-size=>'16',-default=>"$name",-maxlength=>9,-class=>'stbDataTextField');
	my $typechoice = $query->popup_menu(-id=>'type',-name=>'Type',-values=>['Dusky (Sky+)','Bluetooth (SkyQ)','Network (Sky+)','Network (SkyQ)'],-default=>"$type",-onchange=>"stbTypeChoice(this.value)",-class=>'stbDataSelect');
	my $hdmiip1text = $query->textfield(-id=>'hdmiip1',-name=>'HDMIIP1',-size=>'15',-default=>"$hdmiip1",-maxlength=>15,-class=>'stbDataTextField');
	my $hdmiport1text = $query->textfield(-id=>'hdmiport1',-name=>'HDMIPort1',-size=>'10',-default=>"$hdmiport1",-maxlength=>5,-class=>'stbDataTextField');
	my $hdmiinput1text = $query->popup_menu(-id=>'hdmiinput1',-name=>'HDMIInput1',-values=>[@hdmiins],-default=>"$hdmiinput1",-class=>'stbDataSelect');
	my $hdmioutput1text = $query->popup_menu(-id=>'hdmioutput1',-name=>'HDMIOutput1',-values=>[@hdmiouts],-default=>"$hdmioutput1",-class=>'stbDataSelect');

	my $hdmiip2text = $query->textfield(-id=>'hdmiip2',-name=>'HDMIIP2',-size=>'15',-default=>"$hdmiip2",-maxlength=>15,-class=>'stbDataTextField');
	my $hdmiport2text = $query->textfield(-id=>'hdmiport2',-name=>'HDMIPort2',-size=>'10',-default=>"$hdmiport2",-maxlength=>5,-class=>'stbDataTextField');
	my $hdmiinput2text = $query->popup_menu(-id=>'hdmiinput2',-name=>'HDMIInput2',-values=>[@hdmiins],-default=>"$hdmiinput2",-class=>'stbDataSelect');
	my $hdmioutput2text = $query->popup_menu(-id=>'hdmioutput2',-name=>'HDMIOutput2',-values=>[@hdmiouts],-default=>"$hdmioutput2",-class=>'stbDataSelect');

	my $hdmiip3text = $query->textfield(-id=>'hdmiip3',-name=>'HDMIIP3',-size=>'15',-default=>"$hdmiip3",-maxlength=>15,-class=>'stbDataTextField');
	my $hdmiport3text = $query->textfield(-id=>'hdmiport3',-name=>'HDMIPort3',-size=>'10',-default=>"$hdmiport3",-maxlength=>5,-class=>'stbDataTextField');
	my $hdmiinput3text = $query->popup_menu(-id=>'hdmiinput3',-name=>'HDMIInput3',-values=>[@hdmiins],-default=>"$hdmiinput3",-class=>'stbDataSelect');
	my $hdmioutput3text = $query->popup_menu(-id=>'hdmioutput3',-name=>'HDMIOutput3',-values=>[@hdmiouts],-default=>"$hdmioutput3",-class=>'stbDataSelect');

	my $sdiptext = $query->textfield(-id=>'sdip',-name=>'SDIP',-size=>'15',-default=>"$sdip",-maxlength=>15,-class=>'stbDataTextField');
	my $sdporttext = $query->textfield(-id=>'sdport',-name=>'SDPort',-size=>'10',-default=>"$sdport",-maxlength=>5,-class=>'stbDataTextField');
	my $sdinputtext = $query->popup_menu(-id=>'sdinput',-name=>'SDInput',-values=>['01'..'50'],-default=>"$sdinput",-class=>'stbDataSelect');
	my $sdoutputtext = $query->popup_menu(-id=>'sdoutput',-name=>'SDOutput',-values=>['01','02','Both'],-default=>"$sdoutput",-class=>'stbDataSelect');

	my $btnclrtext = $query->textfield(-id=>'buttoncolour',-name=>'ButtonColour',-size=>'10',-default=>"$btnclr",-maxlength=>15,-class=>'stbDataTextField centered');
	my $btntextclrtext = $query->textfield(-id=>'buttontextcolour',-name=>'ButtonTextColour',-size=>'10',-default=>"$btntextclr",-maxlength=>15,-class=>'stbDataTextField centered');


	# If $option is defined, just print the control table it refers to and then exit. This
	# supports the 'stbTypeChoice' function in stbController.js which changes the STB control
	# details table when a user selects a control type for a box on the STB Data page. 
	if ($option) {
		if ($$option =~ /Dusky/i) {
			printDuskyTable($duskymoxaip,$duskymoxaport,$duskyport);
			exit;
		}
		if ($$option =~ /Bluetooth/i) {
			printBluetoothTable($btcontip,$btcontport);
			exit;
		}
		if ($$option =~ /Network/i) {
			printNetworkTable($networkip);
			exit;
		}
		if ($$option =~ /IR/i) {
			printIRTable($irip,$irport,$irout);
			exit;
		}
	}
	# End of $option actions

	print "<div class=\"stbDataWrapRight\">";

print <<DUTTABLE;
<table class="stbDataFormTable DUT">
<th colspan="2" style="font-size:1.8vh;">STB DUT Details</th>
<tr><td style="font-size:1.4vh;">Serial Number:</td><td>$serialtext</td></tr>
<tr><td style="font-size:1.4vh;">Version Number:</td><td>$versiontext</td></tr>
<tr><td style="font-size:1.4vh;">Card Number:</td><td>$cardtext</td></tr>
<tr><td style="font-size:1.4vh;">MAC Address:</td><td>$mactext</td></tr>
<tr><td style="font-size:1.4vh;">Current Software:</td><td>$swvtext</td></tr>
</table>
<div class="stbDataBtnClrDiv">
	<h2>Custom Grid Button Colour</h2>
	<p>You can specify a custom background and text colour for this STB on the control grid. Enter either the colour name, hex code, or RGB code for the colour you want. Take a look <a target="_blank" href="https://www.w3schools.com/colors/colors_picker.asp">HERE</a> to find your colour codes</p>
	<div class="bottomHalf">
		<p>Background:</p>$btnclrtext
		<p>Text:</p>$btntextclrtext
	</div>
</div>
DUTTABLE

print <<DATARIGHT;
<div id="typeChange">
DATARIGHT

	if ($type) {	# If the stb Type is already been selected from previous editing, load that type table
		printDuskyTable($duskymoxaip,$duskymoxaport,$duskyport) if ($type =~ /Dusky/i);
		printBluetoothTable($btcontip,$btcontport) if ($type =~ /Bluetooth/i);
		printNetworkTable($networkip) if ($type =~ /Network/i);
		printIRTable($irip,$irport,$irout) if ($type =~ /IR/i);
	} else {
		printDuskyTable('','','');
	}

	print '</div>';	# End of 'typeChange' div

	print '</div>';	# End of 'wrapRight' div

print <<DATA;
<div class="stbDataWrapLeft">
<table class="stbDataFormTable First">
<tr><td style="font-size:1.7vh;font-weight:normal;">STB Name</td><td style="font-size:1.7vh;font-weight:normal;text-align:right;">STB Control Type</td></tr>
<tr><td>$nametext</td><td style="text-align:right;">$typechoice</td></tr>
</table>
<table class="stbDataFormTable">
<th colspan="4"><b>HDMI Switch 1</b></th>
<tr style="font-size:1.4vh;"><td align="center">IP</td><td align="center">Control Port</td><td align="center">Input</td><td align="center">Output</td></tr>
<tr><td>$hdmiip1text</td><td>$hdmiport1text</td><td>$hdmiinput1text</td><td>$hdmioutput1text</td></tr>
</table>
<table class="stbDataFormTable">
<th colspan="4"><b>HDMI Switch 2</b></th>
<tr style="font-size:1.4vh;"><td align="center">IP</td><td align="center">Control Port</td><td align="center">Input</td><td align="center">Output</td></tr>
<tr><td>$hdmiip2text</td><td>$hdmiport2text</td><td>$hdmiinput2text</td><td>$hdmioutput2text</td></tr>
</table>
<table class="stbDataFormTable">
<th colspan="4"><b>HDMI Switch 3</b></th>
<tr style="font-size:1.4vh;"><td align="center">IP</td><td align="center">Control Port</td><td align="center">Input</td><td align="center">Output</td></tr>
<tr><td>$hdmiip3text</td><td>$hdmiport3text</td><td>$hdmiinput3text</td><td>$hdmioutput3text</td></tr>
</table>
<table class="stbDataFormTable">
<th colspan="4"><b>SD Video Switch</b></th>
<tr style="font-size:1.4vh;"><td align="center">IP</td><td align="center">Control Port</td><td align="center">Input</td><td align="center">Output</td></tr>
<tr><td>$sdiptext</td><td>$sdporttext</td><td>$sdinputtext</td><td>$sdoutputtext</td></tr>
</table>
DATA

print <<LASTBIT;
			</div>
		</form>
	</div>
</div>
LASTBIT
}

sub printDuskyTable {
	my ($duskymoxaip,$duskymoxaport,$duskyport) = @_;
	my $duskymoxaiptext = $query->textfield(-id=>'duskymoxaip',-name=>'MoxaIP',-size=>'15',-default=>$duskymoxaip,-maxlength=>15,-class=>'stbDataTextField right');
	my $duskymoxaporttext = $query->textfield(-id=>'duskymoxaport',-name=>'MoxaPort',-size=>'15',-default=>$duskymoxaport,-maxlength=>5,-class=>'stbDataTextField right');
	my $duskyporttext = $query->popup_menu(-id=>'duskyport',-name=>'DuskyPort',-values=>['01'..'15'],-default=>$duskyport,-class=>'stbDataSelect');

print <<DUSKY;
<p class="narrow" style="font-size:1.8vh;">Dusky Control</p>
<table class="stbDataFormTable ctrltype">
<tr><td>Dusky Moxa IP:</td><td>$duskymoxaiptext</td></tr>
<tr><td>Dusky Moxa Port:</td><td>$duskymoxaporttext</td></tr>
<tr><td>Dusky Port:</td><td>$duskyporttext</td></tr>
</table>
DUSKY
}

sub printBluetoothTable {
	my ($btcontip,$btcontport) = @_;
	my $btcontiptext = $query->textfield(-id=>'btcontip',-name=>'BTContIP',-size=>'15',-default=>$btcontip,-maxlength=>15,-class=>'stbDataTextField right');
	my $btcontporttext = $query->popup_menu(-id=>'btcontport',-name=>'BTContPort',-values=>['01'..'16'],-default=>$btcontport,-class=>'stbDataSelect');

print <<BLUETOOTH;
<p class="narrow" style="font-size:1.8vh;">Bluetooth Control</p>
<table class="stbDataFormTable ctrltype">
<tr><td>BT Server IP:</td><td>$btcontiptext</td></tr>
<tr><td>BT Server USB Port:</td><td>$btcontporttext</td></tr>
</table>
BLUETOOTH
}

sub printNetworkTable {
	my ($ip) = @_;
	my $iptext = $query->textfield(-id=>'netip',-name=>'VNCIP',-size=>'15',-default=>$ip,-maxlength=>15,-class=>'stbDataTextField');

print <<NETWORK;
<p class="narrow" style="font-size:1.8vh;">Network Control</p>
<table class="stbDataFormTable ctrltype">
<tr><td style="text-align:right;font-size:1.4vh;">STB IP Address:</td><td style="float:right;">$iptext</td></tr>
</table>
<div id="stbDataNoteDiv">
	<p>For network control to work, the computer hosting this control system needs to have access to the STBs network</p>
</div>
NETWORK
}

sub printIRTable {
	my ($irip,$irport,$irout) = @_;
	my $iriptext = $query->textfield(-id=>'irip',-name=>'IRIP',-size=>'15',-default=>$irip,-maxlength=>15,-class=>'stbDataTextField');
	my $irporttext = $query->textfield(-id=>'irport',-name=>'IRPort',-size=>'15',-default=>$irport,-class=>'stbDataTextField');
	my $irouttext = $query->popup_menu(-id=>'irout',-name=>'IROutput',-values=>['01'..'05'],-default=>$irout,-class=>'stbDataSelect');
print <<IR;
<p class="narrow" style="font-size:1.8vh;">IR Control</p>
<table class="stbDataFormTable ctrltype">
<tr><td>IR Blaster IP:</td><td>$iriptext</td></tr>
<tr><td>IR Blaster Port:</td><td>$irporttext</td></tr>
<tr><td>IR Blaster Output:</td><td>$irouttext</td></tr>
</table>
IR
}
