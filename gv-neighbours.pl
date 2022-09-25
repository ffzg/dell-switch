#!/usr/bin/perl
use warnings;
use strict;
use autodie;
use Storable;
use Data::Dump qw(dump);

$|=1;

my $gv = Storable::retrieve( '/tmp/gv.storable' );
delete $gv->{'sw-core'}->{$_} foreach 7 .. 10; # remove sw-b101 lacp
warn "# gv = ",dump( $gv );

my @sw = qw( sw-core );
my @prefix = ( '' );

my $done_sw;

foreach my $sw ( @sw ) {

	$done_sw->{$sw}++;
	next if $done_sw->{$sw} > 1;

	my $s = delete( $gv->{$sw} );
	if ( ! $s ) {
		#die "no sw $sw in gv";#,dump($gv);
		warn "ERROR: no $sw in gv";
		next;
	}
	my $prefix = shift @prefix;
warn "XX $sw";
	foreach my $port ( sort { $a <=> $b } keys %$s ) {
		my $to_sw   = ( keys %{ $s->{$port}           } )[0];
		my @to_ports=   keys %{ $s->{$port}->{$to_sw} } ;
		my $to_port = $to_ports[0];

		if ( scalar @to_ports > 1 ) {
			warn "ERROR $sw $port -- $to_sw more than one destination port ",dump( @to_ports );
		}

		next if $to_port eq 'no_port';

		next if $prefix =~ m/\b$to_sw\b/; # skip back link to upstream

		( $port, $to_port ) = @{ $s->{$port}->{$to_sw}->{$to_port} }; # replace port number with name

		print "$prefix $sw $port $to_sw $to_port\n";

		next if $done_sw->{$to_sw};

		if ( $to_sw =~ m/^sw-/ ) {
			push @prefix, "$prefix $sw $port $to_sw $to_port";
			push @sw, $to_sw;
			warn "++ $to_sw";
		} else {
			warn "SKIP $to_sw treathing as end-point";
		}
	}
}

