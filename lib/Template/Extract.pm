# $File: //member/autrijus/Template-Extract/lib/Template/Extract.pm $ $Author: autrijus $
# $Revision: #6 $ $Change: 7820 $ $DateTime: 2003/09/01 10:11:13 $ vim: expandtab shiftwidth=4

package Template::Extract;
$Template::Extract::VERSION = '0.21';

use 5.006;
use strict;
use warnings;
use base 'Template';
use Template::Parser;
our $DEBUG;

=head1 NAME

Template::Extract - Extract data structure from TT2-rendered documents

=head1 VERSION

This document describes version 0.21 of Template::Extract, released
September 1, 2003.

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

This module is a subclass of the B<Template> toolkit, with added template
extraction functionality.  It can take a rendered document and its template
together, and get the original data structure back, effectively reversing
the C<process> function.

This module is considered experimental.  If you just wish to extract
RSS-type information out of a HTML document, B<WWW::SherlockSearch>
may be a more robust solution.

=head1 METHODS

=head2 $obj->extract($template, $document, \%values)

This method takes three arguments: the template string, or a reference to
it; a document string to match against; and an optional hash reference to
store the extracted values into.

Extraction is done by transforming the result from I<Template::Parser>
to a highly esoteric regular expression, which utilizes the (?{...}) 
construct to insert matched parameters into the hash reference.

The special C<[% ... %]> directive is taken as C</.*?/s> in regex terms,
i.e. "ignore everything (as short as possible) between this identifier
and the next one".  For backward compatibility reasons, C<[% _ %]> and
C<[% __ %]> are also accepted.

You may set C<$Template::Extract::DEBUG> to a true value to display
generated regular expressions.

=head1 CAVEATS

Currently, the C<extract> method only handles C<[% GET %]>,
C<[% SET %]> and C<[% FOREACH %]> directives, because C<[% WHILE %]>,
C<[% CALL %]> and C<[% SWITCH %]> blocks are next to impossible to
extract correctly.

There is no support for different I<PRE_CHOMP> and I<POST_CHOMP> settings 
internally, so extraction could fail silently on wrong places.

=head1 NOTES

This module's companion class, B<Template::Generate>, is still missing;
it's supposed to take a data structure and the preferred rendering, and
automagically generate a template to do the transformation. If you are
into related research, please mail any ideas to me.

=cut

my ($params, $cur_loop, %loop);

sub extract {
    my ($self, $template, $document, $ext_param) = @_;
    my ($output, $error);

    if (!defined($self->{regex})) {
        $self->set_param($ext_param);
        $params = {};
        %loop = ();
        $cur_loop = undef;

        my $parser = Template::Parser->new({
            PRE_CHOMP  => 1,
            POST_CHOMP => 1,
        });
    
        $parser->{ FACTORY } = ref($self);
        $template = $$template if UNIVERSAL::isa($template, 'SCALAR');
        $template =~ s/\n+$//;
        $template =~ s/\[%\s*(?:\.\.\.|_)\s*%\]/[% __ %]/g;

        $self->{regex} = $parser->parse($template)->{ BLOCK };
    }

    if ($document) {
        use re 'eval';
        print "Regex: [\n$self->{regex}\n]\n" if $DEBUG;
        return $document =~ /$self->{regex}/s ? $params : undef;
    }
}

sub _enter_loop {
    if ($cur_loop and $cur_loop->{id} == $_[1]) {
        $cur_loop->{count}++;
        $cur_loop->{var} = {};
    }
    else {
        $cur_loop = $loop{$_[1]} ||= {
            name    => $_[0],
            id      => $_[1],
            count   => 0,
            var     => {},
        };
    }
}

sub _validate {
    return;
    my $vars = shift;
    my $obj;

    $obj = (_adjust($params, @_))[0]->{$_[0]};
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
        my $cur = $loop{$_[0]};
        my $index = $cur->{var}{$num}++; # the iteration we are currently in
        $obj = (_traverse($params, @_))[0]->{$cur->{name}}[$index] ||= {};
    }
    else {
        $obj = $params;
    }

    ($obj, $var) = _adjust($obj, @$var);
    $obj->{$var} = $val;
    return;
}

sub _adjust {
    my ($obj, $val) = (shift, pop);

    foreach my $var (@_) {
        $obj = $obj->{$var} ||= {};
    }
    return ($obj, $val);
}

sub _traverse {
    my $obj = shift;
    my $val = shift;

    my $depth = -1;
    foreach my $id (reverse @_) {
        my $var = $loop{$id}{name};
        my $index = $cur_loop->{count};
        $obj = $obj->{$var}[$index] ||= {};
    }
    return ($obj, $val);
}

# Factory API implementation begins here

my $count      = 0;
my $ext_param  = {};
my $last_regex = '';
my $block_id;

sub set_param { 
    $ext_param = $_[-1] if defined $_[-1];
}

sub template {
    my $reg = $_[1];

    $count = 0;
    $block_id = 0;
    $reg =~ s/\*\*//g;
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
        ? _re("_set(([$_[1]], \$^N, $count)\*\*)")
        : _re("_set(([$_[1]], \$$count, $count)\*\*)");
    return "(.*?)";
}

sub set {
    return unless defined $ext_param;

    my @parents = map {$_[1][0][$_ * 2]} (0 .. $#{$_[1][0]} / 2);
    my $val = $_[1][1];
    my ($obj, $var);
    
    $_ = substr($_, 1, -1) foreach @parents;

    ($obj, $var) = _adjust($ext_param, @parents);
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

    # find out immediate SET childrens
    my %vars;
    $vars{$1}++ while $reg =~ m/_set\(\(\[('\w+')[^\]]*\], \$\^N, \d+\)\*\*/g;
    my $vars = join(', ', sort keys %vars);

    # append this block's id into the _set calling chain
    $block_id++;
    $reg =~ s/\*\*/, $block_id\*\*/g;

    return _re("_enter_loop($_[2], $block_id)") .   # sets $cur_loop
           "(?:$reg)*" .                            # match content
           _re("_validate([$vars], $_[2])")         # weed out partial matches
}

sub text {
    return $_[1];
}

sub quoted {
    my $output = '';

    foreach my $token (@{$_[1]}) {
        if ($token =~ m/^'(.+)'$/) { # nested hash traversal
            $output .= '$';
            $output .= "{$_}" foreach split(/','/, $1);
        }
        else {
            $output .= $token;
        }
    }
    return $output;
}

# handy method to add regex eval brackets
sub _re { "(?{\n    @_\n})" }

our $AUTOLOAD;

sub AUTOLOAD {
    return unless $DEBUG;

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

sub DESTROY {}

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
