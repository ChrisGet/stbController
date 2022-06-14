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
my $fullsizefile = $confdir . 'gridFullSize.conf';

##### Get the grid size option
my $fullsize = 'off';
if (open my $fsfh, '<', $fullsizefile) {
        local $/;
        my $fs = <$fsfh>;
        if ($fs and $fs =~ /on/i) {
                $fullsize = 'on';
        }
}

##### Create the JSON object for later use
my $json = JSON->new->allow_nonref;
$json = $json->canonical('1');

chomp(my $option = $query->param('option') || $ARGV[0] || '');
chomp(my $box = $query->param('stb') || $ARGV[1] || '');

stbSelect() if ($option =~ /chooseSTB/i);
stbConfig(\$box) if ($option =~ /configSTB/i);
stbConfig(\$box,\'printDuskyTable') and exit if ($option =~ /printDusky/i);
stbConfig(\$box,\'printBluetoothTable') and exit if ($option =~ /printBluetooth/i);
stbConfig(\$box,\'printNowTVNetworkTable') and exit if ($option =~ /printNetwork/i and $option =~ /NowTV/i);
stbConfig(\$box,\'printNetworkTable') and exit if ($option =~ /printNetwork/i);
stbConfig(\$box,\'printIRNetBoxIVNowTV') and exit if ($option =~ /printInfraRed IRNetBoxIV/i and $option =~ /NowTV/i);
#stbConfig(\$box,\'printIRNetBoxIVQSoip') and exit if ($option =~ /printInfraRed IRNetBoxIV/i and $option =~ /QSoip/i);
stbConfig(\$box,\'printIRNetBoxIV') and exit if ($option =~ /printInfraRed IRNetBoxIV/i);
stbConfig(\$box,\'printGlobalCacheIRNowTV') and exit if ($option =~ /printInfraRed GlobalCache/i and $option =~ /NowTV/i);
stbConfig(\$box,\'printGlobalCacheIR') and exit if ($option =~ /printInfraRed GlobalCache/i and $option =~ /SkyQ/i);

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
		if ($data) {
			my $decoded = $json->decode($data);
			%stbdata = %{$decoded};
		}
	}
	
	open FH,"<",$conffile or die "Couldn't open $conffile for reading: $!\n";
	chomp(my @confdata = <FH>);
	close FH;
	if (!@confdata) {
		print '<div class="errorDiv"><h1>No STB Grid configuration found!<br><br>Select "Controller" from the top menu to get setup</h1></div>';
		exit;
	}
	
	my $confdata = join("\n", @confdata);
	my ($columns) = $confdata =~ m/columns\s*\=\s*(\d+)/;
	my ($rows) = $confdata =~ m/rows\s*\=\s*(\d+)/;

	if (!$columns or !$rows) {
		print '<div class="errorDiv"><h1>No valid STB Grid configuration found!<br><br>Select "Controller" from the top menu to get setup</h1></div>';
		exit;
	}

	my $divwidth = '200';
	my $fullcoll = $columns+42;
        my $btnwidth = 98/$columns;
        my $grstyle = '';
        my $btnstyle = '';
        my $gridstylemanual = '';
        if ($fullsize eq 'on') {
                if ($btnwidth > 49) {
                        $btnwidth = 50;
                } elsif ($btnwidth > 48) {
                        $btnwidth = 40;
                }
                $btnstyle = 'width:' . $btnwidth . '%;';
                if ($columns > 25) {
                        $btnstyle .= 'font-size:1.1vh;';
                }
                $divwidth = '100%';

                my $grheight = 90/$rows;
                if ($grheight > 18) {
                        $grheight = 20;
                }
                $grstyle = 'height:' . $grheight . '%;';
        } else {
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
                $btnstyle = 'width:' . $btnwidth . 'px;';
                $divwidth .= 'px';
                $gridstylemanual = 'style="width:auto;"';
        }

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
		print "<div id=\"Row$r\" class=\"stbGridRow\" style=\"$grstyle\">";
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
		if ($data) {
			my $decoded = $json->decode($data);
			%stbdata = %{$decoded};
		}
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

	##### STB Control Data
	my $type = $stbdata{$$stb}{'Type'} || '';

	my $duskymoxaip = $stbdata{$$stb}{'MoxaIP'} || '';
	my $duskymoxaport = $stbdata{$$stb}{'MoxaPort'} || '';
	my $duskyport = $stbdata{$$stb}{'DuskyPort'} || '';
	my $btcontip = $stbdata{$$stb}{'BTContIP'} || '';
	my $btcontport = $stbdata{$$stb}{'BTContPort'} || '';
	my $irnb4ip = $stbdata{$$stb}{'IRNetBoxIVIP'} || '';
	my $irnb4out = $stbdata{$$stb}{'IRNetBoxIVOutput'} || '';
	my $nowtvmodel = $stbdata{$$stb}{'IRNetBoxIVNowTVModel'} || '';
	my $networkip = $stbdata{$$stb}{'VNCIP'} || '';
	my $nowtvip = $stbdata{$$stb}{'NOWTVIP'} || '';
	my $gcirip = $stbdata{$$stb}{'GlobalCacheIP'} || '';
	my $gcirport = $stbdata{$$stb}{'GlobalCachePort'} || '';
	my $btnclr = $stbdata{$$stb}{'ButtonColour'} || '';
	my $btntextclr = $stbdata{$$stb}{'ButtonTextColour'} || '';
	##### STB Control Data

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

	my $nametext = $query->textfield(-id=>'name',-name=>'Name',-size=>'16',-default=>"$name",-maxlength=>9,-class=>'stbDataTextField new');
	my @controltypes = (	'Bluetooth (SkyQ)',
				'Network (SkyQ)',
				'InfraRed IRNetBoxIV (SkyQ)',
				'Network (QSoIP)',
				'InfraRed IRNetBoxIV (QSoIP UK)',
				'InfraRed IRNetBoxIV (QSoIP DE/IT)',
				'Dusky (Sky+)',
				'Network (Sky+)',
				'InfraRed IRNetBoxIV (NowTV)',
				'Network (NowTV)',
				'InfraRed GlobalCache (NowTV)',
				'InfraRed GlobalCache (SkyQ)'
				);

	my $typechoice = $query->popup_menu(-id=>'type',-name=>'Type',-values=>[@controltypes],-default=>"$type",-onchange=>"stbTypeChoice(this.value)",-class=>'stbDataSelect new');

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
			if ($$option =~ /NowTV/i) {
				printNowTVNetworkTable($nowtvip);
				exit;
			}
			printNetworkTable($networkip);
			exit;
		}
		if ($$option =~ /IRNetBoxIV/i) {
			if ($$option =~ /NowTV/i) {
				printIRNetBoxIVNowTV($irnb4ip,$irnb4out,$nowtvmodel);
				exit;
			}
			printIRNetBoxIV($irnb4ip,$irnb4out);
			exit;
		}
		if ($$option =~ /GlobalCache/i) {
			if ($$option =~ /NowTV/i) {
				printGlobalCacheIRNowTV($gcirip,$gcirport);#,$nowtvmodel);
				exit;
			}
			printGlobalCacheIR($gcirip,$gcirport);
			exit;
		}
	}
	# End of $option actions

	print "<div class=\"stbDataWrapRight\">";

print <<DUTTABLE;
<table class="stbDataFormTable DUT">
<th colspan="2" style="font-size:1.8vh;">STB Details</th>
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

	print '</div>';	# End of 'wrapRight' div

print <<DATA;
<div class="stbDataWrapLeft">
	<div class="stbDataInfoSectionHead">
		<div class="stbDataHeadTitle">
			<p>STB Name</p>
		</div>
		<div class="stbDataHeadDesc">
			<p>Give your STB a name to identify it on the grid</p>
		</div>
	</div>
	<div class="stbDataInfoSection name">
		$nametext
	</div>

	<div class="stbDataInfoSectionHead">
		<div class="stbDataHeadTitle">
			<p>Control</p>
		</div>
		<div class="stbDataHeadDesc">
			<p>Select which type of control method will be used for this STB</p>
		</div>
	</div>
	<div class="stbDataInfoSection control">
		<div class="stbDataControlSelectSection">
			$typechoice
		</div>
		<div id="typeChange">
	
DATA

	if ($type) {	# If the stb Type is already been selected from previous editing, load that type table
		printDuskyTable($duskymoxaip,$duskymoxaport,$duskyport) if ($type =~ /Dusky/i);
		printBluetoothTable($btcontip,$btcontport) if ($type =~ /Bluetooth/i);
		printNetworkTable($networkip) if ($type =~ /Network \(Sky|Network \(Q/i);
		printIRNetBoxIV($irnb4ip,$irnb4out) if ($type =~ /InfraRed IRNetBoxIV \(Sky/i or $type =~ /InfraRed IRNetBoxIV \(QSoIP/i);
		printIRNetBoxIVNowTV($irnb4ip,$irnb4out,$nowtvmodel) if ($type =~ /InfraRed IRNetBoxIV \(NowTV\)/i);
		printNowTVNetworkTable($nowtvip) if ($type =~ /Network \(NowTV\)/i);
		printGlobalCacheIRNowTV($gcirip,$gcirport) if ($type =~ /InfraRed GlobalCache \(NowTV\)/);
		printGlobalCacheIR($gcirip,$gcirport) if ($type =~ /InfraRed GlobalCache \(SkyQ\)/);
	} else {
		printBluetoothTable('','');
	}




print <<DATA2;

		</div>
	</div>
	<div class="stbDataInfoSectionHead">
		<div class="stbDataHeadTitle">
			<p>Video</p>
		</div>
		<div class="stbDataHeadDesc">
			<p>Configure up to 3 video switches for viewing this STB</p>
		</div>
	</div>
	<div class="stbDataInfoSection video">
		<div id="stbDataVideoInfoHolder">
			<h1>Video Info:</h1>
			<h2>WyreStorm and BluStream:</h2>
			<p>Control for both of these hardware types is done over Telnet. The default port for this is 23.</p>
		</div>



DATA2

	##### List of the available video switch types stored in @videotypes
	my @videotypes = (	'Kramer',
				'WyreStorm',
				'BluStream'
				);

	##### Foreach loop to print each of the 3 video switch details
	foreach my $vid (1..3) {
		my $hdmitype = $stbdata{$$stb}{"HDMIType$vid"} // '';
		my $hdmiip = $stbdata{$$stb}{"HDMIIP$vid"} // '';
		my $hdmiport = $stbdata{$$stb}{"HDMIPort$vid"} // '';
		my $hdmiinput = $stbdata{$$stb}{"HDMIInput$vid"} // '';
		my $hdmioutput = $stbdata{$$stb}{"HDMIOutput$vid"} // '';

		my $hdmitypetext = $query->popup_menu(-id=>"hdmitype$vid",-name=>"HDMIType$vid",-values=>[@videotypes],-default=>"$hdmitype",-class=>'stbDataSelect');
		my $hdmiiptext = $query->textfield(-id=>"hdmiip$vid",-name=>"HDMIIP$vid",-size=>'15',-default=>"$hdmiip",-maxlength=>15,-class=>'stbDataTextField');
		my $hdmiporttext = $query->textfield(-id=>"hdmiport$vid",-name=>"HDMIPort$vid",-size=>'10',-default=>"$hdmiport",-maxlength=>5,-class=>'stbDataTextField');
		my $hdmiinputtext = $query->popup_menu(-id=>"hdmiinput$vid",-name=>"HDMIInput$vid",-values=>[@hdmiins],-default=>"$hdmiinput",-class=>'stbDataSelect');
		my $hdmioutputtext = $query->popup_menu(-id=>"hdmioutput$vid",-name=>"HDMIOutput$vid",-values=>[@hdmiouts],-default=>"$hdmioutput",-class=>'stbDataSelect');

print <<HDMI;
		<div class=stbDataVideoSection>
			<button class="clearSTBVideoDataBtn" onclick="clearSTBVideoData('$vid')" title="Clear this video switch data" type="button"></button>
			<div class="videoHorizontalHalf">
				<div class="videoVerticalHalf">
					<div class="videoHorizontalHalf">
						<p class="videoDataTitle">Make/Model</p>
					</div>
					<div class="videoHorizontalHalf">
						$hdmitypetext
					</div>
				</div>
				<div class="videoVerticalHalf">
					<div class="videoHorizontalHalf">
						<p class="videoDataTitle">IP Address</p>
					</div>
					<div class="videoHorizontalHalf">
						$hdmiiptext
					</div>				
				</div>
			</div>
			<div class="videoHorizontalHalf">
				<div class="videoVerticalThird">
					<div class="videoHorizontalHalf">
						<p class="videoDataTitle">Port</p>
					</div>
					<div class="videoHorizontalHalf">
						$hdmiporttext
					</div>
				</div>
				<div class="videoVerticalThird">
					<div class="videoHorizontalHalf">
						<p class="videoDataTitle">Input</p>
					</div>
					<div class="videoHorizontalHalf">
						$hdmiinputtext
					</div>
				</div>
				<div class="videoVerticalThird">
					<div class="videoHorizontalHalf">
						<p class="videoDataTitle">Output</p>
					</div>
					<div class="videoHorizontalHalf">
						$hdmioutputtext
					</div>
				</div>
			</div>
		</div>
HDMI
	}

	print '</div>';


#<table class="stbDataFormTable First">
#<tr><td style="font-size:1.7vh;font-weight:normal;">STB Name</td><td style="font-size:1.7vh;font-weight:normal;text-align:right;">STB Control Type</td></tr>
#<tr><td>$nametext</td><td style="text-align:right;">$typechoice</td></tr>
#</table>
#<div class="stbDataHeadDiv">
#	<p>Video Switch Settings</p>
#</div>
#<table class="stbDataFormTable">
#<th colspan="4"><b>Video Switch 1</b></th>
#<tr style="font-size:1.4vh;"><td align="center">Type</td><td align="center">IP</td><td align="center">Control Port</td><td align="center">Input</td><td align="center">Output</td></tr>
#<tr><td></td><td>$hdmiip1text</td><td>$hdmiport1text</td><td>$hdmiinput1text</td><td>$hdmioutput1text</td></tr>
#</table>
#<table class="stbDataFormTable">
#<th colspan="4"><b>Video Switch 2</b></th>
#<tr><td style="font-size:1.4vh;">Type</td><td></td><td></td><td></td></tr>
#<tr style="font-size:1.4vh;"><td align="center">IP</td><td align="center">Control Port</td><td align="center">Input</td><td align="center">Output</td></tr>
#<tr><td>$hdmiip2text</td><td>$hdmiport2text</td><td>$hdmiinput2text</td><td>$hdmioutput2text</td></tr>
#</table>
#<table class="stbDataFormTable">
#<th colspan="4"><b>Video Switch 3</b></th>
#<tr style="font-size:1.4vh;"><td align="center">Type</td><td align="center">IP</td><td align="center">Control Port</td><td align="center">Input</td><td align="center">Output</td></tr>
#<tr><td></td><td>$hdmiip3text</td><td>$hdmiport3text</td><td>$hdmiinput3text</td><td>$hdmioutput3text</td></tr>
#</table>

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

sub printNowTVNetworkTable {
	my ($ip) = @_;
	my $iptext = $query->textfield(-id=>'netip',-name=>'NOWTVIP',-size=>'15',-default=>$ip,-maxlength=>15,-class=>'stbDataTextField');

print <<NETWORK;
<p class="narrow" style="font-size:1.8vh;">Network Control</p>
<table class="stbDataFormTable ctrltype">
<tr><td style="text-align:right;font-size:1.4vh;">NOW TV IP Address:</td><td style="float:right;">$iptext</td></tr>
</table>
<div id="stbDataNoteDiv">
	<p>For network control to work, the computer hosting this control system needs to have access to the NOW TV units network</p>
</div>
NETWORK
}

sub printIRNetBoxIV {
	my ($irnb4ip,$irnb4out) = @_;
	my $iriptext = $query->textfield(-id=>'irnb4ip',-name=>'IRNetBoxIVIP',-size=>'15',-default=>$irnb4ip,-maxlength=>15,-class=>'stbDataTextField');
	my $irouttext = $query->popup_menu(-id=>'irout',-name=>'IRNetBoxIVOutput',-values=>['01'..'16'],-default=>$irnb4out,-class=>'stbDataSelect');
print <<IR;
<p class="narrow" style="font-size:1.8vh;">IR Control</p>
<table class="stbDataFormTable ctrltype">
<tr><td>IRNetBoxIV IP:</td><td>$iriptext</td></tr>
<tr><td>IRNetBoxIV Output:</td><td>$irouttext</td></tr>
</table>
IR
}

sub printIRNetBoxIVNowTV {
	my ($irnb4ip,$irnb4out,$nowtvmodel) = @_;
	my @models = ('Please Choose...','Smart Box 4631UK');
	my $nowtvtext = $query->popup_menu(-id=>'irnowtvmodel',-name=>'IRNetBoxIVNowTVModel',-values=>[@models],-default=>$nowtvmodel,-class=>'stbDataSelect nowtvmodel');
	my $iriptext = $query->textfield(-id=>'irnb4ip',-name=>'IRNetBoxIVIP',-size=>'15',-default=>$irnb4ip,-maxlength=>15,-class=>'stbDataTextField');
	my $irouttext = $query->popup_menu(-id=>'irout',-name=>'IRNetBoxIVOutput',-values=>['01'..'16'],-default=>$irnb4out,-class=>'stbDataSelect');
print <<IR;
<p class="narrow" style="font-size:1.8vh;">IR Control</p>
<table class="stbDataFormTable ctrltype">
<tr><td>IRNetBoxIV IP:</td><td>$iriptext</td></tr>
<tr><td>IRNetBoxIV Output:</td><td>$irouttext</td></tr>
<tr><td>NowTV Model:</td><td>$nowtvtext</td></tr>
</table>
<div id="stbDataNoteDivNowTV">
	<p>You do not have to specify a NOW TV model as the generic commands work with most models. It may benefit to select your specific model if you plan to use the shortcut keys like Kids or My TV</p>
</div>
IR
}

sub printGlobalCacheIRNowTV {
	my ($gcirip,$gcirport) = @_;
	#my @models = ('Please Choose...','Smart Box 4631UK');
	#my $nowtvtext = $query->popup_menu(-id=>'irnowtvmodel',-name=>'IRNetBoxIVNowTVModel',-values=>[@models],-default=>$nowtvmodel,-class=>'stbDataSelect nowtvmodel');
	my $iriptext = $query->textfield(-id=>'gcirip',-name=>'GlobalCacheIP',-size=>'15',-default=>$gcirip,-maxlength=>15,-class=>'stbDataTextField');
	my $irouttext = $query->popup_menu(-id=>'gcirport',-name=>'GlobalCachePort',-values=>['1'..'3'],-default=>$gcirport,-class=>'stbDataSelect');
print <<IR;
<p class="narrow" style="font-size:1.8vh;">IR Control</p>
<table class="stbDataFormTable ctrltype">
<tr><td>GlobalCache iTach IP:</td><td>$iriptext</td></tr>
<tr><td>GlobalCache iTach Output:</td><td>$irouttext</td></tr>
</table>
<div id="stbDataNoteDivNowTVGC">
</div>
IR
}

sub printGlobalCacheIR {
	my ($gcirip,$gcirport) = @_;
	#my @models = ('Please Choose...','Smart Box 4631UK');
	#my $nowtvtext = $query->popup_menu(-id=>'irnowtvmodel',-name=>'IRNetBoxIVNowTVModel',-values=>[@models],-default=>$nowtvmodel,-class=>'stbDataSelect nowtvmodel');
	my $iriptext = $query->textfield(-id=>'gcirip',-name=>'GlobalCacheIP',-size=>'15',-default=>$gcirip,-maxlength=>15,-class=>'stbDataTextField');
	my $irouttext = $query->popup_menu(-id=>'gcirport',-name=>'GlobalCachePort',-values=>['1'..'3'],-default=>$gcirport,-class=>'stbDataSelect');
print <<IR;
<p class="narrow" style="font-size:1.8vh;">IR Control</p>
<table class="stbDataFormTable ctrltype">
<tr><td>GlobalCache iTach IP:</td><td>$iriptext</td></tr>
<tr><td>GlobalCache iTach Output:</td><td>$irouttext</td></tr>
</table>
<div id="stbDataNoteDivNowTVGC">
</div>
IR
}
