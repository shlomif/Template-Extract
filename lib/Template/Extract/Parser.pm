package Template::Extract::Parser;
$Template::Extract::Parser::VERSION = '0.40';

use 5.006;
use strict;
use warnings;
use base 'Template::Parser';

=head1 NAME

Template::Extract::Parser - Template parser for extraction

=head1 SYNOPSIS

    use Template::Extract::Parser;

    my $parser = Template::Extract::Parser->new(\%config);
    my $template = $parser->parse($text) or die $parser->error();

=head1 DESCRIPTION

This is a trivial subclass of C<Template::Extract>; the only difference
with its base class is that C<PRE_CHOMP> and C<POST_CHOMP> is enabled by
default.

=cut

sub new {
    my $class  = shift;
    my $params = shift || {};

    $class->SUPER::new(
        {
            PRE_CHOMP  => 1,
            POST_CHOMP => 1,
            %$params,
        }
    );
}

1;

=head1 SEE ALSO

L<Template::Extract>, L<Template::Parser>

=head1 AUTHORS

Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>

=head1 COPYRIGHT

Copyright 2005 by Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>.

This program is free software; you can redistribute it and/or 
modify it under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut
