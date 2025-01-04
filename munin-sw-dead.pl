#!/usr/bin/perl
use warnings;
use strict;

# run toggle-dead-switch-port.sh first

use Data::Dump qw(dump);

open(my $dead_fh, '<', '/dev/shm/sw.dead');
my $dead;
while(<$dead_fh>) {
	chomp;
	$dead->{$_}++;
}

print "# dead switches = ",dump($dead), $/;

# https://munin.ffzg.hr/snmp/sw-lib/if_bytes/if_1.html
# https://munin.ffzg.hr/munin-cgi/munin-cgi-graph/snmp/sw-lib/if_bytes/if_1-day.png
# https://munin.ffzg.hr/munin-cgi/munin-cgi-graph/snmp/sw-lib/if_bytes/if_1-week.png
# https://munin.ffzg.hr/munin-cgi/munin-cgi-graph/snmp/sw-lib/if_bytes/if_1-month.png

open(my $dead_fh, '>', '/etc/munin/static/_/sw-dead.html');

print $dead_fh <<__HTML__;
<html>
<head>
    <title>dead sw</title>
<!-- <meta content="300" http-equiv="refresh"></meta> -->
</head>
<body>
<table>
__HTML__

open(my $neighbour_fh, '<', '/dev/shm/neighbors.tab');
while(<$neighbour_fh>) {
	chomp;
	my ( $from_sw, $from_port, undef, $to_port, $to_sw, undef ) = split(/\t/,$_);
	if ( exists $dead->{$to_sw} ) {
		print "# $from_sw $from_port $to_sw $to_port\n";
		print $dead_fh "<tr>\n";
		my $group = 'snmp';
		foreach my $interval ( qw( day week month ) ) {

			my $host = $from_sw;
			my $plugin = 'if_bytes/if_';
			$plugin .= $1 if $from_port =~ m/(\d+)$/;
			print $dead_fh qq{<td><img title="$from_sw $from_port" src="http://munin.ffzg.hr/munin-cgi/munin-cgi-graph/$group/$host/$plugin-$interval.png"></td>\n};

			my $host = $to_sw;
			my $plugin = 'if_bytes/if_';
			$plugin .= $1 if $to_port =~ m/(\d+)$/;
			print $dead_fh qq{<td><img title="$to_sw $to_port" src="http://munin.ffzg.hr/munin-cgi/munin-cgi-graph/$group/$host/$plugin-$interval.png"></td>\n};

		}
		print $dead_fh "</tr>\n";
	}
}

print $dead_fh <<__HTML__;
</table>
</body>
</html>
__HTML__
