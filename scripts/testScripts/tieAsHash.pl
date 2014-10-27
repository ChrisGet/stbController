#!/usr/bin/perl -w
use strict;

use Tie::File::AsHash;
use DBM::Deep;

tie my %oldhash, 'DBM::Deep', '/home/stbController/files/commandEvents.db' or die "Problem tying \%oldhash: $!\n";
tie my %newhash, 'Tie::File::AsHash', 'commandEvents.txt', split => ':' or die "Problem tying \%newhash: $!\n";

my %btusb = (		'Select' => "{\"action\":\"pressTouch\",\"duration\":0.1,\"points\":\[\[255,255,0\],\[255,255,0\]\],\"area\":\"Select\"",
			'Up' => "{\"action\":\"draw\",\"move\":\[\[256,256,0\],\[256,252,0\]\]",
			'Down' => "{\"action\":\"draw\",\"move\":\[\[256,256,0\],\[256,260,0\]\]",
			'Right' => "{\"action\":\"draw\",\"move\":\[\[256,256,0\],\[260,256,0\]\]",
			'Left' => "{\"action\":\"draw\",\"move\":\[\[256,256,0\],\[252,256,0\]\]",
			'ChUp' => 'Ch+',
			'ChDown' => 'Ch-',
		);

while ( my($key,$value) = each %oldhash) {
#foreach (sort keys %oldhash) {
	my $comstring = join(',', @{$value});
	$newhash{$key} = $comstring;
}

untie %oldhash;
untie %newhash;
