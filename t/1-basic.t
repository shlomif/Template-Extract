#!/usr/bin/perl
# $File: //member/autrijus/Template-Extract/t/1-basic.t $ $Author: autrijus $
# $Revision: #5 $ $Change: 7822 $ $DateTime: 2003/09/01 12:53:35 $ vim: expandtab shiftwidth=4

use strict;
use Test::More tests => 6;

use_ok('Template::Extract');

my ($obj, $template, $document, $result);

$obj = Template::Extract->new;
isa_ok($obj, 'Template');
isa_ok($obj, 'Template::Extract');

$template = << '.';
<ul>[% FOREACH record %]
<li><A HREF="[% url %]">[% title %]</A>: [% rating %] - [% comment %].
[% ... %]
[% END %]</ul>
.

$document = << '.';
<html><head><title>Great links</title></head><body>
<ul><li><A HREF="http://slashdot.org">News for nerds.</A>: A+ - nice.
this text is ignored.</li>
<li><A HREF="http://microsoft.com">Where do you want...</A>: Z! - yeah.
this text is ignored, too.</li></ul>
.

$result = $obj->extract($template, $document);

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

$obj = Template::Extract->new;

$template = << '.';
[% FOREACH subject %]
[% ... %]
<h1>[% sub.heading %]</h1>
<ul>[% FOREACH record %]
<li><A HREF="[% url %]">[% title %]</A>: [% rating %] - [% comment %].
[% ... %]
[% END %]</ul>
[% ... %]
[% END %]
<ol>[% FOREACH record %]
<li><A HREF="[% url %]">[% title %]</A>: [% rating %] - [% comment %].
[% ... %]
[% END %]</ol>
.

$document = << '.';
<html><head><title>Great links</title></head><body>
<h1>Foo</h1>
<ul><li><A HREF="http://slashdot.org">News for nerds.</A>: A+ - nice.
this text is ignored.</li>
<li><A HREF="http://microsoft.com">Where do you want...</A>: Z! - yeah.
this text is ignored, too.</li></ul>
<h1>Bar</h1>
<ul><li><A HREF="http://slashdot.org">News for nerds.</A>: A+ - nice.
this text is ignored.</li>
<li><A HREF="http://microsoft.com">Where do you want...</A>: Z! - yeah.
this text is ignored, too.</li></ul>
<ol><li><A HREF="http://cpan.org">CPAN.</A>: +++++ - cool.
this text is ignored, also.</li></ol>
.

#$Template::Extract::DEBUG++;
$result = $obj->extract($template, $document);
#use YAML; print YAML::Dump($result);

is_deeply($result, {
    'record' => [ { 
        'rating'    => '+++++',
        'comment'   => 'cool',
        'url'       => 'http://cpan.org',
        'title'     => 'CPAN.',
    } ],
    subject => [map { {
    'sub' => { 'heading' => $_ },
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
} } qw(Foo Bar)] }, 'extract() with two nested and one extra FOREACH');

$obj = Template::Extract->new;

$template = << '.';
_[% C %][% D %]_
_[% D %][% E %]_
_[% E %][% D %][% C %]_
.

$document = << '.';
_doeray_
_rayme_
_meraydoe_
.

$result = $obj->extract($template, $document);

is_deeply($result, {
    'C' => 'doe',
    'D' => 'ray',
    'E' => 'me'
}, 'extract() with backtracking');

