#!/usr/bin/perl
use warnings;
use strict;
use autodie;

# ./sw-name-mac.sh
# ./sw-names | xargs -i ./dell-switch.pl {} 'show lldp neighbors'
# /home/dpavlin/mikrotik-switch/m-neighbour

use Data::Dump qw(dump);

my $debug = $ENV{DEBUG} || 0;

my $mac2name;

open(my $f, '<'. '/dev/shm/sw-name-mac');
while(<$f>) {
	chomp;
	#my ( $ip, $name, $mac ) = split(/ /,$_);
	my ( $name, $mac ) = split(/ /,$_);
	$mac = lc($mac);
	$mac2name->{$mac} = $name;
}

sub mac2name {
	my ( $mac, $name ) = @_;

	$mac = lc($mac);

	if ( exists $mac2name->{$mac} ) {
		my $mac_name = $mac2name->{$mac};
		warn "ERROR: name different $name != $mac_name" if $name && $name ne $mac_name;
		return ( $mac, $mac_name );
	}
	return ( $mac, $name );
}

warn "# mac2name = ",dump($mac2name) if $debug;

open(my $n_fh, '>', '/dev/shm/neighbors.tab');
open(my $html_fh, '>', '/var/www/neighbors.html');
print $html_fh qq{<table>\n};

# parse Dell switch lldp neighbors output

foreach my $file ( glob('log/*lldp*') ) {
	my ( undef, $name, undef ) = split(/_/, $file);
	print "# $name $file\n" if $debug;

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

			print "## line_regex = $line_regex\n" if $debug;
			next;
		}

		s{^\s+}{} if $file =~ m/remote-device/; # remote left-over from pager

		my @v;

		if ( defined($line_regex) &&  /$line_regex/ ) {
 			# port, mac, remote_port, system_name, capabilities
			@v = ( $1, $2, $3, $4, $5 );

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
		} elsif ( defined($line_regex) && $file =~ m/remote-device/ ) {
			# if we don't have system name, line_regex is too long
			my @s = split(/\s+/,$_);
			@v = ( $s[0], $s[2], $s[3], '', '' ) if $#s == 3;
		} elsif ( $debug ) {
			my $l = $line_regex;
			$l =~ s{[\(\)]}{}g;
			print "# [$_]<-- LINE IGNORED\n# [$l]\n",dump($_);
		}

		if (@v) {
			print "# [$_] ",join('|',@v),$/ if $debug;

			@v = map { s/^\s+//; s/\s+$//; $_ } @v;

			if ( length($v[1]) == 6 ) { # decode text mac
				$v[1] = unpack('H*', $v[1]);
				$v[1] =~ s/(..)/$1:/g;
				$v[1] =~ s/:$//;
			}

			( $v[1], $v[3] ) = mac2name( $v[1], $v[3] );


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
			if ( $debug ) {
				my $l = $line_regex;
				$l =~ s{[\(\)]}{}g;
				print "# [$_]<-- IGNORED no v\n# [$l]\n";
			}
		}
	}

	foreach my $p ( @ports ) {
		next if ( $p->[1] eq lc($p->[2]) && $p->[3] eq '' ); # FIXME hosts?
		print "$name ", join(' | ', @$p ), "\n";
		print $n_fh "$name\t", join("\t", @$p ), "\n";
		print $html_fh "<tr><td>$name</td><td>", join("</td><td>", @$p ), "</td></tr>\n";
	}
}

# prase MikroTik /ip neighbor print detail terse

foreach my $file ( glob('../mikrotik-switch/out/*neighbor*'), glob('../tilera/out/*neighbor*') ) {
	my $name = $1 if $file =~ m{out/([\w\-]+)\.ip neighbor};
	print "## [$name] file $file\n" if $debug;
	open(my $f, '<', $file);
	while(<$f>) {
		chomp;
		next if m/^\s*$/;
		s{^\s*\d+\s+}{}; # remote ordinal number
		print "# $_\n" if $debug;
		my $l;
		foreach my $kv ( split(/ /, $_) ) {
			my ($k,$v) = split(/=/, $kv);
			$l->{$k} = $v if ( defined($v) && $v ne '""' );
		}

		no warnings 'uninitialized';

		#warn "## l=",dump($l),$/;
		# Port       Device ID          Port ID          System Name     Capabilities 
		my @v = (
			$l->{interface},
			$l->{'mac-address'},
			$l->{'interface-name'},
			$l->{'identity'},
			#$l->{caps},
			join(' ', $l->{address}, $l->{platform}, $l->{board}, $l->{version} ),
		);

		( $v[1], $v[3] ) = mac2name( $v[1], $v[3] );

		print "$name ", join(' | ', @v), $/;
		print $n_fh "$name\t", join("\t", @v ), "\n";
		print $html_fh "<tr><td>$name</td><td>", join("</td><td>", @v ), "</td></tr>\n";
	}
}

print $html_fh qq{</table>\n};
