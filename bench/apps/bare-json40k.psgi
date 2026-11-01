#!/usr/bin/env perl
use strict;
use warnings;

# A ~40KB JSON document: the shape response compression exists for, and the
# only honest way to measure it. Compare this row against itself with the
# server's `compress => 1` on and off, and read BOTH numbers - requests/sec
# AND bytes on the wire. A throughput drop that buys a 6x smaller response
# is a pass, and the trade is only legible if both are recorded.
#
# Deliberately repetitive-but-not-degenerate: real API payloads are lists of
# similar records, which is why they compress as well as they do. A body of
# one repeated character would flatter gzip and prove nothing.
my $body = '{"items":[' . join(',', map {
    sprintf '{"id":%d,"name":"record %d","status":"%s","note":"%s"}',
        $_, $_, ($_ % 3 ? 'active' : 'pending'),
        "a short human sentence about item $_ that varies a little"
} 1 .. 320) . ']}';

my @headers = ('Content-Type'   => 'application/json',
               'Content-Length' => length $body);

sub { [ 200, \@headers, [$body] ] };
