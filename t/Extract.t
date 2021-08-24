use v5.22;
use warnings;
use utf8;

use Test::More;

use JSON::PP 'decode_json';
no warnings 'experimental::smartmatch';


my $EXTRACT = {
    perl_mail_box => 'perl lib/JWebmail/Model/Driver/QMailAuthuser/Extract.pm ',
    rust_maildir  => 'extract/target/debug/jwebmail-extract',
}->{perl_mail_box};
my $MAILDIR = 't/';
my $SYS_USER = $ENV{USER};
my $MAIL_USER = 'maildir';

my $PROG = "$EXTRACT $MAILDIR $SYS_USER $MAIL_USER";


subtest start => sub {
    my @res = `$PROG invalid`;

    is($? >> 8, 3);
    is @res, 1;
    my $result = decode_json $res[0];

    ok($result->{error})
};

subtest folders => sub {
    my @res = `$PROG folders`;

    is($? >> 8, 0);
    is @res, 1;
    my $result = decode_json $res[0];

    is(@$result, 2);
};

subtest count => sub {
    my @res = `$PROG count ''`;

    is($? >> 8, 0);
    is @res, 1;
    my $result = decode_json $res[0];

    is($result->{count}, 2);
    #is($result->{new}, 0);
};

subtest list => sub {
    my @res = `$PROG list 0 10 date ''`;

    is($? >> 8, 0);
    is @res, 1;
    my $result = decode_json $res[0];

    is(@$result, 2);
    ok($result->[0]{mid});
    ok($result->[0]{from});
    ok($result->[0]{to});
};

subtest read => sub {
    my @pre_res = `$PROG list 0 10 date ''`;

    is($? >> 8, 0);
    is @pre_res, 1;
    my $pre_result = decode_json $pre_res[0];
    ok(my $mid = $pre_result->[0]{mid});

    my @res = `$PROG read-mail '$mid'`;

    is($? >> 8, 0);
    is @res, 1;
    my $result = decode_json $res[0];

    is_deeply($result->{from}, [{address => 'shipment-tracking@amazon.de', name => 'Amazon.de'}]);
    ok($result->{date_received});
    ok(index($result->{date_received}, '2019-02-22T10:06:54') != -1);
    like($result->{date_received}, qr'2019-02-22T10:06:54');
};

done_testing;
