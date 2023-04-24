#!/usr/bin/perl
use warnings;
use strict;
use autodie;

# example usage as pipe:
# ./ips | sed 's/^/ping /' | NO_LOG=1 ./dell-switch.pl sw-dpc

use Net::OpenSSH;
use Data::Dump qw(dump);
use Time::HiRes qw(sleep);

our $login;
our $passwd;
our $debug = $ENV{DEBUG} || 0;

use lib '.';
require 'config.pl';

#$Net::OpenSSH::debug = ~0;

my $ip = shift @ARGV || die "usage: $0 IP command[ command ...]\n";
$ip = $1 if `host $ip` =~ m/has address (\S+)/;
my @commands = @ARGV;
if ( ! @commands && ! -t STDIN && -p STDIN ) { # we are being piped into
	while(<>) {
		push @commands, $_;
	}
} else {
	@commands = <DATA> unless @commands;
}

warn "\n## ssh $ip\n";
my $ssh = Net::OpenSSH->new($ip, user => $login, passwd => $passwd, 
    ssh_cmd => '/usr/bin/ssh1', # apt-get install openssh-client-ssh1
    master_opts => [
	-o => "StrictHostKeyChecking=no",
	-F => '/home/dpavlin/dell-switch/ssh1-config'
	],
    default_ssh_opts => [
	-o => "StrictHostKeyChecking=no",
	-F => '/home/dpavlin/dell-switch/ssh1-config'
	],
);
my ($pty ,$pid) = $ssh->open2pty();
if ( ! $pty ) {
	warn "ERROR: can't connect to $ip, skipping";
	exit 0;
}

my $buff;

sub send_pty {
	my $string = shift;
	sleep 0.05; # we really need to wait for slow PowerConnect 5324
	foreach (split //, $string) {
		print STDERR "[$_]" if $debug;
		syswrite $pty, $_;
		#$pty->flush;
		sleep 0.01;

		sysread $pty, my $echo, 1;
		print STDERR $echo;
		$buff .= $echo;
	}
}

mkdir 'log' unless -d 'log';

chdir 'log';

sub save_log {
	my ($ip, $hostname, $command, $buff) = @_;

	return unless $command;
	return if $ENV{NO_LOG};
	
	my $file = "${ip}_${hostname}_${command}.log";
	open my $log, '>', $file;
	$buff =~ s/\r//gs; # strip CR, leave LF only
	print $log $buff;
	if ( -e '.git' ) {
		system 'git', 'add', $file;
		system 'git', 'commit', '-m', "$ip $hostname", $file;
	}
}

my $command;
my @commands_while = ( @commands );

while() {
	my $data;
	my $read = sysread($pty, $data, 1);
	print STDERR $data;
	$buff .= $data;
	if ( $buff =~ m/User Name:/ ) {
		send_pty "$login\n";
		$buff = '';
	} elsif ( $buff =~ m/Password:/ ) {
		send_pty "$passwd\n";
		$buff = '';
	} elsif ( $buff =~ m/[\n\r\b]([\w\-\(\)\/]+)#\s*$/ ) {
		# config interface needs / in prompt
		my $hostname = $1;
		if ( $buff ) {
			save_log $ip, $hostname, $command, $buff;
			$buff = '';
		}
		if ( $command = shift @commands_while ) {
			$command =~ s/[\n\r]+$//;
			send_pty "$command\n";
			$buff = '';
		} else  {
			send_pty "exit\n";
			close($pty);
			last;
		}
	} elsif ( $buff =~ m/% Unrecognized command/ ) {
		#exit 1;
		warn "SKIP $command\n";
		$buff = '';

	} elsif ( $buff =~ m/% Invalid input detected at .* marker/ ) {

		# try to rewrite command differences

		if ( $command =~ m/show lldp neighbors/ ) {
			unshift @commands_while, 'show lldp remote-device all';
			undef $command; # don't save this command
			$buff = '';
		}

		warn "# commands_while = ",dump( \@commands_while );

	} elsif ( $buff =~ s{More: <space>,  Quit: q.*One line: <return>\s*}{} ) {
		send_pty " ";
	} elsif ( $buff =~ s{\Q--More-- or (q)uit\E}{} ) {
		send_pty " ";
	} elsif ( $buff =~ s{\r\s{18}\r}{} ) {
		# strip spaces delete after more prompt
	} elsif ( $buff =~ s{\e\[0m\s*\r\s+\r}{} ) {
		# nop
	} elsif ( $buff =~ m/^[\r\n]+[\w\-]+>$/ ) {
		send_pty "enable\n";
	} elsif ( $buff =~ m{\QOverwrite file [startup-config] ?[Yes/press any key for no]....\E} ) {
		send_pty "y";
		$buff = '';
	} elsif ( $buff =~ s{Management access will be blocked for the duration of the transfer.*Are you sure you want to start\? \(y/n\) }{}s ) {
		send_pty 'y';
	} elsif ( $buff =~ s{\QThis command will reset the whole system and disconnect your current session.\E}{}s ) { # reload
		warn "\nRELOAD detected\n";
		sleep 0.5;
		send_pty 'y';
	} elsif ( $buff =~ m{MikroTik RouterOS} ) {
		warn "\nERROR: don't know how to talk to MicroTik - ABORTING";
		exit 0;
	}
}

__DATA__
show system
show arp
show vlan
show running-config
show bridge address
show interfaces status
