# $File: //member/autrijus/Template-Extract/lib/Template/Extract.pm $ $Author: autrijus $
# $Revision: #12 $ $Change: 8495 $ $DateTime: 2003/10/20 01:01:46 $ vim: expandtab shiftwidth=4

package Template::Extract;
$Template::Extract::VERSION = '0.30';

use 5.006;
use strict;
use warnings;
use base 'Template';
use Template::Parser;
our $DEBUG;

=head1 NAME

Template::Extract - Extract data structure from TT2-rendered documents

=head1 VERSION

This document describes version 0.30 of Template::Extract, released
October 20, 2003.

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

If you just wish to extract RSS-type information out of a HTML document,
B<WWW::SherlockSearch> may be a more flexible solution.

=head1 METHODS

=head2 extract($template, $document, \%values)

This method takes three arguments: the template string, or a reference to
it; a document string to match against; and an optional hash reference to
supply initial files, as well as storing the extracted values into.

The return value is C<\%values> upon success, and C<undef> on failure.
If C<\%values> is omitted from the argument list, a new hash reference
will be constructed and returned.

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

C<[% SET key = "value" %]> only works for simple scalar values.

There is no support for different I<PRE_CHOMP> and I<POST_CHOMP> settings 
internally, so extraction could fail silently on wrong places.

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
	$template =~ s/\[%\s*(?:\.\.\.|_)\s*%\]/[% __ %]/g;

	$self->{regex} = $parser->parse($template)->{BLOCK};
    }

    defined($document)        or return undef;
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

sub _validate {
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
    $regex =~ s/\*\*/, $block_id\*\*/g;

    return _re("_enter_loop($_[2], $block_id)") .    # sets $cur_loop
           "(?:$regex)*()" .                         # match content
           _re("_ext(([[$_[2],[$vars]]], \\'validate', $paren_id)**)");
           # weed out partial matches
}

sub get {
    return '.*?' if $_[1] eq "'__'";

    ++$paren_id;
    return '(.*?)' .    # ** is the placeholder for parent loop ids
           _re("_ext(([$_[1]], \$$paren_id, $paren_id)\*\*)");
}

sub set {
    ++$paren_id;

    my $val = $_[1][1];
    $val =~ s/^'(.*)'\z/$1/;

    push(@set, $val);

    my $parents = join ',',
                  map { $_[1][0][ $_ * 2 ] }
                  ( 0 .. $#{ $_[1][0] } / 2 );
    return '()' . _re("_ext(([$parents], \\$#set, $paren_id)\*\*)");
}

sub _ext {
    my ( $var, $val, $num ) = splice( @_, 0, 3 );
    my $obj = $data;

    if (@_) {
	print "Ext: [ $$val with $num on $-[$num]]\n" if ref($val) and $DEBUG;
	my $cur = $loop{ $_[0] };           # current loop structure

	# if pos() changed, increment the iteration counter
	$cur->{var}{$num}++ if ( ( $cur->{pos}{$num} ||= -1 ) != $-[$num] )
	    or ref $val and $$val eq 'validate';
	$cur->{pos}{$num} = $-[$num];       # remember pos()

	my $iteration = $cur->{var}{$num} - 1;
	$obj = _traverse( $data, @_ )->{ $cur->{name} }[$iteration] ||= {};
    }

    ( $obj, $var ) = _adjust( $obj, @$var );

    if (!ref($val)) {
        $obj->{$var} = $val;
    }
    elsif ($$val eq 'validate') {
        _validate($obj, @$var);
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

L<WWW::SherlockSearch>

=head1 AUTHORS

Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>

=head1 COPYRIGHT

Copyright 2001, 2002, 2003 by Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>.

This program is free software; you can redistribute it and/or 
modify it under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut
