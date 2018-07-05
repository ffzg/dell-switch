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
					push @{ $stat->{$sw}->{$port} }, $vlan;
				}
			}
			while ( $ports =~ s/(\d+)// ) {
				my $port = $1;
				push @{ $stat->{$sw}->{$port} }, $vlan;
			}
			#warn "# ports left:[$ports] stat = ",dump($stat);
		} else {
			warn "INGORED [$_]";
		}
	}
}

print dump($stat);

