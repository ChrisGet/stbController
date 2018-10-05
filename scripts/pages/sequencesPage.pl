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

print <<STUFF;
<table>
<tr>
STUFF

	my $colcount = '1';
	foreach my $key (sort keys %sequences) {
		if ($colcount == '8') {
			print '</tr><tr>';
			$colcount = '1';
		}
		
		my $titlestring = $sequences{$key} || '';

print <<SEQ;
<td style="padding:3px;width:auto;">
 <table class="roundedTable" style="width:100%;">
  <tr>
   <td colspan="3" align="center" class="fancyCell" style="width:250px;height:40px;border-radius:4px;">
    <label class="seqLabel masterTooltip" value="Commands: $titlestring">$key</label>
   </td>
  </tr>
  <tr>
   <td align="center" width="33%">
    <button class="seqListBtn" onclick="editSequencePage('$key')">Edit</button>
   </td>
   <td align="center" width="33%">
    <button class="seqListBtn Del" onclick="deleteSequence('$key')">Delete</button>
   </td>
   <td align="center" width="33%">
    <button class="evSchedAdmin pauseall" onclick="copySequence('$key')">Copy</button>
   </td>
  </tr>
 </table>
</td>
SEQ
	
		$colcount++;
	}

	print '</tr></table>'
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
		$headertext = "Sequences \&\#8594; Edit <font color\=\"green\">\"$$seq\"<\/font>";
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
				<p class="seqInfo rem">** Click on a button within the Sequence Area to remove it **</p>
			</div>
			<div id="seqAreaBottom">
				<button id="clearSeqAreaBtn" onclick="clearSeqArea('sequenceArea')">Clear Sequence Area</button>
				<div id="sequenceArea" contenteditable="true"></div>
				<button id="createSeqBtn" onclick="$onclick">$buttontext</button>
			</div>
		</div>
	</div>
	<div id="controllerButtons">
		@controller
	</div>
</div>
MAIN
} # End of sub 'createSeq'
