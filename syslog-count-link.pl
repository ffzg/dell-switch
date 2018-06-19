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

my $name = $0;
$name =~ s/.*\/([^\/]+)$/$1/;
$name =~ s/\.pl$//;
my $dir = "/dev/shm/$name";
mkdir $dir unless -e $dir;

my $stat;

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
			my $out = sprintf "%s %s:%s %d\n", $host, $port, $stat->{$host}->{$port}, $stat->{$host}->{_count}->{$port};
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
		$stat->{$host}->{$port} .= substr($state,0,1);
		$stat->{$host}->{_count}->{$port} += $state =~ m/Up/ ? 1 : -1;
	} elsif ( m/(\S+)\s%STP-W-PORTSTATUS:\s([\w\/]+): STP status (\w+)/ ) {
		my ($host,$port,$state) = ($1,$2,$3);
		$stat->{$host}->{$port} .= '-';
		$stat->{$host}->{_count}->{$port} += $state =~ m/F/ ? 1 : -1;


	## Dell new
	} elsif ( m/LINK - (\w+) - Hostname: <($host_re)>, ($port_re)/ ) {
		my ($state, $host, $port ) = ($1,$2,$3);
		$stat->{$host}->{$port} .= substr($state,0,1);
		$stat->{$host}->{_count}->{$port} += $state =~ m/U/ ? 1 : -1;
	} elsif ( m/STP - PORTSTATUS - Hostname: <($host_re)>,($port_re): STP status (\w+)/ ) {
		my ($host,$port,$state) = ($1,$2,$3);
		$stat->{$host}->{$port} .= '-';
		$stat->{$host}->{_count}->{$port} += $state =~ m/F/ ? 1 : -1;


	## Mikrotik
	} elsif ( m/($host_re) \w+: ([\w\-]+) link (\w+)/ ) {
		my ($host, $port, $state ) = ($1,$2,$3);
		$stat->{$host}->{$port} .= substr($state,0,1);
		$stat->{$host}->{_count}->{$port} += $state =~ m/U/i ? 1 : -1;


	} elsif ( m'==> /var/log/' ) {
		# ignore tail output
	} else {
		warn "IGNORE: [$_]\n";
	}

	if ( -e "$dir/dump" ) {
		print "### ",strftime("%Y-%m-%d %H:%M:%S",localtime(time)), "\n";
		print_stats;
	}
}



warn "# stat = ", dump($stat);
print_stats;


