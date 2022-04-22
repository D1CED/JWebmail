use v5.22;
use warnings;
use utf8;

use Test::More;

use JWebmail::Plugin::I18N2;

*add_option = \&JWebmail::Plugin::I18N2::Match::__add_option_no_override;


subtest 'add_option' => sub {

    is_deeply(add_option(a => 1, {}), {a => 1}, "empty-hash");
    is_deeply(add_option(a => 5, {a => 1}), {a => 1}, "no-add-hash");
    is_deeply(add_option(b => 2, {a => 1}), {a => 1, b => 2}, "add-hash");

    is_deeply([add_option(a => 1, 'arg', {})], ['arg', {a => 1}], "empty-arg-hash");
    is_deeply([add_option(a => 5, 'arg', {a => 1})], ['arg', {a => 1}], "no-add-arg-hash");
    is_deeply([add_option(b => 2, 'arg', {a => 1})], ['arg', {a => 1, b => 2}], "add-arg-hash");

    is_deeply([add_option(a => 1)], [a => 1], "empty-array");
    is_deeply([add_option(a => 5, a => 1)], [a => 1], "no-add-array");
    eq_set([add_option(b => 2, a => 1)], [a => 1, b => 2], "add-array");

    is_deeply([add_option(a => 1, 'arg')], ['arg', a => 1], "empty-arg-array");
    is_deeply([add_option(a => 5, 'arg', a => 1)], ['arg', a => 1], "no-add-arg-array");
    eq_set([add_option(b => 2, 'arg', a => 1)], ['arg', a => 1, b => 2], "add-arg-array");
};

done_testing;
