package JWebmail::Test::INI;

use v5.22;
use warnings;
use utf8;

use Config::Tiny;
use JWebmail::Plugin::INIConfig;
use Data::Dumper;

use Test2::Bundle::More;
#use Test2::V0;
#use Test::More;


local $/;
my $data = <DATA>; 
close DATA;

my $ct = Config::Tiny->new;
my $conf = $ct->read_string($data);

ok(not $ct->errstr) or diag $ct->errstr;

SKIP: {
    skip 'only for debuging';

    diag explain $conf;
}


subtest 'flat' => sub {
    is $conf->{'_'}{a}, 'b';
    is $conf->{section}{d}, 'e';
    is $conf->{section}{1}, 'a';
    is $conf->{'nested::section'}{a}, 'info';
    is $conf->{array_section}{0}, 'a';
    is $conf->{'nested::array_section'}{0}, 'a';
};


subtest 'processed' => sub {
    my $conf2 = JWebmail::Plugin::INIConfig::_process_config($conf);

    is $conf2->{a}, 'b';
    is $conf2->{section}{d}, 'e';
    is $conf2->{section}{1}, 'a';
    is $conf2->{nested}{section}{a}, 'info';
    is $conf2->{nested}{section}{deeply}{x}, 'deeply';
    is $conf2->{array_section}[0], 'a';
    is $conf2->{nested}{array_section}[0], 'a';
};


done_testing;


__DATA__

# example file
# [global_section alias _]
a = b ; line comment

[section]
d = e
f = e # not a comment

"ha llo , = &f" = 'nic a = %& xa'

1 = a
2 = b

x = 
y = 

[othersection]
long = my very long value

[nested::section]
a = info

[nested::section::deeply]
x = deeply

[array_section]
0 = a
1 = b
2 = c
3 = d
4 = e

[nested::array_section]
0 = a

#[nested::array_section::1::deeply]
#key = val