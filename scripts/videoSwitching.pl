#!/usr/bin/perl -w

use strict;
use DBM::Deep;
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
my $stbdatafile = ($maindir . '/config/stbDatabase.db');

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
	tie my %stbdata, 'DBM::Deep', {file => $stbdatafile, locking => 1, autoflush => 1, num_txns => 100};
	foreach my $box (@boxes) {
		my %boxinfo = %{$stbdata{$box}};
		warn "No video control data found for $box\n" and next if (!%boxinfo);
		my $first = '01';

		######## Switch up to 3 HDMI switches per STB
		foreach my $switch (1..3) {
			next if (!$boxinfo{"HDMIIP$switch"} or $boxinfo{"HDMIIP$switch"} !~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/);
			my $hdmi = new IO::Socket::INET(PeerAddr => $boxinfo{"HDMIIP$switch"}, PeerPort => $boxinfo{"HDMIPort$switch"}, Proto => 'tcp', Timeout => 5);
			if (!$hdmi) {
				warn "Failed to connect to HDMI switch at " . $boxinfo{"HDMIIP$switch"} . " on port " . $boxinfo{"HDMIPort$switch"} . "\n";
				next;
			}
			my $hdmiin = '128'+$boxinfo{"HDMIInput$switch"};
			my $hdmiout;
			if ($boxinfo{"HDMIOutput$switch"} =~ /Both/i) {
				$hdmiout = '128';
			} else {
				$hdmiout = '128'+$boxinfo{"HDMIOutput$switch"};
			}
			my $hdmilast = '81';
			chomp $hdmiin;
			my $hdmiinhex = sprintf("%x", $hdmiin);
			my $hdmiouthex = sprintf("%x", $hdmiout);
			my $hdmisig = pack ("H8", "$first$hdmiinhex$hdmiouthex$hdmilast");
			print $hdmi $hdmisig;
			$hdmi->close;
		}
		######## Switch up to 3 HDMI switches per STB

		next if (!$boxinfo{'SDIP'} or $boxinfo{'SDIP'} !~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/);

		my $svideo = new IO::Socket::INET(PeerAddr => $boxinfo{'SDIP'}, PeerPort => $boxinfo{'SDPort'}, Proto => 'tcp', Timeout => 1);
		if (!$svideo) {
			die "Failed to connect to SD Video Switch at $boxinfo{'SDIP'} on port $boxinfo{'SDPort'}\n";
		}

		my $audio = '02';
		my $svid = $boxinfo{'SDInput'};
		my $svidout = $boxinfo{'SDOutput'};
		my $svideoin;
		my $svideoout;
		my $sdlast;

		if ($svidout =~ /Both/i) {
			$svideoout = '128';
		} else {
			$svideoout = '128'+$svidout;
		}

		if ($svid >= 01 && $svid <= 12) {
			$svideoin = '128'+$svid;
			$sdlast = '81';
		}
		if ($svid >= 13 && $svid <= 24) {
			$svideoin = '116'+$svid;
			$sdlast = '82';
		}
		if ($svid >= 25 && $svid <= 36) {
			$svideoin = '104'+$svid;
			$sdlast = '83';
		}

		chomp $svideoin;

		my $svideoinhex = sprintf("%x", $svideoin);
		my $svideoouthex = sprintf("%x", $svideoout);
		my $svideosig = pack ("H8", "$first$svideoinhex$svideoouthex$sdlast");
		my $audiosig = pack ("H8", "$audio$svideoinhex$svideoouthex$sdlast");
		print $svideo $svideosig;
		print $svideo $audiosig;
		$svideo->close;
	}
}
