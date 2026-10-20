#!/usr/bin/perl
# Scenario IRC server for the launch model (Bitcoin 0.1 ends lines with a bare CR).
# SCEN=hal1: replay of Hal's first session: our own JOIN and WHO line first
#   (own address, not routable -> AddAddress false -> count on an EMPTY map),
#   then a new routable address (u4HUtbXQT3ySNk = 1.2.3.4) in the WHO list,
#   then that node re-JOINs (count on a non-empty map).
# SCEN=own: only our own JOIN (Hal's sessions 2 and 3, map loaded from addr.dat).
# SCEN=quiet: no JOIN or WHO lines at all.
use strict; use warnings; use IO::Socket::INET;
$| = 1; $/ = "\r";
my $scen = $ENV{SCEN} || 'hal1';
my $peer = "u4HUtbXQT3ySNk";
my $srv = IO::Socket::INET->new(LocalAddr => "127.0.0.1", LocalPort => 6667, Listen => 5, ReuseAddr => 1) or die "listen: $!";
while (my $c = $srv->accept) {
  print "IRCD: client connected ($scen)\n";
  print $c ":srv NOTICE AUTH :*** Found your hostname\r\n";
  my $me = "x";
  while (my $l = <$c>) {
    $l =~ s/[\r\n]+//g; print "IRCD < $l\n";
    $me = $1 if $l =~ /^NICK (\S+)/;
    print $c ":srv 001 $me :Welcome\r\n:srv 004 $me srv test\r\n" if $l =~ /^USER /;
    next unless $l =~ /^WHO /;
    next if $scen eq 'quiet';
    print "IRCD > own JOIN $me\n"; print $c ":$me!n=u\@host JOIN :#bitcoin\r\n"; sleep 2;
    next if $scen eq 'own';
    print $c ":srv 352 $me #bitcoin n=u host srv $me H :0 $me\r\n:srv 352 $me #bitcoin n=u host srv $peer H :0 $peer\r\n:srv 315 $me #bitcoin :End of /WHO list.\r\n";
    sleep 3; print "IRCD > JOIN $peer (known)\n"; print $c ":$peer!n=u\@host JOIN :#bitcoin\r\n";
  }
  print "IRCD: client gone\n";
}
