use Test::More;
use Plack::Builder;
use utf8;
use Encode;
use File::Basename 'dirname';
use File::Spec;

$template = join '/', File::Spec->rel2abs(File::Spec->splitdir(dirname(__FILE__))), 'template.txt';

my $app =  builder {
    enable 'StackTrace::ParseMessage';
    sub {die "Some error occured at $template line 6"};
};

my $psgi_errors = _EH->new(qr{^Some error occured at $template line 6\n});

my $res = $app->( { HTTP_ACCEPT => 'text/html', REQUEST_URI => '/', 'psgi.errors' => $psgi_errors } );

like($res->[2]->[0], qr{\x{E3}\x{83}\x{86}});

done_testing;

package _EH;
use strict;
use warnings;
use Test::More;
    
    sub new {
        my ($class, $expected) = @_;
        bless \$expected, $class;
    }
    sub print {
        my $self = shift;
        like($_[0], $$self);
    }