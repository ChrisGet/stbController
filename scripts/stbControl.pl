#!/usr/bin/perl -w

use strict;
use JSON;
use Fcntl ':flock';
use CGI;
use Tie::File::AsHash;
use Time::HiRes qw (sleep);
use FindBin qw($Bin);
use Digest::MD5 qw(md5 md5_hex md5_base64);

chomp(my $fullpath = $ARGV[3] || '');
my $maindir;
BEGIN {
if ($fullpath) {
	$maindir = $fullpath;
	chomp($maindir);
} else {
	if ($Bin) {
                $maindir = $Bin;
                $maindir =~ s/\/\w+\/*$//;
        } else {
                chomp($maindir = (`cat homeDir.txt` || ''));
                $maindir =~ s/\/$//;
        }
}
die "Couldn't find where my main files are installed. No \"stbController\" directory was found on your system...\n" if (!$maindir);
}

use lib "$maindir/scripts";
use RedRat::RedRatHub qw(openSocket sendMessage closeSocket readData);

$|++;

my $query = CGI->new;
print $query->header();

fork and exit;

my $filedir = $maindir . '/files/';
my $confdir = $maindir . '/config/';
my $runningpids = $filedir . '/pidsRunning/';
my $seqrundir = $filedir . '/sequencesRunning/';
my $groupsfile = $filedir . 'stbGroups.json';
my $seqfile = $filedir . 'commandSequences.json';
my $pidfile = $filedir . 'scheduler.pid';
my $stbdatafile = $confdir . 'stbData.json';
my $archfile = $filedir . 'hostArchitecture.txt';
my $redrathubdir = $maindir . '/RedRatHub-V5.11/';
my $redrathubip = '';

my ($dayname,$mon,$daynum,$time,$year) = split(/\s+/,localtime(time));
my $ts = "$time";
my $logts = "$daynum-$mon-$year $time";

my $json = JSON->new->allow_nonref;
$json = $json->canonical('1');

my %stbdata;
if (-e $stbdatafile) {
        local $/ = undef;
        open my $fh, "<", $stbdatafile or die "$logts - ERROR: Unable to open $stbdatafile: $!\n";
        my $data = <$fh>;
	if ($data) {
	        my $decoded = $json->decode($data);
        	%stbdata = %{$decoded};
	}
}

##### Load the groups data
my %groups;
if (-e $groupsfile) {
        local $/ = undef;
        open my $fh, "<", $groupsfile or die "$logts - ERROR: Unable to open $groupsfile: $!\n";
        my $data = <$fh>;
	if ($data) {
	        my $decoded = $json->decode($data);
        	%groups = %{$decoded};
	}
}

##### Load the sequences data
my %seqs;
if (-e $seqfile) {
        local $/ = undef;
        open my $fh, "<", $seqfile or die "$logts - ERROR: Unable to open $seqfile: $!\n";
        my $data = <$fh>;
	if ($data) {
	        my $decoded = $json->decode($data);
        	%seqs = %{$decoded};
	}
}

chomp(my $action = $ARGV[0] // $query->param('action') // '');
chomp(my $command = $ARGV[1] // $query->param('command') // '');
chomp(my $info = $ARGV[2] // $query->param('info') // '');
chomp(my $logpid = $ARGV[4] || '');	# $logpid will only ever be used by the backend eventScheduleControl.pl script
my $logging = '';
my $schedpid = '';

die "$logts - Error: No action was specified. Options are \"Control\" or \"Event\"\n" if ($action !~ m/^Control$|^Event$/i);
die "$logts - No STBs Selected" if (!$info);

if ($logpid) {
	if ($logpid =~ /^logpid$/i) {
		$logging = 1;
		chomp($schedpid = `cat $pidfile` // '');
                $schedpid =~ s/\s+//g if ($schedpid);
	}
}

if ($logging) {		# Log the pid of this main script if logging has been requested
	my $pidlog = $runningpids . $$;
	system("touch $pidlog")
}

my @targetsraw = split(',',$info);
my $targetstring = '';

#### Below we separate the target STB input ($info) and process each item to see whether it is a group or a single STB

foreach my $target (@targetsraw) {
	$target = uc($target);
	if (exists $groups{$target}) {
		my @members = split(',',$groups{$target}{'stbs'});
		foreach my $member (@members) {
			$targetstring .= "$member,";
		}
	} else {
		$targetstring .= "$target,";
	}
}

#### End of processing the target STB input ($info)

if (!$targetstring or $targetstring !~ /\S+/) {
	if ($logging) {
		my $pidlog = $runningpids . $$;
		system("rm $pidlog")
	}
	die "$logts - No STBs selected for control after processing the input\n";
}

if ($action =~ m/^Event$/i) {
	my @sequences = split(',',$command);
	my $seqcoms = '';
	foreach my $seq (@sequences) {
		$seq = uc($seq);
		warn "$logts - Sequence $seq was not found in the sequences file\n" and next if (!exists $seqs{$seq});
		$seqcoms .= $seqs{$seq}{'commands'};
		$seqcoms .= ',';
	}

	control(\$seqcoms,\$targetstring,\$command);
}

if ($action =~ m/^Control$/i) {
	control(\$command,\$targetstring);
}

if ($logging) {
	my $pidlog = $runningpids . $$;
	system("rm $pidlog")
}

sub control {
	my ($commands,$boxes,$sequence) = @_;	# All input args are scalar references at this point
	my @stbs = split (',', $$boxes);			
	my %duskydata;
	my %irnetboxiv;

	# Create the md5 string of this control request for later use
	my $procstring = "$commands" . $$boxes . "$ts";
	my $md5 = md5_hex($procstring);
	my $boxnamestring = '';
	foreach my $stb (@stbs) {
		if (exists $stbdata{$stb}{'Name'}) {
			$boxnamestring .= $stbdata{$stb}{'Name'} . ',';
		}
	}
	$boxnamestring =~ s/,$//;
	my $numstbs = scalar @stbs;

	# Log this sequence run details
	my $seqlogfile = $seqrundir . $md5;
	if ($sequence and $$sequence and !$logging) {			# If $sequence is defined and $logging is not (so has not been run from the scheduler), log the sequence control md5
		if (open my $fh, '+>', $seqlogfile) {
			print $fh "$ts >> " . $$sequence . " >> $numstbs >> $boxnamestring";
			close $fh;
		}
	}

	foreach my $stb (@stbs) {
		my %boxdata = %{ $stbdata{$stb}};		# Get the box details from the main %stbData hash 
		my $type = $boxdata{'Type'} || '';		# Get the 'Type' for the STB to know what kind of control it uses (Dusky, Bluetooth, or IR)
		warn "$logts - Error: Could not find control protocol for $stb, has this STB had its control type configured?\n" and next if (!$type);

		if ($type =~ /Dusky/) {		# If the STB is controlled via Dusky and Moxa, add it to the %duskydata hash for separate processing
			my $moxaip = $boxdata{'MoxaIP'};
                        my $moxaport = $boxdata{'MoxaPort'};
                        my $duskyport = $boxdata{'DuskyPort'};
			my $name = $boxdata{'Name'};
			my $duskyinfo = $moxaip . '-' . $moxaport;
			$duskydata{$duskyinfo}{$stb}{'Name'} = $name;
			$duskydata{$duskyinfo}{$stb}{'DuskyPort'} = $duskyport;
		} elsif ($type =~ /IRNetBoxIV/) {
			my $irnbip = $boxdata{'IRNetBoxIVIP'};
			my $irnbout = $boxdata{'IRNetBoxIVOutput'};
			my $type = $boxdata{'Type'};
			my $hw = 'skyq';	# Identify the hardware type from the box type data
			if ($type) {
				if ($type =~ /\(SkyQ\)/i) {
					$hw = 'skyq';
				} elsif ($type =~ /\(Sky\+\)/i) {
					$hw = 'sky+';
				} elsif ($type =~ /\(QSoIP UK\)/i) {
					#$hw = 'qsoip_uk';
					$hw = 'qsoip_all';
				} elsif ($type =~ /\(QSoIP DE\/IT\)/i) {
					#$hw = 'qsoip_de_it';
					$hw = 'qsoip_all';
				} elsif ($type =~ /\(Now\s*TV\)/i) {
					##### First set the hardware type ($hw) to generic nowtv
					$hw = 'nowtv';
					if (exists $boxdata{'IRNetBoxIVNowTVModel'}) {
						##### If this STB has the NOW TV Model defined, set that as the specific hardware type
						if ($boxdata{'IRNetBoxIVNowTVModel'} and $boxdata{'IRNetBoxIVNowTVModel'} !~ /Please Choose/i) {
							$hw .= $boxdata{'IRNetBoxIVNowTVModel'};
							##### Format the NOW TV Model text to lower case with no spaces
							##### "nowtvSmart Box 4631UK" becomes "nowtvsmartbox4631uk" for RedRatHub reference
							$hw = lc($hw);
							$hw =~ s/\s+//g;
						}
					}
				}
			}
			$irnetboxiv{$irnbip}{$hw}{'outputs'} .= "$irnbout,";
		} else {
			my $pid = fork;
        		if ($pid==0) {
				# Fork the sendComms sub for each stb, inputting the stb, commands, and %boxdata for it
				if ($logging) {
                        	        $0 = "stbControl(Scheduler-$schedpid) - $stb - $type";
	                        } else {
        	                        $0 = "stbControl - $stb - $type - master ID $md5";
                	        }
				sendBTComms(\$stb,$commands,\%boxdata,\$logging,\$runningpids) if ($type =~ /Bluetooth/);
				#sendIRNetBoxIVComms(\$stb,$commands,\%boxdata,\$logging,\$runningpids) if ($type =~ /IRNetBoxIV/);
				sendVNCCommsLegacy(\$stb,$commands,\%boxdata,\$logging,\$runningpids) if ($type =~ /Network \(Sky|Network \(QSoIP/);
				sendVNCCommsNew(\$stb,$commands,\%boxdata,\$logging,\$runningpids) if ($type =~ /Network VNC Port 5900/);
				sendNowTVNetwork(\$stb,$commands,\%boxdata,\$logging,\$runningpids) if ($type =~ /Network \(NowTV/);
				sendGlobalCacheIRNowTV(\$stb,$commands,\%boxdata,\$logging,\$runningpids) if ($type =~ /GlobalCache \(NowTV/);
				sendGlobalCacheIRSkyQ(\$stb,$commands,\%boxdata,\$logging,\$runningpids) if ($type =~ /GlobalCache \(SkyQ/);
	                	exit;
	        	}
		}
	}

	#### Now deal with the dusky controlled STBs
	if (%duskydata) {
		foreach my $dusky (keys %duskydata) {
			my $duskycount = scalar keys %{$duskydata{$dusky}};
			my $pid = fork;
			if ($pid==0) {
				if ($logging) {
					$0 = "stbControl(Scheduler-$schedpid) - $duskycount Dusky STBs on Moxa $dusky";
				} else {
					$0 = "stbControl - $duskycount Dusky STBs on Moxa $dusky - master ID $md5";
				}
				sendDuskyCommsNew(\$dusky,$commands,$duskydata{$dusky},\$logging,\$runningpids);
				exit;
			}
		}
	}

	### Now deal with IRNetBoxIV controlled STBs
	if (%irnetboxiv) {
		my $rres = checkRedRatHub();
		if (!$rres) {
			foreach my $nbiv (keys %irnetboxiv) {
				my %hwdata = %{$irnetboxiv{$nbiv}};
				foreach my $hwtype (keys %hwdata) {
					my $outs = $hwdata{$hwtype}{'outputs'};
					my $pid = fork;
					if ($pid==0) {
						if ($logging) {
							$0 = "stbControl(Scheduler-$schedpid) - IRNetBoxIV at $nbiv for hardware $hwtype to outputs $outs";
						} else {
							$0 = "stbControl - IRNetBoxIV at $nbiv for hardware $hwtype to outputs $outs - master ID $md5";
						}
						sendIRNetBoxIVComms($nbiv,$commands,$hwtype,$outs,$logging,$runningpids);
						exit;
					}
				}
			}
		}
	}

	##### Wait for all child processes to complete
	while (wait() != -1) { print "\0";}
	if (-e $seqlogfile) {
		unlink $seqlogfile;
	}
	#warn "STB Control Finished!\n";	# Enable for debug!
} ## End of sub 'control'

sub sendDuskyCommsNew {
	use IO::Socket::INET;
	my ($duskydetails,$commands,$boxdata,$logging,$runningpids) = @_;
	if ($$logging) {
		my $logpid = $$runningpids . $$;
		system("touch $logpid");
	}
	my @commands = split(',', $$commands);
	my $duskycomfile = $filedir . 'skyDuskyCommands.txt';

	tie my %duskycoms, 'Tie::File::AsHash', $duskycomfile, split => ':' or die "Problem tying \%duskycoms to $duskycomfile: $!\n";	# Tie the %group hash to the groups file for quick group member lookup

	my ($moxaip,$moxaport) = $$duskydetails =~ /(\S+)\-(\d+)/;
	if (!$moxaip) {
		die "$logts - ERROR: Moxa IP was not defined!\n";
	} elsif (!$moxaport) {
		die "$logts - ERROR: Moxa Port was not defined!\n";
	} else {

		my $tries = '1';
		my $dusky = '';
		until (($dusky) or ($tries >= '5')) {
			$dusky = new IO::Socket::INET(PeerAddr => $moxaip, PeerPort => $moxaport, Proto => 'tcp', Timeout => 2);
			$tries++;
		}

		if ($dusky) {
			foreach my $com (@commands) {
                		if ($com =~ m/^t(\d+)$/i) {
                        		sleep $1;
	                        	next;
        	        	}

                		my $raw = $duskycoms{$com};
                		unless(defined $raw) {          # 'defined' needs to be used to handle '0' value for the STB command
	                        	warn "$logts - $com was not found to be a valid command\n" and next;     # If the requested command is not found in the commands database, print a warning and skip to the next command
        	        	}

				foreach my $box (keys %{$boxdata}) {
					my $name = $$boxdata{$box}{'Name'};
					my $duskyport = $$boxdata{$box}{'DuskyPort'};
					my $fullcom = 'A+' . $duskyport . $raw . 'x';
					$dusky->send($fullcom);
					sleep(0.15);	# Sleep breifly to allow Dusky to process the command
				}
			}
			$dusky->close;
		} else {
			warn "$logts - Failed to connect to dusky at IP $moxaip port $moxaport\n";
		}
	}

	untie %duskycoms;

	if ($$logging) {
		my $logpid = $$runningpids . $$;
		system("rm $logpid");
	}
}

sub sendDuskyComms {
	use IO::Socket::INET;
	my ($stb,$commands,$boxdata,$logging,$runningpids) = @_;
	if ($$logging) {
		my $logpid = $$runningpids . $$;
		system("touch $logpid");
	}
	my @commands = split(',', $$commands);
	my $duskycomfile = $filedir . 'skyDuskyCommands.txt';
	my $moxaip = $$boxdata{'MoxaIP'};
	my $moxaport = $$boxdata{'MoxaPort'};
	my $duskyport = $$boxdata{'DuskyPort'};

	tie my %duskycoms, 'Tie::File::AsHash', $duskycomfile, split => ':' or die "Problem tying \%duskycoms to $duskycomfile: $!\n";	# Tie the %group hash to the groups file for quick group member lookup

	foreach my $com (@commands) {
		if ($com =~ m/^t(\d+)$/i) {
			sleep $1;
			next;
		}
		my $tries = '1';
		my $dusky = '';
		until (($dusky) or ($tries >= '50')) {
			$dusky = new IO::Socket::INET(PeerAddr => $moxaip, PeerPort => $moxaport, Proto => 'tcp', Timeout => 3);
			sleep 1;
			$tries++;
		}

		if ($dusky) {
			my $raw = $duskycoms{$com};
			unless(defined $raw) {		# 'defined' needs to be used to handle '0' value for the STB command
				warn "$logts - $com was not found to be a valid command\n" and next;	# If the requested command is not found in the commands database, print a warning and skip to the next command
			}
			my $fullcom = 'A+' . $duskyport . $raw . 'x';
			$dusky->send($fullcom);
			$dusky->close;
		} else {
			warn "$logts - ERROR: Dusky connection failed for $$stb\n";
		}
	}

	untie %duskycoms;

	if ($$logging) {
		my $logpid = $$runningpids . $$;
		system("rm $logpid");
	}
}

sub sendBTComms {
	use LWP::UserAgent;
	use HTTP::Request;
	my ($stb,$commands,$boxdata,$logging,$runningpids) = @_;
	if ($$logging) {
		my $logpid = $$runningpids . $$;
		system("touch $logpid");
	}
	my @commands = split(',',$$commands);
	my $btcomfile = $filedir . 'skyBTUSBCommands.txt';
	my $serverip = $$boxdata{'BTContIP'};
	my $serverport = $$boxdata{'BTContPort'};
	tie my %btcoms, 'Tie::File::AsHash', $btcomfile, split => ':' or die "$logts - ERROR: Problem tying \%btcoms to $btcomfile: $!\n";
        foreach my $command (@commands) {
                if ($command =~ /^t(\d+)/i) {
                        sleep $1;
                        next;
                }
		my $basecom = $btcoms{$command};
		unless (defined $basecom) {		# 'defined' needs to be used to handle '0' value for the STB command
			warn "$logts - ERROR: $command is not a valid command for $$stb\n" and next;
		}
                my $json = "\{\"action\"\:\"press\"";
		my $comtosend;
                if ($basecom =~ /^(TouchPad|TrickPlaySlider|Hid)\s*(.+)$/i) {
                        $comtosend = $1;
                        $json = $2;
                } else {
			$comtosend = $basecom;
                        $json .= "\,\"duration\"\:\"0.1\"";
                }

                $json .= '}';

my $uri = <<URI;
http://$serverip:8000/v0.0.0/$serverport/$comtosend
URI

                my $ua = new LWP::UserAgent;
		$ua->timeout(3);
                my $request = new HTTP::Request('POST',$uri);
                $request->header( 'Content-Type' => 'application/json' );
                $request->content( $json );

                my $response = $ua->request($request);

                if ($response->is_success) {
                        my $stuff = $response->code . " " . $response->message;
                } else {
                        my $stuff = $response->code . " " . $response->message;
                        warn "PID $$: Failed to send \"$command\" to STB \"$$stb\" on port $serverport at RCES server $serverip: $stuff\n";
                }
        }
	untie %btcoms;

	if ($$logging) {
		my $logpid = $$runningpids . $$;
		system("rm $logpid");
	}
}

sub sendIRNetBoxIVComms {
	my ($netboxip,$commands,$hwtype,$outputs,$logging,$runningpids) = @_;
	if ($logging) {
		my $logpid = $runningpids . $$;
		system("touch $logpid");
	}

	$outputs =~ s/,$//;

	if (!$redrathubip) {	# Check that the IP address for the RedRatHub process has been found, die if it hasn't
		die "$logts - ERROR: RedRatHub IP was not defined!\n";
	}
	
	&openSocket($redrathubip, 40000);

	my @commands = split(',',$$commands);

	my $rrres = '';
	$rrres = &readData('hubquery="list redrats"');
	#warn "$rrres\n";
	if ($rrres) {
		if ($rrres !~ m/$netboxip/) {
			$rrres = &readData('hubquery="add redrat" ip="' . $netboxip . '"');
			$rrres =~ s/\n|\r//g;
			if ($rrres =~ /Failed/i) {
				warn "$logts - Failed to add RedRat $netboxip to RedRatHub - $rrres\n";
			}
		}# else {
		#	warn "$netboxip already added\n";
		#}
	}
	$rrres = &readData('hubquery="connect redrat" ip="' . $netboxip . '"');
	#warn "Connect to RedRat $netboxip - $rrres\n";
	
        my $comfile = $filedir . 'skyQIRNetBoxIVCommands.txt';
        if ($hwtype =~ /nowtv/) {
		my $newfile = $filedir . $hwtype . 'IRNetBoxIVCommands.txt';
        	if (-e $newfile) {
			$comfile = $newfile;
        	} else {
			$comfile = $filedir . 'nowTVIRNetBoxIVCommands.txt';
		}
        } elsif ($hwtype =~ /qsoip/) {
		if ($hwtype =~ /uk/) {
			$comfile = $filedir . 'skySoipUKIRNetBoxIVCommands.txt';
		} elsif ($hwtype =~ /de_it/) {
			$comfile = $filedir . 'skySoipDEITIRNetBoxIVCommands.txt';
		} elsif ($hwtype =~ /all/) {
			$comfile = $filedir . 'skySoipAllIRNetBoxIVCommands.txt';
		}
	}
        
	tie my %ircoms, 'Tie::File::AsHash', $comfile, split => ':' or die "$logts - ERROR: Problem tying \%ircoms: $!\n";

        foreach my $command (@commands) {
                if ($command =~ /^t(\d+)/i) {
                        sleep $1;
                        next;
                }
		if (exists $ircoms{$command}) {
			my $sig = $ircoms{$command};
			#warn "$netboxip - $hwtype - $sig\n";
			my $res = &readData('ip="' . $netboxip . '" dataset="' . $hwtype . '" signal="' . $sig . '" output="' . $outputs . '"');
			#warn "$res\n";
			if ($res and $res !~ /OK/) {
				warn "$logts - ERROR: Failed to send command $command to IRNetBoxIV at $netboxip - $res\n";
			}
		} else {
			warn "$logts - ERROR: No entry found for $command\n";
		}
	}
	# To be determined

	if ($logging) {
		my $logpid = $runningpids . $$;
		system("rm $logpid");
	}
	&readData('hubquery="disconnect redrat" ip="' . $netboxip . '"');
	untie %ircoms;
}

sub sendVNCCommsLegacy {
	use IO::Socket::INET;
	my ($stb,$commands,$boxdata,$logging,$runningpids) = @_;
        if ($$logging) {
                my $logpid = $$runningpids . $$;
                system("touch $logpid");
        }

	my $ip = $$boxdata{'VNCIP'};
	my $mac = $$boxdata{'MAC'} // '';	# This will be used for WakeOnLAN

	if ($$commands =~ /wakeonlan/) {
		## Send 2 wakeonlan packets
		# First to the recorded IP of the box
		wakeonlan($$stb,$mac,$ip,'9');
		sleep 1;
		# Second WOL packet to the broadcast address of the recorded IP
		(my $bcast = $ip) =~ s/\.\d{1,3}$/\.255/;	# Substitute the last octect of the STB IP with 255
		wakeonlan($$stb,$mac,$bcast,'9');
		sleep 1;
	}

	my $port = '49160';
	my $string = "SKY 000.001\n";
	my $keytype = '4';
	my $keydown = '1';
	my $keyup = '0';
	my @commands = split(',', $$commands);
        my $comfile = $filedir . 'skyVNCCommands.txt';
	my $socket = new IO::Socket::INET (
			PeerHost => $ip,
			PeerPort => $port,
			Proto => 'tcp',
			Timeout => 2,
	);	
	unless ($socket) {
		if ($$logging) {
                	my $logpid = $$runningpids . $$;
        	        system("rm $logpid");
	        }
		die "$logts - ERROR: Cannot connect to $$stb for Legacy Network control at IP $ip, Port $port: $!\n";
	}

	tie my %vnckeys, 'Tie::File::AsHash', $comfile, split => ':' or die "$logts - ERROR: Problem tying \%vnckeys: $!\n";

	$socket->autoflush(1);
	$socket->setsockopt(SOL_SOCKET, SO_RCVTIMEO, pack('l!l!', 2, 0));
	
	# Add the socket option SO_LINGER so that it sends RST instead of FIN when finished
	my $linger = pack("ii", 1, 0);
	$socket->setsockopt(SOL_SOCKET, SO_LINGER, $linger);

	my $stuff = '';
	$socket->recv($stuff,12);
	$socket->send($string);
	$stuff = '';
	$socket->recv($stuff,12);
	if ($stuff) {
		my $num = '1';
		my $tosend = pack("C",$num);
		my $new = '';
		$socket->send($tosend);	# Send '01' to the STB for security selection
		$socket->recv($new,12);	# Receive security response from STB in to $new
		if ($new) {
			$new = '';
			$socket->send($tosend);	# Send '01' to the STB again for client init message
			$socket->recv($new,64);	# Receive server init message back from STB in to $new
			if ($new) {	# If all is good up to here, send the commands!
				foreach my $com (@commands) {
					if ($com =~ /^t(\d+)/i) {
						sleep $1;
					} elsif ($com =~ /^app/) {
						soipAppCall($ip,$com); 
					}else {
						my $ds = '';
						if ($com =~ /passive/i) {
							$ds = 1;
							$com = 'power';
						}
						if ($com eq 'wakeonlan') {
							next;
						}
						if (exists $vnckeys{$com}) {
							my ($first,$last) = process(\$vnckeys{$com});
							my $kdown = pack "C*", $keytype,$keydown,0,0,0,0,$first,$last;
							my $kup = pack "C*", $keytype,$keyup,0,0,0,0,$first,$last;
							$socket->send($kdown);
							sleep 10 if ($ds);
							$socket->send($kup);
						} else {
							warn "$logts - ERROR: $com not found in the file $comfile\n";
						}
					}
				}
			} else {
				warn "$logts - ERROR: No response from $$stb during Legacy VNC handshake (Client/Server Init Exchange) at IP $ip, Port $port.\n";
			}
		} else {
			warn "$logts - ERROR: No response from $$stb during Legacy VNC handshake (Security Exchange) at IP $ip, Port $port.\n";
		}
	} else {
		warn "$logts - ERROR: No response from $$stb during Legacy VNC handshake (Protocol Exchange) at IP $ip, Port $port.\n";
	}	

	sleep(0.5);	# This is VERY IMPORTANT! This timeout makes control MUCH more reliable as it allows the devices to process the key presses before disconnecting
        $socket->shutdown(2);
	sleep(0.5);
        $socket->close();
	untie %vnckeys;

	if ($$logging) {
                my $logpid = $$runningpids . $$;
                system("rm $logpid");
        }

	sub process {
		my ($in) = @_;
		$$in =~ s/^0x//;
		my ($first,$last) = unpack('a2 a2',$$in);
		$first = '0x'.$first;
		$last = '0x'.$last;
		$first = eval $first;
		$last = eval $last;
		return ($first,$last);
	}
}

sub sendVNCCommsNew {
	my ($stb,$commands,$boxdata,$logging,$runningpids) = @_;
        if ($$logging) {
                my $logpid = $$runningpids . $$;
                system("touch $logpid");
        }

        my $ip = $$boxdata{'VNCIP'};
        my $mac = $$boxdata{'MAC'} // '';       # This will be used for WakeOnLAN

        if ($$commands =~ /wakeonlan/) {
                ## Send 2 wakeonlan packets
                # First to the recorded IP of the box
                wakeonlan($$stb,$mac,$ip,'9');
                sleep 1;
                # Second WOL packet to the broadcast address of the recorded IP
                (my $bcast = $ip) =~ s/\.\d{1,3}$/\.255/;       # Substitute the last octect of the STB IP with 255
                wakeonlan($$stb,$mac,$bcast,'9');
                sleep 1;
        }

        my @commands = split(',', $$commands);
        my $comfile = $filedir . 'skyVNCCommandsPort5900.txt';
        my $keytype = '4';
        my $keydown = '1';
        my $keyup = '0';

        my $port = '5900';
        my $socket = new IO::Socket::INET (
                        PeerHost => $ip,
                        PeerPort => $port,
                        Proto => 'tcp',
                        Timeout => 3,
        );
        unless ($socket) {
                if ($$logging) {
			my $logpid = $$runningpids . $$;
                        system("rm $logpid");
                }
                die "$logts - ERROR: Cannot connect to $$stb for port 5900 Network control at IP $ip, Port $port: $!\n";
        }

        $socket->autoflush(1);
        $socket->setsockopt(SOL_SOCKET, SO_RCVTIMEO, pack('l!l!', 2, 0));

        my $stuff = '';
        $socket->recv($stuff,12);
        $socket->send($stuff);
        $socket->recv($stuff,1);
        $socket->send(pack "H*", '01');
        $socket->recv($stuff,12);
        $socket->send(pack "H*", '01');
	sleep(0.3);	# Wait 0.3 seconds after connection before sending commands
	
        tie my %vnckeys, 'Tie::File::AsHash', $comfile, split => ':' or die "Problem tying \%vnckeys: $!\n";

        foreach my $com (@commands) {
                if ($com =~ /^t(\d+)/i) {
                        sleep $1;
		} elsif ($com =~ /^app/) {
			soipAppCall($ip,$com); 
                } else {
                        my $ds = '';
                        if ($com =~ /passive/i) {
                                $ds = 1;
                                $com = 'power';
                        }
                        if ($com eq 'wakeonlan') {
                                next;
                        }
                        if (exists $vnckeys{$com}) {
                                my $k = $vnckeys{$com};
                                $k = '0x' . $k if ($k !~ /^0x/);
                                $k =~ s/^0x/0000/;
                                $k = lc($k);

                                my $kdown = '04010000' . $k;
                                my $kdown2 = pack "H*", $kdown;

                                my $kup = '04000000' . $k;
				my $kup2 = pack "H*", $kup;

                                $socket->send($kdown2);
                                $socket->send($kup2);
                        } else {
                                warn "$logts - ERROR: $com not found in the file $comfile\n";
                        }
                }
        }

	sleep(0.5);
        $socket->shutdown(2);
	sleep(0.5);
        $socket->close();

        untie %vnckeys;

        if ($$logging) {
                my $logpid = $$runningpids . $$;
                system("rm $logpid");
        }
}

sub checkRedRatHub {
	my $redrathubdll = $redrathubdir . 'RedRatHub.dll';
	my $dotnetbin = 'dotnet';
	my $redrathubdebug = $filedir . '/RedRatHubDebug.txt';
	chomp(my $arch = `cat $archfile` // '');
	if ($arch) {
		$dotnetbin = $maindir . "/dotnet$arch" . '/dotnet';
	} else {
		die "$logts - CRITICAL ERROR: Unable to identify host architecture for checking RedRatHub process in stbControl.pl\n";
	}

	chomp(my $running = `ps -ax | grep "stbController-RedRatHubProcess" | grep -v grep` // '');
        if (!$running) {
                print "RedRatHub which controls IRNetBoxIV communication is NOT running. I have tried to start it for you. Please wait 10 seconds and then try to control IRNetBoxIV devices again\n\nIf the problem persists, check your webserver error log for details or contact your system administrator.";
                chomp(my $sysip = `hostname -I | awk \'\{print \$1\}\'` // '');
                $sysip =~ s/\s+//g;
                $sysip =~ s/\r|\n//g;
                if ($sysip) {
			my $lfh;
			my $lockfile = $filedir . 'redRatHub.lock';
			open $lfh, '+>', $lockfile or print "ERROR: Unable to open $lockfile for writing and locking: $!\n" and return;
			if (flock($lfh, LOCK_EX | LOCK_NB)) {
				system("cd $redrathubdir && bash -c \"exec -a stbController-RedRatHubProcess-$sysip $dotnetbin RedRatHub.dll --noscan --nohttp > $redrathubdebug 2>&1 \&\" \&");
				flock($lfh, LOCK_UN);
				close $lfh;
			}
			return \"fail";
                } else {
                        die "$logts - ERROR: Could not identify the system ip address for the RedRatHub process. STB controller IR requires this.\n";
                }
        } else {
        	my ($runpid) = $running =~ /^\s*(\d+)/;
        	return if (!$runpid);
        	##### If the RedRatHub is running, check to see if there are errors in the log file which suggest a restart would help
		my $errors = `grep -i "exception\\\|cancelled" $redrathubdebug` // '';
		if ($errors) {
			my $lfh;
			my $lockfile = $filedir . 'redRatHub.lock';
			open $lfh, '+>', $lockfile or print "ERROR: Unable to open $lockfile for writing and locking: $!\n" and return;
			if (flock($lfh, LOCK_EX | LOCK_NB)) {
				if (!$logpid) {
					print "Multiple errors have been detected with the RedRatHub process that supports RedRat IR. I have restarted the process for you. If this problem persists, please contact your system administrator for assistance.";
				}
				##### Kill all current RedRatHub processes
				my @runs = split("\n",$running);
				foreach my $r (@runs) {
					system("kill -9 $r");
				}
				
				##### Clear out the current debug log file
				if (open my $fh, '+>',$redrathubdebug) {
					close $fh;
				} else {
					warn "$logts - ERROR: Unable to overwrite the file $redrathubdebug for error reset. $!\n";
				}
				
				##### Start the new RedRatHub process
		                chomp(my $sysip = `hostname -I | awk \'\{print \$1\}\'` // '');	# Get the systems IP address
		                $sysip =~ s/\s+//g;
		                $sysip =~ s/\r|\n//g;
		                if ($sysip) {
					system("cd $redrathubdir && bash -c \"exec -a stbController-RedRatHubProcess-$sysip $dotnetbin RedRatHub.dll --noscan --nohttp > $redrathubdebug 2>&1 \&\" \&");
		                } else {
		                        die "$logts - ERROR: Could not identify the system ip address for the RedRatHub process. STB controller IR requires this.\n";
		                }
		                
				if ($logpid) {	# If this script has been run from the event scheduler, wait for it to restart before carrying on
					sleep 5;
				} else {	# Otherwise this has come from the front end control so just stop and return a fail status
					return \"fail";
				}
				flock($lfh, LOCK_UN);
				close $lfh;
			}
		}
		
		if ($running =~ /(\d+\.\d+\.\d+\.\d+)/) {
                        $redrathubip = $1;
                        return;
                }
        }
}

sub sendNowTVNetwork {
        use LWP::UserAgent;
        use HTTP::Request;
        my ($stb,$commands,$boxdata,$logging,$runningpids) = @_;
        if ($$logging) {
                my $logpid = $$runningpids . $$;
                system("touch $logpid");
        }
        my @commands = split(',',$$commands);
        my $ntvfile = $filedir . 'nowTVNetworkCommands.txt';
        my $nowtvip = $$boxdata{'NOWTVIP'};
        my $nowtvport = '8060';

        tie my %ntvcoms, 'Tie::File::AsHash', $ntvfile, split => ':' or die "$logts - ERROR: Problem tying \%ntvcoms to $ntvfile: $!\n";

        foreach my $command (@commands) {
                if ($command =~ /^t(\d+)/i) {
                        sleep $1;
                        next;
                }
                my $basecom = $ntvcoms{$command};
                unless (defined $basecom) {             # 'defined' needs to be used to handle '0' value for the STB command
                        warn "$logts - ERROR: $command is not a valid command for $$stb\n" and next;
                }

                my $ua = new LWP::UserAgent;
                my $service = "http://$nowtvip:$nowtvport/" . $basecom;

                $ua->timeout(3);
                my $request = new HTTP::Request('POST',$service);
                my $response = $ua->request($request);
                if ($response->is_success) {
                        my $stuff = $response->code . " " . $response->message;
                } else {
                        my $stuff = $response->code . " " . $response->message;
                        warn "PID $$: Failed to send \"$command\" to Now TV Box \"$$stb\" at $nowtvip on port $nowtvport: $stuff\n";
                }
        }

        untie %ntvcoms;

        if ($$logging) {
                my $logpid = $$runningpids . $$;
                system("rm $logpid");
        }
}

sub sendGlobalCacheIRNowTV {
        use IO::Socket::INET;
        my ($stb,$commands,$boxdata,$logging,$runningpids) = @_;
        if ($$logging) {
                my $logpid = $$runningpids . $$;
                system("touch $logpid");
        }
        my @commands = split(',',$$commands);
        my $ntvfile = $filedir . 'nowTVGlobalCacheIRCommands.txt';
        my $gcip = $$boxdata{'GlobalCacheIP'};
        my $gcport = $$boxdata{'GlobalCachePort'};

        tie my %ntvcoms, 'Tie::File::AsHash', $ntvfile, split => ':' or die "$logts - ERROR: Problem tying \%ntvcoms to $ntvfile: $!\n";

	my $sock = new IO::Socket::INET(PeerAddr => $gcip, PeerPort => 4998, Proto => 'tcp');

        foreach my $command (@commands) {
                if ($command =~ /^t(\d+)/i) {
                        sleep $1;
                        next;
                }
                my $basecom = $ntvcoms{$command};
                unless (defined $basecom) {             # 'defined' needs to be used to handle '0' value for the STB command
                        warn "$logts - ERROR: $command is not a valid command for $$stb\n" and next;
                }

		my $EOL = "\015\012";
		my $fullcom = 'sendir,1:' . $gcport . ',' . $basecom . $EOL;
		my $res = '';
		$sock->send($fullcom);
		$sock->recv($res,16);
		if ($res !~ /completeir/) {
			warn "PID $$: ERROR: Issue when sending command \"$command\" to GlobalCache device at $gcip: $res\n";
		}
        }

        untie %ntvcoms;

        if ($$logging) {
                my $logpid = $$runningpids . $$;
                system("rm $logpid");
        }
}

sub sendGlobalCacheIRSkyQ {
        use IO::Socket::INET;
        my ($stb,$commands,$boxdata,$logging,$runningpids) = @_;
        if ($$logging) {
                my $logpid = $$runningpids . $$;
                system("touch $logpid");
        }
        my @commands = split(',',$$commands);
        my $comfile = $filedir . 'skyQGlobalCacheIRCommands.txt';
        my $gcip = $$boxdata{'GlobalCacheIP'};
        my $gcport = $$boxdata{'GlobalCachePort'};

        tie my %coms, 'Tie::File::AsHash', $comfile, split => ':' or die "$logts - ERROR: Problem tying \%coms to $comfile: $!\n";

	my $sock = new IO::Socket::INET(PeerAddr => $gcip, PeerPort => 4998, Proto => 'tcp');

        foreach my $command (@commands) {
                if ($command =~ /^t(\d+)/i) {
                        sleep $1;
                        next;
                }
                my $basecom = $coms{$command};
                unless (defined $basecom) {             # 'defined' needs to be used to handle '0' value for the STB command
                        warn "$logts - ERROR: $command is not a valid command for $$stb\n" and next;
                }

		my $EOL = "\015\012";
		my $fullcom = 'sendir,1:' . $gcport . ',' . $basecom . $EOL;
		my $res = '';
		$sock->send($fullcom);
		$sock->recv($res,16);
		if ($res !~ /completeir/) {
			warn "PID $$: ERROR: Issue when sending command \"$command\" to GlobalCache device at $gcip: $res\n";
		}
        }

        untie %coms;

        if ($$logging) {
                my $logpid = $$runningpids . $$;
                system("rm $logpid");
        }
}

sub wakeonlan {
	use IO::Socket;

	my ($stb,$mac,$ip,$port) = @_;
	if (!$mac) {
		warn "$logts - ERROR: No MAC address data for $stb! Unable to use WakeOnLAN\n";
		return;
	}

	# use the discard service if $port not passed in
	if (! defined $ip) { $ip = '255.255.255.255' }
	if (! defined $port || $port !~ /^\d+$/ ) { $port = 9 }

	warn "$logts - Sending WOL to $ip - $mac - $port\n";
	my $sock = new IO::Socket::INET(Proto=>'udp') || return undef;

	my $ip_addr = inet_aton($ip);
	my $sock_addr = sockaddr_in($port, $ip_addr);
	$mac =~ s/://g;
	my $packet = pack('C6H*', 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, $mac x 16);

	setsockopt($sock, SOL_SOCKET, SO_BROADCAST, 1);
	send($sock, $packet, 0, $sock_addr);
	close ($sock);
}

sub soipAppCall {
	use LWP::UserAgent;
	
	my ($ip,$callstring) = @_;
	my ($a,$opt,$appid) = split(':',$callstring);

	my $url = 'http://' . $ip . ':9005/as/apps/action/' . $opt . '?appId=' . $appid;
	my $ua = LWP::UserAgent->new();
	$ua->timeout(5);
	my $req = $ua->post($url);
	return;
}
