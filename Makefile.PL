use ExtUtils::MakeMaker;

WriteMakefile(
    NAME => 'PDL::DateTime',
    VERSION_FROM => 'lib/PDL/DateTime.pm',
    PREREQ_PM => { 'PDL' => '2.014', 'Time::Moment' => 0 },
    # Test::Number::Delta
    # Test::More
);