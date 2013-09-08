use strict;
use warnings;

# this test was generated with Dist::Zilla::Plugin::Test::Compile 2.026

use Test::More  tests => 7 + ($ENV{AUTHOR_TESTING} ? 1 : 0);



my @module_files = (
    'CPAN/Meta.pm',
    'CPAN/Meta/Converter.pm',
    'CPAN/Meta/Feature.pm',
    'CPAN/Meta/History.pm',
    'CPAN/Meta/Prereqs.pm',
    'CPAN/Meta/Spec.pm',
    'CPAN/Meta/Validator.pm'
);



# fake home for cpan-testers
use File::Temp;
local $ENV{HOME} = File::Temp::tempdir( CLEANUP => 1 );


use IPC::Open3;
use IO::Handle;

my @warnings;
for my $lib (@module_files)
{
    # see L<perlfaq8/How can I capture STDERR from an external command?>
    my $stdin = '';     # converted to a gensym by open3
    my $stderr = IO::Handle->new;
    binmode $stderr, ':crlf' if $^O eq 'MSWin32';

    my $pid = open3($stdin, '>&STDERR', $stderr, qq{$^X -Mblib -e"require q[$lib]"});
    waitpid($pid, 0);
    is($? >> 8, 0, "$lib loaded ok");

    if (my @_warnings = <$stderr>)
    {
        warn @_warnings;
        push @warnings, @_warnings;
    }
}



is(scalar(@warnings), 0, 'no warnings found') if $ENV{AUTHOR_TESTING};


