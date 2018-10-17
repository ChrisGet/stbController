#!/usr/bin/perl -w

use strict;
use DBM::Deep;
use JSON -convert_blessed_universally;

my $dbfile = '../config/stbDatabase.db';
my $jsonfile = '../config/stbData.json';

if (!-e $dbfile) {
	die "ERROR: No stbDatabase.db was found\n";
}

print "Warning! This process will overwrite any existing stbData.json file that already exists in your config directory. Are you sure you want to continue? (y/n)\n";
my $yn = <STDIN>;
chomp $yn;

if ($yn !~ /^y$|^yes$/i) {
	print "DB convert aborted\n";
	exit;
}

tie my %stbData, 'DBM::Deep', {file => $dbfile, locking => 1, autoflush => 1, num_txns => 100};

my %newdata;
while (my ($key,$value) = each %stbData) {
	$newdata{$key} = $value;
}

my $json = JSON->new->allow_nonref->convert_blessed;
$json = $json->canonical('1');
my $encoded = $json->pretty->encode(\%newdata);

my %filtered;
my $decoded = $json->decode($encoded);
my %raw = %{$decoded};
foreach my $key (sort keys %raw) {
	if (exists $raw{$key}{'Name'}) {
		$filtered{$key} = $raw{$key};
	}
}

my $newenc = $json->pretty->encode(\%filtered);
if (open my $fh, '+>', $jsonfile) {
	print $fh $newenc;
	close $fh;
} else {
	print "Failed to open $jsonfile for writing: $!\n";
}

untie %stbData;

print "STB database converted to JSON successfully. You can now manually delete the stbDatabase.db file if you wish\n";
