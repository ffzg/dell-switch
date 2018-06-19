#!/usr/bin/perl
use warnings;
use strict;

# count Dell and Microtik syslog for port and stp events

## report all logs:
# sudo cat /var/log/switch/sw-[a-z][0-9]*.log | ./syslog-count-link.pl | less -S
#
## tail logs and report status on kill -HUP
# sudo tail -f /var/log/switch/sw-[a-z][0-9]*.log | ./syslog-count-link.pl &

use Data::Dump qw(dump);
use POSIX qw(strftime);

my $timeout = $ENV{TIMEOUT} || 60; # forget switch after sec
# timeout should be smaller than stp refresh inverval or
# stp messages will accumulate forever

my $name = $0;
$name =~ s/.*\/([^\/]+)$/$1/;
$name =~ s/\.pl$//;
my $dir = "/dev/shm/$name";
mkdir $dir unless -e $dir;

our $stat;

sub print_stats {
	open(my $fh, '>', "$dir/stats");

	foreach my $host ( sort keys %$stat ) {
		foreach my $port ( sort {
			my $a1 = $a; $a1 =~ s/\D+//g;
			my $b1 = $b; $b1 =~ s/\D+//g;
			no warnings;
			$a1 <=> $b1;
		} keys %{ $stat->{$host} } ) {
			next if $port =~ m/^_/;
			my $dt = time() - $stat->{$host}->{$port}->[0];
			if ( $dt > $timeout ) {
				delete $stat->{$host}->{$port};
				next;
			}
			my $out = sprintf "%-12s %-8s %-2d %s\n", $host, $port, $dt, $stat->{$host}->{$port}->[1];
			print $out;
			print $fh $out;
		}
	}

	close($fh);
}

sub reset_stats {
	if ( -e "$dir/reset" && unlink "$dir/reset" ) {
		$stat = {};
		warn "# reset stats\n";
	}
}


$SIG{HUP} = sub {
	print_stats();
	reset_stats;
};

warn "kill -HUP $$  # to dump stats\n";
{
	open(my $fh, '>', "$dir/pid");
	print $fh $$;
	close($fh);
}

sub stat_host_port {
	my ( $host, $port, $state ) = @_;
	if ( ! exists $stat->{$host}->{$port} ) {
		$stat->{$host}->{$port} = [-1, $state];
	} else {
		$stat->{$host}->{$port}->[1] .= $state;
	}
	$stat->{$host}->{$port}->[0] = time();
	#warn "# stat_host_port ",dump($stat);
}


my $host_re = '[\w-]+';
my $port_re = '[\w/]+';

while(<>) {
	chomp;
	s/[\r\n]+//;

	reset_stats;

	next if m/^$/;
	next if m/%PIX-/; # ignore PIX logs

	## Dell old
	if ( m/(\S+)\s%LINK-[IW]-(\w+):\s*(\w+)/ ) {
		my ($host,$state,$port) = ($1,$2,$3);
		stat_host_port( $host, $port, substr($state,0,1) );
	} elsif ( m/(\S+)\s%STP-W-PORTSTATUS:\s([\w\/]+): STP status (\w+)/ ) {
		my ($host,$port,$state) = ($1,$2,$3);
		stat_host_port( $host, $port, '-' );


	## Dell new
	} elsif ( m/LINK - (\w+) - Hostname: <($host_re)>, ($port_re)/ ) {
		my ($state, $host, $port ) = ($1,$2,$3);
		stat_host_port( $host, $port, substr($state,0,1) );
	} elsif ( m/STP - PORTSTATUS - Hostname: <($host_re)>,($port_re): STP status (\w+)/ ) {
		my ($host,$port,$state) = ($1,$2,$3);
		stat_host_port( $host, $port, '-' );


	## Mikrotik
	} elsif ( m/($host_re) \w+: ([\w\-]+) link (\w+)/ ) {
		my ($host, $port, $state ) = ($1,$2,$3);
		stat_host_port( $host, $port, substr($state,0,1) );


	} elsif ( m/($host_re) TRAPMGR.* %% Spanning Tree Topology Change: (\d+)/ ) {
		my ( $host, $state ) = ( $1, $2 );
		stat_host_port( $host, 'STP', $2 );


	} elsif ( m'==> /var/log/' ) {
		# ignore tail output
		next;
	} else {
		warn "IGNORE: [$_]\n";
		next;
	}

	if ( -e "$dir/dump" ) {
		print "### ",strftime("%Y-%m-%d %H:%M:%S",localtime(time)), "\n";
		print_stats;
	}
}



warn "# stat = ", dump($stat);
print_stats;


