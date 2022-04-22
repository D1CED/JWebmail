use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
  AUTHOR => '"Jannis M. Hoffmann" <jannis@fehcom.de>',
  MIN_PERL_VERSION => 'v5.22',
  NAME => 'JWebmail',
  VERSION_FROM => 'lib/JWebmail.pm',
  LICENSE => 'gpl_3',
  PREREQ_PM => {
    'Mojolicious' => '8.64',
    'Config::Tiny' => 'v2.24',
    'Crypt::URandom' => 0,
    'Email::MIME' => 0,
    'Mail::Box::Manager' => 'v3.9',
  },
  test => {TESTS => 't/*.t'}
)
