#!perl
use 5.010;
use strict;
use warnings;
use FindBin ();
use lib "$FindBin::Bin/lib";
use Test::More;
use Punk::Plugin::Sitemap;

# $app->keyword($name => @args) and $app->has_keyword($name): how a plugin
# calls a keyword ANOTHER plugin installed, from code rather than from the
# application's package body. What is tested is that the call is the same
# call the bareword would have made - same arguments, same context, same
# return - and that the two failure modes croak rather than do nothing.

our @SEEN;

# ---- the same call the bareword makes -----------------------------------------

{
    {
        package KwApp;
        use Punk;
        BEGIN {
            KwApp->punk_app->install_kw(record => sub {
                push @main::SEEN, [@_];
                return wantarray ? (1, 2, 3) : 'scalar';
            }, 'Some::Plugin');
        }
        record 'a', 'b';                       # the bareword form
    }

    my $app = KwApp->punk_app;
    $app->keyword(record => 'a', 'b');         # the method form
    is_deeply(\@SEEN, [['a', 'b'], ['a', 'b']],
        'keyword() hands the installed code the same arguments the bareword does');

    $app->keyword('record');
    is_deeply($SEEN[-1], [], '...and no arguments when there are none');
}

# ---- context is propagated, not forced ----------------------------------------

{
    my $app = KwApp->punk_app;
    my $scalar = $app->keyword('record');
    my @list   = $app->keyword('record');
    is($scalar, 'scalar', 'a scalar-context call gets the scalar return');
    is_deeply(\@list, [1, 2, 3], 'and a list-context call keeps its list');
    my @none = do { $app->keyword('record'); () };
    is_deeply(\@none, [], 'a void-context call returns nothing');
}

# ---- has_keyword ---------------------------------------------------------------

{
    my $app = KwApp->punk_app;
    is($app->has_keyword('record'), 'Some::Plugin',
        'has_keyword answers the installing owner');
    ok(!defined $app->has_keyword('nope'), '...undef for a keyword nothing installed');
    ok(!defined $app->has_keyword('get'),
        '...and undef for a core DSL word, which is a method and not a keyword');
    ok(!defined $app->has_keyword(''), '...and undef for no name at all');
}

# ---- the install is per application -------------------------------------------

{
    {
        package OtherApp;
        use Punk;
    }
    my $app = OtherApp->punk_app;
    ok(!defined $app->has_keyword('record'),
        'a keyword installed on one application is not seen from another');
    my $err = '';
    eval { $app->keyword(record => 1); 1 } or $err = $@;
    like($err, qr/no keyword 'record' is installed on this application/,
        '...and calling it there croaks naming the keyword');
    is_deeply($SEEN[-1], [], '...without running the other application\'s code');
}

# ---- the failure modes croak ----------------------------------------------------

{
    my $app = KwApp->punk_app;
    my $err = '';
    eval { $app->keyword(get => '/x' => sub { 1 }); 1 } or $err = $@;
    like($err, qr/keyword 'get' is part of the Punk DSL/,
        'a core DSL word is refused - it is the registrar\'s own method');
    $err = '';
    eval { $app->keyword('' => 1); 1 } or $err = $@;
    like($err, qr/keyword needs a name/, 'an empty name is refused');
}

# ---- the reason it exists: one plugin consuming another's keyword -------------
# A blog-shaped plugin adds a sitemap section from an on_compile callback,
# which is where it can be sure the application's own `plugin 'Sitemap'`
# line has run whatever order the two lines were written in.

{
    {
        package SiteApp;
        use Punk;
        plugin 'Sitemap' => { base => 'https://example.com' };
        get '/' => sub { $_[0]->text('home') };
    }

    my $app = SiteApp->punk_app;
    is($app->has_keyword('sitemap'), 'Punk::Plugin::Sitemap',
        'the consumer can see that the application loaded Sitemap');

    $app->on_compile(sub {
        my ($a) = @_;
        $a->keyword(sitemap => blog => sub {
            return ({ loc => '/blog/post/hello', lastmod => 1_700_000_000 });
        });
    }, 'T::Blog');

    SiteApp->to_app;
    my $doc = Punk::Plugin::Sitemap->_doc($app);
    like($doc, qr{<loc>https://example\.com/blog/post/hello</loc>},
        'a section added through keyword() from on_compile is in the document');
    like($doc, qr{<loc>https://example\.com/</loc>},
        '...beside the route half');
}

{
    {
        package NoSiteApp;
        use Punk;
        get '/' => sub { $_[0]->text('home') };
    }
    my $app = NoSiteApp->punk_app;
    ok(!defined $app->has_keyword('sitemap'),
        'an application without Sitemap has no sitemap keyword');
    my $err = '';
    eval { $app->keyword(sitemap => blog => sub { () }); 1 } or $err = $@;
    like($err, qr/no keyword 'sitemap' is installed.*is the plugin that provides it loaded/,
        '...and asking anyway croaks with the hint');
}

done_testing();
