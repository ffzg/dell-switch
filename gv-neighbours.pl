#!/usr/bin/perl
use warnings;
use strict;
use autodie;
use Storable;
use Data::Dump qw(dump);

my $gv = Storable::retrieve( '/tmp/gv.storable' );
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
		my $to_port = ( keys %{ $s->{$port}->{$to_sw} } )[0];

		next if $to_port eq 'no_port';

		next if $prefix =~ m/\b$to_sw\b/; # skip back link to upstream

		( $port, $to_port ) = @{ $s->{$port}->{$to_sw}->{$to_port} }; # replace port number with name

		print "$prefix $sw $port $to_sw $to_port\n";

		if ( $to_sw =~ m/^sw-/ ) {
			push @prefix, "$prefix $sw $port $to_sw $to_port";
			push @sw, $to_sw;
			warn "++ $to_sw";
		} else {
			warn "SKIP $to_sw treathing as end-point";
		}
	}
}

