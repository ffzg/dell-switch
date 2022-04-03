#!/usr/bin/perl
use warnings;
use strict;
use autodie;

# ./sw-names | xargs -i ./dell-switch.pl {} 'show lldp neighbors'

foreach my $file ( glob('log/*lldp*') ) {
	my ( undef, $name, undef ) = split(/_/, $file);
	#print "# $name $file\n";

	my $line_regex;
	my @ports;

	open(my $f, '<', $file);
	while(<$f>) {
		chomp;
		#print "## $_<--\n";
		next if ( /^$/ || /^\s+Port/ );
		if ( /^--+/ ) {
			$line_regex = $_;
			$line_regex =~ s/\s+$//;
			$line_regex =~ s/-/./g;
			$line_regex =~ s/^/(/g;
			$line_regex =~ s/ /) (/g;
			$line_regex =~ s/$/)/g;
			#print "## line_regex = $line_regex\n";
			next;
		}
		if ( defined($line_regex) &&  /$line_regex/ ) {
			my @v = ( $1, $2, $3, $4, $5 );
			@v = map { s/^\s+//; s/\s+$//; $_ } @v;
			if ( length($v[1]) == 6 ) {
				$v[1] = unpack('H*', $v[1]);
				$v[1] =~ s/(..)/$1:/g;
				$v[1] =~ s/:$//;
			}
			#my ( $port, $device_id, $port_id, $system_name, $cap ) = @v;
			if ( $v[0] =~ m/^$/ ) {
				my @old = @{ pop @ports };
				foreach my $i ( 0 .. $#old ) {
					$old[$i] .= $v[$i];
				}
				push @ports, [ @old ];
			} else {
				push @ports, [ @v ];
			}
		} else {
			warn "# $_<--\n";
		}
	}

	foreach my $p ( @ports ) {
		print "$name ", join(' ', @$p ), "\n";
	}
}
