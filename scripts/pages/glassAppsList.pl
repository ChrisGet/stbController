#!/usr/bin/perl -w

use strict;
use CGI;
use Tie::File::AsHash;
use JSON;

my $query = CGI->new;
print $query->header();

chomp(my $maindir = (`cat homeDir.txt` || ''));
die "Couldn't find where my main files are installed. No \"stbController\" directory was found on your system...\n" if (!$maindir);
$maindir =~ s/\/$//;
#my $confdir = $maindir . '/config/';
#my $conffile = $confdir . 'stbGrid.conf';
my $filedir = $maindir . '/files/';
my $appsjson = $filedir . 'soipAppShortcuts.json';

chomp(my $option = $query->param('option') // $ARGV[0] // '');
print "ERROR: No option provided for Glass apps list\n" and exit if (!$option);
chomp(my $flag = $query->param('flag') // $ARGV[1] // '');

my $json = JSON->new->allow_nonref;
$json = $json->canonical('1');
my %apps;

if (open my $afh, '<', $appsjson) {
	local $/;
	my $data = <$afh>;
	my $decoded = $json->decode($data);
	%apps = %{$decoded};
} else {
	print "ERROR: Unable to open the Glass apps list file for reading: $!\n";
	exit;
}

#my @keys = sort { $apps{$a} <=> $apps{$b} } keys %apps;
#while (my ($key,$value) = each %apps) {
#foreach my $key (sort keys %apps) {
#foreach my $key (@keys) {
foreach my $key (sort { $apps{$a} cmp $apps{$b} } keys %apps) {
	my $value = $apps{$key} // ''; 
	# $key is the app ID to be used for the AS API call
	# $value is the friendly name to be shown to users
	next if (!$value or $value !~ /\S+/);
	(my $shorttext = $value) =~ s/Sky\s*Live/SL/i;
	my $launchonclick = "onclick=\"stbControl(\'control\',\'app:launch:$key\')\"";
	my $closeonclick = "onclick=\"stbControl(\'control\',\'app:close:$key\')\"";
	if ($flag and $flag eq 'sequences') {
		$launchonclick = "onclick=\"seqTextUpdate(\'app:launch:$key\',\'LAUNCH $value\')\"";
		$closeonclick = "onclick=\"seqTextUpdate(\'app:close:$key\',\'CLOSE $value\')\"";
	}
	
print <<APP;
<div class="glassAppListRow masterTooltip" value="$value" title="$value">
	<div class="glassAppListRowHead">
		<p>$shorttext</p>
	</div>
	<div class="glassAppListRowOpts">
		<button class="appBtn launch masterTooltip" value="LAUNCH $value" $launchonclick></button>
		<button class="appBtn close masterTooltip" value="CLOSE $value" $closeonclick></button>
	</div>
</div>

APP
}
