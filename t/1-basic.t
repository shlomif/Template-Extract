#!/usr/bin/perl
# $File: //member/autrijus/Template-Extract/t/1-basic.t $ $Author: autrijus $
# $Revision: #2 $ $Change: 7798 $ $DateTime: 2003/08/30 21:33:11 $ vim: expandtab shiftwidth=4

use strict;
use Test::More tests => 4;

use_ok('Template::Extract');

my $obj = Template::Extract->new;
isa_ok($obj, 'Template');
isa_ok($obj, 'Template::Extract');

my $template = << '.';
<ul>[% FOREACH record %]
<li><A HREF="[% url %]">[% title %]</A>: [% rating %] - [% comment %].
[% ... %]
[% END %]</ul>
.

my $document = << '.';
<html><head><title>Great links</title></head><body>
<ul><li><A HREF="http://slashdot.org">News for nerds.</A>: A+ - nice.
this text is ignored.</li>
<li><A HREF="http://microsoft.com">Where do you want...</A>: Z! - yeah.
this text is ignored, too.</li></ul>
.

my $result = $obj->extract($template, $document);

is_deeply($result, {
    'record' => [ { 
        'rating'    => 'A+',
        'comment'   => 'nice',
        'url'       => 'http://slashdot.org',
        'title'     => 'News for nerds.',
    }, {
        'rating'    => 'Z!',
        'comment'   => 'yeah',
        'url'       => 'http://microsoft.com',
        'title'     => 'Where do you want...',
    } ]
}, 'extract() as documented in synopsis');

