#!/usr/bin/perl -w
use strict;
use CGI;

my $query = CGI->new;
print $query->header();

chomp(my $data = `date +"%a,%d,%m,%Y,%H,%M,%S"`);
print "$data";
