#!/usr/bin/perl -w

use strict;
use JSON;
use IO::Socket::INET;
use Fcntl;
use CGI;
use Tie::File::AsHash;
use FindBin qw($Bin);

my $query = CGI->new;
print $query->header();

my $maindir;
if ($Bin) {
        $maindir = $Bin;
        $maindir =~ s/\/\w+\/*$//;
} else {
        chomp($maindir = (`cat homeDir.txt` || ''));
        $maindir =~ s/\/$//;
}
die "Couldn't find where my main files are installed. No \"stbController\" directory was found on your system...\n" if (!$maindir);
my $filedir = $maindir . '/files/';
my $groupsfile = ($filedir . 'stbGroups.txt');
my $confdir = ($maindir . '/config/');
my $stbdatafile = $confdir . 'stbData.json';

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

chomp(my $stbs = $query->param('stbs') || $ARGV[0] || '');

die "No STBs selected for video switching\n" if (!$stbs);

my @targetsraw = split(',',$stbs);
my $targetstring = '';

tie my %groups, 'Tie::File::AsHash', $groupsfile, split => ':' or die "Problem tying \%groups to $groupsfile: $!\n";

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

die "No STBs selected for video switching after processing the input\n" if (!$targetstring or $targetstring !~ /\S+/);

$targetstring =~ s/,$//;
video(\$targetstring);

sub video {
	my ($stbs) = @_;
	my @boxes = split(',', $$stbs);
	foreach my $box (@boxes) {
		my %boxinfo = %{$stbdata{$box}};
		warn "No video control data found for $box\n" and next if (!%boxinfo);
		my $first = '01';

		######## Switch up to 3 video switches per STB
		foreach my $switch (1..3) {
			next if (!$boxinfo{"HDMIIP$switch"} or $boxinfo{"HDMIIP$switch"} !~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/);
			my $type = $boxinfo{"HDMIType$switch"} // '';
			my $ip = $boxinfo{"HDMIIP$switch"};
			my $port = $boxinfo{"HDMIPort$switch"} // '';
			my $input = $boxinfo{"HDMIInput$switch"} // '';
			my $output = $boxinfo{"HDMIOutput$switch"} // '';

			if ($type eq 'Kramer') {
				kramer($ip,$port,$input,$output);
			} elsif ($type eq 'WyreStorm') {
				wyrestorm($ip,$port,$input,$output);
			} elsif ($type eq 'BluStream') {
				blustream($ip,$port,$input,$output);
			} else {
				kramer($ip,$port,$input,$output); # Default to Kramer if this is not specified
			}
		}
		######## Switch up to 3 video switches per STB
	}
}

sub kramer {
	my ($ip,$port,$input,$output) = @_;
	my $hdmi = new IO::Socket::INET(PeerAddr => $ip, PeerPort => $port, Proto => 'tcp', Timeout => 5);
	if (!$hdmi) {
		warn "Failed to connect to Kramer video switch at $ip on port $port\n";
		next;
	}
	my $hdmiin = '128'+$input;
	my $hdmiout;
	if ($output =~ /Both/i) {
		$hdmiout = '128';
	} else {
		$hdmiout = '128'+$output;
	}
	my $hdmilast = '81';
	chomp $hdmiin;
	my $hdmiinhex = sprintf("%x", $hdmiin);
	my $hdmiouthex = sprintf("%x", $hdmiout);
	my $hdmisig = pack ("H8", "01$hdmiinhex$hdmiouthex$hdmilast");
	print $hdmi $hdmisig;
	$hdmi->close;
}

sub wyrestorm {
	use Net::Telnet();
	my ($ip,$port,$input,$output) = @_;

	# Remove leading zeros from input and output
	$input =~ s/^0//;
	$output =~ s/^0//;
	my $out = "out$output";

	# If output 'Both' has been selected on the data page, adjust the output part of the command
	if ($output =~ /both/i) {
		$out = 'all';
	}

	my $t = new Net::Telnet ( Timeout => 5, Port => $port);
	$t->open($ip);
	$t->print("Set SW hdmiin$input $out\r\n");
	$t->close;
}

sub blustream {
	use Net::Telnet();
	my ($ip,$port,$input,$output) = @_;

	my $out = $output;
	# If output 'Both' has been selected on the data page, adjust the output part of the command
	if ($output =~ /both/i) {
		$out = '00';
	}

	my $t = new Net::Telnet ( Timeout => 5, Port => $port, Prompt => '/Pro-Matrix>/');
	$t->open($ip);
	$t->waitfor('/Pro-Matrix>/');
	$t->cmd("OUT $out FR $input");
	$t->close;
}
