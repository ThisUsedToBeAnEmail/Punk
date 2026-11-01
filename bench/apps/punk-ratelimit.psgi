#!/usr/bin/env perl
use strict;
use warnings;
use FindBin ();
use lib "$FindBin::Bin/../../lib";

# punk-hello plus one rate_limit rule, so the per-request path into
# Hyperman's shared arena (ratelimit_hit through the ABI) is on the bench
# board. The limit is never reached: every request is a counted hit and a
# 200, which is what the rule costs when it is doing its job quietly.
package BenchRateLimit;
use Punk;

rate_limit limit => 1_000_000_000, window => 60;

get '/' => sub { $_[0]->text('hello') };

package main;
BenchRateLimit->to_app;
