package JWebmail::Plugin::INIConfig;
use Mojo::Base 'Mojolicious::Plugin::Config';

use List::Util 'all';

use Config::Tiny;


sub parse {
    my ($self, $content, $file, $conf, $app) = @_;

    my $ct = Config::Tiny->new;
    my $config = $ct->read_string($content, 'utf8');
    die qq{Can't parse config "$file": } . $ct->errstr unless defined $config;

    $config = _process_config($config) unless $conf->{flat};

    return $config;
}


sub _process_config {
    my $val_prev = shift;
    my %val = %$val_prev;

    # arrayify section with number keys
    for my $key (keys %val) {
        if (keys %{$val{$key}} && all { $_ =~ /\d+/} keys %{$val{$key}}) {
            my $tmp = $val{$key};
            $val{$key} = [];

            for (keys %$tmp) {
                $val{$key}[$_] = $tmp->{$_};
            }
        }
    }

    # merge top section
    my $top_section = $val{'_'};
    delete $val{'_'};
    for (keys %$top_section) {
        $val{$_} = $top_section->{$_} unless $val{$_};
    }

    # make implicit nesting explicit
    for my $key (grep { $_ =~ /^\w+(::\w+)+$/} keys %val) {

        my @sections = split m/::/, $key;
        my $x = \%val;
        my $y;
        for (@sections) {
            $x->{$_} = {} unless ref $x->{$_};# eq 'HASH';
            $y = $x;
            $x = $x->{$_};
        }
        # merge
        if (ref $val{$key} eq 'ARRAY') {
            $y->{$sections[-1]} = [];
            $x = $y->{$sections[-1]};
            for ( keys @{ $val{$key} } ) {
                $x->[$_] = $val{$key}[$_];
            }
        }
        else {
            for ( keys %{ $val{$key} } ) {
                $x->{$_} = $val{$key}{$_};
            }
        }
        delete $val{$key};
    }

    return \%val
}


1

__END__

=encoding utf-8

=head1 NAME

INIConfig - Reads in ini config files.

=head1 SYNOPSIS

  $app->plugin('INIConfig');

  @@ my_app.conf

  # global section
  key = val ; line comment
  [section]
  other_key = other_val
  [other::section]
  0 = key1
  1 = key2
  2 = key3

=head1 DESCRIPTION

INI configuration is simple with limited nesting and propper comments.
For more precise specification on the syntax see the Config::Tiny documentation
on metacpan.

=head1 OPTIONS

=head2 default

Sets default configuration values.

=head2 ext

Sets file extension defaults to '.conf'.

=head2 file

Sets file name default '$app->moniker'.

=head2 flat

Keep configuration to exactly two nesting levels for all
and disable auto array conversion.

=head1 METHODS

=head2 parse

overrides the parse method of Mojolicious::Plugin::Config

=head1 DEPENDENCIES

Config::Tiny

=cut