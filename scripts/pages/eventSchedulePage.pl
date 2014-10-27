#!/usr/bin/perl -w
use strict;

use CGI;
use Tie::File::AsHash;
use DBM::Deep;

my $query = CGI->new;
print $query->header();
chomp(my $action = $query->param('action') || $ARGV[0] || '');
chomp(my $event = $query->param('event') || $ARGV[1] || '');
die "No Action given for eventSchedulePage.pl\n" if (!$action);
die "Invalid Action \"$action\" given for eventSchedulePage.pl\n" if ($action !~ /^Menu$|^Create$|^Edit$/i);
die "No Event given to be edited for eventSchedulePage.pl\n" if (($action =~ /^Edit$/i) and (!$event));

chomp(my $maindir = (`cat homeDir.txt` || ''));
die "Couldn't find where my main files are installed. No \"stbController\" directory was found on your system...\n" if (!$maindir);
$maindir =~ s/\/$//;
my $confdir = $maindir . '/config/';
my $filedir = $maindir . '/files/';
my $eventsfile = ($filedir . 'eventSchedule.txt');
my $htmldir = $maindir . '/scripts/pages/';

mainMenu() and exit if ($action =~ /^Menu$/i);
createEvSched(\$event) and exit if ($action =~ /^Create$|^Edit$/i);

sub mainMenu {
	tie my %events, 'Tie::File::AsHash', $eventsfile, split => ':' or die "Problem tying \%events to $eventsfile: $!\n";
	if (!%events) {
		print '<font size="4" color="red">You currently have no Scheduled Events</font>';
		exit;
	}

	my @times;
	foreach my $key (keys %events) {
		my @sections = split('\|',$events{$key});
		my $mins = $sections[1];
		my $hour = $sections[2];
		push (@times,"$key-$hour:$mins");
	}

	my @sorted = sort {($a =~ /-(\d+):/)[0] <=> ($b =~ /-(\d+):/)[0] or ($a =~ /:(\d+)$/)[0] <=> ($b =~ /:(\d+)$/)[0]} @times;	# Sorted the list by hour and then minute

	foreach my $thing (@sorted) {
		my ($id) = $thing =~ /^(\d+)-/;
		my @info = split('\|',$events{$id});
		my %data = (	'Active' => $info[0],
				'Minute' => $info[1],
				'Hour' => $info[2],
				'DOM' => $info[3],
				'Month' => $info[4],
				'DOW' => $info[5],
				'Event' => $info[6],
				'Boxes' => $info[7],
			);
		my $time = $data{'Hour'} . ':' . $data{'Minute'};
		my $months = numbersToDays(\$data{'Month'},\'month');
		$$months =~ s/_/ /g;
		my $days = numbersToDays(\$data{'DOW'},\'dow');
		my $dom = $data{'DOM'};
		$dom = 'Every Day Of The Month' if ($dom =~ /\*/);
		my $togglebtn = "<button class=\"activateBtn\" onclick=\"scheduleStateChange(\'Disable\',\'$id\')\">Running<\/button>";
		my $editbtn = "<button class=\"seqListBtn\" onclick=\"editSchedulePage(\'$id\')\" style=\"width:90\%;\">Edit<\/button>";
		my $delbtn = "<button class=\"seqListBtn Del\" onclick=\"deleteSchedule(\'$id\')\" style=\"width:90\%;margin-top:5px;\">Delete<\/button>";
		if ($data{'Active'} eq 'n') {
			$togglebtn = "<button class=\"deactivateBtn\" onclick=\"scheduleStateChange(\'Enable\',\'$id\')\">Disabled<\/button>";
		}
		my $stbdatafile = $confdir . 'stbDatabase.db';
		tie my %stbdata, 'DBM::Deep', {file => $stbdatafile,   locking => 1, autoflush => 1, num_txns => 100};
		my $stbnames = '';
		my @stbs = split(',',$data{'Boxes'});
		foreach my $box (@stbs) {
			if (exists $stbdata{$box}) {
				my $name = $stbdata{$box}{'Name'} || '';
				if ($name) {
					$stbnames .= " $name ,";
				} else {
					$stbnames .= " $box ,";
				}
			} else {
				$stbnames .= " $box ,";
			}
		}
		untie %stbdata;
		$stbnames =~ s/\,$//;
		$stbnames =~ s/^ //;

print <<STUFF;
<table class="Bordered">
<tr><td class="fancyCell cellHead" width="50px">Time</td><td class="fancyCell cellHead" width="110px">Day Of Month</td><td class="fancyCell cellHead" width="60px">Month</td><td class="fancyCell cellHead" width="110px">Day Of Week</td><td class="fancyCell cellHead" width="120px">Event</td><td class="fancyCell cellHead" width="300px">Target STB(s)</td><td rowspan="2" style="text-align:center;vertical-align:middle;" width="80px">$editbtn<br>$delbtn</td><td rowspan="2" width="90px">$togglebtn</td></tr>
<tr><td class="cellInfo" style="max-width:50px;">$time</td><td class="cellInfo" style="max-width:110px;">$dom</td><td class="cellInfo" style="max-width:60px;">$$months</td><td class="cellInfo" style="max-width:110px;">$$days</td><td class="cellInfo" style="max-width:120px;">$data{'Event'}</td><td class="cellInfo" style="max-width:300px;">$stbnames</td></tr>
STUFF
	}

	print '</table>';
	untie %events;
}

sub numbersToDays {
	my ($string,$flag) = @_;
	my %days = qw(0 Sun 1 Mon 2 Tues 3 Weds 4 Thurs 5 Fri 6 Sat 7 Sun * Everyday);
	my %months = qw(1 Jan 2 Feb 3 Mar 4 Apr 5 May 6 Jun 7 Jul 8 Aug 9 Sep 10 Oct 11 Nov 12 Dec * Every_Month);

	my %ref;
	%ref = %days if ($$flag =~ /dow/i);
	%ref = %months if ($$flag =~ /month/i);

	my $result = '';	
	my @parts = split(/(\d+)/,$$string);
	foreach my $bit (@parts) {
		my $res = $ref{$bit} || '';
		if ($res) {
			$result .= $res;
		} else {
			$result .= $bit;
		}
	}
	return \$result;
}

sub createEvSched {
	my ($event) = @_;
	my $groupsfile = $filedir . 'stbGroups.txt';
	my $seqfile = $filedir . 'commandSequences.txt';
	my $headertext = 'Create New Scheduled Event';
	my $headertext2 = 'Use the sections below to build your new scheduled event';
	my $buttontext = 'Create New Scheduled Event';
	my $onclick = 'newSchedValidate()';
	tie my %groups, 'Tie::File::AsHash', $groupsfile, split => ':' or die "Problem tying \%groups to $groupsfile: $!\n";
	tie my %sequences, 'Tie::File::AsHash', $seqfile, split => ':' or die "Problem tying \%sequences to $seqfile: $!\n";
	tie my %events, 'Tie::File::AsHash', $eventsfile, split => ':' or die "Problem tying \%events to $eventsfile: $!\n";
	my ($active,$min,$hour,$dom,$month,$dow,$eventname,$boxes);

	if ($event) {
		if ($$event) {
			my @info = split('\|',$events{$$event});
			($active,$min,$hour,$dom,$month,$dow,$eventname,$boxes) = @info;
			$dom = 'Every Day Of The Month' if ($dom =~ /\*/);
			$month = numbersToDays(\$month,\'month');
			$month = $$month;
			$dow = numbersToDays(\$dow,\'dow');
			$dow = $$dow;
			print "<input type=\"hidden\" name=\"$$event\" />";
			$headertext = 'Edit Your Scheduled Event';
			$headertext2 = 'Use the sections below to update the scheduled event parameters';
			$buttontext = 'Update This Scheduled Event';
			$onclick = "newSchedValidate(\'$$event\')";
		}
	}
	
	print '<div class="wrapLeft shaded" style="width:520px;">';
print <<HEAD;
<div id="seqMain">
<h1 style="margin-top:0em;margin-bottom:0em;"><u>$headertext</u></h1>
<p style="margin-top:2px;margin-bottom:2px;color:white;font-size:20px;">$headertext2</p>
</div>
HEAD
	
	my @mins = ('00'..'59');
	my @hours = ('00'..'23');
	my @dom = ('Every Day Of The Month','01'..'31');
	my @months = ('Every Month','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec');
	my @dayoptions = ('Everyday','Mon-Fri','Sun-Thurs','Sat,Sun','Mon,Weds,Fri');
	my @days = qw/Mon Tues Weds Thurs Fri Sat Sun/;

	my $mindata = $query->popup_menu(-id=>'minutes',-name=>'minutes',-values=>[@mins],-default=>$min,-class=>'styledSelect');
	my $hourdata = $query->popup_menu(-id=>'hours',-name=>'hours',-values=>[@hours],-default=>$hour,-class=>'styledSelect');
	my $domdata = $query->popup_menu(-id=>'dom',-name=>'dom',-values=>[@dom],-default=>$dom,-class=>'styledSelect');
	my $monthdata = $query->popup_menu(-id=>'month',-name=>'month',-values=>[@months],-default=>$month,-class=>'styledSelect');
	my $dayoptsdata = $query->popup_menu(-id=>'dayopts',-name=>'dayopts',-values=>[@dayoptions],-default=>$dow,-class=>'styledSelect');
	#my $daysdata = $query->popup_menu(-id=>'days',-name=>'days',-values=>[@days],-default=>$dow,-class=>'styledSelect');
	
	my $presetradio = "<input class=\"trigger radiooff\" type=\"radio\" name=\"dayOption\" value=\"dayPresets\">Day Presets";
	my $customradio = "<input class=\"trigger radiooff\" type=\"radio\" name=\"dayOption\" value=\"dayCustom\">Custom Days";

	my $preset = 'false';
	foreach my $dayopts (@dayoptions) {
		if ($dow =~ /$dayopts/) {
			$preset = 'true';
		}
	}

	if ($preset =~ /false/) {
		if ($$event) {
			$customradio = "<input class=\"trigger radioon\" type=\"radio\" name=\"dayOption\" value=\"dayCustom\" checked>Custom Days";
		}
	} else {
		$presetradio = "<input class=\"trigger radioon\" type=\"radio\" name=\"dayOption\" value=\"dayPresets\" checked>Day Presets";
	}

	my @dayshtml;
	foreach my $day (@days) {
		my $html;
		if ($$event) {
			if ($preset =~ /true/) {
				$html = "<input type=\"checkbox\" name=\"dayCheck\" onchange=\"daysSelectedCheck()\" value=\"$day\">$day<br>";
				#$html = $query->checkbox(-name=>'dayCheck',-onchange=>'daysSelectedCheck()',-value=>$day);				
			} else {
				if ($dow =~ /$day/) {
					$html = "<input type=\"checkbox\" name=\"dayCheck\" onchange=\"daysSelectedCheck()\" value=\"$day\" checked>$day<br>";
					#$html = $query->checkbox(-name=>'dayCheck',-onchange=>'daysSelectedCheck()',-value=>$day,-selected=>1);
				} else {
					$html = "<input type=\"checkbox\" name=\"dayCheck\" onchange=\"daysSelectedCheck()\" value=\"$day\">$day<br>";
					#$html = $query->checkbox(-name=>'dayCheck',-onchange=>'daysSelectedCheck()',-value=>$day);
				}
			}
		} else {
			$html = "<input type=\"checkbox\" name=\"dayCheck\" onchange=\"daysSelectedCheck()\" value=\"$day\">$day<br>";
			#$html = $query->checkbox(-name=>'dayCheck',-onchange=>'daysSelectedCheck()',-value=>$day);
		}
		#my $html = "<input type=\"checkbox\" name=\"dayCheck\" onchange=\"daysSelectedCheck()\" value=\"$day\">$day<br>";
		push(@dayshtml,$html);
	}

print <<TOPTABLE;		# Print the top table which contains the hour, minute, day of month, and month fields
<table class="Bordered" style="width:100%;">
  <tr><td class="fancyCell cellHead">Hour</td><td class="fancyCell cellHead">Minute</td><td class="fancyCell cellHead">Day Of Month</td><td class="fancyCell cellHead">Month</td></tr>
  <tr><td>$hourdata</td><td>$mindata</td><td>$domdata</td><td>$monthdata</td></tr>
</table>
TOPTABLE

print <<BOTTOMTABLELEFT;		# Print the bottom table which contains the day options
<table class="Bordered" style="width:55%;float:left;">
  <tr><td class="fancyCell cellHead" colspan="2">Day Options (Select One)</td></tr>
  <tr>
   <td>
    <table style="width:100%;">
     <tr><td class="fancyCell cellHead">$presetradio</td><td class="fancyCell cellHead">$customradio</td></tr>
     <tr><td valign="top">$dayoptsdata</td><td style="text-align:left;font-size:17px;">@dayshtml</td></tr>
    </table>
   </td>
  </tr>
</table>
BOTTOMTABLELEFT

	my @seqs = sort keys %sequences;
	my $seqlist = $query->popup_menu(-id=>'seqList',-name=>'seqList',-values=>[@seqs],-class=>'styledSelect');	

print <<BOTTOMTABLERIGHT1;	# Print the table which holds the list of available sequences to be selected
<table class="Bordered" style="height:auto;width:40%;float:right;">
 <tr>
  <td class="fancyCell cellHead" align="center"><p style="font-size:20px;margin-top:1px;margin-bottom:0em;">Sequence Selection</p></td>
 </tr>
 <tr>
  <td align="left"><p style="color:white;font-size:15px;margin-top:1px;margin-bottom:0em;">Select a sequence from the list below which is to be run.</p>
			<p style="color:#c0c0c0;font-size:15px;margin-top:1px;margin-bottom:0em;">The list contains all sequences you have created</p></td>
 </tr>
 <tr>
  <td align="center">$seqlist</td> 
 </tr>
</table>
BOTTOMTABLERIGHT1

	my @groups = sort keys %groups;
	my $grouplist = $query->popup_menu(-id=>'groupList',-name=>'groupList',-values=>[@groups],-class=>'styledSelect');	
	my $addgrpbtn = "<button class=\"menuButton\" onclick=\"addSeqGroup()\">Add Group</button>";


print <<BOTTOMTABLERIGHT2;	# Print the table which holds the STB Group data
<table class="Bordered" style="height:auto;width:40%;float:right;">
 <tr>
  <td colspan="2" class="fancyCell cellHead" align="center"><p style="font-size:20px;margin-top:1px;margin-bottom:0em;">STB Groups</p></td>
 </tr>
 <tr>
  <td align="center">$grouplist</td>
  <td align="center">$addgrpbtn</td>
 </tr>
</table>
BOTTOMTABLERIGHT2

print <<TARGETS;		# Print the div which holds the Target STBs data
<div class="wrapLeft shaded" style="margin-top:7px;padding:3px;width:98%;">
	<h1 style="margin-top:2px;margin-bottom:2px;margin-left:2px;font-size:20px;text-decoration:underline;">Target STBs</h1>
	<p style="margin-top:2px;margin-bottom:2px;margin-left:2px;font-size:15px;color:white;">Click on a box in the grid to the right to add it to the list of target STBs (below)<br>
		You can also add a group by selecting it from the drop down list above and clicking "Add Group"</p>
	<p style="margin-top:2px;margin-bottom:6px;margin-left:2px;font-size:15px;color:#c0c0c0;">Click on a box or group in the target STBs list to remove it.</p>
	<button class="menuButton" onclick="clearSeqArea()">Clear Target STB List</button>
	<div id="sequenceArea" contenteditable="true"></div>
	
</div>
<br>
<button class="newSeqSubmit" onclick="$onclick">$buttontext</button>
TARGETS
	print '</div>';	# End of div 'wrapLeft'

print <<RIGHT;
<div class="wrapLeft" style="margin-right:5px;">
RIGHT
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
<div id="stbSelect" style="margin-top:2px;padding:5px;">
<p style="align:center;font-size:18px;margin-top:3px;margin-bottom:3px;">STB Selection Grid</p>
<table id="stbConfigGrid" class="stbConfigGrid"><tr>
HEAD
                tie my %stbdata, 'DBM::Deep', {file => $dbfile,   locking => 1, autoflush => 1, num_txns => 100};

                my $c = '0';

                foreach my $key (sort { ($a =~ /STB(\d+)/)[0] <=> ($b =~ /STB(\d+)/)[0] } keys %stbdata) {
                        if ($c >= $columns) {
                                print '</tr><tr>';
                                $c = '0';
                        }
                        my ($num) = $key =~ /STB(\d+)/;
			my $name = 'STB ' . $num;
                        $name = $stbdata{$key}{'Name'} if ((exists $stbdata{$key}{'Name'}) and ($stbdata{$key}{'Name'} =~ /\S+/));
print <<KEY;
<td><button id="$key" class="configButton" onClick="seqTextUpdate('$key','$name')">$name</button></td>
KEY
                        $c++;
                }
                print '</table></div>';
        } else {
                print "<font size=\"5\" color=\"red\">No STB Database found. Have you setup your STB Controller Grid yet?<\/font>";
        }
	
	
	untie %groups;
	untie %sequences;
	untie %events;

} # End of sub 'createEvSched'
