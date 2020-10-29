package JWebmail::Model::Driver::QMailAuthuser;

use Mojo::Base -base;

use IPC::Open2;
use File::Basename 'fileparse';
use JSON::PP;


has 'user';
has 'maildir';
has 'include';
has qmail_dir => '/var/qmail/';
has prog      => [fileparse(__FILE__)]->[1] . '/QMailAuthuser/Extract.pm';
has logfile   => '/dev/null';


sub communicate {
    use autodie;

    my $self = shift;
    my %args = @_;

    $args{challenge} //= '';
    $args{args} //= [];

    my $exec = do {
        if ($args{mode} eq 'auth') {
            $self->qmail_dir . "/bin/qmail-authuser true 3<&0";
        }
        else {
            my ($user_name) = $args{user} =~ /(\w*)@/;

            $self->qmail_dir.'/bin/qmail-authuser'
            . ' perl '
            . join('', map { ' -I ' . $_ } @{ $self->include })
            . ' -- '
            . join(' ', map { $_ =~ s/(['\\])/\\$1/g; "'$_'" } ($self->prog, $self->maildir, $self->user, $user_name, $args{mode}, @{$args{args}}))
            . ' 3<&0'
            . ' 2>>'.$self->logfile;
        }
    };

    my $pid = open2(my $reader, my $writer, $exec)
        or die 'failed to create subprocess';

    $writer->print("$args{user}\0$args{password}\0$args{challenge}\0")
        or die 'pipe wite failed';
    close $writer
        or die 'closing write pipe failed';

    binmode $reader, ':utf8';
    my $input = <$reader>;
    close $reader
        or die 'closing read pipe failed';

    waitpid($pid, 0);
    my $rc = $? >> 8;

    my $resp;
    if ($rc == 3 || $rc == 0) {
        eval { $resp = decode_json $input; };
        if ($@) { $resp = {error => 'decoding error'} };
    }
    elsif ($rc) {
        $resp = {error => "qmail-authuser returned code: $rc"};
    }

    return ($resp, $rc);
}


1

__END__

=encoding utf-8

=head1 NAME

QMailAuthuser

=head1 SYNOPSIS

  my $m = JWebmail::Model::ReadMails->new(driver => JWebmail::Model::Driver::QMailAuthuser->new(...));

=head1 DESCRIPTION

This ReadMails driver starts and communicates with L<JWebmail::Model::Driver::QMailAuthuser::Extract> over qmail-authuser.
The Extract programm runs with elevated priviliges to be able to read and modify mailboxes.

=head1 ATTRIBUTES

=head2 qmail_dir

The parent directory of the bin directory where all qmail executables live.
Default C</var/qmail/>.

=head2 prog

The path to the extractor programm.
Default is the location of L<JWebmail::Model::Driver::QMailAuthuser::Extract> package.

=head2 logfile

A path to a log file that the extractor logs to.
Default '/dev/null' but highly recommended to set a real one.
Keep in mind that a different user need to be able to write to it.

=head1 METHODS

=head2 communicate

Arguments:

=over 6

=item mode

=item args

Depends on the mode

=item user

User name

=item password

User password

=item challenge

Challenge when using cram

=back

=head1 SEE ALSO

L<JWebmail::Model::ReadMails>, L<JWebmail::Model::Driver::QMailAuthuser::Extract>

=cut