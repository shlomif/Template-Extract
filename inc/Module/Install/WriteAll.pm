#line 1 "inc/Module/Install/WriteAll.pm - /usr/local/lib/perl5/site_perl/5.8.0/Module/Install/WriteAll.pm"
# $File: //depot/cpan/Module-Install/lib/Module/Install/AutoInstall.pm $ $Author: autrijus $
# $Revision: #12 $ $Change: 1481 $ $DateTime: 2003/05/07 10:41:22 $ vim: expandtab shiftwidth=4

package Module::Install::WriteAll;
use Module::Install::Base; @ISA = qw(Module::Install::Base);

sub WriteAll {
    my $self = shift;

    $self->Meta->write;

    $self->load($_) for qw(Makefile check_nmake can_run get_file);
    $self->load('Build') if -e 'Build.PL';

    if ($0 =~ /Build.PL$/i) {
	$self->Build->write;
    }
    else {
	$self->check_nmake;
        $self->makemaker_args( PL_FILES => {} )
            unless $self->makemaker_args->{'PL_FILES'};
	$self->Makefile->write;
    }
}

1;
