#!/usr/bin/perl -w
use strict;

chomp(my $pwd = `pwd`);
my ($maindir) = $pwd =~ /^(.*stbController\/)/;

my $filedir = $maindir . 'files/';
my $webdir = $maindir . 'web/';
my $configdir = $maindir . 'config/';
my $dirfile = $maindir . 'files/homeDir.txt';
my $scriptfile = $maindir . 'scripts/homeDir.txt';
my $webpagesfile = $maindir . 'scripts/pages/homeDir.txt';
my $formsfile = $maindir . 'scripts/pages/forms/homeDir.txt';
my $titlefile = $webdir . 'dynamicTitle.txt';
my $archfile = $filedir . 'hostArchitecture.txt';

my @files = ($dirfile , $scriptfile , $webpagesfile , $formsfile);

for (@files) {
	open FH, '+>', $_;
	print FH "$maindir";
	close FH;
	system("chmod 775 $_");
}

system("chmod -R 775 $maindir");
system("chmod -R 777 $filedir");
if (!-e $titlefile) {	# If a title file does not exist, create it
	system("echo \"STB Controller\" > $titlefile");
}
system("chmod 777 $titlefile");
system("chmod -R 777 $configdir");

my $arch = '';
my $dotnetfile = '';
chomp(my $archraw = `uname -m` // '');
if ($archraw) {
	if ($archraw =~ /x86/) {
		if ($archraw =~ /64/) {
			$arch = 'x86_64';
			$dotnetfile = 'dotnet-sdk-3.1.402-linux-x64.tar.gz';
		} else {
			print "WARNING: RedRatHub is not supported on Linux 32 bit. You will not be able to use IrNetBoxIV hardware on this host.\n";
			#$arch = 'x86_32';
		}
	} elsif ($archraw =~ /arm/) {
		if ($archraw =~ /v(\d+)/) {
			my $ver = $1;
			if ($ver < 8) {
				$arch = 'arm32';
				$dotnetfile = 'dotnet-sdk-3.1.402-linux-arm.tar.gz';
			} else {
				$arch = 'arm64';
				$dotnetfile = 'dotnet-sdk-3.1.402-linux-arm64.tar.gz';
			}
		}
	}
}

if ($arch and $dotnetfile) {
	my $dir = $maindir . 'dotnet' . $arch;
	#chomp(my $installcheck = `ls -1 $dir \| grep LICENSE`);
	#if (!$installcheck) {
	#	my $file = "$dir/$dotnetfile";
	#	print "Architecture successfully found. Will use $dir\nUnpacking dotnet files, please wait...\n";
	#	#system("cd $dir && tar -xf $file");
	#	#print "dotnet files unpacked. Finished\n";
	#} else {
	#	print "The correct version of dotnet already appears to be extracted\nFinished\n";
	#}
	system("echo $arch > $archfile && chmod 777 $archfile");
}

system("chmod 777 /var/www");
