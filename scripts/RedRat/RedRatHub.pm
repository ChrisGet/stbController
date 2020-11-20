#
# Simple perl module to send commands to the RedRatHubCmd application via a socket.
#
# Chris Dodge - RedRat Ltd.
#
package RedRat::RedRatHub;
use strict;
use warnings;

use IO::Socket::INET;
use Exporter qw(import);

our @EXPORT_OK = qw(openSocket sendMessage closeSocket readData);

my $sock;	     # The socket
my $socketOpen = 0;  # Socket state

#
# Opens the socket to RedRatHubCmd.
#
sub openSocket {
	my ($ip_addr, $port) = @_;
	$sock = new IO::Socket::INET(
					PeerAddr => $ip_addr,
					PeerPort => $port,
      					Proto => 'tcp',
				);
	die "Could not create socket: $!\n" unless $sock;
	#binmode $sock => ":encoding(utf8)";
	$socketOpen = 1;
}

#
# Closes the RedRatHubCmd socket.
#
sub closeSocket {
	if ($socketOpen) {
		close($sock);
		$socketOpen = 0;
	}
}

#
# Sends a command message to RedRatHubCmd. It expects 'OK' to be returned, so if
# this does not happen, it prints out the returned information (probably an error).
#
sub sendMessage {
	my ($message) = @_;
	
	my $inData = readData($message);
	if ($inData eq "OK" ) {
		return;
	}
	print "Error from RedRatHub: $inData \n";	
}

#
# Reads data back from RedRatHub.
#
sub readData {
	my ($message) = @_;
	if (!$socketOpen) {
		print "Socket has not been opened. Call 'openSocket()' first.";
		return;
	}
	
	# Send message
	print $sock $message, "\n";
	#$sock->send($message);

	# Check response. This is either a single line, e.g. "OK\n", or a multi-line response with 
	# '{' and '}' start/end delimiters.
	my $inData = '';
	my $res = '';
	do {
		#$inData = <$sock>;
		$sock->recv($inData, 1024);
		#$sock->read($inData, 16);
		$res = $res . $inData;
	} while (!haveEOM($res));
	#} while (!$res);
	chomp ($res);
	return "\"$res\"\n";
}

#
# Checks for the end of message from RRHub. It could be a single line message, or multi-line 
# message, the letter being delimited with '{' and '}'.
#
sub haveEOM {
	my ($message) = @_;
	
	# Multiline message
	if ($message =~ /{/) {
		# If we have a terminating '}' return true.
		return ($message =~ /}/) ? 1 : 0;
	}
	
	# Single line message, so check for newline (=EOM).
	return ($message =~ /.*\z/) ? 1 : 0;
}

1;
