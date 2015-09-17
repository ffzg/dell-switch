#!/usr/bin/perl
use warnings;
use strict;
use autodie;

use Net::OpenSSH;
use Data::Dump qw(dump);
use List::Util qw(first);
use Time::HiRes;

our $login;
our $passwd;

require 'config.pl';

#$Net::OpenSSH::debug = ~0;

my $ip = shift @ARGV || '10.20.0.2';
my @commands = @ARGV;
@commands = <DATA> unless @commands;

my $ssh = Net::OpenSSH->new('auto@'.$ip);
my ($pty ,$pid) = $ssh->open2pty();

open my $log, '>', '/tmp/dell.log';

my $buff;

while(1) {
	my $data;
	my $read = sysread($pty, $data, 1);
	print STDERR $data;
	$buff .= $data;
	if ( $buff =~ m/User Name:/ ) {
		print $pty "$login\n";
		$buff = '';
	} elsif ( $buff =~ m/Password:/ ) {
		print $pty "$passwd\n";
		$buff = '';
	} elsif ( $buff =~ m/#$/ ) {
		if ( $buff ) {
			print $log $buff;
			$buff = '';
		}
		if ( my $command = shift @commands ) {
			$command .= "\n" unless $command =~ m/\n$/;
			warn ">> $command\n";
			print $pty "$command";
			$buff = '';
		} else  {
			print $pty "exit\n";
			close($pty);
			last;
		}
	} elsif ( $buff =~ m/% Unrecognized command/ ) {
		exit 1;
	} elsif ( $buff =~ s{More: <space>,  Quit: q, One line: <return> }{} ) {
		print $pty " ";
	} elsif ( $buff =~ s{\e\[0m\r\s+\r}{} ) {
	}
}

__DATA__
show arp
show vlan
show running-config
show bridge address-table
