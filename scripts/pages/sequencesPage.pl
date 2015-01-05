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
   <td colspan="2" align="center" class="fancyCell" style="width:250px;height:40px;border-radius:4px;">
    <label class="seqLabel masterTooltip" onmouseover="tooltip()" value="Commands: $titlestring">$key</label>
   </td>
  </tr>
  <tr>
   <td align="center" width="50%">
    <button class="seqListBtn" onclick="editSequencePage('$key')">Edit</button>
   </td>
   <td align="center" width="50%">
    <button class="seqListBtn Del" onclick="deleteSequence('$key')">Delete</button>
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
	open my $fh, '<', $conthtml or die "Unable to open $conthtml: $!\n";
	my @controller = <$fh>;
	close $fh;
	print '<div class="wrapLeft shaded">' , @controller;

	my $headertext = 'Create New Command Sequence:';
	my $defname;
	my $commands;
	my $buttontext = 'Create New Sequence';
	my $onclick = 'seqValidate()';

	if ($$seq) {
		$headertext = "Edit Command Sequence for <font color\=\"#65a9d7\">\"$$seq\"<\/font>:";
		$defname = $$seq;
		tie my %sequences, 'Tie::File::AsHash', $seqfile, split => ':' or die "Problem tying \%sequences to $seqfile: $!\n";
		$commands = $sequences{$defname};		
		$buttontext = "Update \"$defname\"";
		print "<input type=\"hidden\" name=\"originalName\" value=\"$defname\"\/>";
		$onclick = "seqValidate(\'$defname\')";
	}

	my $timeouts = $query->popup_menu(-id=>'timeoutList',-name=>'timeoutList',-values=>['1','2','5','10'],-class=>'styledSelect');
	my $tobtn = '<button class="menuButton" onclick="addSeqTO()">Add Timeout</button>';
	my $namefield = $query->textfield(-id=>'sequenceName',-name=>'sequenceName',-size=>30,,-maxlength=>25,-default=>$defname);

	

print <<MAIN;
<div id="seqMain" style="width:700px;">
<h1 style="margin-bottom:0em;"><u>$headertext</u></h1>
<p style="margin-top:2px;margin-bottom:5px;color:white;font-size:20px;">Click the buttons from the controller on the right to add them to the Sequence area below</p>
<p style="margin-top:2px;color:white;font-size:18px;">You can insert new commands between existing sequence commands by placing the cursor where required</p>
<p style="margin-top:2px;margin-bottom:5px;color:white;font-size:18px;">Click on a button within the Sequence Area to remove it</p>
<table style="width:100%;">
<tr><td><div style="float:left;">
	<font size="6"><u>Sequence Area</u></font><br><br>
	<table>
		<tr>
		<td><button class="menuButton" onclick="clearSeqArea()">Clear Sequence Area</button></td>
		</tr>
	</table>
	</div>
</td>
<td align="left" valign="bottom"><div style="margin-top:50px;">
	<table>
		<tr>
		<td colspan="2" align="center"><font color="white" size="3">Please give your new sequence a name below</font></td>
		</tr>
		<tr>
		<td><font size="5" color="#69ABBF">Name: </font></td>
		<td>$namefield</td>
		</tr>		
	</table>
</div>
</td>
<td valign="bottom"><div style="float:right;border:1px solid;">
	<table>
		<tr><td align="center"><font size="4" color="white">Timeout (seconds)</font></td></tr>
		<tr height="7px"></tr>
		<tr><td align="center">$timeouts</td></tr>
		<tr height="7px"></tr>
		<tr><td align="center">$tobtn</td></tr>
	</table>
</div>
</td>
</tr>
</table>
<div id="sequenceArea" contenteditable="true" style="width:75%;"></div>
<div id="seqSubmitBtnDiv">
	<button class="newSeqSubmit" onclick="$onclick">$buttontext</button>
</div>
</div>
</div>
MAIN


} # End of sub 'createSeq'
