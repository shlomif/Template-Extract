# $File: //member/autrijus/Template-Extract/lib/Template/Extract.pm $ $Author: autrijus $
# $Revision: #18 $ $Change: 9564 $ $DateTime: 2004/01/03 08:54:59 $ vim: expandtab shiftwidth=4

package Template::Extract;
$Template::Extract::VERSION = '0.34';

use 5.006;
use strict;
use warnings;
use base 'Template';
use Template::Parser;
our ($DEBUG, $EXACT);

=head1 NAME

Template::Extract - Extract data structure from TT2-rendered documents

=head1 VERSION

This document describes version 0.34 of Template::Extract, released
January 3, 2004.

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

=head1 METHODS

=head2 extract($template, $document, \%values)

This method takes three arguments: the template string, or a reference to
it; a document string to match against; and an optional hash reference to
supply initial values, as well as storing the extracted values into.

The return value is C<\%values> upon success, and C<undef> on failure.
If C<\%values> is omitted from the argument list, a new hash reference
will be constructed and returned.

Extraction is done by transforming the result from B<Template::Parser>
to a highly esoteric regular expression, which utilizes the C<(?{...})>
construct to insert matched parameters into the hash reference.

The special C<[% ... %]> directive is taken as the C</.*?/s> regex, i.e.
I<ignore everything (as short as possible) between this identifier and
the next one>.  For backward compatibility, C<[% _ %]> and C<[% __ %]>
are also accepted.

The special C<[% // %]> directive is taken as a non-capturing regex,
embedded inside C</(?:)/s>; for example, C<[% /\d*/ %]> matches any
number of digits.  Capturing parentheses may not be used with this
directive.

You may set C<$Template::Extract::DEBUG> to a true value to display
generated regular expressions.

The extraction process defaults to succeed even with a partial match.
To match the entire document only, set C<$Template::Extract::EXACT> to
a true value.

=head1 CAVEATS

Currently, the C<extract> method only supports C<[% GET %]>,
C<[% SET %]> and C<[% FOREACH %]> directives, because C<[% WHILE %]>,
C<[% CALL %]> and C<[% SWITCH %]> blocks are next to impossible to
extract correctly.

C<[% SET key = "value" %]> only works for simple scalar values.

Outermost C<[% FOREACH %]> blocks must match at least once in the
document, but inner ones may occur zero times.  This is to prevent
the regex optimizer from failing prematurely.

There is no support for different I<PRE_CHOMP> and I<POST_CHOMP> settings 
internally, so extraction could fail silently on extra linebreaks.

=head1 NOTES

This module's companion class, B<Template::Generate>, is still in early
experimental stages; it can take data structures and rendered documents,
then automagically generates templates to do the transformation. If you are
into related research, please mail any ideas to me.

=cut

my ( %loop, $cur_loop, $paren_id, $block_id, $data, @set );

sub extract {
    my ( $self, $template, $document, $ext_data ) = @_;

    $self->_init($ext_data);

    if ( defined $template ) {
	my $parser = Template::Parser->new(
	    {
                PRE_CHOMP  => 1,
		POST_CHOMP => 1,
	    }
	);

	$parser->{FACTORY} = ref($self);
	$template = $$template if UNIVERSAL::isa( $template, 'SCALAR' );
	$template =~ s/\n+$//;
	$template =~ s/\[%\s*(?:\.\.\.|_|__)\s*%\]/[% \/.*?\/ %]/g;
	$template =~ s/\[%\s*(\/.*?\/)\s*%\]/'[% "' . quotemeta($1) . '" %]'/eg;

	$self->{regex} = $parser->parse($template)->{BLOCK};
    }

    defined( $document )      or return undef;
    defined( $self->{regex} ) or return undef;

    {
        use re 'eval';
        print "Regex: [\n$self->{regex}\n]\n" if $DEBUG;
        return $data if $document =~ /$self->{regex}/s;
    }

    return undef;
}

sub _enter_loop {
    $cur_loop = $loop{ $_[1] } ||= {
	name  => $_[0],
	id    => $_[1],
	count => -1,
    };
    $cur_loop->{count}++;
    $cur_loop->{var} = {};
    $cur_loop->{pos} = {};
}

sub _leave_loop {
    my ($obj, $key, $vars) = @_;

    ref($obj) eq 'HASH' or return;
    my $old = $obj->{$key} if exists $obj->{$key};
    ref($old) eq 'ARRAY' or return;

    print "Validate: [$old $key @$vars]\n" if $DEBUG;

    my @new;

    OUTER:
    foreach my $entry (@$old) {
	next unless %$entry;
	foreach my $var (@$vars) {
	    # If it's a foreach, it needs to not match or match something.
	    if (ref($var)) {
		next if !exists($entry->{$$var}) or @{$entry->{$$var}};
	    }
	    else {
		next if exists($entry->{$var});
	    }
	    next OUTER; # failed!
	}
	push @new, $entry;
    }

    delete $_[0]{$key} unless @$old = @new;
}

sub _adjust {
    my ( $obj, $val ) = ( shift, pop );

    foreach my $var (@_) {
	$obj = $obj->{$var} ||= {};
    }
    return ( $obj, $val );
}

sub _traverse {
    my ( $obj, $val ) = ( shift, shift );

    my $depth = -1;
    while (my $id = pop(@_)) {
	my $var   = $loop{$id}{name};
        my $index = $loop{$_[-1] || $val}{count};
	$obj = $obj->{$var}[$index] ||= {};
    }
    return $obj;
}

# initialize temporary variables
sub _init {
    $paren_id = 0;
    $block_id = 0;
    %loop     = ();
    @set      = ();
    $cur_loop = undef;
    $data     = $_[1] || {};
}

# utility function to add regex eval brackets
sub _re { "(?{\n    @_\n})" }

# --- Factory API implementation begins here ---

sub template {
    my $regex = $_[1];

    $regex =~ s/\*\*//g;
    $regex =~ s/\+\+/+/g;
    $regex = "^$regex\$" if $EXACT;

    # Deal with backtracking here -- substitute repeated occurences of
    # the variable into backtracking sequences like (\1)
    my %seen;
    $regex =~ s{(                       # entire sequence [1]
        \(\.\*\?\)                      #   matching regex
        \(\?\{                          #   post-matching regex...
            \s*                         #     whitespaces
            _ext\(                      #     capturing handler...
                \(                      #       inner cluster of...
                    \[ (.+?) \],\s*     #         var name [2]
                    \$.*?,\s*           #         dollar with ^N/counter
                    (\d+)               #         counter [3]
                \)                      #       ...end inner cluster
                (.*?)                   #       outer loop stack [4]
            \)                          #     ...end capturing handler
            \s*                         #     whitespaces
        \}\)                            #   ...end post-maching regex
    )}{
        if ($seen{$2,$4}) {             # if var reoccured in the same loop
            "(\\$seen{$2,$4})"          #   replace it with backtracker
        } else {                        # otherwise
            $seen{$2,$4} = $3;          #   register this var's counter
            $1;                         #   and preserve the sequence 
        }
    }gex;
    return $regex;
}

sub foreach {
    my $regex = $_[4];

    # find out immediate children
    my %vars = reverse (
	$regex =~ /_ext\(\(\[(\[?)('\w+').*?\], [^,]+, \d+\)\*\*/g
    );
    my $vars = join( ',', map { $vars{$_} ? "\\$_" : $_ } sort keys %vars );

    # append this block's id into the _get calling chain
    ++$block_id;
    ++$paren_id;
    $regex =~ s/\*\*/, $block_id**/g;
    $regex =~ s/\+\+/*/g;

    return (
        # sets $cur_loop
        _re("_enter_loop($_[2], $block_id)") .
        # match loop content
        "(?:\\n*?$regex)++()" .
        # weed out partial matches
        _re("_ext(([[$_[2],[$vars]]], \\'leave_loop', $paren_id)**)") .
        # optional, implicit newline
        "\\n*?"
    );
}

sub get {
    return "(?:$1)" if $_[1] =~ m{^/(.*)/$};

    ++$paren_id;

    # ** is the placeholder for parent loop ids
    return "(.*?)" . _re("_ext(([$_[1]], \$$paren_id, $paren_id)\*\*)");
}

sub set {
    ++$paren_id;

    my $val = $_[1][1];
    $val =~ s/^'(.*)'\z/$1/;
    push(@set, $val);

    my $parents = join(
        ',', map {
            $_[1][0][ $_ * 2 ]
        } ( 0 .. $#{ $_[1][0] } / 2 )
    );
    return '()' . _re("_ext(([$parents], \\$#set, $paren_id)\*\*)");
}

sub _ext {
    my ( $var, $val, $num ) = splice( @_, 0, 3 );
    my $obj = $data;

    if (@_) {
	print "Ext: [ $$val with $num on $-[$num]]\n" if ref($val) and $DEBUG;

        # fetch current loop structure
	my $cur = $loop{ $_[0] };
	# if pos() changed, increment the iteration counter
	$cur->{var}{$num}++ if ( ( $cur->{pos}{$num} ||= -1 ) != $-[$num] )
	    or ref $val and $$val eq 'leave_loop';
        # remember pos()
	$cur->{pos}{$num} = $-[$num];

	my $iteration = $cur->{var}{$num} - 1;
	$obj = _traverse( $data, @_ )->{ $cur->{name} }[$iteration] ||= {};
    }

    ( $obj, $var ) = _adjust( $obj, @$var );

    if (!ref($val)) {
        $obj->{$var} = $val;
    }
    elsif ($$val eq 'leave_loop') {
        _leave_loop($obj, @$var);
    }
    else {
        $obj->{$var} = $set[$$val];
    }
}

sub textblock {
    return quotemeta( $_[1] );
}

sub block {
    return join( '', @{ $_[1] || [] } );
}

sub quoted {
    my $rv = '';

    foreach my $token ( @{ $_[1] } ) {
	if ( $token =~ m/^'(.+)'$/ ) {    # nested hash traversal
	    $rv .= '$';
	    $rv .= "{$_}" foreach split( /','/, $1 );
	}
	else {
	    $rv .= $token;
	}
    }

    return $rv;
}

sub ident {
    return join( ',', map { $_[1][ $_ * 2 ] } ( 0 .. $#{ $_[1] } / 2 ) );
}

sub text {
    return $_[1];
}

# debug routine to catch unsupported directives
sub AUTOLOAD {
    $DEBUG or return;

    require Data::Dumper;
    $Data::Dumper::Indent = 1;

    our $AUTOLOAD;
    print "\n$AUTOLOAD -";

    for my $arg ( 1 .. $#_ ) {
	print "\n    [$arg]: ";
	print ref( $_[$arg] )
	  ? Data::Dumper->Dump( [ $_[$arg] ], ['__'] )
	  : $_[$arg];
    }

    return '';
}

sub DESTROY { }

1;

=head1 SEE ALSO

L<Template>, L<Template::Generate>, L<Template::Parser>

Simon Cozens's introduction to this module, in O'Reilly's I<Spidering Hacks>:
L<http://www.oreillynet.com/pub/a/javascript/excerpt/spiderhacks_chap01/index.html>

Mark Fowler's introduction to this module, in The 2003 Perl Advent Calendar:
L<http://perladvent.org/2003/5th/>

=head1 AUTHORS

Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>

=head1 COPYRIGHT

Copyright 2001, 2002, 2003, 2004
by Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>.

This program is free software; you can redistribute it and/or 
modify it under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut
