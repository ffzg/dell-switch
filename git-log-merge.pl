#!/usr/bin/perl
use warnings;
use strict;
use autodie;
use Data::Dump qw(dump);
use Carp;

my @repos = qw(
/home/dpavlin/dell-switch/running-config/
/home/dpavlin/mikrotik-switch/backup/
/home/dpavlin/tilera/backup/
);

my $debug = $ENV{DEBUG} || 0;
$| = 1 if $debug;

open(my $less, '|-', "less -R -S");

my $commit;
my $commit_next;

our $fh;
my $date_commit;

sub get_commit {
	my $repo = shift;
	my $r = $fh->{$repo};
	Carp::confess "ERROR on $repo in ",dump($fh) unless $r;
	while(<$r>) {
		if ( m/(\e\[\d*m)?commit [0-9a-f]+/ ) {
		#if ( m/commit [0-9a-f]+/ ) {
			if ( ! defined $commit->{$repo} ) { # first time, read commit
				$commit->{$repo} = $_;
				warn "## first commit ",dump($_) if $debug;
			} else {
				$commit_next->{$repo} = $_;
				warn "## --------------" if $debug;
				last;
			}
		} elsif (m/Date:\s+([0-9-\+: ]+)/ ) {
			$date_commit->{$1} = $repo;
			warn "# $repo $1" if $debug;
			$commit->{$repo} .= $_;
		} else {
			$commit->{$repo} .= $_;
			warn "## $repo $. ",dump($_) if $debug;
		}
	}
}

foreach my $repo ( @repos ) {
	$ENV{PAGER} = 'cat';
	open(my $r, '-|', "git -C $repo log --date=iso --color @ARGV");
	$fh->{$repo} = $r;
	get_commit $repo;
}


while(1) {
	#warn "# date_commit = ",dump($date_commit);
	my $date = ( sort { $b cmp $a } keys %$date_commit )[0];
	my $repo = $date_commit->{$date};
	print $less "# $date $repo\n$commit->{$repo}";
	$commit->{$repo} = $commit_next->{$repo};
	delete $date_commit->{$date};
	get_commit $repo;
}
