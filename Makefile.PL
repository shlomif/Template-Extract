#!/usr/bin/env perl
# $File: //member/autrijus/Template-Extract/Makefile.PL $ $Author: autrijus $
# $Revision: #3 $ $Change: 9292 $ $DateTime: 2003/12/13 01:55:15 $

use 5.006;
use inc::Module::Install;

requires	('Template' => '2.00');
include_deps	('Test::More', 5.006);
build_requires	('Test::More', 0);

author		('Autrijus Tang (autrijus@autrijus.org)');
name		('Template-Extract');
abstract	('Extract data structure from TT2-rendered documents');
version_from	('lib/Template/Extract.pm');
sign		(1);

&WriteAll;
