use ExtUtils::MakeMaker;

WriteMakefile(
    NAME => 'PDL::DateTime',
    VERSION_FROM => 'lib/PDL/DateTime.pm',
    PREREQ_PM => {
          'PDL'          => '2.014', # we need longlong-double fix
          'Time::Moment' => '0.12',  # we need lenient ISO 8601 parsing
    },
    BUILD_REQUIRES => {
          'PDL'                 => '2.014',
          'Time::Moment'        => '0.12',
          'Test::More'          => '0.88',  # we need: done_testing()
          'Test::Number::Delta' => '1.06',  # versions before 1.06 have buggy relative mode
    },
);
