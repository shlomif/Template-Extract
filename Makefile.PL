#!/usr/bin/env perl
# $File: //member/autrijus/Template-Extract/Makefile.PL $ $Author: autrijus $
# $Revision: #4 $ $Change: 9563 $ $DateTime: 2004/01/03 06:52:01 $

use 5.006;
use inc::Module::Install;

author		('Autrijus Tang <autrijus@autrijus.org>');
name		('Template-Extract');
abstract	('Extract data structure from TT2-rendered documents');
version_from	('lib/Template/Extract.pm');
license		('perl');

requires	(
    perl	=> 5.006,
    Template	=> 2.00,
);
build_requires	('Test::More');

auto_include();
WriteAll( sign => 1 );
