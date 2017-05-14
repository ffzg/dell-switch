#!/usr/bin/perl
use warnings;
use strict;
use autodie;

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
my @commands = @ARGV;
@commands = <DATA> unless @commands;

warn "\n## ssh $ip\n";
my $ssh = Net::OpenSSH->new($ip, user => $login, passwd => $passwd);
my ($pty ,$pid) = $ssh->open2pty();
if ( ! $pty ) {
	warn "ERROR: can't connect to $ip, skipping";
	exit 0;
}

my $buff;

sub send_pty {
	my $string = shift;
	sleep 0.1; # we really need to wait for slow PowerConnect 5324
	foreach (split //, $string) {
		print STDERR "[$_]" if $debug;
		syswrite $pty, $_;
		#$pty->flush;
		sleep 0.05;

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
	} elsif ( $buff =~ m/([\w\-]+)#$/ ) {
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
		exit 1;
	} elsif ( $buff =~ s{More: <space>,  Quit: q.*One line: <return>\s*}{} ) {
		send_pty " ";
	} elsif ( $buff =~ s{\Q--More-- or (q)uit\E}{} ) {
		send_pty " ";
	} elsif ( $buff =~ s{\e\[0m\s*\r\s+\r}{} ) {
		# nop
	} elsif ( $buff =~ m/^[\r\n]+[\w\-]+>$/ ) {
		send_pty "enable\n";
	}
}

__DATA__
show system
show arp
show vlan
show running-config
show bridge address
show interfaces status

