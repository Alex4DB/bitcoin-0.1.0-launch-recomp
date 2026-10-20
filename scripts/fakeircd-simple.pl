#!/usr/bin/perl
# Minimal IRC server for Bitcoin 0.1 ThreadIRCSeed: hostname notice, 004,
# then a WHO reply (352) for a u-nickname (new address) and, a few seconds
# later, a JOIN of the same nickname (already-known address -> the else branch
# with mapAddresses.count in the launch-day 0.1.0).
use strict; use warnings; use IO::Socket::INET;
$| = 1; $/ = "\r";  # Bitcoin 0.1 ends IRC lines with a bare CR
my $nick = "u4HUtbXQT3ySNk";   # 1.2.3.4:8333, test address
my $srv = IO::Socket::INET->new(LocalAddr => "127.0.0.1", LocalPort => 6667, Listen => 5, ReuseAddr => 1) or die "listen: $!";
while (my $c = $srv->accept) {
  print "IRCD: client connected\n";
  print $c ":srv NOTICE AUTH :*** Found your hostname\r\n";
  my $me = "x";
  while (my $l = <$c>) {
    $l =~ s/[\r\n]+//g; print "IRCD < $l\n";
    $me = $1 if $l =~ /^NICK (\S+)/;
    if ($l =~ /^USER /) { print $c ":srv 001 $me :Welcome\r\n:srv 004 $me srv test\r\n"; }
    if ($l =~ /^WHO /) {
      print $c ":srv 352 $me #bitcoin n=u host srv $nick H :0 $nick\r\n:srv 315 $me #bitcoin :End of /WHO list.\r\n";
      sleep 3;
      print "IRCD > JOIN $nick (known)\n";
      print $c ":$nick!n=u\@host JOIN :#bitcoin\r\n";
      sleep 3;
      print $c ":$nick!n=u\@host JOIN :#bitcoin\r\n";
    }
  }
  print "IRCD: client gone\n";
}
