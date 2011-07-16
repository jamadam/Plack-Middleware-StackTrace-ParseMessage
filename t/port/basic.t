use strict;
use warnings;
use Test::More;
use Plack::Middleware::StackTrace::ParseMessage;
use Plack::Test;
use HTTP::Request::Common;

my $traceapp = Plack::Middleware::StackTrace::ParseMessage->wrap(sub { die "orz" }, no_print_errors => 1);
my $app = sub {
    my $env = shift;
    my $ret = $traceapp->($env);
    like $env->{'plack.stacktrace.text'}, qr/orz/;
    return $ret;
};

test_psgi $app, sub {
    my $cb = shift;

    my $req = GET "/";
    $req->header(Accept => "text/html,*/*");
    my $res = $cb->($req);

    ok $res->is_error;
    is_deeply [ $res->content_type ], [ 'text/html', 'charset=utf-8' ];
    like $res->content, qr/<title>Error: orz/;
};

done_testing;

