use v5.22;
use warnings;
use utf8;

use Test::More;
use Test::Mojo;

use JWebmail::Model::Driver::Mock;

my $user = JWebmail::Model::Driver::Mock::VALID_USER;
my $pw   = JWebmail::Model::Driver::Mock::VALID_PW;

my $t = Test::Mojo->new('JWebmail', {
    development => { use_read_mock => 1, block_writes  => 1 },
});

$t->get_ok('/')->status_is(200);

$t->post_ok('/login', form => {userid => $user, password => 'x'})
  ->status_is(400);

$t->post_ok('/login', form => {userid => $user, password => 'abcde'})
  ->status_is(401);

$t->post_ok('/login', form => {userid => $user, password => $pw})
  ->status_is(303);

done_testing();


#$r->get('/123' => sub { my $c = shift; $c->render(inline => $c->stash->{lang}) });
#my $x = $self->build_controller;
#$x->match->find($self, {method => 'GET', path => '//write'});
#print $self->dumper($x->match->stack);