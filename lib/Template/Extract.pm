# $File: //member/autrijus/Template-Extract/lib/Template/Extract.pm $ $Author: autrijus $
# $Revision: #1 $ $Change: 7794 $ $DateTime: 2003/08/30 17:01:35 $

package Template::Extract;
use 5.006;

$Template::Extract::VERSION = '0.10';

use strict;
use warnings;
use Template::Parser;
use base qw/Template/;

=head1 NAME

Template::Extract - Extract data structure from TT2-rendered documents

=head1 SYNOPSIS

    use Template::Extract;
    use Data::Dumper;

    my $obj = Template::Extract->new;
    my $template = << '.';
    <ul>[% FOREACH record %]
    <li><A HREF="[% url %]">[% title %]</A>: [% rate %] - [% comment %].
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

    print Data::Dumper::Dumper(
	$obj->extract($template, $document)
    );

=head1 DESCRIPTION

This module is a subclass of the standard I<Template> toolkit, with 
added template extraction functionality, which means you can take
a I<process()>ed document and its template together, and get the
original data structure back.

The C<extract> method takes three arguments: the template file itself
(leave it undefined if already initialized), a scalar to match against
it, and an optional external hash reference to store the extracted
values.

Extraction is done by transforming the result from I<Template::Parser>
to a highly esoteric regular expression, which utilizes the (?{...}) 
construct to insert matched parameters into the hash reference.

The special C<[% ... %]> directive is understood as C<(?:[\x00-\xff]*?)>
in regex terms, i.e. "ignore everything between this identifier and
the next".  For backward compatibility reasons, C<[% _ %]> is also
accepted (but deprecated).

This module is considered experimental.  If you just want to extract
RSS-type information out of a HTML document, B<WWW::SherlockSearch>
may be a more robust solution.

=head1 CAVEATS

Currently, the extract function only understands C<[% GET %]>, C<[% SET %]>
and C<[% FOREACH %]> directives, since C<[% WHILE %]>, C<[% CALL %]> and
C<[% SWITCH %]> blocks are next to impossible to extract correctly.

Its companion class, B<Template::Generate>, is still missing; it's
supposed to take a data structure and the preferred rendering, and
automagically generate a template to do the transformation. If you
are into related research, please mail any ideas to me.

=head1 BUGS

Nested capturing will sometimes suffer from off-by-one errors with perl 
v5.7.1 or earlier; later versions supports the <$^N> variable and is
exempt from such errors.

There is no support for different I<PRE_CHOMP> and I<POST_CHOMP> settings 
internally, so extraction could fail silently on wrong places.

=cut

my ($params, $flagroot);

sub generate {
    die 'Template generation is not yet accomplished.';
}

sub extract {
    my ($self, $template, $document, $ext_param) = @_;
    my ($output, $error);

    if (!defined($self->{regex})) {
        Template::Extract->set_param($ext_param);
        $params = { %{$flagroot} = () };

        my $parser = Template::Parser->new({
            PRE_CHOMP  => 1,
            POST_CHOMP => 1,
        });
    
        $parser->{ FACTORY } = ref($self);
	$template = $$template if UNIVERSAL::isa($template, 'SCALAR');
	$template =~ s/\n+$//;
	$template =~ s/\[% (?:\.\.\.|_) %\]/[% __ %]/g;

        $self->{regex} = $parser->parse($template)->{ BLOCK };
    }

    if ($document) {
        use re 'eval';
        print "Regex: [$self->{regex}]\n" if $::DEBUG;
        return $document =~ /$self->{regex}/s ? $params : undef;
    }
}

sub _validate {
    my $vars = shift;
    my $obj;

    my ($flagnode, $lastvar) = _adjust($flagroot, @_);
    $obj = (_adjust($params, @_))[0]->{$lastvar};
    return unless UNIVERSAL::isa($obj, 'ARRAY');

    @{$obj} = grep {
	my $entry = $_;
 	scalar (grep { exists $entry->{$_} } @{$vars}) == scalar @{$vars};
    } @{$obj};
}

sub _set {
    my ($var, $val, $num) = splice(@_, 0, 3);
    my $obj;

    if (@_) {
        my ($flagnode, $lastvar) = _adjust($flagroot, @_);

        $obj = (_adjust($params, @_))[0]->{$lastvar}[
	    $flagnode->{$lastvar}{$num}++
	] ||= {};
    }
    else {
        $obj = $params;
    }

    ($obj, $var) = _adjust($obj, $var);
    $obj->{$var} = $val;
    
    return;
}

sub _adjust {
    my ($obj, $val) = (shift, pop);

    $obj = $obj->{$_} ||= {} foreach @_;
    return ($obj, $val);
}

# The worker methods

my $count      = 0;
my $ext_param  = {};
my $last_regex = '';
my @vars;

sub set_param { 
    $ext_param = $_[-1] if defined $_[-1];
}

sub template {
    my $reg = $_[1];

    $count = 0;
    $reg =~ s/, \*\*//g; # this is safe because normal *s are escaped
    return $reg;
}

sub block {
    return join('', @{ $_[1] || [] });
}

sub ident {
    return join(',', map {$_[1][$_ * 2]} (0 .. int($#{$_[1]}) / 2));
}

sub get {
    return '.*?' if ($_[1] eq "'__'");

    ++$count; # which capturing parenthesis is this?

    # ** is the placeholder for parent tree in foreach() 
    $last_regex = ($] >= 5.007002)
	? "(?{_set($_[1], \$^N, $count, **)})"
	: "(?{_set($_[1], \$$count, $count, **)})";

    push @vars, $_[1];

    return "(.*?)";
}

sub set {
    return unless defined $ext_param;

    my @parents = map {$_[1][0][$_ * 2]} (0 .. int($#{$_[1][0]}) / 2);
    my $val = $_[1][1];
    my ($obj, $var);
    
    $_ = substr($_, 1, -1) foreach @parents;

    ($obj, $var) = Template::Extract::_adjust($ext_param, @parents);
    $obj->{$var} = $val;
    
    return '';
}

sub textblock {
    my $ret = quotemeta($_[1]) . $last_regex;

    $last_regex = '';
    return $ret;
}

sub foreach {
    my $reg = $_[4];

    $last_regex = "(?{_validate([".join(',', @vars)."], $_[2])})";
    undef @vars;

    $reg =~ s/\*\*/$_[2]/g; # this is safe because normal *s are escaped
    return "(?:$reg)*";
}

sub text {
    return $_[1];
}

sub quoted {
    my $output = '';

    foreach my $token (@{$_[1]}) {
        if ($token =~ m/^'(.+)'$/) { # nested hash traversal
            $output .= '$';
            $output .= "{$_}" foreach split("','", $1);
        }
        else {
            $output .= $token;
        }
    }
    return $output;
}

our $AUTOLOAD;

sub AUTOLOAD {
    return unless $::DEBUG;

    require Data::Dumper;
    $Data::Dumper::Indent = 1;

    my $output = "\n$AUTOLOAD -";

    for my $arg (1..$#_) {
        $output .= "\n    [$arg]: ";
        $output .= ref($_[$arg]) 
	    ? Data::Dumper->Dump([$_[$arg]], ['__']) 
	    : $_[$arg];
    }

    print $output;

    return '';
}

1;

=head1 SEE ALSO

L<Template>, L<Template::Parser>, L<WWW::SherlockSearch>

=head1 AUTHORS

Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>

=head1 COPYRIGHT

Copyright 2001, 2002, 2003 by Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>.

This program is free software; you can redistribute it and/or 
modify it under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut
