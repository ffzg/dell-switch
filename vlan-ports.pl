#!/usr/bin/perl
use warnings;
use strict;
use autodie;
use Data::Dump qw(dump);

# ./vlan-ports.pl ./log/*sw-{dpc,e300}*vlan* | less

my @logs = @ARGV;

my $stat;

foreach my $log ( @logs ) {
	open(my $log_fh, '<', $log);
	my $sw = $log; $sw =~ s/^.*?_//; $sw =~ s/_.*$//;
	while(<$log_fh>) {
		chomp;
		if ( m/\s*(\d+)\s+(\S+)\s+([gc]\S+)\s+(\w+)\s+(\w+)/ ) {
			my ($vlan,$name,$ports,$type,$authorization) = ( $1,$2,$3,$4,$5 );

			warn "$sw $vlan $name $ports $type $authorization\n";
			$stat->{$sw}->{_vlan_count}->{$vlan}++;

			while ( $ports =~ s/(ch\([^\)]+\))// ) {
				warn "# removed [$1] from ports\n";
			}

			while ( $ports =~ s/(\d+)-(\d+)// ) {
				foreach my $port ( $1 .. $2 ) {
					push @{ $stat->{$sw}->{port_vlan}->{$port} }, $vlan;
					push @{ $stat->{$sw}->{vlan_port}->{$vlan} }, $port;
				}
			}
			while ( $ports =~ s/(\d+)// ) {
				my $port = $1;
				push @{ $stat->{$sw}->{port_vlan}->{$port} }, $vlan;
				push @{ $stat->{$sw}->{vlan_port}->{$vlan} }, $port;
			}
			#warn "# ports left:[$ports] stat = ",dump($stat);
		} else {
			warn "INGORED [$_]";
		}
	}
}

warn dump($stat),$/;


foreach my $sw ( sort keys %$stat ) {
	my @ports = sort { $a <=> $b } keys %{ $stat->{$sw}->{port_vlan} };
	#warn "# ports = ",dump( \@ports );
	printf( "%-11s %-5s %s\n", ('-' x 11), ('-' x 5), join(' ', map { sprintf("%-2s", $_) } ( 1 .. $ports[-1] )) );
	foreach my $vlan ( sort { $a <=> $b } keys %{ $stat->{$sw}->{vlan_port} } ) {
		my @p = ( '.' ) x ( $ports[-1] + 1 );
		foreach my $port ( @{ $stat->{$sw}->{vlan_port}->{$vlan} } ) {
			$p[$port] = 'X';
		}
		shift @p; # skip port 0
		#warn "# $sw $vlan p = ",dump( \@p );
		printf( "%-11s %-5d %s\n", $sw, $vlan, join(' ', map { sprintf("%-2s", $_) } @p) );
	}
}

