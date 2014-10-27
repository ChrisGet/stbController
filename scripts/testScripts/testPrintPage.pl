#!/usr/bin/perl -w
use strict;

use CGI;
my $query = CGI->new;
print $query->header();

print <<CONTENT;
<p>This content was generated from a perl script. Well done!</p>
CONTENT
