package Plack::Middleware::StackTrace::ParseMessage;
use strict;
use warnings;
use parent qw/Plack::Middleware::StackTrace/;
use Devel::StackTrace;
use Devel::StackTrace::AsHTML;
use Try::Tiny;
use Plack::Util::Accessor qw( force no_print_errors);
our $VERSION = '0.01';

our $StackTraceClass = $Plack::Middleware::StackTrace::StackTraceClass;

sub call {
    my($self, $env) = @_;

    my $trace;
    local $SIG{__DIE__} = sub {
        if ($_[0] =~ qr{^(.+?)\s+at\s+([\S]+)\s+line\s+(\d+)}) {
            my ($message, $file, $line) = ($1, $2, $3);
            $trace = Devel::StackTrace->new(
                indent => 1, message => $message,
                ignore_package => __PACKAGE__,
            );
            unshift(@{$trace->{raw}}, {args => [], caller => ['', $file, $line, '', '']});
        }
        die @_;
    };

    my $caught;
    my $res = try {
        $self->app->($env);
    } catch {
        $caught = $_;
        [ 500, [ "Content-Type", "text/plain; charset=utf-8" ], [ no_trace_error(utf8_safe($caught)) ] ];
    };

    if ($trace && ($caught || ($self->force && ref $res eq 'ARRAY' && $res->[0] == 500)) ) {
        my $text = $trace->as_string;
        my $html = $trace->as_html;
        $env->{'plack.stacktrace.text'} = $text;
        $env->{'plack.stacktrace.html'} = $html;
        $env->{'psgi.errors'}->print($text) unless $self->no_print_errors;
        if (($env->{HTTP_ACCEPT} || '*/*') =~ /html/) {
            $res = [500, ['Content-Type' => 'text/html; charset=utf-8'], [ utf8_safe($html) ]];
        } else {
            $res = [500, ['Content-Type' => 'text/plain; charset=utf-8'], [ utf8_safe($text) ]];
        }
    }

    # break $trace here since $SIG{__DIE__} holds the ref to it, and
    # $trace has refs to Standalone.pm's args ($conn etc.) and
    # prevents garbage collection to be happening.
    undef $trace;

    return $res;
}

{
    no strict 'refs';
    *{__PACKAGE__. '::utf8_safe'} = \&Plack::Middleware::StackTrace::utf8_safe;
    *{__PACKAGE__. '::no_trace_error'} = \&Plack::Middleware::StackTrace::no_trace_error;
    *{__PACKAGE__. '::munge_error'} = \&Plack::Middleware::StackTrace::munge_error;
}

1;

__END__

=head1 NAME

Plack::Middleware::StackTrace::ParseMessage - Extended StackTrace

=head1 SYNOPSIS

  enable "StackTrace::ParseMessage";

=head1 DESCRIPTION

This is an extended class of Plack::Middleware::StackTrace for replacement.
This retrieves file name and line number out of error messages and appends a
stack entry for it.

This module is aimed at template engines who reports errors in template
perspective so that the debug screen indicates where the error occurred inside
template as follows.

    function some_func not defined at /path/to/file/index.html line 13

    10: <body>
    11:     <div>
    12:         <ul>
    13:            <% some_func() %> <-- highlighted
    14:         </ul>
    15:     </div>
    16: </body>

=head1 METHODS

=head2 call

=head1 SEE ALSO

L<Plack::Middleware::StackTrace>

=head1 AUTHOR

Sugama Keita, E<lt>sugama@jamadam.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Sugama Keita.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
