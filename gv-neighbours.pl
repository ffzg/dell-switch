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

foreach my $sw ( @sw ) {
	my $s = delete( $gv->{$sw} ) || die "no sw $sw in ",dump($gv);
	my $prefix = shift @prefix;
warn "XX $sw";
	foreach my $port ( sort { $a <=> $b } keys %$s ) {
		my $to_sw   = ( keys %{ $s->{$port}           } )[0];
		my $to_port = ( keys %{ $s->{$port}->{$to_sw} } )[0];
		next if $to_port eq 'no_port';
		next if $prefix =~ m/\b$to_sw\b/;
		print "$prefix $sw $port $to_sw $to_port\n";
		push @prefix, "$prefix $sw $port $to_sw $to_port";
		push @sw, $to_sw;
	}
}

