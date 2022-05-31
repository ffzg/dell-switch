#!/usr/bin/perl
use warnings;
use strict;
use autodie;
use Data::Dump qw(dump);

# ./vlan-ports.pl ./log/*sw-{dpc,e300}*vlan* | less

my $debug = $ENV{DEBUG} || 1;

my @logs = @ARGV;
@logs = glob('./log/*vlan*') unless @logs;

my $stat;

foreach my $log ( @logs ) {
	warn "###< $log\n" if $debug;
	open(my $log_fh, '-|', "./table2tab.pl '$log'");
	my $sw = $log; $sw =~ s/^.*?_//; $sw =~ s/_.*$//;
	while(<$log_fh>) {
		chomp;
		if ( m/\t/ ) {
			my ($vlan,$name,$ports,$type,$authorization);

			my @v = split(/\t/, $_);

			if ( $#v == 4 ) {
				($vlan,$name,$ports,$type,$authorization) = @v;
			} elsif ( $#v == 3 ) {
				($vlan,$name,$ports,$type) = @v;
			} elsif ( $#v == 5 ) {
				($vlan,$name,$ports,undef,$type) = @v;
			} else {
				warn "ERROR: ", scalar(@v), " elements in [$_]" if $#v != 4;
			}

			$ports =~ s{(Po|Gi\d/\d/|Te\d/\d/)}{}gi;

			warn "$sw $vlan $name $ports $type\n";
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
			warn "INGORED [$_]\n";
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
			$p[$port] = $port;
		}
		shift @p; # skip port 0
		#warn "# $sw $vlan p = ",dump( \@p );
		printf( "%-11s %-5d %s\n", $sw, $vlan, join(' ', map { sprintf("%-2s", $_) } @p) );
	}
}

