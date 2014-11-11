#!/usr/bin/perl -w
use strict;
use CGI;

my $query = CGI->new;
print $query->header();
print `date +"%H:%M:%S - %a %d %b %Y"`;
