#!/usr/bin/env perl
# $File: //member/autrijus/Template-Extract/Makefile.PL $ $Author: autrijus $
# $Revision: #1 $ $Change: 7794 $ $DateTime: 2003/08/30 17:01:35 $

use 5.006;
use inc::Module::Install;

include_deps   ('Test::More', 5.006);
build_requires ('Test::More', 0);

WriteMakefile (
    AUTHOR	    => 'Autrijus Tang (autrijus@autrijus.org)',
    NAME	    => 'Template::Extract',
    ABSTRACT	    => 'Extract data structure from TT2-rendered documents',
    VERSION_FROM    => 'lib/Template/Extract.pm',
    PREREQ_PM       => {
        'Template'  => '2.00',
    },
);

