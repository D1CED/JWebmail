package JWebmail::Model::Driver::MockMaildir;

use Mojo::Base -base;

use Mojo::JSON 'decode_json';


has user    => sub { $ENV{USER} };
has maildir => 't/';
has extractor => 'perl';


our %EXTRACTORS = (
    perl => 'perl lib/JWebmail/Model/Driver/QMailAuthuser/Extract.pm',
    rust => 'extract/target/debug/jwebmail-extract',
);

use constant {
    VALID_USER => 'me@mockmaildir.com',
    VALID_PW   => '12345',
};

sub communicate {
    my $self = shift;
    my %args = @_;

    if ($args{mode} eq 'auth') {
        return ("", 0) if $args{user} eq VALID_USER && $args{password} eq VALID_PW;
        return ("", 1);
    }

    my $mail_user = 'maildir';
    my $exec = $EXTRACTORS{$self->extractor} . ' ' . join(' ', map { $_ =~ s/(['\\])/\\$1/g; "'$_'" } ($self->maildir, $self->user, $mail_user, $args{mode}, @{$args{args}}));

    my $pid = open(my $reader, '-|', $exec)
        or die 'failed to create subprocess';

    my $input = <$reader>;

    waitpid($pid, 0);
    my $rc = $? >> 8;

    my $resp;
    if ($rc == 3 || $rc == 0) {
        eval { $resp = decode_json $input; };
        if (my $err = $@) { $resp = {error => "decoding error '$err'"}; $rc ||= 1; };
    }
    elsif ($rc) {
        $resp = {error => "qmail-authuser returned code: $rc"};
    }

    return ($resp, $rc);
}


1

