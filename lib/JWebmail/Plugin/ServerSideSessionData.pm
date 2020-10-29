package JWebmail::Plugin::ServerSideSessionData;

use Mojo::Base 'Mojolicious::Plugin';

use Mojo::JSON qw(decode_json encode_json);
use Mojo::File;

use constant {
    S_KEY => 's3d.key',
};


has '_session_directory';
sub session_directory { my $self = shift; @_ ? $self->_session_directory(Mojo::File->new(@_)) : $self->_session_directory }

has 'expiration';
has 'cleanup_interval';

has '_cleanup';
sub cleanup {
    my $self = shift;
    if (@_) {
        return $self->_cleanup(@_);
    }
    else {
        if ($self->_cleanup < time) {
            return 0;
        }
        else {
            $self->_cleanup(time + $self->cleanup_interval);
            return 1;
        }
    }
}


sub s3d {
    my $self = shift;
    my $c = shift;

    # cleanup old sessions
    if ($self->cleanup) {
        my $t = time;
        for ($self->session_directory->list->each) {
            if ( $_->stat->mtime + $self->expiration < $t ) {
                $_->remove;
            }
        }
    }

    my $file = $self->session_directory->child($c->session(S_KEY) || $c->req->request_id . $$);

    if (-e $file) {
        if ($file->stat->mtime + $self->expiration < time) {
            $file->remove;
        }
        else {
            $file->touch;
        }
    }
    my $data = decode_json($file->slurp) if (-s $file);

    my ($key, $val) = @_;

    if (defined $val) { # set
        unless (-e $file) {
            $c->session(S_KEY, $file->basename);
        }
        $data = ref $data ? $data : {};
        $data->{$key} = $val;

        #$file->spurt(encode_json $data);
        open(my $f, '>', $file) or die "$!";
        chmod 0600, $f;
        $f->say(encode_json $data);
        close($f);
    }
    else { # get
        return defined $key ? $data->{$key} : $data;
    }
};


sub register {
    my ($self, $app, $conf) = @_;

    $self->session_directory($conf->{directory} || "/tmp/" . $app->moniker);
    $self->expiration($conf->{expiration} || $app->sessions->default_expiration);
    $self->cleanup_interval($conf->{cleanup_interval} || $self->expiration);
    $self->cleanup(time + $self->cleanup_interval);

    unless (-d $self->session_directory) {
        mkdir($self->session_directory)
            or $! ? die "failed to create directory: $!" : 1;
    }

    $app->helper( s3d => sub { $self->s3d(@_) } );
}


1

__END__

=encoding utf-8

=head1 NAME

ServeSideSessionData - Stores session data on the server (alias SSSD or S3D)

=head1 SYNOPSIS

  $app->plugin('ServeSideSessionData');

  $c->s3d(data => 'Hello, S3D');
  $c->s3d('data');

=head1 DESCRIPTION

Store data temporarily on the server.
The only protetction on the server are struct user access rights.

=head1 OPTIONS

=head2 directory

default C<< 'tmp/' . $app->moniker >>

=head2 expiration

default session expiration

=head2 cleanup_interval

default session expiration

=head1 HELPERS

=head2 s3d

Stores and retrieves values.

  $c->s3d(data => 'Hello, S3D');
  $c->s3d('data');
  $c->s3d->{data};

=cut