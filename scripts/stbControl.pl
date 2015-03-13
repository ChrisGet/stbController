#!/usr/bin/perl -w

use strict;
use DBM::Deep;
use Fcntl;
use CGI;
use Tie::File::AsHash;

my $query = CGI->new;
print $query->header();

chomp(my $fullpath = $ARGV[3] || '');
my $maindir;
if ($fullpath) {
	$maindir = $fullpath;
} else {
	chomp($maindir = (`cat homeDir.txt` || ''));
}
die "Couldn't find where my main files are installed. No \"stbController\" directory was found on your system...\n" if (!$maindir);
$maindir =~ s/\/$//;
my $filedir = $maindir . '/files/';
my $runningpids = $filedir . '/pidsRunning/';
my $stbDataFile = ($maindir . '/config/stbDatabase.db');
my $groupsfile = ($filedir . 'stbGroups.txt');
my $seqfile = ($filedir . 'commandSequences.txt');

chomp(my $action = $ARGV[0] // $query->param('action') // '');
chomp(my $command = $ARGV[1] // $query->param('command') // '');
chomp(my $info = $ARGV[2] // $query->param('info') // '');
chomp(my $logpid = $ARGV[4] || '');	# $logpid will only ever be used by the backend eventScheduleControl.pl script
my $logging = '';
die "Error: No action was specified. Options are \"Control\" or \"Event\"\n" if ($action !~ m/^Control$|^Event$/i);
die "No STBs Selected" if (!$info);

if ($logpid) {
	if ($logpid =~ /^logpid$/i) {
		$logging = 1;
	}
}

if ($logging) {		# Log the pid of this main script if logging has been requested
	my $pidlog = $runningpids . $$;
	system("touch $pidlog")
}

my @targetsraw = split(',',$info);
my $targetstring = '';

#### Below we separate the target STB input ($info) and process each item to see whether it is a group or a single STB
tie my %groups, 'Tie::File::AsHash', $groupsfile, split => ':' or die "Problem tying \%groups to $groupsfile: $!\n";	# Tie the %group hash to the groups file for quick group member lookup

foreach my $target (@targetsraw) {
	$target = uc($target);
	if (exists $groups{$target}) {
		my @members = split(',',$groups{$target});
		foreach my $member (@members) {
			$targetstring .= "$member,";
		}
	} else {
		$targetstring .= "$target,";
	}
}

untie %groups;
#### End of processing the target STB input ($info)

if (!$targetstring or $targetstring !~ /\S+/) {
	if ($logging) {
		my $pidlog = $runningpids . $$;
		system("rm $pidlog")
	}
	die "No STBs selected for control after processing the input\n";
}

if ($action =~ m/^Event$/i) {
	tie my %seqs, 'Tie::File::AsHash', $seqfile, split => ':' or die "Problem tying \%seqs to $seqfile: $!\n";
	my @sequences = split(',',$command);
	foreach my $seq (@sequences) {
		$seq = uc($seq);
		my $seqcoms = $seqs{$seq} || '';
		warn "Sequence $seq was not found in the sequences file\n" and next if (!$seqcoms);
		control(\$seqcoms,\$targetstring);
		sleep 2;	# Sleep 2 seconds between each sequence
	}
	untie %seqs;
}

if ($action =~ m/^Control$/i) {
	control(\$command,\$targetstring);
}

if ($logging) {
	my $pidlog = $runningpids . $$;
	system("rm $pidlog")
}

sub control {
	my ($commands,$boxes) = @_;	# All input args are scalar references at this point
	my @stbs = split (',', $$boxes);			
	tie my %stbData, 'DBM::Deep', {file => $stbDataFile, locking => 1, autoflush => 1, num_txns => 100};
	
	foreach my $stb (@stbs) {
		my %boxdata = %{ $stbData{$stb}};		# Get the box details from the main %stbData hash 
		my $type = $boxdata{'Type'} || '';		# Get the 'Type' for the STB to know what kind of control it uses (Dusky, Bluetooth, or IR)
		warn "Error: Could not find control protocol for $stb, has this STB had its control type configured?\n" and next if (!$type);
		my $pid = fork;
        	if ($pid==0) {
			# Fork the sendComms sub for each stb, inputting the stb, commands, and %boxdata for it
                	sendDuskyComms(\$stb,$commands,\%boxdata,\$logging,\$runningpids) if ($type =~ /Dusky/);
			sendBTComms(\$stb,$commands,\%boxdata,\$logging,\$runningpids) if ($type =~ /Bluetooth/);
			sendIRComms(\$stb,$commands,\%boxdata,\$logging,\$runningpids) if ($type =~ /IR/);
	                exit;
        	}
	}

	untie %stbData;
} ## End of sub 'control'

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
	my $dusky;
	my $tries = '1';
	until (($dusky) or ($tries >= '50')) {
		$dusky = new IO::Socket::INET(PeerAddr => $moxaip, PeerPort => $moxaport, Proto => 'tcp', Timeout => 3);
		$tries++;
	}

	if ($dusky) {
		tie my %duskycoms, 'Tie::File::AsHash', $duskycomfile, split => ':' or die "Problem tying \%duskycoms to $duskycomfile: $!\n";	# Tie the %group hash to the groups file for quick group member lookup

		foreach my $com (@commands) {
			if ($com =~ m/^t(\d+)$/i) {
				sleep $1;
				next;
			}
			my $raw = $duskycoms{$com};
			unless(defined $raw) {		# 'defined' needs to be used to handle '0' value for the STB command
				warn "$com was not found to be a valid command\n" and next;	# If the requested command is not found in the commands database, print a warning and skip to the next command
			}
			my $fullcom = 'A+' . $duskyport . $raw . 'x';
			$dusky->send($fullcom);
		}
		sleep 1;		
		$dusky->close;
		untie %duskycoms;
	} else {
		warn "Dusky connection failed for $$stb\n";
	}

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
	tie my %btcoms, 'Tie::File::AsHash', $btcomfile, split => ':' or die "Problem tying \%btcoms to $btcomfile: $!\n";
        foreach my $command (@commands) {
                if ($command =~ /^t(\d+)/i) {
                        sleep $1;
                        next;
                }
		my $basecom = $btcoms{$command};
		unless (defined $basecom) {		# 'defined' needs to be used to handle '0' value for the STB command
			warn "$command is not a valid command for $$stb\n" and next;
		}
                my $json = "\{\"action\"\:\"press\"";
		my $comtosend;
                if ($basecom =~ /^(TouchPad|TrickPlaySlider)\s*(.+)$/i) {
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
                my $request = new HTTP::Request('POST',$uri);
                $request->header( 'Content-Type' => 'application/json' );
                $request->content( $json );

                my $response = $ua->request($request);

                if ($response->is_success) {
                        my $stuff = $response->code . " " . $response->message;
                } else {
                        my $stuff = $response->code . " " . $response->message;
                        warn "Failed to send \"$command\" to STB \"$$stb\" on port $serverport: $stuff\n";
                }
        }
	untie %btcoms;

	if ($$logging) {
		my $logpid = $$runningpids . $$;
		system("rm $logpid");
	}
}

sub sendIRComms {
	my ($stb,$commands,$boxdata,$logging,$runningpids) = @_;
	if ($$logging) {
		my $logpid = $$runningpids . $$;
		system("touch $logpid");
	}

	# To be determined

	if ($$logging) {
		my $logpid = $$runningpids . $$;
		system("rm $logpid");
	}
}
