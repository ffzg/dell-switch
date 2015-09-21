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

require 'config.pl';

#$Net::OpenSSH::debug = ~0;

my $ip = shift @ARGV || die "usage: $0 IP command[ command ...]\n";
my @commands = @ARGV;
@commands = <DATA> unless @commands;

warn "## $ip\n";
my $ssh = Net::OpenSSH->new('auto@'.$ip);
my ($pty ,$pid) = $ssh->open2pty();

my $buff;

sub send_pty {
	my $string = shift;
	sleep 0.1; # we really need to wait for slow PowerConnect 5324
	foreach (split //, $string) {
		print STDERR "[$_]" if $debug;
		syswrite $pty, $_;
#		$pty->flush;
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

while(1) {
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
		if ( $command = shift @commands ) {
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
	} elsif ( $buff =~ s{More: <space>,  Quit: q.*One line: <return> }{} ) {
		send_pty " ";
	} elsif ( $buff =~ s{\e\[0m\r\s+\r}{} ) {
	}
}

__DATA__
show arp
show vlan
show running-config
show bridge address-table
