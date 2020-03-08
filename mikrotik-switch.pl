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

my $hostname = shift @ARGV || die "usage: $0 hostname command[ command ...]\n";
my @commands = @ARGV;

if ( ! @commands && ! -t STDIN && -p STDIN ) { # we are being piped into
	while(<>) {
		push @commands, $_;
	}
} elsif ( ! @commands ) {
#	push @commands, "/export verbose file=$hostname.rsc";
	push @commands, "/export file=$hostname.rsc";
	push @commands, "/tool fetch address=10.20.0.216 mode=ftp src-path=$hostname.rsc dst-path=upload/$hostname.rsc upload=yes";
	my $file = "/srv/ftp/upload/$hostname.rsc";
	if ( -e $file ) {
		system "sudo rm -vf $file";
	}
}

$login .= '+c'; # Mikrotik console without colors

warn "\n## ssh $login\@$hostname\n";
my $ssh = Net::OpenSSH->new($hostname, user => $login, passwd => $passwd, 
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

my $command;
my @commands_while = ( @commands );

while ( my $command = shift @commands_while ) {

	print "## $command\n";
	my ($out, $err) = $ssh->capture2($command);
      $ssh->error and
        die "remote find command failed: " . $ssh->error;

	warn "# out = ",dump($out);

	print $out;
}

if ( ! @commands ) {
	system "cp -v /srv/ftp/upload/$hostname.rsc mikrotik/";
}
