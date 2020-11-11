#!/usr/bin/perl -w

use strict;
use CGI;
use Tie::File::AsHash;
use JSON;

my $query = CGI->new;
print $query->header();

chomp(my $action = $query->param('action') || $ARGV[0] || '');
chomp(my $sequence = $query->param('sequence') || $ARGV[1] || '');

die "No Action given for sequencesPages.pl\n" if (!$action);
die "Invalid Action \"$action\" given for sequencesPage.pl\n" if ($action !~ /^Menu$|^Create$|^Edit$|^Delete$/i);
die "No Sequence given to be edited for sequencesPage.pl\n" if (($action =~ /^Edit$/i) and (!$sequence));

chomp(my $maindir = (`cat homeDir.txt` || ''));
die "Couldn't find where my main files are installed. No \"stbController\" directory was found on your system...\n" if (!$maindir);
$maindir =~ s/\/$//;
my $confdir = $maindir . '/config/';
my $filedir = $maindir . '/files/';
my $seqfile = ($filedir . 'commandSequences.txt');
my $jsonfile = $filedir . 'commandSequences.json';
my $image = $maindir . '/images/RT_Logo.png';
my $htmldir = $maindir . '/scripts/pages/';
my $conthtml = $htmldir . 'sequenceController.html';
my $remfile = $confdir . 'sequencesRemote.txt';

checkLegacy();	# Initial check to see if any old sequence files have been converted to the new JSON format

##### Create new JSON object for later use
my $json = JSON->new->allow_nonref;
$json = $json->canonical('1');

my %sequences;
if (-e $jsonfile) {
	local $/ = undef;
	open my $fh, "<", $jsonfile or die "ERROR: Unable to open $jsonfile: $!\n";
	my $data = <$fh>;
	my $decoded = $json->decode($data);
	%sequences = %{$decoded};
}

mainMenu() and exit if ($action =~ /^Menu$/i);
createSeq(\$sequence) and exit if ($action =~ /^Create$/i);
createSeq(\$sequence) and exit if ($action =~ /^Edit$/i);

sub checkLegacy {
	if (!-e $jsonfile and !-e $seqfile) {
		##### If no command sequence files exist, we can start off with JSON straight away
		$seqfile = $jsonfile;
		return;
	} elsif (-e $jsonfile) {
		##### If the new file format already exists, update the $seqfile variable to use
		$seqfile = $jsonfile;
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
				if (open my $newfh, '+>', $jsonfile) {
					print $newfh $encoded;
					close $newfh;
				} else {
					die "Failed to open file $jsonfile for writing in conversion in file " . __FILE__ . " :$!\n";
				}
			}
		}
	}
}

sub mainMenu {
	#tie my %sequences, 'Tie::File::AsHash', $seqfile, split => ':' or die "Problem tying \%sequences to $seqfile: $!\n";
	if (!%sequences) {
		print '<font size="4" color="red">You currently have no Command Sequences</font>';
		exit;
	}
print <<HEAD;
<div id="expMultiSeqDiv">
	<h2>Multi Export</h2>
	<p>Use the checkboxes to select multiple sequences for exporting (Native format only)</p>
	<button class="multiExportBtn" onclick="exportSequence('native','multi-export')">Export</button>
</div>
<div id="sequenceListHeader">
	<div class="seqListRowSec state"><h2>Active</h2></div>
	<div class="seqListRowSec header"><h2>Sequence Name</h2></div>
	<div class="seqListRowSec comlist header"><h2>Commands</h2></div>
	<div class="seqListRowSec manage header">
		<h2>Manage</h2>
		<input type="checkbox" class="seqExpCheck all" id="seqCheck-all-seqs" onclick="expSeqSelect('seqCheck-all-seqs')">
	</div>
</div>
<div id="sequenceListDiv">
HEAD
	my $colcount = '1';
	foreach my $key (sort keys %sequences) {
		my $id = $key;
		$id =~ s/\s+/_/g;
		if ($colcount == '8') {
			print '</tr><tr>';
			$colcount = '1';
		}
		
		my $titlestring = $sequences{$key}{'commands'} || '';
		my @coms = split(',',$titlestring);
		my $comstring = '';
		foreach my $com (@coms) {
			my $classextra = '';
			if ($com =~ /^t\d+$/) {
				$classextra = 'timeout';
			}
			$comstring .= "<div class=\"seqListIconOuter\"><div class=\"seqListIcon $classextra\"><p>$com</p></div><div class=\"seqListArrowDiv $classextra\"></div></div>";
		}

		my $description = $sequences{$key}{'description'} // '';
		$description = 'No description' if ($description !~ /\S+/);

		my $active = $sequences{$key}{'active'} // '';
		my $stateclass = 'stateBox';
		if ($active and $active eq 'yes') {
			$stateclass .= ' active';
		}

print <<SEQ;
<div class="seqListRow">
	<div class="seqListRowSec state">
		<div class="$stateclass" id="stateBox-$id" onclick="seqStateChange(this,'$key')">
		</div>
	</div>
	<div class="seqListRowSec" onclick="seqRowHighlight(this)" title="Click to toggle highlight">
		<div class="seqListTitleSec">
			<p>$key</p>
		</div>
		<div class="seqListDescSec">
			<p>$description</p>
		</div>
	</div>
	<div class="seqListRowSec comlist" onclick="seqRowHighlight(this)" title="Click to toggle highlight"><div class="comStringHolder">$comstring</div></div>
	<div class="seqListRowSec manage header">
		<div id="seqExportOverlay-$id" class="exportOptionsDiv">
			<button class="closeSeqExpBtn" onclick="closeSeqExportDiv('seqExportOverlay-$id')"></button>
			<div class="exportDivHalf">
				<p title="Export in the standard STB controller format">Native<br>Format</p>
				<button title="Export in the standard STB controller format"  class="seqListBtn Export Single" onclick="exportSequence('native','$key')"></button>	
			</div>
			<div class="exportDivHalf">
				<p title="Export in the stress script format (Brentwood)">Stress<br>Format</p>
				<button title="Export in the stress script format (Brentwood)" class="seqListBtn Export Single" onclick="exportSequence('stress','$key')"></button>	
			</div>
		</div>
		<button class="seqListBtn Edit" title="Edit" onclick="editSequencePage('$key')"></button>
		<button class="seqListBtn Copy" title="Copy" onclick="copySequence('$key')"></button>	
		<button class="seqListBtn Del" title="Delete" onclick="deleteSequence('$key')"></button>	
		<button class="seqListBtn Export" title="Export" onclick="exportSequence('show','$key')"></button>	
		<input type="checkbox" class="seqExpCheck" id="seqCheck-$id" onclick="expSeqSelect('seqCheck-$id')" name="$key">
	</div>
</div>
SEQ
		$colcount++;
	}
	
	print '</div>';
}

sub createSeq {
	my ($seq) = @_;
	my $choice = 'universalSeqRemote';
	my @controller;
	if (open my $fh, '<', $remfile) {
		local $/;
		$choice = <$fh>;
		close $fh;
	}
	
	my $file = $maindir . '/scripts/pages/' . $choice . '.html';
	if (-e $file) {
		open my $fh, '<', $file or die "Unable to open $file: $!\n";
		@controller = <$fh>;
		close $fh;
	} else {
		die "Could not find $file for the sequences remote.\n";
	}
	my $headertext = 'Sequences &#8594; Create';
	my $defname;
	my $commands;
	my $description = '';
	my $buttontext = 'Create!';
	my $onclick = 'seqValidate()';

	if ($$seq) {
		$headertext = "Sequences \&\#8594; Edit \&\#8594; <font color\=\"green\">\"$$seq\"<\/font>";
		$defname = $$seq;
		#tie my %sequences, 'Tie::File::AsHash', $seqfile, split => ':' or die "Problem tying \%sequences to $seqfile: $!\n";
		$commands = $sequences{$defname}{'commands'};		
		$description = $sequences{$defname}{'description'} // '';
		$buttontext = 'Update!';
		print "<input type=\"hidden\" name=\"originalName\" value=\"$defname\"\/>";
		$onclick = "seqValidate(\'$defname\')";
	}

	my $timeouts = $query->popup_menu(-id=>'timeoutList',-name=>'timeoutList',-values=>['1','2','5','10'],-class=>'styledSelect');
	my $tobtn = '<button class="seqTimeoutBtn" onclick="addSeqTO()">Add Timeout</button>';
	my $namefield = $query->textfield(-id=>'sequenceName',-name=>'sequenceName',-size=>30,,-maxlength=>25,-default=>$defname);
	my $descfield = $query->textarea(-id=>'sequenceDesc',-name=>'sequenceDescription',-default=>$description);

print <<MAIN;
<div id="sequencesPageHolder">
	<div id="seqHeaderDiv">
		<h1>$headertext</h1>
	</div>
	<div id="seqMain">
		<div id="seqHeadHolder">
			<p class="seqInfo big">Click the buttons from the controller on the right to add them to the Sequence area below</p>
			<p class="seqInfo med">You can insert new commands between existing sequence commands by placing the cursor where required</p>
		</div>
		<div id="seqContentHolder">
			<div id="seqAreaTop">
				<div class="seqTopSec">
					<div class="seqTopSec short">
						<p>Sequence Name</p>
						$namefield
					</div>
					<div class="seqTopSec short">
						<p>Add Timeout (Seconds)</p>
						<input type="text" id="seqTimeoutText" maxlength="3" placeholder="Secs">
						$tobtn
					</div>
				</div>
				<div class="seqTopSec">
					<p>Sequence Description</p>
					$descfield
				</div>
			</div>
			<div id="seqAreaMiddle">
				<p class="seqInfo rem">Click on a button within the Sequence Area to remove it</p>
			</div>
			<div id="seqAreaBottom">
				<button id="clearSeqAreaBtn" onclick="clearSeqArea('sequenceArea')">Clear Sequence Area</button>
				<div id="sequenceArea" contenteditable="true"></div>
				<button id="createSeqBtn" onclick="$onclick">$buttontext</button>
			</div>
		</div>
	</div>
	<div id="seqControllerHolder">
		<div id="controllerButtons">
			@controller
		</div>
	</div>
</div>
MAIN
} # End of sub 'createSeq'
