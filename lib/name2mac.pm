package name2mac;
use warnings;
use strict;
use autodie;

use Data::Dump qw(dump);

my $debug = 1;

my @name_mac_files = ( qw( /dev/shm/sw-name-mac /dev/shm/wap-name-mac ), $ENV{NAME_MAC}, glob '/dev/shm/name-mac*' );

our $mac2name;
my $underscore_whitespace = 0;

foreach my $name_mac ( @name_mac_files ) {
	next unless -e $name_mac;
	open(my $f, '<'. $name_mac);
	my $count = 0;
	while(<$f>) {
		chomp;
		#my ( $ip, $name, $mac ) = split(/ /,$_);
		my ( $name, $mac ) = split(/\s+/,$_);
		$name =~ s/_/ /g if $underscore_whitespace;	# replace underscore with space
		$mac = lc($mac);
		#$mac2name->{$mac} = $name;

		if ( defined $mac2name->{$mac} ) {
			if ( $mac2name->{$mac} ne $name ) {
				warn "ERROR: GOT $mac with $mac2name->{$mac} and now trying to overwrite it with $name\n";
			}
		} else {
			$mac2name->{$mac} = $name;
		}

		#$mac_name_use->{$name} = 0;
		$count++;
	}
	warn "## $name_mac $count";
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

#warn "# mac2name = ",dump($mac2name) if $debug;

1;
