#!/usr/bin/perl
use warnings;
use strict;
use autodie;

use Data::Dump qw(dump);

my $dir="/dev/shm/snmpbulkwalk";

my $stat;

my @dumps = @ARGV;
@dumps = glob("$dir/*") unless @dumps;

sub macfmt {
	my $mac = shift;
	$mac =~ s/^([0-9a-f]):/0$1:/i;
	while ( $mac =~ s/:([0-9a-f]):/:0$1:/ig ) {};
	$mac =~ s/:([0-9a-f])$/:0$1/i;
	return $mac;
}

foreach my $file ( @dumps ) {

	open(my $fh, '<', $file);
	my $sw = $file; $sw =~ s/^.*\///;
	while(<$fh>) {
		chomp;
		if ( m/^SNMPv2-MIB::(sysName|sysDescr)\.0 = STRING: (.+)/ ) {
			$stat->{$sw}->{$1} = $2;
=for xxx
		} elsif ( m/^(IF-MIB)::(ifPhysAddress)\.0 = (\w+): (.+)/ ) {
			my ($name,$oid,$type,$value) = ($1,$2,$3,$4);
			#$value =~ s/\(\d+\)$// if $type eq 'INTEGER';
			$stat->{$sw}->{$name}->{$oid} = $value;
=cut
		} elsif ( m/^(IF-MIB)::(ifPhysAddress)\[(\d+)\] = (\w+): (.+)/ ) {
			my ($name,$oid,$i,$type,$value) = ($1,$2,$3,$4,$5);
			#warn "# $sw ",dump($name,$oid,$i,$type,$value),$/;
			#$stat->{$sw}->{$name}->{$oid}->[$i] = $value;
			$stat->{_mac2sw}->{$value} = $sw;
		} elsif ( m/^BRIDGE-MIB::dot1dTpFdbPort\[STRING: ([^\]]+)\] = INTEGER: (\d+)/ ) {
			my ( $mac, $port ) = ($1,$2);
			push @{ $stat->{_sw_mac_port_vlan}->{$sw}->{$mac}->{$port} }, '';
		} elsif ( m/^Q-BRIDGE-MIB::dot1qTpFdbPort\[(\d+)\]\[STRING: ([^\]]+)\] = INTEGER: (\d+)/ ) {
			my ( $vlan, $mac, $port ) = ($1,$2,$3);
			push @{ $stat->{_sw_mac_port_vlan}->{$sw}->{$mac}->{$port} }, $vlan;
		}
	}
	#warn "# $sw ",dump( $stat->{$sw} );
}
#warn "# stat = ",dump($stat);

open(my $fh, '>', '/dev/shm/mac2sw');
foreach my $mac ( keys %{ $stat->{_mac2sw} } ) {
	print $fh $mac, " ", macfmt( $stat->{_mac2sw}->{$mac} ), "\n";
};

my $s = $stat->{_sw_mac_port_vlan};
foreach my $sw ( keys %$s ) {
	foreach my $mac ( keys %{ $s->{$sw} } ) {
		if ( my $mac_name = $stat->{_mac2sw}->{ $mac } ) {
			next if $sw eq $mac_name; # mikrotik seems to see itself
			foreach my $port ( keys %{ $s->{$sw}->{$mac} } ) {
				#$stat->{_sw_port_sw}->{$sw}->{$port}->{$mac_name} = $s->{$sw}->{$mac}->{$port};
				push @{ $stat->{_sw_port_sw}->{$sw}->{$port} }, $mac_name;
			}
		}
	}
}

warn "# _sw_port_sw = ",dump($stat->{_sw_port_sw});

open(my $dot, '>', '/tmp/snmp-topology.dot');
print $dot "digraph topology {\n";

my $s = $stat->{_sw_port_sw};
our $later;
my $last_later;

sub uniq {
	my @visible = @_;
	my $u; $u->{$_}++ foreach @visible;
	@visible = sort keys %$u;
	return @visible;
}

sub uniq_visible {
	my @visible = uniq(@_);
	@visible = grep { ! exists $stat->{_found}->{$_} } @visible;
	return @visible;
}

sub to_later {
	my $sw = shift;
	my $port = shift;
	my @visible = uniq_visible(@_);
	warn "# to_later $sw $port visible = ", $#visible + 1, "\n";
	$later->{$sw}->{$port} = [ @visible ];
	return @visible;
}

while ( ref $s ) {
#warn "## s = ",dump($s);
foreach my $sw ( sort keys %$s ) {

	#warn "## $sw s = ",dump($s->{$sw}),$/;

	my @ports = sort { $a <=> $b } uniq( keys %{ $s->{$sw} } );

	foreach my $port ( @ports ) {
		warn "## $sw $port => ",join(' ', @{$s->{$sw}->{$port}}),$/;
	}
	if ( $#ports == 0 ) {
		my $port = $ports[0];
		#print "$sw $port TRUNK\n";
		push @{$stat->{_trunk}->{$sw}}, $port; # FIXME multiple trunks?
		#warn "## _trunk = ",dump( $stat->{_trunk} ).$/;

		my @visible = uniq_visible( @{ $s->{$sw}->{$port} } );
		to_later( $sw, $port, @visible );
		next;
	}

	foreach my $port ( @ports ) {
		my @visible = uniq_visible( @{ $s->{$sw}->{$port} } );
		warn "### $sw $port visible=",dump(\@visible),$/;

		if ( $#visible == 0 ) {
			warn "++++ $sw $port $visible[0]\n";
			#print "$sw $port $visible[0]\n";
			print $dot qq{ "$sw" -> "$visible[0]" [ label="$port" ];\n};
			$stat->{_found}->{$visible[0]} = "$sw $port";
		
		} elsif ( @visible ) {
			to_later( $sw, $port, @visible );
		} else {
			warn "#### $sw $port doesn't have anything visible\n";
		}
			
	}
	warn "## _found = ",dump( $stat->{_found} ),$/;
}

warn "NEXT later = ",dump($later),$/;
$s = $later;

my $d = dump($later);
if ( $d eq $last_later ) {
	warn "FIXME later didn't change, last\n";
	last;
}
$last_later = $d;

$later = undef;

} # while

print $dot "}\n";

warn "FINAL _found = ",dump( $stat->{_found} ),$/;
warn "FINAL _trunk = ",dump( $stat->{_trunk} ),$/;

foreach my $sw ( keys %{ $stat->{_found} } ) {
	printf "%s -> %s %s\n", $stat->{_found}->{$sw}, $sw, uniq(@{ $stat->{_trunk}->{$sw} });
}
