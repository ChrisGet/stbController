#!/usr/bin/perl -w
use strict;

use CGI;
use Fcntl ':flock';

my $query = CGI->new;
print $query->header();

chomp(my $maindir = (`cat homeDir.txt` || ''));
die "Couldn't find where my main files are installed. No \"stbController\" directory was found on your system...\n" if (!$maindir);
$maindir =~ s/\/$//;
my $confdir = $maindir . '/config/';
my $filedir = $maindir . '/files/';

my $option = $query->param('option') // '';

if ($option eq 'savelayout') {
	saveLayout();
	exit;
}
if ($option eq 'rowrestrict') {
	rowRestrict();
	exit;
}
if ($option eq 'gridfullsize') {
	gridFullSize();
	exit;
}
if ($option eq 'restartredrathub') {
	restartRedRatHub();
	exit;
}

sub saveLayout {
	my $orderfile = $confdir . 'controllerPageOrder.conf';
	my $layout = $query->param('data') // '';
	if ($layout) {
		if (open my $fh, '+>', $orderfile) {
			print $fh $layout;
			close $fh;
			print "SUCCESS: Page layout saved. Please reload the Controller page for the new layout to take effect.";
		}
	}
}

sub rowRestrict {
	my $restrictfile = $confdir . 'gridRowRestriction.conf';
	my $option = $query->param('state');
	if ($option) {
		if (open my $fh, '+>', $restrictfile) {
			print $fh $option;
			close $fh;
			print "SUCCESS: Row restriction was updated successfully.";
		}
	} else {
		print "ERROR: No option detected.";
	}
}

sub gridFullSize {
	my $gridfsfile = $confdir . 'gridFullSize.conf';
	my $option = $query->param('state');
	if ($option) {
		if (open my $fh, '+>', $gridfsfile) {
			print $fh $option;
			close $fh;
			print "SUCCESS: STB Grid sizing was updated successfully.";
		}
	} else {
		print "ERROR: No option detected.";
	}
}

sub restartRedRatHub {
	my $archfile = $filedir . 'hostArchitecture.txt';
	my $redrathubdir = $maindir . '/RedRatHub-V5.11/';
	my $redrathubdll = $redrathubdir . 'RedRatHub.dll';
        my $dotnetbin = 'dotnet';
        my $redrathubdebug = $filedir . '/RedRatHubDebug.txt';
        chomp(my $arch = `cat $archfile` // '');
        if ($arch) {
                $dotnetbin = $maindir . "/dotnet$arch" . '/dotnet';
        } else {
                die "CRITICAL ERROR: Unable to identify host architecture for checking RedRatHub process in stbControl.pl\n";
        }

	chomp(my $running = `ps -ax | grep "stbController-RedRatHubProcess" | grep -v grep` // '');
        if (!$running) {
		print "ERROR: The RedRatHub process is not currently running. If you have STBs that are controlled by RedRat hardware, try selecting and controlling them from the STB control grid to start the RedRatHub software";
		return;
        }

	my @runningpids;
        my @runningraw = split("\n",$running);
        foreach my $runraw (@runningraw) {
                my ($runpid) = $runraw =~ /^\s*(\d+)/;
                if ($runpid) {
                        push(@runningpids,$runpid);
                }
        }

	print "ERROR: Unable to stop the current running RedRatHub process. Please try again later or contact your system admin for assistance" and return if (!@runningpids);

	my $lfh;
	my $lockfile = $filedir . 'redRatHub.lock';
	open $lfh, '+>', $lockfile or print "ERROR: Unable to open $lockfile for writing and locking: $!\n" and return;
	if (flock($lfh, LOCK_EX | LOCK_NB)) {
		foreach my $runpid (@runningpids) {
                        ##### Kill the current RedRatHub process
                        system("kill -9 $runpid");
                }

	        ##### Clear out the current debug log file
	        if (open my $fh, '+>',$redrathubdebug) {
	                close $fh;
	        } else {
	                warn "Unable to overwrite the file $redrathubdebug for manual restart. $!\n";
	        }

	        ##### Start the new RedRatHub process
	        chomp(my $sysip = `hostname -I | awk \'\{print \$1\}\'` // ''); # Get the systems IP address
	        $sysip =~ s/\s+//g;
	        $sysip =~ s/\r|\n//g;
	        if ($sysip) {
	                system("cd $redrathubdir && bash -c \"exec -a stbController-RedRatHubProcess-$sysip $dotnetbin RedRatHub.dll --noscan --nohttp > $redrathubdebug 2>&1 \&\" \&");
			print "SUCCESS: RedRatHub process has been restarted!";
			return;
	        } else {
	                print "ERROR: Could not identify the system ip address for the RedRatHub process. STB controller IR requires this.\n";
			return;
	        }
	} else {
		print "ERROR: It looks like another process is handling the restart of the RedRatHub process. Aborting";
		return;
	}
}

