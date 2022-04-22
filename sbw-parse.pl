#!/usr/bin/perl
use warnings;
use strict;
use autodie;

# ./sw-name-mac.sh

# usage: NAME_MAC=/dev/shm/file-with-name-space-mac sbw-parse.pl [optional-switch-snmpbulkwalk-dump]

use Data::Dump qw(dump);

$|=1; # flush stdout

my $debug = $ENV{DEBUG} || 0;

my @cols = qw( ifName ifHighSpeed ifAdminStatus ifOperStatus ifType dot1dStpPortPathCost ifAlias );

my $mac2name;

foreach my $name_mac ( qw( /dev/shm/sw-name-mac /dev/shm/wap-name-mac ), $ENV{NAME_MAC} ) {
	next unless -e $name_mac;
	open(my $f, '<'. $name_mac);
	while(<$f>) {
		chomp;
		#my ( $ip, $name, $mac ) = split(/ /,$_);
		my ( $name, $mac ) = split(/ /,$_);
		$mac = lc($mac);
		$mac2name->{$mac} = $name;
	}
}

sub mac2name {
	my ( $mac, $name ) = @_;

	$mac = lc($mac);

	if ( exists $mac2name->{$mac} ) {
		my $mac_name = $mac2name->{$mac};
		warn "ERROR: name different $name != $mac_name" if $name && $name ne $mac_name;
		return ( $mac, $mac_name );
	}
	return ( $mac, $name );
}

warn "# mac2name = ",dump($mac2name) if $debug;


my $sw;

sub fix_mac {
	my $mac = shift;
	$mac = lc($mac);
	$mac =~ s/^([0-9a-f]):/0$1:/;
	while ( $mac =~ s/:([0-9a-f]):/:0$1:/g ) {};
	$mac =~ s/:([0-9a-f])$/:0$1/;
#	warn "# $mac\n";
	return $mac;
}

sub sw_name_mac_port {
	my ( $name, $mac, $port ) = @_;
	$mac = fix_mac($mac);
	if ( exists $mac2name->{$mac} ) {
		my $sw_name = $mac2name->{$mac};
		$sw->{$name}->{port_for_switch}->{$port}->{ $sw_name }++;
		#print "## $name $port $sw_name\n";
	}
}

my $gv; # collect for graphviz

my @files = @ARGV;
@files = glob('snmpbulkwalk/*') unless @files;

foreach my $file ( @files ) {
	my ( undef, $name ) = split(/\//, $file);
	print "# $name $file\n" if $debug;

	if ( -s "/dev/shm/$file" ) {
		if ( -M $file < -M "/dev/shm/$file" ) {
			warn "UPDATE $file\n";
			system "cp -pv /dev/shm/$file $file";
		}
		$file="/dev/shm/$file";
	} else {
		warn "WARNING: using old file $file\n";
	}

	open(my $f, '<', $file);
	while(<$f>) {
		chomp;
		if ( m/::(sysName|sysLocation|ipDefaultTTL|dot1dStpPriority|dot1dStpTopChanges|dot1dStpDesignatedRoot|dot1dStpRootCost|dot1dStpRootPort|dot1qNumVlans)\./ ) {
			my ( undef, $v ) = split(/ = \w+: /,$_,2);
			$sw->{$name}->{$1} = $v;
		} elsif ( m/::(ifMtu|ifHighSpeed)\[(\d\d?)\] = (?:INTEGER|Gauge32): (\d+)/ ) {
			$sw->{$name}->{$1}->[$2] = $3;
		} elsif ( m/::(ifPhysAddress)\[(\d\d?)\] = STRING: ([0-9a-f:]+)/ ) {
			$sw->{$name}->{$1}->[$2] = fix_mac($3);
		} elsif ( m/::(ifName|ifAlias)\[(\d\d?)\] = STRING: (.+)/ ) {
			$sw->{$name}->{$1}->[$2] = $3;
			if ( $1 eq 'ifName' ) {
				my ( $if_name, $port ) = ($3,$2);
				$sw->{$name}->{port_name_to_number}->{$3} = $2;
			}
		} elsif ( m/::(ifAdminStatus|ifOperStatus|ifType|dot3StatsDuplexStatus)\[(\d\d?)\] = INTEGER: (\w+)\(/ ) {
			$sw->{$name}->{$1}->[$2] = $3;
		} elsif ( m/::(dot1dStpPortPathCost)\[(\d\d?)\] = INTEGER: (\d+)/ ) {
			$sw->{$name}->{$1}->[$2] = $3;
		} elsif ( m/::(dot1dTpFdbPort)\[STRING: ([0-9a-f:]+)\] = INTEGER: (\d+)/ ) {
			$sw->{$name}->{$1}->{ fix_mac($2) } = $3;
			sw_name_mac_port( $name, $2, $3 );
		} elsif ( m/::(dot1qTpFdbPort)\[(\d+)\]\[STRING: ([0-9a-f:]+)\] = INTEGER: (\d+)/ ) {
			$sw->{$name}->{$1}->{ fix_mac($3) } = [ $4, $2 ]; # port, vlan
			sw_name_mac_port( $name, $3, $4 );
		}

		# dot1qVlanCurrentEgressPorts
		# dot1qVlanCurrentUntaggedPorts
		# dot1qVlanStaticName
		# dot1qVlanStaticEgressPorts
		# dot1qVlanStaticUntaggedPorts
		# dot1qPvid

		# entPhysicalDescr
		# entPhysicalClass

		#print "## $_<--\n";
	}
	warn "# sw $name = ",dump($sw->{$name}) if $debug;

	foreach my $port ( 1 .. $#{ $sw->{$name}->{ifName} } ) {
		print "$name $port";
		foreach my $oid ( @cols ) {
			if ( $oid eq 'ifAlias' ) {
				if ( defined( $sw->{$name}->{$oid}->[$port] ) ) {
					print " [",$sw->{$name}->{$oid}->[$port],"]";
				}
			} elsif ( defined $sw->{$name}->{$oid}->[$port] ) {
				print " ", $sw->{$name}->{$oid}->[$port];
			} else {
				print " ?";
				#warn "MISSING $name $oid $port\n";
			}

		}
		if ( exists( $sw->{$name}->{port_for_switch}->{ $port } ) ) {
			my @visible = sort keys %{ $sw->{$name}->{port_for_switch}->{ $port } };
			print " ",join(',', @visible);

			if ( scalar @visible == 1 ) {
				$gv->{$name}->{$port}->{ $visible[0] }->{ 'no_port' } = [$port,0]; # no port
			}
		}
		print "\n";
	}}

# fix ifPhysAddress

# read neighbour visibility from lldp

sub port2number {
	my ($name,$port) = @_;

	return $port if $port =~ m/^\d+$/;
	$port =~ s{bridge\d*/}{};  # remove mikrotik port prefix
	$port =~ s{,bridge\d*$}{}; # remove mikrotik port suffix
	$port =~ s{,bonding\d*$}{}; # remove mikrotik port suffix

	if ( exists $sw->{$name}->{port_name_to_number}->{$port} ) {
		return $sw->{$name}->{port_name_to_number}->{$port};
	}

	# gigabitethernet1/0/45 or gi1/0/45
	if ( $port =~ m{(.+)1/0/(\d+)$} ) {
		my ($type,$port) = ($1,$2);
		if ( $type =~ m{gi}i ) {
			return $port;
		} elsif ( $type =~ m{te}i ) {
			return $port <= 4 ? $port + 10000 : $port;
		} else {
			die "unknown [$type]";
		}
	}

	# linux
	if ( $port =~ m{eth(\d+)} ) {
		return $1;
	}

	my @fuzzy = grep { m/^$port/ } keys %{ $sw->{$name}->{port_name_to_number} };
	if ( scalar @fuzzy == 1 ) {
		return $sw->{$name}->{port_name_to_number}->{$fuzzy[0]}
	}

	warn "ERROR [$_] can't find port $port for $name in ",dump( $sw->{$name}->{port_name_to_number} );
}

sub fix_sw_name {
	my $name = shift;
	if ( $name eq 'rack3-lib' ) {
		$name = 'sw-lib-srv';
	}
	return $name;
}


open(my $n_fh, '<', '/dev/shm/neighbors.tab');
while(<$n_fh>) {
	chomp;
	my ( $sw1, $port1, undef, $port2, $sw2, undef ) = split(/\t/, $_, 6 );
	next if $port2 =~ m/:/; # skip mac in port number (wap lldp leek)
	next unless $sw2 && $port2;
	$sw1 = fix_sw_name($sw1);
	my $port1_nr = port2number( $sw1, $port1 );
	my $port2_nr = port2number( $sw2, $port2 );

	if ( $sw->{$sw1}->{ifType}->[$port1_nr] ne 'ethernetCsmacd' ) {
		warn "SKIP $sw1 $port1_nr $sw->{$sw1}->{ifType}->[$port1_nr]\n";
		next;
	} elsif ( $port1 =~ m{bridge} ) { # skip mikrotik bridges
#		warn "SKIP $sw1 $port1_nr $port1\n";
#		next;
	}

	$gv->{$sw1}->{$port1_nr}->{$sw2}->{$port2_nr} = [ $port1, $port2 ];
	delete $gv->{$sw1}->{$port1_nr}->{$sw2}->{'no_port'} if exists $gv->{$sw1}->{$port1_nr}->{$sw2}->{'no_port'};
}

# FIXME sw-b101 doesn't have lldp so we insert data here manually from pictures
sub fake_gv {
	my ($sw1, $p1, $sw2, $p2) = @_;
	$gv->{$sw1}->{$p1}->{$sw2}->{$p2} = [ $p1, $p2 ];
	$gv->{$sw2}->{$p2}->{$sw1}->{$p1} = [ $p2, $p1 ];
}
delete $gv->{'sw-b101'};
fake_gv( 'sw-b101' => 3, 'sw-b101' => 4 ); # vlan1-to-vlan2 / vlan2-to-vlan1

fake_gv( 'sw-b101' => 21, 'sw-rack2' => 50 );
fake_gv( 'sw-b101' => 23, 'sw-lib-srv' => 48 );
fake_gv( 'sw-b101' => 24, 'sw-rack1' => 48 );

#delete $gv->{'sw-ganeti'};
# spf-16 -> "sw-rack2"        => { 2 => ["16-sfp-uplink-b101,bridge", "te1/0/2"] },

print "# gv = ",dump( $gv );

open(my $dot_fh, '>', '/tmp/network.dot');
print $dot_fh qq|
digraph topology {
graph [ rankdir = LR ]
node [ shape = record ]
edge [ color = "gray" ]
|;

my @edges;
my $node;

foreach my $sw1 ( sort keys %$gv ) {
	foreach my $p1 ( sort { $a <=> $b } keys %{ $gv->{$sw1} } ) {
		foreach my $sw2 ( sort keys %{ $gv->{$sw1}->{$p1} } ) {
			if ( $sw1 eq $sw2 ) {
				warn "SKIP same switch $sw1 == $sw2\n";
				next;
			}
			#push @{ $node->{$sw1} }, [ $p1, $sw2 ];
			foreach my $p2 ( keys %{ $gv->{$sw1}->{$p1}->{$sw2} } ) {
				push @edges, [ $sw1, $sw2, $p1, $p2 ];
				##push @{ $node->{$sw2} }, [ $p2, $sw1 ];
				push @{ $node->{$sw1} }, [ $p1, $sw2, $p2 ];
			}
		}
	}
}

foreach my $n ( keys %$node ) {
	no warnings;
	my @port_sw =
		sort { $a->[0] <=> $b->[0] }
		@{ $node->{$n} };
	print $dot_fh qq!"$n" [ label="!.uc($n).'|' . join('|', map {
		sprintf "<%d>%2d %s%s", $_->[0], $_->[0], $_->[1], $_->[2] eq 'no_port' ? '' : ' ' . $_->[2]
	} @port_sw ) . qq!" ];\n!;
}

foreach my $e ( @edges ) {
	no warnings;
	print $dot_fh sprintf qq{ "%s":%d -> "%s":%d\n}, $e->[0], $e->[2], $e->[1], $e->[3];
}

print $dot_fh qq|
}
|;

system "dot -Tsvg /tmp/network.dot > /var/www/network.svg";