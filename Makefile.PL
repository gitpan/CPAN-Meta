
# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v5.025.
use strict;
use warnings;

use 5.008;

use ExtUtils::MakeMaker 6.17;



my %WriteMakefileArgs = (
  "ABSTRACT" => "the distribution metadata for a CPAN dist",
  "AUTHOR" => "David Golden <dagolden\@cpan.org>, Ricardo Signes <rjbs\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => "6.17"
  },
  "DISTNAME" => "CPAN-Meta",
  "EXE_FILES" => [],
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.008",
  "NAME" => "CPAN::Meta",
  "PREREQ_PM" => {
    "CPAN::Meta::Requirements" => "2.121",
    "CPAN::Meta::YAML" => "0.008",
    "Carp" => 0,
    "JSON::PP" => "2.27200",
    "Parse::CPAN::Meta" => "1.4414",
    "Scalar::Util" => 0,
    "strict" => 0,
    "version" => "0.88",
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "Data::Dumper" => 0,
    "ExtUtils::MakeMaker" => 0,
    "File::Basename" => 0,
    "File::Spec" => 0,
    "File::Temp" => "0.20",
    "IO::Dir" => 0,
    "Test::More" => "0.88",
    "overload" => 0,
    "utf8" => 0
  },
  "VERSION" => "2.143240",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "CPAN::Meta::Requirements" => "2.121",
  "CPAN::Meta::YAML" => "0.008",
  "Carp" => 0,
  "Data::Dumper" => 0,
  "ExtUtils::MakeMaker" => "6.17",
  "File::Basename" => 0,
  "File::Spec" => 0,
  "File::Temp" => "0.20",
  "IO::Dir" => 0,
  "JSON::PP" => "2.27200",
  "Parse::CPAN::Meta" => "1.4414",
  "Scalar::Util" => 0,
  "Test::More" => "0.88",
  "overload" => 0,
  "strict" => 0,
  "utf8" => 0,
  "version" => "0.88",
  "warnings" => 0
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

# Added by Dist::Zilla::Plugin::MakeMaker::Highlander
if ( $] < 5.012
  && ! $ENV{PERL_NO_HIGHLANDER}
  && ! ( $ENV{PERL_MM_OPT} && $ENV{PERL_MM_OPT} =~ /(?:INSTALL_BASE|PREFIX)/ )
  && ! grep { /INSTALL_BASE/ || /PREFIX/ } @ARGV
) {
    $WriteMakefileArgs{UNINST} = 1;
}

WriteMakefile(%WriteMakefileArgs);



