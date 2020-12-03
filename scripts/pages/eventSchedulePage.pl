#!/usr/bin/perl -w
use strict;

use CGI;
use Tie::File::AsHash;
use JSON;

my $query = CGI->new;
print $query->header();
chomp(my $action = $query->param('action') // $ARGV[0] // '');
chomp(my $event = $query->param('event') // $ARGV[1] // '');
die "No Action given for eventSchedulePage.pl\n" if (!$action);
die "Invalid Action \"$action\" given for eventSchedulePage.pl\n" if ($action !~ /^Menu$|^Create$|^Edit$/i);
die "No Event given to be edited for eventSchedulePage.pl\n" if (($action =~ /^Edit$/i) and (!$event));

chomp(my $maindir = (`cat homeDir.txt` || ''));
die "Couldn't find where my main files are installed. No \"stbController\" directory was found on your system...\n" if (!$maindir);
$maindir =~ s/\/$//;
my $confdir = $maindir . '/config/';
my $filedir = $maindir . '/files/';
my $statefile = $filedir . 'schedulerState.txt';
my $eventsfile = ($filedir . 'eventSchedule.txt');
my $eventsjsonfile = $filedir . 'eventSchedule.json';
my $groupsjsonfile = $filedir . 'stbGroups.json';
my $seqsjsonfile = $filedir . 'commandSequences.json';
my $htmldir = $maindir . '/scripts/pages/';
my $stbdatafile = $confdir . 'stbData.json';

checkLegacy(); # Initial check to see if any old STB group files have been converted to the new JSON format

my $json = JSON->new->allow_nonref;
$json = $json->canonical('1');

my %stbdata;
if (-e $stbdatafile) {
	local $/ = undef;
	open my $fh, "<", $stbdatafile or die "ERROR: Unable to open $stbdatafile: $!\n";
	my $data = <$fh>;
	my $decoded = $json->decode($data);
	%stbdata = %{$decoded};
}

##### Load the events schedule data
my %events;
if (-e $eventsjsonfile) {
        local $/ = undef;
        open my $fh, "<", $eventsjsonfile or die "ERROR: Unable to open $eventsjsonfile: $!\n";
        my $data = <$fh>;
        my $decoded = $json->decode($data);
        %events = %{$decoded};
}

##### Load the groups data
my %groups;
if (-e $groupsjsonfile) {
        local $/ = undef;
        open my $fh, "<", $groupsjsonfile or die "ERROR: Unable to open $groupsjsonfile: $!\n";
        my $data = <$fh>;
        my $decoded = $json->decode($data);
        %groups = %{$decoded};
}

##### Load the sequences data
my %sequences;
if (-e $seqsjsonfile) {
        local $/ = undef;
        open my $fh, "<", $seqsjsonfile or die "ERROR: Unable to open $seqsjsonfile: $!\n";
        my $data = <$fh>;
        my $decoded = $json->decode($data);
        %sequences = %{$decoded};
}

mainMenu() and exit if ($action =~ /^Menu$/i);
createEvSched(\$event) and exit if ($action =~ /^Create$|^Edit$/i);

sub mainMenu {
	if (!%events) {
		print '<font size="4" color="red">You currently have no Scheduled Events</font>';
		exit;
	}
	chomp(my $schedstate = `cat $statefile` || '');
	if ($schedstate =~ /^Disabled$/i) {
print <<TOP;
<div id="evSchedAdminDiv">
	<button class="evSchedAdminBtn enable" onclick="scheduleAdmin('EnableSchedule')">Turn Scheduler On</button>
	<p class="evSchedDisabledText">The Event Scheduler is currently disabled. You can still manage the scheduled events but nothing will run until you enable the scheduler</p>
</div>
TOP
	} else {
print <<TOP;
<div id="evSchedAdminDiv">
	<button class="evSchedAdminBtn disable" onclick="scheduleAdmin('DisableSchedule')">Turn Scheduler Off</button>
	<button class="evSchedAdminBtn stopall" onclick="scheduleAdmin('KillAll')">Stop All</button>
	<button class="evSchedAdminBtn pauseall" onclick="scheduleAdmin('PauseAll')">Pause All</button>
	<button class="evSchedAdminBtn resumeall" onclick="scheduleAdmin('ResumeAll')">Resume All</button>
</div>
TOP
	}
print <<HEAD;
<div id="evSchedListHeader">
	<div class="evSchedRowSec"><h2>Time</h2></div>
	<div class="evSchedRowSec"><h2>DOM</h2></div>
	<div class="evSchedRowSec"><h2>Month</h2></div>
	<div class="evSchedRowSec"><h2>Day(s)</h2></div>
	<div class="evSchedRowSec event"><h2>Event</h2></div>
	<div class="evSchedRowSec targets"><h2>Target STB(s)</h2></div>
	<div class="evSchedRowSec"><h2>Manage</h2></div>
	<div class="evSchedRowSec"><h2>Disable/Enable</h2></div>
</div>
<div id="evSchedList">
HEAD

	my %times;
	foreach my $key (sort keys %events) {
		my @sections = split(/\s+/,$events{$key}{'schedule'});
		my $mins = $sections[0];
		my $hour = $sections[1];
		$times{$hour}{$mins}{$key} = '1';
	}

	foreach my $hour (sort keys %times) {
                my %mins = %{$times{$hour}};
                foreach my $min (sort keys %mins) {
                        my %evs = %{$mins{$min}};
                        foreach my $id (sort keys %evs) {
				my @info = split(/\s+/,$events{$id}{'schedule'});
				my %timedata = (
						'Minute' => $info[0],
						'Hour' => $info[1],
						'DOM' => $info[2],
						'Month' => $info[3],
						'DOW' => $info[4],
					);
				my $time;
				if ($timedata{'Minute'} =~ /\*\/(\d+)/) {
					my $mins = $1;
					if ($timedata{'Hour'} =~ /(\d+)-(\d+)/) {
						$time = "Every $mins minutes at $1:00 to $2:00"; 
					} else {
						$time = "Every $mins minutes at " . $timedata{'Hour'} . ':00';
					}
				} else {
					$time = $timedata{'Hour'} . ':' . $timedata{'Minute'};
				}
				my $months = numbersToDays(\$timedata{'Month'},\'month');
				$$months =~ s/_/ /g;
				my $days = numbersToDays(\$timedata{'DOW'},\'dow');
				$$days =~ s/,/, /g;
				my $dom = $timedata{'DOM'};
				$dom = 'Every Day Of The Month' if ($dom =~ /\*/);
				my $togglebtn = "<button class=\"schedToggleBtn active\" onclick=\"scheduleStateChange(\'Disable\',\'$id\')\">Enabled<\/button>";
				my $editbtn = "<button class=\"schedListBtn edit\" title=\"Edit\" onclick=\"editSchedulePage(\'$id\')\"><\/button>";
				my $delbtn = "<button class=\"schedListBtn del\" title=\"Delete\" onclick=\"deleteSchedule(\'$id\')\"><\/button>";
				my $copybtn = "<button class=\"schedListBtn copy\" title=\"Copy\" onclick=\"copySchedule(\'$id\')\"><\/button>";
				if ($events{$id}{'active'} eq 'n') {
					$togglebtn = "<button class=\"schedToggleBtn inactive\" onclick=\"scheduleStateChange(\'Enable\',\'$id\')\">Disabled<\/button>";
				}

				my $stbnames = '';
				my @stbs = split(',',$events{$id}{'stbs'});
				foreach my $box (@stbs) {
					if (exists $stbdata{$box}) {
						my $name = $stbdata{$box}{'Name'} || '';
						if ($name) {
							if ($name =~ /^\s*\-\s*$/) {
								$stbnames .= " Unconfigured STB ,";
							} else {
								$stbnames .= " $name ,";
							}
						} else {
							$stbnames .= " Unconfigured STB ,";
						}
					} else {
						$stbnames .= " $box ,";
					}
				}

				$stbnames =~ s/\,$//;
				$stbnames =~ s/^ //;

				my $eventdata = $events{$id}{'commands'};
				$eventdata =~ s/,/, /g;
print <<SCHED;
	<div class="evSchedRow" onclick="evSchedRowHighlight(this)" title="Click to toggle highlight">
		<div class="evSchedRowSec"><p>$time</p></div>
		<div class="evSchedRowSec"><p>$dom</p></div>
		<div class="evSchedRowSec"><p>$$months</p></div>
		<div class="evSchedRowSec"><p>$$days</p></div>
		<div class="evSchedRowSec event"><p>$eventdata</p></div>
		<div class="evSchedRowSec targets"><p>$stbnames</p></div>
		<div class="evSchedRowSec">
			$editbtn
			$copybtn
			$delbtn
		</div>
		<div class="evSchedRowSec">
			$togglebtn
		</div>
	</div>
SCHED
			}
		}
	}
	print "</div>";
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
	my $headertext = 'Scheduled Event &#8594; Create';
	my $headertext2 = 'Use the sections below to build your new scheduled event';
	my $buttontext = 'Create!';
	my $onclick = 'newSchedValidate()';
	my ($active,$min,$hour,$dom,$month,$dow,$eventname,$boxes,$everymin);
	my $mintype = 'normal';		# 'normal' means event runs once at a certain time. This is default until changed.
	my $everyhrstart = '00';	# Used if the event runs every x minutes at a certain time
	my $everyhrend = '00';		# Same as above
	my @evhrs = ('00'..'23');
	$active = 'y';
	if ($event) {
		if ($$event) {
			my @info = split(/\s+/,$events{$$event}{'schedule'});
			($min,$hour,$dom,$month,$dow) = @info;
			$active = $events{$$event}{'active'};
			$eventname = $events{$$event}{'commands'};
			$boxes = $events{$$event}{'stbs'};

			if ($min =~ /\*\/(\d+)/) {
				$everymin = $1;
				$min = '';
				$mintype = 'every';	# Change $mintype to every to show that this event runs every x minutes
				if ($hour =~ /(\d+)-(\d+)/) {
					$everyhrstart = $1;
					$everyhrend = $2;
				} else {
					$everyhrstart = $hour;
					$everyhrend = $hour;					
				}
				$hour = '';
				@evhrs = ("$everyhrstart"..'23');
			}

			$dom = 'Every Day Of The Month' if ($dom =~ /\*/);
			$month = numbersToDays(\$month,\'month');
			$month = $$month;
			$dow = numbersToDays(\$dow,\'dow');
			$dow = $$dow;
			print "<input type=\"hidden\" name=\"$$event\" />";
			$headertext = 'Scheduled Event &#8594; Edit';
			$headertext2 = 'Use the sections below to update the scheduled event parameters';
			$buttontext = 'Update!';
			$onclick = "newSchedValidate(\'$$event\')";
		}
	}
	
print <<HEAD;
<div id="eventSchedulePageHolder">
	<div id="evSchedPageHeaderDiv">
		<h1>$headertext</h1>
	</div>
	<div id="eventScheduleInfoArea">
HEAD
	
	my @everymins = ('10'..'59');

	my @mins = ('00'..'59');
	my @hours = ('00'..'23');
	my @dom = ('Every Day Of The Month','01'..'31');
	my @months = ('Every Month','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec');
	my @dayoptions = ('Everyday','Mon-Fri','Sun-Thurs','Sat,Sun','Mon,Weds,Fri');
	my @days = qw/Mon Tues Weds Thurs Fri Sat Sun/;

	my $everymindata = $query->popup_menu(-id=>'everyminutes',-name=>'everyminutes',-values=>[@everymins],-default=>$everymin,-class=>'evSchedSelect');
	my $everyhrstartdata = $query->popup_menu(-id=>'everyhrstart',-name=>'everyhrstart',-values=>[@hours],-default=>$everyhrstart,-class=>'evSchedSelect',-onChange=>'eventScheduleEndHourControl()');
	my $everyhrenddata = $query->popup_menu(-id=>'everyhrend',-name=>'everyhrend',-values=>[@evhrs],-default=>$everyhrend,-class=>'evSchedSelect');

	my $mindata = $query->popup_menu(-id=>'minutes',-name=>'minutes',-values=>[@mins],-default=>$min,-class=>'evSchedSelect');
	my $hourdata = $query->popup_menu(-id=>'hours',-name=>'hours',-values=>[@hours],-default=>$hour,-class=>'evSchedSelect');
	my $domdata = $query->popup_menu(-id=>'dom',-name=>'dom',-values=>[@dom],-default=>$dom,-class=>'evSchedSelect');
	my $monthdata = $query->popup_menu(-id=>'month',-name=>'month',-values=>[@months],-default=>$month,-class=>'evSchedSelect');
	my $dayoptsdata = $query->popup_menu(-id=>'dayopts',-name=>'dayopts',-values=>[@dayoptions],-default=>$dow,-class=>'evSchedSelect');
	
	my $presetradio = "<input class=\"trigger radiooff\" type=\"radio\" name=\"dayOption\" value=\"dayPresets\" onchange=\"eventRadioSwitch()\">Day Presets";
	my $customradio = "<input class=\"trigger radiooff\" type=\"radio\" name=\"dayOption\" value=\"dayCustom\" onchange=\"eventRadioSwitch()\">Custom Days";

	my $preset = 'false';
	my $everyxminsradio = "<input class=\"trigger radiooff\" type=\"radio\" name=\"timeOption\" value=\"everyxmins\" onchange=\"eventRadioSwitch()\"/>";
	my $normalradio = "<input class=\"trigger radiooff\" type=\"radio\" name=\"timeOption\" value=\"normalmins\" onchange=\"eventRadioSwitch()\"/>";

	if ($event) {
		if ($$event) {
			foreach my $dayopts (@dayoptions) {
				if ($dow =~ /$dayopts/) {
					$preset = 'true';
				}
			}

			if ($preset =~ /false/) {
				$customradio = "<input class=\"trigger radioon\" type=\"radio\" name=\"dayOption\" value=\"dayCustom\" onchange=\"eventRadioSwitch()\" checked>Custom Days";
			} else {
				$presetradio = "<input class=\"trigger radioon\" type=\"radio\" name=\"dayOption\" value=\"dayPresets\" onchange=\"eventRadioSwitch()\" checked>Day Presets";
			}

			if ($mintype =~ /every/) {
				$everyxminsradio = "<input class=\"trigger radioon\" type=\"radio\" name=\"timeOption\" value=\"everyxmins\" onchange=\"eventRadioSwitch()\" checked/>Process repeats every (x) minutes";
			} else {
				if ($mintype =~ /normal/) {
					$normalradio = "<input class=\"trigger radioon\" type=\"radio\" name=\"timeOption\" value=\"normalmins\" onchange=\"eventRadioSwitch()\" checked/>Process runs once at the set time";
				}
			}
		}
	}

	my @dayshtml;
	foreach my $day (@days) {
		my $html = '<div class="evSchedSection dow">';
		if ($$event) {
			if ($preset =~ /true/) {
				$html .= "<p>$day</p><input class=\"dayOptsCheck\" type=\"checkbox\" name=\"dayCheck\" onchange=\"daysSelectedCheck()\" value=\"$day\">";
			} else {
				if ($dow =~ /$day/) {
					$html .= "<p>$day</p><input class=\"dayOptsCheck\" type=\"checkbox\" name=\"dayCheck\" onchange=\"daysSelectedCheck()\" value=\"$day\" checked>";
				} else {
					$html .= "<p>$day</p><input class=\"dayOptsCheck\" type=\"checkbox\" name=\"dayCheck\" onchange=\"daysSelectedCheck()\" value=\"$day\">";
				}
			}
		} else {
			$html .= "<p>$day</p><input class=\"dayOptsCheck\" type=\"checkbox\" name=\"dayCheck\" onchange=\"daysSelectedCheck()\" value=\"$day\">";
		}
		$html .= '</div>';
		push(@dayshtml,$html);
	}

print <<REPEAT;
<div class="evSchedSection processRepeat">
	<div class="evSchedSection halfInner">
		<div class="evSchedSection head main">
			$everyxminsradio
			<p>Repeat every x minutes</p>
		</div>
		<div class="evSchedSection third underHead masterTooltip" value="The minute interval to repeat the event">
			<div class="evSchedSection head">
				<p>Minute</p>
			</div>
			<div class="evSchedSection underHead">
				$everymindata
			</div>			
		</div>
		<div class="evSchedSection third underHead">
			<div class="evSchedSection head">
				<p>Start Hour</p>
			</div>
			<div class="evSchedSection underHead">
				$everyhrstartdata
			</div>			
		</div>
		<div class="evSchedSection third underHead masterTooltip" value="This hour is included. To stop at 4pm, the end hour would need to be 15 (3pm)">
			<div class="evSchedSection head">
				<p>End Hour</p>
			</div>
			<div class="evSchedSection underHead">
				$everyhrenddata
			</div>			
		</div>
	</div>
	<div class="evSchedSection halfInner" style="border-left:1px solid #cccccc;">
		<div class="evSchedSection head main">
			$normalradio
			<p>Run at set time</p>
		</div>
		<div class="evSchedSection quarter underHead">
			<div class="evSchedSection head">
				<p>Hour</p>
			</div>
			<div class="evSchedSection underHead">
				$hourdata
			</div>			
		</div>
		<div class="evSchedSection quarter underHead">
			<div class="evSchedSection head">
				<p>Minute</p>
			</div>
			<div class="evSchedSection underHead">
				$mindata
			</div>			
		</div>
		<div class="evSchedSection quarter underHead masterTooltip" value="Day Of Month">
			<div class="evSchedSection head">
				<p>DOM</p>
			</div>
			<div class="evSchedSection underHead">
				$domdata
			</div>			
		</div>
		<div class="evSchedSection quarter underHead">
			<div class="evSchedSection head">
				<p>Month</p>
			</div>
			<div class="evSchedSection underHead">
				$monthdata
			</div>			
		</div>
	</div>
</div>
REPEAT

print <<DAYOPTS;
<div class="evSchedSection dayOpts">
	<div class="evSchedSection third">
		<div class="evSchedSection head main">
			$presetradio
			<p>Preset Days</p>
		</div>
		<div class="evSchedSection underHead">
			$dayoptsdata
		</div>
	</div>
	<div class="evSchedSection twothirds" style="border-left:1px solid #cccccc;float:right;">
		<div class="evSchedSection head main">
			$customradio
			<p>Custom Days</p>
		</div>
		<div class="evSchedSection underHead">
			@dayshtml
		</div>
	</div>
</div>
DAYOPTS
	my @seqs = sort keys %sequences;
	my $seqlist = $query->popup_menu(-id=>'seqList',-name=>'seqList',-values=>[@seqs],-default=>$eventname,-class=>'evSchedSelect skinny');
	my $addseqbtn = "<button id=\"addEvSchedSeqButton\" onclick=\"addSeqSequence()\">Add Sequence</button>";

print <<SEQS;
<div class="evSchedSection seqs">
	<div class="evSchedSection seqHead">
		<p>Sequence Selection</p>
	</div>
	<div class="evSchedSection seqHead smaller">
		<p>Select a sequence from the drop down menu and click "ADD" to add it to the sequence area</p>
	</div>
	<div class="evSchedSection seqBody">
		<div class="evSchedSection twothirds">
			<div id="sequenceEventArea" contenteditable="true">
			</div>
		</div>
		<div class="evSchedSection third">
			<button id="clearEvSeqAreaBtn" onclick="clearSchedSeqArea('sequenceEventArea')">Clear All</button>
			<div class="evSchedSection seqHead" style="text-align:center;">
				<p>Sequences</p>
			</div>
			<div class="evSchedSection underHead" style="text-align:center;">
				$seqlist
				$addseqbtn
			</div>
		</div>
	</div>
</div>
SEQS

	my @groups = sort keys %groups;
	my $grouplist = $query->popup_menu(-id=>'groupList',-name=>'groupList',-values=>[@groups],-class=>'evSchedSelect skinny');
	my $addgrpbtn = "<button id=\"addEvSchedGroupButton\" onclick=\"addSeqGroup()\">Add Group</button>";

print <<GROUPS;
<div class="evSchedSection groups">
	<div class="evSchedSection seqHead">
		<p>STB/Group Selection</p>
	</div>
	<div class="evSchedSection seqHead smaller">
		<p>Click on a STB from the grid to the right to add it to the Target STB list</p>
	</div>
	<div class="evSchedSection seqBody">
		<div class="evSchedSection twothirds">
			<div id="sequenceArea" class="eventGroupArea" contenteditable="true" style="float:none;">
			</div>
		</div>
		<div class="evSchedSection third">
			<button id="clearEvGroupAreaBtn" onclick="clearSeqArea('sequenceArea')">Clear All</button>
			<div class="evSchedSection seqHead" style="text-align:center;">
				<p>STB Groups</p>
			</div>
			<div class="evSchedSection underHead" style="text-align:center;">
				$grouplist
				$addgrpbtn
			</div>
		</div>
	</div>
</div>
<input type="hidden" id="eventActive" value="$active">
<button id="scheduledEventSubmitBtn" class="newSeqSubmit" onclick="$onclick">$buttontext</button>
GROUPS
	print '</div>';	# End of div 'eventScheduleInfoArea'

	###### Print the STB Grid for STB selection
        if (-e $stbdatafile) {
                my $conffile = $confdir . 'stbGrid.conf';
                open FH,"<",$conffile or die "Couldn't open $conffile for reading: $!\n";
                chomp(my @confdata = <FH>);
                close FH;
                my $confdata = join("\n", @confdata);
                my ($columns) = $confdata =~ m/columns\s*\=\s*(\d+)/;
                my ($rows) = $confdata =~ m/rows\s*\=\s*(\d+)/;

		my $divwidth = '200';
        	my $widcnt = '1';
        	until ($widcnt == $columns or $divwidth >= 1150) {
                	$divwidth = $divwidth + 110;
                	$widcnt++;
        	}
        	if ($divwidth > 1100) {
                	$divwidth = '1150';
        	} else {
                	$divwidth = $divwidth + 50;
        	}
	
        	my $fullcoll = $columns+42;
        	my $btnwidth = ($divwidth-$fullcoll)/$columns;
        	my $btnstyle = 'width:' . $btnwidth . 'px;';
        	$divwidth .= 'px';

print <<HEAD;
<div id="eventScheduleGridArea">
	<div id="stbSelect" style="margin-top:0;">
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
				my $onclick;
                        	my $buttontext;
                        	if (exists $stbdata{$id}) {
                        	} else {
                        		%{$stbdata{$id}} = ();
                        	}

				if ((exists $stbdata{$id}{'Name'}) and ($stbdata{$id}{'Name'} =~ /\S+/)) {
                                	$buttontext = $stbdata{$id}{'Name'};
					if ($buttontext =~ /^\s*(:|-)\s*$/) {
						$onclick = '';
					} else {
						$onclick = "onclick\=\"seqTextUpdate\(\'$id\'\,\'$buttontext\'\)\"";
					}
                            	} else {
                                	$buttontext = '-';
					$onclick = '';
                         	}

print <<BOX;
<button name="$name" id="$id" class="stbButton data" $onclick style="$btnstyle">$buttontext</button>
BOX
				
				$stbno++;
                                $c++;
                   	}

print <<ROWEND;
<button id="Row $r" class="gridButton row inactive">$r</button></div>
ROWEND

                   	$r++;
          	}

print <<LAST;
				</div>
			</div>
		</div>
	</div>
</div>
LAST

        } else {
                print "<font size=\"5\" color=\"red\">No STB Database found. Have you setup your STB Controller Grid yet?<\/font>";
        }
} # End of sub 'createEvSched'

sub checkLegacy {
        if (!-e $eventsjsonfile and !-e $eventsfile) {
                ##### If no event schedule files exist, we can start off with JSON straight away
                $eventsfile = $eventsjsonfile;
                return;
        } elsif (-e $eventsjsonfile) {
                ##### If the new file format already exists, update the $eventsfile variable to use
                $eventsfile = $eventsjsonfile;
                return;
        }

        ##### If the checks get this far, we need to convert the old event schedule to the new JSON format
        if (-e $eventsfile) {
                my %newjson;
                tie my %temp, 'Tie::File::AsHash', $eventsfile, split => ':' or die "Problem tying \%temp to $eventsfile for conversion in " . __FILE__ . ": $!\n";
                if (%temp) {
                        foreach my $old (sort keys %temp) {
				my @bits = split('\|',$temp{$old});
				my ($active,$mins,$hours,$dom,$month,$dow,$commands,$stbs) = @bits;
                                %{$newjson{$old}} = (	'active' => $active,
                                			'schedule' => "$mins $hours $dom $month $dow",
                                			'commands' => $commands,
                                			'stbs' => $stbs
                                			);
                        }

                        if (%newjson) {
                                my $json = JSON->new->allow_nonref;
                                $json = $json->canonical('1');
                                my $encoded = $json->pretty->encode(\%newjson);
                                if (open my $newfh, '+>', $eventsjsonfile) {
                                        print $newfh $encoded;
                                        close $newfh;
                                } else {
                                        die "Failed to open file $eventsjsonfile for writing in conversion in file " . __FILE__ . " :$!\n";
                                }
                        }
                }
                untie %temp;
        }
}
