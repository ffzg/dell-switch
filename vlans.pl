#!/usr/bin/perl
use warnings;
use strict;
use autodie;
use Data::Dump qw(dump);

# ./vlans.pl ./log/*sw-{dpc,e300}*vlan* | less

my $debug = $ENV{DEBUG} || 0;
$| = 1 if $debug;

my @logs = @ARGV;
@logs = glob('./log/*vlan*') unless @logs;

my $stat;

foreach my $log ( @logs ) {
	warn "###< $log\n" if $debug;
	open(my $log_fh, '-|', "./table2tab.pl '$log'");
	my $sw = $log; $sw =~ s/^.*?_//; $sw =~ s/_.*$//;
	while(<$log_fh>) {
		chomp;
		next unless m/\t/;

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

		#$ports =~ s{(Po|Gi\d/\d/|Te\d/\d/)}{}gi;

		warn "## $sw $vlan $name $ports $type\n" if $debug;
		$stat->{$sw}->{_vlan_count}->{$vlan}++;

		#while ( $ports =~ s/(ch\([^\)]+\))// ) {
		#	warn "# removed [$1] from ports\n";
		#}


		sub range {
			my ( $prefix, $f, $t ) = @_;
			$prefix = '' if ! defined $prefix;
			@v = ( $f .. $t );
			my $v = join(',', map { $prefix . $_ } @v);
			warn "XXX range $prefix $f $t = $v\n" if $debug;
			return $v;
		}
		$ports =~ s{(Po|Gi\d/\d/|Te\d/\d/)?(\d+)-(\d+)}{range($1,$2,$3)}ige;

		sub expand {
			my ( $prefix, $nrs ) = @_;
			my @v;
			push @v, $prefix . '(' . $_ . ')' foreach split(/,/,$nrs);
			my $v = join(',', @v);
			warn "XXX expand $prefix $nrs = $v\n" if $debug;
			return $v;
		}

		while ( $ports =~ s/([\w\/]+)\((\d+(:?,\d+)+)\)/expand($1,$2)/ge ) {
			warn "# ports $ports\n" if $debug;
		}	

		foreach my $port ( split(/,/, $ports ) ) {
			$port =~ s{^(g|ch)\((\d+)\)$}{$1$2}; # g(42) -> g42
			print "$sw $port $vlan\n";
		}
	}

}

warn dump($stat),$/;



