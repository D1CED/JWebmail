use v5.22;
use warnings;
use utf8;

use Test::More;

use Encode 'decode';
use MIME::Words 'decode_mimewords';

use JWebmail::Plugin::Helper;


subtest 'print_size10' => sub {
    my %TESTS = (
        1 => '1 Byte',
        10 => '10 Byte',
        100 => '100 Byte',
        1000 => '1 kByte',
        10000 => '10 kByte',
        100000 => '100 kByte',
        1000000 => '1 MByte',
        10 * 10**6 => '10 MByte',
        10 * 2**20 => '10 MByte',
        800 => '800 Byte',
        9999 => '10 kByte',
        9500 => '10 kByte',
        1024 => '1 kByte',
        1023 => '1 kByte',
    );

    plan tests => scalar keys %TESTS;

    while (my ($input, $want) = each %TESTS) {
        is(JWebmail::Plugin::Helper::print_sizes10($input), $want);
    }
};


subtest 'vaild_mail_line' => sub {
    my %TESTS = (
        'abc@example.com' => 1,
        'ABC Ex <abc@example.com>' => 1,
        '"ABC Ex" <abc@example.com>' => 1,
        '"A@B.V Ex" <abc@example.com>' => 1,
        '"A@B.V Ex\"" <abc@example.com>' => 1,
        'ABC Ex abc@example.com' => 0,
    );

    plan tests => scalar keys %TESTS;

    while (my ($input, $want) = each %TESTS) {
        cmp_ok(JWebmail::Plugin::Helper->mail_line('', $input), '!=', $want);
    }
};


subtest 'mime_word_decode' => sub {
    my $input = "=?utf-8?Q?Jannis=20wir=20vermissen=20dich!=20Komm=20zur=C3=BCck=20und=20spare=20mit=20uns=20beim=20shoppen=20deiner=20Lieblingsmarken?=";
    my $want = "Jannis wir vermissen dich! Komm zurück und spare mit uns beim shoppen deiner Lieblingsmarken";
    my $got = scalar decode_mimewords $input;

    isnt $want, $got;
    is $want, _to_perl_enc(decode_mimewords $input);
    is $want, decode('MIME-Header', $input);

    done_testing 3;
};

sub _to_perl_enc {
    my $out = '';
    for (@_) {
        if ($_->[1]) {
            $out .= decode($_->[1], $_->[0]);
        }
        else {
            $out .= $_->[0];
        }
    }
    return $out;
}


subtest 'pagination' => sub {
    my %res;

    %res = JWebmail::Plugin::Helper::_paginate(first_item => 0, page_size => 10, total_items => 55);

    is $res{first_item}, 1;
    is $res{last_item}, 10;
    is $res{total_items}, 55;

    is $res{page_size}, 10;
    is $res{total_pages}, 6;
    is $res{current_page}, 1;

    is_deeply $res{first_page}, [1, 10], 'first';
    is_deeply $res{prev_page}, [1, 10], 'prev';
    is_deeply $res{next_page}, [11, 20], 'next';
    is_deeply $res{last_page}, [51, 55], 'last';

    %res = JWebmail::Plugin::Helper::_paginate(first_item => 10, page_size => 10, total_items => 55);

    is $res{first_item}, 11;
    is $res{last_item}, 20;
    is $res{total_items}, 55;

    is $res{page_size}, 10;
    is $res{total_pages}, 6;
    is $res{current_page}, 2;

    is_deeply $res{first_page}, [1, 10], 'first';
    is_deeply $res{prev_page}, [1, 10], 'prev';
    is_deeply $res{next_page}, [21, 30], 'next';
    is_deeply $res{last_page}, [51, 55], 'last';

    %res = JWebmail::Plugin::Helper::_paginate(first_item => 20, page_size => 10, total_items => 55);

    is $res{first_item}, 21;
    is $res{last_item}, 30;
    is $res{total_items}, 55;

    is $res{page_size}, 10;
    is $res{total_pages}, 6;
    is $res{current_page}, 3;

    is_deeply $res{first_page}, [1, 10], 'first';
    is_deeply $res{prev_page}, [11, 20], 'prev';
    is_deeply $res{next_page}, [31, 40], 'next';
    is_deeply $res{last_page}, [51, 55], 'last';

    %res = JWebmail::Plugin::Helper::_paginate(first_item => 50, page_size => 10, total_items => 55);

    is $res{first_item}, 51;
    is $res{last_item}, 55;
    is $res{total_items}, 55;

    is $res{page_size}, 10;
    is $res{total_pages}, 6;
    is $res{current_page}, 6;

    is_deeply $res{first_page}, [1, 10], 'first';
    is_deeply $res{prev_page}, [41, 50], 'prev';
    is_deeply $res{next_page}, [51, 55], 'next';
    is_deeply $res{last_page}, [51, 55], 'last';

    %res = JWebmail::Plugin::Helper::_paginate(first_item => 0, page_size => 10, total_items => 0);

    is $res{first_item}, 0;
    is $res{last_item}, 0;
    is $res{total_items}, 0;

    is $res{page_size}, 10;
    is $res{total_pages}, 0;
    is $res{current_page}, 1;

    is_deeply $res{first_page}, [0, 0], 'first';
    is_deeply $res{prev_page}, [0, 0], 'prev';
    is_deeply $res{next_page}, [0, 0], 'next';
    is_deeply $res{last_page}, [0, 0], 'last';

    SKIP: {
        skip 'The first_item does not align with page boundaries and behaiviour is not specified.';

        %res = JWebmail::Plugin::Helper::_paginate(first_item => 19, page_size => 10, total_items => 55);

        is $res{first_item}, 20;
        is $res{last_item}, 29;
        is $res{total_items}, 55;

        is $res{page_size}, 10;
        is $res{total_pages}, 6;
        is $res{current_page}, 3;

        is_deeply $res{first_page}, [1, 10], 'first';
        is_deeply $res{prev_page}, [11, 20], 'prev';
        is_deeply $res{next_page}, [31, 40], 'next';
        is_deeply $res{last_page}, [51, 55], 'last';
    }

    done_testing;
};


done_testing;