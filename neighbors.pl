#!/usr/bin/perl
use warnings;
use strict;
use autodie;

# ./sw-ip-name-mac.sh
# ./sw-names | xargs -i ./dell-switch.pl {} 'show lldp neighbors'

use Data::Dump qw(dump);

my $mac2ip;
my $mac2name;

open(my $f, '<'. '/dev/shm/sw-ip-name-mac');
while(<$f>) {
	chomp;
	my ( $ip, $name, $mac ) = split(/ /,$_);
	$mac2ip->{$mac} = $ip;
	$mac2name->{$mac} = $name;
}

warn "# mac2name = ",dump($mac2name);

foreach my $file ( glob('log/*lldp*') ) {
	my ( undef, $name, undef ) = split(/_/, $file);
	print "# $name $file\n";

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

			if ( $file =~ m/remote-device/ ) {
				$line_regex =~ s{\) \(}{.)(}g;
				$line_regex =~ s{\(\.+\)$}{(.+)}g;
			}

			print "## line_regex = $line_regex\n";
			next;
		}

		s{^\s+}{} if $file =~ m/remote-device/; # remote left-over from pager

		if ( defined($line_regex) &&  /$line_regex/ ) {
 			# port, mac, remote_port, system_name, capabilities
			my @v = ( $1, $2, $3, $4, $5 );

			if ( $file =~ m/neighbors/ ) {

				# show lldp neighbours
				# Port       Device ID          Port ID          System Name     Capabilities 

			} elsif ( $file =~ m/remote-device/ ) {

				# show lldp remote-device all
				# Interface RemID   Chassis ID          Port ID           System Name

				@v = ( $v[0], $v[2], $v[3], $v[4], '' );

				# move overflow numbers from system name to port id
				if ( $v[3] =~ s{^(\d+)}{} ) {
					$v[2] .= $1;
				}

			} else {
				die "don't know how to parse $file";
			}

			print "# [$_] ",join('|',@v),$/;

			@v = map { s/^\s+//; s/\s+$//; $_ } @v;

			if ( length($v[1]) == 6 ) { # decode text mac
				$v[1] = unpack('H*', $v[1]);
				$v[1] =~ s/(..)/$1:/g;
				$v[1] =~ s/:$//;
			}

			if ( exists $mac2name->{$v[1]} ) {
				my $mac_name = $mac2name->{$v[1]};
				if ( $v[3] eq '' ) {
					$v[3] = $mac_name;
				} else {
					warn "ERROR: name different $v[3] != $mac_name" if $v[3] ne $mac_name;
				}
			}

			#my ( $port, $device_id, $port_id, $system_name, $cap ) = @v;
			if ( @ports && $v[0] =~ m/^$/ ) {
				my @old = @{ pop @ports };
				foreach my $i ( 0 .. $#old ) {
					$old[$i] .= $v[$i];
				}
				push @ports, [ @old ];
			} else {
				push @ports, [ @v ];
			}
		} else {
			print "# $_<--\n";
		}
	}

	foreach my $p ( @ports ) {
		next if ( $p->[1] eq $p->[2] && $p->[3] eq '' ); # FIXME hosts?
		print "$name ", join(' | ', @$p ), "\n";
	}
}
