#!/usr/bin/perl -w
use strict;

use DBM::Deep;
my $stbdatafile = '/home/stbController/config/stbDatabase.db';
tie my %stbdata, 'DBM::Deep', {file => $stbdatafile, locking => 1, autoflush => 1, num_txns => 100};

foreach my $key (sort keys %stbdata) {
#	delete $stbdata{$key} if ($key =~ /stb/);
#	print $stbdata{$key}{'NAME'};
#	print "Key = $key --- Value = $stbdata{$key}{'Name'}\n";
print "$key\n";
}
