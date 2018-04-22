#!/usr/bin/perl
use warnings;
use strict;
use autodie;
use Data::Dump qw(dump);

open(my $dot, '>', '/dev/shm/wap-scan.dot');
print $dot qq|digraph wap {

|;

my $stat;

sub path2hostname {
	my $hostname = shift;
	$hostname =~ s/^.*\///;
	$hostname =~ s/_.*$//;
	return $hostname;
}

my $mac2hostname;
foreach my $link ( glob "/dev/shm/wap/*ip_link*" ) {
	my $hostname = path2hostname $link;
	open(my $fh, '<', $link);
	my $if;
	while(<$fh>) {
		chomp;
		if ( m/^\d+:\s(\S+):/ ) {
			$if = $1;
		} elsif ( m/link\/ether\s(\S+)/ ) {
			push @{ $mac2hostname->{$1}->{$hostname} }, $if;
		}
	}

}

warn "# mac2hostname = ",dump($mac2hostname);

foreach my $scan ( glob "/dev/shm/wap/*iw_*_scan" ) {
	my $hostname = path2hostname $scan;

	open(my $fh, '<', $scan);
	my $bss;
	while(<$fh>) {
		chomp;
		if ( m/^BSS\s(\S+)\(on\s(\S+)\)/ ) {
			$bss = $1;
			$stat->{$hostname}->{$bss} = {
				if => $2,
			};
		
		} elsif ( m/^\s*(freq|signal|SSID):\s*(.+)/ ) {
			$stat->{$hostname}->{$bss}->{$1} = $2;
		}
	}

}

warn "# stat = ", dump($stat);

sub _dot {
	my $t = shift;
	$t =~ s/\W+/_/g;
	return $t;
}

foreach my $ap ( keys %$stat ) {
	foreach my $bss ( keys %{ $stat->{$ap} } ) {
		if ( exists $mac2hostname->{$bss} ) {
			my $remote = join(',', keys %{ $mac2hostname->{$bss} } );
			print "$ap $remote ";
			my $len = $stat->{$ap}->{$bss}->{signal} || die "no signal in ",dump($stat->{$ap}->{$bss});
			$len =~ s/ \w+//;
			$len = abs($len);
			printf $dot qq| %s -> %s [ len = %d ];\n|, _dot($ap),_dot($remote),$len;
		} else {
			print "$ap EXTERNAL ";
		}
		my $info = dump( $stat->{$ap}->{$bss} );
		$info =~ s/[\n\r\s]+/ /gs;
		print "$bss $info\n";
	}
}

print $dot qq|
}
|;
__END__

ls /dev/shm/wap/*iw_*_scan | while read file ; do

	hostname=`echo $file | sed -e 's/^.*\///' -e 's/_.*$//'`

	echo `egrep '(BSS|freq:|signal:|SSID:)' $file` \
	| sed -e 's/\n  */ /g' -e "s/ *BSS/\n## $hostname BSS/g" -e 's/ *(on \([^ ][^ ]*\)) */ \1 /g'
done

