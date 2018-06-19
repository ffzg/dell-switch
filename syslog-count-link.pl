#!/usr/bin/perl
use warnings;
use strict;

use Data::Dump qw(dump);

my $stat;

my $host_re = '[\w-]+';
my $port_re = '[\w/]+';

while(<>) {
	chomp;

	## Dell
	if ( m/(\S+)\s%LINK-[IW]-(\w+):\s*(\w+)/ ) {
		my ($host,$state,$port) = ($1,$2,$3);
		$stat->{$host}->{$port} .= substr($state,0,1);
		$stat->{$host}->{_count}->{$port} += $state =~ m/Up/ ? 1 : -1;
	} elsif ( m/(\S+)\s%STP-W-PORTSTATUS:\s([\w\/]+): STP status (\w+)/ ) {
		my ($host,$port,$state) = ($1,$2,$3);
		$stat->{$host}->{$port} .= '-';
		$stat->{$host}->{_count}->{$port} += $state =~ m/F/ ? 1 : -1;


	## Mikrotik
	} elsif ( m/LINK - (\w+) - Hostname: <($host_re)>, ($port_re)/ ) {
		my ($state, $host, $port ) = ($1,$2,$3);
		$stat->{$host}->{$port} .= substr($state,0,1);
		$stat->{$host}->{_count}->{$port} += $state =~ m/U/ ? 1 : -1;
	} elsif ( m/STP - PORTSTATUS - Hostname: <($host_re)>,($port_re): STP status (\w+)/ ) {
		my ($host,$port,$state) = ($1,$2,$3);
		$stat->{$host}->{$port} .= '-';
		$stat->{$host}->{_count}->{$port} += $state =~ m/F/ ? 1 : -1;


	} else {
		warn "IGNORE: [$_]\n";
	}
}

warn "# stat = ", dump($stat);

foreach my $host ( sort keys %$stat ) {
	foreach my $port ( sort {
		my $a1 = $a; $a1 =~ s/\D+//g;
		my $b1 = $b; $b1 =~ s/\D+//g;
		$a1 <=> $b1;
	} keys %{ $stat->{$host} } ) {
		next if $port =~ m/^_/;
		printf "%s %s:%s %d\n", $host, $port, $stat->{$host}->{$port}, $stat->{$host}->{_count}->{$port};
	}
}
