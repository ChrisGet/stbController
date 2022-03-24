#!/usr/bin/perl -w

use strict;
use CGI;
use Tie::File::AsHash;
use JSON;

my $query = CGI->new;
print $query->header();
#chomp(my $action = $query->param('action') || $ARGV[0] || '');
#chomp(my $group = $query->param('group') || $ARGV[1] || '');
#die "No Action given for stbGroupsPage.pl\n" if (!$action);
#die "Invalid Action \"$action\" given for stbGroupsPage.pl\n" if ($action !~ /^Menu$|^Create$|^Edit$/i);
#die "No STB group given to be edited for stbGroupsPage.pl\n" if (($action =~ /^Edit$/i) and (!$group));

chomp(my $maindir = (`cat homeDir.txt` || ''));
die "Couldn't find where my main files are installed. No \"stbController\" directory was found on your system...\n" if (!$maindir);
$maindir =~ s/\/$//;
my $confdir = $maindir . '/config/';
my $filedir = $maindir . '/files/';
my $groupsfile = ($filedir . 'stbGroups.txt');
my $htmldir = $maindir . '/scripts/pages/';
my $stbdatafile = $confdir . 'stbData.json';
my $orderfile = $confdir . 'controllerPageOrder.conf';
my $rowresfile = $confdir . 'gridRowRestriction.conf';
my $gridsizefile = $confdir . 'gridFullSize.conf';

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

##### Get the STB Selection Grid Row Restriction option
my $rowresclass = 'off';
chomp(my $rowresopt = `cat $rowresfile` // '');
if ($rowresopt) {
	if ($rowresopt =~ /^on$/i) {
		$rowresclass = 'on';
	}
}

##### Get the STB grid full size option
my $fullsizeclass = 'off';
if (open my $fsfh, '<', $gridsizefile) {
	local $/;
	my $d = <$fsfh>;
	if ($d =~ /on/i) {
		$fullsizeclass = 'on';
	}
	close $fsfh;
}

print <<DATA;
<div id="settingsPageHolder">
	<div id="settingsPageHeader">
		<h1>Settings</h1>
		<h2>Here you can change various settings to customise the look and functionality of your control system</h2>
	</div>
	<div id="settingsPageContent">
		<div class="settingSection layout">
			<div class="setSecHead">
				<h2>Controller Page Layout</h2>
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
		<div class="settingSection">
			<div class="setSecHead">
				<h2>STB Selection Grid Row Restriction</h2>
				<h3>By default you can only select one STB within a column on the STB control grid at a time.</h3>
			</div>
			<div class="setSecDetail">
				<p style="width:95%;text-align:left;margin-left:2%;">This restriction is in place so that you only ever send control commands to STBs that you are currently viewing the output of (if you have video switching setup for the STBs)</p>
				<p style="width:95%;text-align:left;margin-left:2%;">Disabling this feature can cause odd behaviour with row highlighting and the Row Up/Down buttons on the 3 remote control panels</p>
				<div id="rowRestrictionSlider" class="rowRestrictSlider $rowresclass" onclick="rowRestrictionToggle(this)">
					<div class="rowResInnerSlide"></div>
				</div>
			</div>
		</div>
		<div class="settingSection">
			<div class="setSecHead">
				<h2>STB Grid Button Sizing</h2>
				<h3>By default the STB grid and button size is restricted.</h3>
			</div>
			<div class="setSecDetail">
				<p style="width:95%;text-align:left;margin-left:2%;">Enabling this setting will make the STB controller grid fill all available space on the page<br>(This may look odd if you only have a small number of STBs in the grid)</p>
				<p style="width:95%;text-align:left;margin-left:2%;">This will affect the grid size on ALL pages where the STB grid appears</p>
				<div id="gridFullSizeSlider" class="rowRestrictSlider $fullsizeclass" onclick="gridFullSizeToggle(this)">
					<div class="rowResInnerSlide"></div>
				</div>
			</div>
		</div>
		<div class="settingSection">
			<div class="setSecHead debug">
				<h2>Debug - RedRatHub Manual Restart</h2>
				<h3>Manually restart the RedRatHub process</h3>
			</div>
			<div class="setSecDetail">
				<p style="width:95%;text-align:left;margin-left:2%;">The RedRatHub software runs in the background to assist with control using IRNetBoxIV and other RedRat IR hardware</br>Sometimes the software can get in to a state where it no longer communicates with RedRat hardware</p>
				<p style="width:95%;text-align:left;margin-left:2%;">Use the button below to manually restart the software if you are having STB control issues using RedRat IRNetBoxIV hardware</p>
				<button id="restartRedRatHubBtn" class="settingsBtn" onclick="restartRedRatHub()">RESTART</button>
			</div>
		</div>
	</div>
</div>
DATA
