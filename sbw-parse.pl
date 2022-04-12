#!/usr/bin/perl
use warnings;
use strict;
use autodie;

# ./sw-name-mac.sh

# usage: NAME_MAC=/dev/shm/file-with-name-space-mac sbw-parse.pl [optional-switch-snmpbulkwalk-dump]

use Data::Dump qw(dump);

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
	if ( $port =~ m{1/0/(\d+)$} ) {
		return $1;
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
	$gv->{$sw1}->{$port1_nr}->{$sw2}->{$port2_nr} = [ $port1, $port2 ];
	delete $gv->{$sw1}->{$port1_nr}->{$sw2}->{'no_port'} if exists $gv->{$sw1}->{$port1_nr}->{$sw2}->{'no_port'};
}

print "# gv = ",dump( $gv );
