#!/usr/bin/perl -w

use strict;
use CGI;
use Tie::File::AsHash;

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
my $image = $maindir . '/images/RT_Logo.png';
my $htmldir = $maindir . '/scripts/pages/';
my $conthtml = $htmldir . 'sequenceController.html';
my $remfile = $confdir . 'sequencesRemote.txt';

mainMenu() and exit if ($action =~ /^Menu$/i);
createSeq(\$sequence) and exit if ($action =~ /^Create$/i);
createSeq(\$sequence) and exit if ($action =~ /^Edit$/i);

sub mainMenu {
	tie my %sequences, 'Tie::File::AsHash', $seqfile, split => ':' or die "Problem tying \%sequences to $seqfile: $!\n";
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
		
		my $titlestring = $sequences{$key} || '';
		my @coms = split(',',$titlestring);
		my $comstring = '';
		foreach my $com (@coms) {
			$comstring .= '<div class="seqListIconOuter"><div class="seqListIcon"><p>' . $com . '</p></div><div class="seqListArrowDiv"></div></div>';
		}

print <<SEQ;
<div class="seqListRow">
	<div class="seqListRowSec" onclick="seqRowHighlight(this)" title="Click to toggle highlight"><p>$key</p></div>
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
	my $buttontext = 'Create!';
	my $onclick = 'seqValidate()';

	if ($$seq) {
		$headertext = "Sequences \&\#8594; Edit \&\#8594; <font color\=\"green\">\"$$seq\"<\/font>";
		$defname = $$seq;
		tie my %sequences, 'Tie::File::AsHash', $seqfile, split => ':' or die "Problem tying \%sequences to $seqfile: $!\n";
		$commands = $sequences{$defname};		
		$buttontext = 'Update!';
		print "<input type=\"hidden\" name=\"originalName\" value=\"$defname\"\/>";
		$onclick = "seqValidate(\'$defname\')";
	}

	my $timeouts = $query->popup_menu(-id=>'timeoutList',-name=>'timeoutList',-values=>['1','2','5','10'],-class=>'styledSelect');
	my $tobtn = '<button class="seqTimeoutBtn" onclick="addSeqTO()">Add Timeout</button>';
	my $namefield = $query->textfield(-id=>'sequenceName',-name=>'sequenceName',-size=>30,,-maxlength=>25,-default=>$defname);

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
					<p>Sequence Name</p>
					$namefield
				</div>
				<div class="seqTopSec">
					<p>Add Timeout (Seconds)</p>
					<input type="text" id="seqTimeoutText" maxlength="3" placeholder="Secs">
					$tobtn
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
