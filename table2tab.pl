#!/usr/bin/perl
use warnings;
use strict;
use autodie;

use Data::Dump qw(dump);

# parse formatted dell output with
# --- ------- -----
# to tab delimited lines

my $debug = $ENV{DEBUG} || 0;

my $line_regex;
my @line_regex_short;
my @lines;

while(<>) {
	chomp;

	if ( /^--+/ ) {
		$line_regex = $_;
		$line_regex =~ s/\s+$//;
		$line_regex =~ s/-/./g;
		$line_regex =~ s/^/(/g;
		$line_regex =~ s/(\s+)/)$1(/g;
		$line_regex =~ s/$/)/;

		my $l = $line_regex;
		while ( $l ) {
			my $l_w = $l;
			$l_w =~ s/\.+\)$/.+)/;
			push @line_regex_short, $l_w;
			$l =~ s/\s*\(\.+\)$//;
			warn "# [$l]\n" if $debug;
		}

		print STDERR "$_\n$line_regex\n", dump( @line_regex_short ), "\n" if $debug;
		next;
	}

	my @v;

	if ( defined($line_regex) ) {
		my @v = ( /$line_regex/ );

		foreach my $regex ( @line_regex_short ) {
			last if @v;
			@v = ( /$regex/ );
		}

		if ( @v ) {
			@v = map { s/^\s+//; s/\s+$//; $_ } @v;
			warn "# v = ",dump(@v) if $debug;
			if ( $v[0] eq '' ) {

				foreach my $i ( 1 .. $#v ) {
					next if $v[$i] eq '';
					$lines[$#lines]->[$i] .= $v[$i];
				}

			} else {
				push @lines, [ @v ];
			}
		} else {
			push @lines, [ $_ ];
			warn "SKIP [$_]\n" if $debug;
		}
	} else {
		push @lines, [ $_ ];
	}
}

foreach my $a ( @lines ) {
	print join("\t", @$a), "\n" 
}
