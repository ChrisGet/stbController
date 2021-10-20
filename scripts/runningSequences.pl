#!/usr/bin/perl -w
use strict;
use CGI;
use Proc::ProcessTable;

my $query = CGI->new;
print $query->header();

chomp(my $maindir = (`cat homeDir.txt` || ''));
die "Couldn't find where my main files are installed. No \"stbController\" directory was found on your system...\n" if (!$maindir);
$maindir =~ s/\/$//;
my $filedir = $maindir . '/files/';
my $seqrundir = $filedir . 'sequencesRunning/';

chomp(my $option = $ARGV[0] // $query->param('option') // '');
chomp(my $id = $ARGV[1] // $query->param('id') // '');
#chomp(my $info = $ARGV[2] // $query->param('info') // '');

if (!$option or $option !~ /getinfo|stop/) {
	die "Invalid option \"$option\" in " . __FILE__ . "\n";
}

if ($option =~ /getinfo/) {
	getInfo();
} elsif ($option =~ /stop/) {
	stop();
}

sub getInfo {
	my @files;
	if (opendir my $dir, $seqrundir) {
		@files = grep { /^[^\.]/} readdir $dir;
		close $dir;
	}

	if (!@files) {
		print "<h2>No active sequences</h2>";
		exit;
	}

	my %runbytime;
	foreach my $f (@files) {
		my $fullpath = $seqrundir . $f;
		if (open my $fh, '<', $fullpath) {
			local $/;
			my $info = <$fh>;
			if ($info) {
				#my ($time,$seq,$numstbs,$info) = $info =~ /^(.+) \>\> (.+) \>\> (.+) \>\> (.+)$/;
				my ($time,$seq,$numstbs,$info) = split('>>',$info);# =~ /^(.+) \>\> (.+) \>\> (.+) \>\> (.+)$/;
				if ($time and $seq and $numstbs and $info) {
					$runbytime{$time}{'seq'} = $seq;
					$runbytime{$time}{'id'} = $f;
					$runbytime{$time}{'numstbs'} = $numstbs;
					$runbytime{$time}{'info'} = $info;
				}
			}
		}
	}

	foreach my $run (sort {$b cmp $a} keys %runbytime) {
		my %data = %{$runbytime{$run}};
		my $info = $data{'info'} // '';
		my $id = $data{'id'} // '';
		my $numstbs = $data{'numstbs'} // '';
		my $seq = $data{'seq'} // '';
		my $sname = 'STBs';
		if ($numstbs == 1) {
			$sname = 'STB';
		}

print <<STUFF;
<div class="runningSeqInfoHolder masterTooltip" value="$info">
	<div class="runningSeqInfoSection time">
		<p>$run</p>
	</div>
	<div class="runningSeqInfoSection info">
		<p>$seq on $numstbs $sname</p>
	</div>
	<div class="runningSeqInfoSection btn">
		<button class="stopSeqBtn" onclick="stopSequence('$id')">STOP</button>
	</div>
</div>
STUFF
	}
}

sub stop {
	if (!$id) {
		print "ERROR: No sequence ID provided!";
		exit;
	}

	my $found;
	my $pt = Proc::ProcessTable->new();
	foreach my $proc (@{$pt->table}) {
		if ($proc->cmndline =~ /$id/) {
			my $pid = $proc->pid;
			kill 9, $pid;
			$found = 1;
		}
	}

	if (!$found) {
		my $f = $seqrundir . $id;
		if (-e $f) {
			unlink $f;
		}
	}
}
