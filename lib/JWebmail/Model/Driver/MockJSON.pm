package JWebmail::Model::Driver::MockJSON;

use Mojo::Base -base;

use List::Util 'sum';

use Mojo::JSON qw(decode_json);


use constant {
    VALID_USER => 'mockjson@example.com',
    VALID_PW   => 'vwxyz',
};

use constant {
    LIST_START  => 0,
    LIST_END    => 1,
    LIST_SORT   => 2,
    LIST_FOLDER => 3,
};

sub _read_json_file {
    my ($file_name) = @_;

    use constant PREFIX => 't/private/';

    open(my $body_file, '<', PREFIX . $file_name);
    local $/;
    my $body = <$body_file>;
    close $body_file;

    return decode_json($body);
}


sub list_reply {
    state $init = _read_json_file('msgs.json');
}
sub read_reply {
    state $init = {
        'SC-ORD-MAIL54526c63b751646618a793be3f8329cca@sc-ord-mail5' => _read_json_file('msg2.json'),
        'example' => _read_json_file('msg.json'),
    };
}


sub communicate {
    no warnings 'experimental::smartmatch';

    my $self = shift;

    my %args = @_;

    given ($args{mode}) {
        when ('auth') {
            return (undef, 0) if $args{user} eq VALID_USER && $args{password} eq VALID_PW;
            return (undef, 2);
        }
        when ('list') {
            return ([@{ $self->list_reply }[$args{args}->[LIST_START]..$args{args}->[LIST_END]]], 0) if !$args{args}->[LIST_SORT];
            return ([], 0) if $args{args}->[LIST_FOLDER] eq 'test';
            my $s = sub {
                my $sort_by = $args{args}->[LIST_SORT];
                my $rev = $sort_by !~ m/^![[:lower:]]+/ ? 1 : -1;
                $sort_by =~ s/!//;
                $sort_by = "date_received" if $sort_by eq "date";
                return ($a->{$sort_by} cmp $b->{$sort_by}) * $rev;
            };
            return ([sort { &$s } @{ $self->list_reply }[$args{args}->[LIST_START]..$args{args}->[LIST_END]]], 0);
        }
        when ('count') {
            return ({
                count => scalar(@{ $self->list_reply }),
                size  => sum(map {$_->{size}} @{ $self->list_reply }),
                new   => 0,
            }, 0);
        }
        when ('read-mail') {
            my $mid = $args{args}->[0];
            my $mail = $self->read_reply->{$mid};
            return ($mail, 0) if $mail;
            return ({error => 'unkown mail-id'}, 3);
        }
        when ('folders') {
            return ([qw(cur test devel debug)], 0);
        }
        when ('move') {
            local $, = ' ';
            say "@{ $args{args} }";
            return (undef, 0);
        }
        default { return ({error => 'unkown mode'}, 3); }
    }
}


1

__END__

=head1 NAME

Mock - Simple file based mock for the L<JWebmail::Model::ReadMails> module.

=cut
