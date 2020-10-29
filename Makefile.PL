use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
  AUTHOR => '"Jannis M. Hoffmann" <jannis@fehcom.de>',
  MIN_PERL_VERSION => 'v5.18',
  NAME => 'JWebmail',
  VERSION_FROM => 'lib/JWebmail.pm',
  LICENSE => 'GPL',
  PREREQ_PM => {
    'Mojolicious' => '8.57',
    'File::Type' => 0,
    'Email::MIME' => 0,
    'Config::Tiny' => 0,
    'Mail::Box::Manager' => 0,
  },
  test => {TESTS => 't/*.t'}
);