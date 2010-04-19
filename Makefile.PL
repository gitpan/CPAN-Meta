
use strict;
use warnings;

 BEGIN { require 5.006; } 

use ExtUtils::MakeMaker 6.31;



my %WriteMakefileArgs = (
                       'test' => {
                                   'TESTS' => 't/*.t'
                                 },
                       'NAME' => 'CPAN::Meta',
                       'DISTNAME' => 'CPAN-Meta',
                       'CONFIGURE_REQUIRES' => {
                                                 'ExtUtils::MakeMaker' => '6.31'
                                               },
                       'AUTHOR' => 'David Golden <dagolden@cpan.org>, Ricardo Signes <rjbs@cpan.org>',
                       'BUILD_REQUIRES' => {
                                             'Test::More' => '0.88',
                                             'File::Temp' => '0.20',
                                             'Data::Dumper' => '0',
                                             'File::Spec' => '0',
                                             'IO::Dir' => '0'
                                           },
                       'ABSTRACT' => 'the distribution metadata for a CPAN dist',
                       'EXE_FILES' => [],
                       'VERSION' => '2.101091',
                       'PREREQ_PM' => {
                                        'Scalar::Util' => '0',
                                        'Parse::CPAN::Meta' => '0',
                                        'Version::Requirements' => '0.101020',
                                        'autodie' => '0',
                                        'Storable' => '0',
                                        'JSON' => '2',
                                        'Carp' => '0'
                                      },
                       'LICENSE' => 'perl'
                     );


delete $WriteMakefileArgs{BUILD_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.56) };

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);



