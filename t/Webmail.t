use v5.22;
use warnings;
use utf8;

use Test::More;
use Test::Mojo;

use JWebmail::Model::Driver::MockJSON;


use constant DEFAULT_LANGUAGE => 'en';
my $user = JWebmail::Model::Driver::MockJSON::VALID_USER;
my $pw   = JWebmail::Model::Driver::MockJSON::VALID_PW;


my $t = Test::Mojo->new('JWebmail', {
    development => { use_read_mock => 'json', block_writes => 1 },
    i18n        => { default_language => DEFAULT_LANGUAGE },
});

$t->get_ok('/')->status_is(200);

subtest login => sub {
    $t->post_ok('/login', form => {userid => $user, password => 'x'})->status_is(400);
    $t->post_ok('/login', form => {userid => $user, password => 'abcde'})->status_is(401);
    $t->post_ok('/login', form => {userid => $user, password => $pw})->status_is(303);
};


subtest lang => sub {
    $t->get_ok('/about')->status_is(200)->attr_is('html', 'lang', DEFAULT_LANGUAGE);
    $t->get_ok('/en/about')->status_is(200)->attr_is('html', 'lang', 'en');
    $t->get_ok('/de/about')->status_is(200)->attr_is('html', 'lang', 'de');
};


done_testing;
