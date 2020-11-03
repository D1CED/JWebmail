package JWebmail::Plugin::ServerSideSessionData v1.1.0;

use Mojo::Base 'Mojolicious::Plugin';

use Mojo::JSON qw(decode_json encode_json);
use Mojo::File;

use Fcntl ':DEFAULT', ':seek';
use Time::HiRes 'sleep';


use constant S_KEY => 's3d.key';
use constant CLEANUP_FILE_NAME => 'cleanup';
use constant LOCK_ITER => 5;
use constant ADVANCE_ON_FAILURE => 10; # seconds to retry to acquire the lock

has 'session_directory';
has 'expiration';
has 'cleanup_interval';

has 'next_cleanup' => 0;


# read und potentially update file return bool
# needs atomic lock file
# the file contains a single timestamp
sub _rw_cleanup_file {
    my $self = shift;
    my $time = shift;

    my $lock_name = $self->session_directory->child(CLEANUP_FILE_NAME . ".lock");
    my $info_name = $self->session_directory->child(CLEANUP_FILE_NAME . ".info");

    my ($lock, $ctr, $rmlock);
    until (sysopen($lock, $lock_name, O_WRONLY | O_CREAT | O_EXCL)) {
        die "unexpected error '$!'" unless $! eq 'File exists';
        if ($ctr > LOCK_ITER) {
            open($lock, '<', $lock_name) or die "unexpected error '$!'";
            my $pid = <$lock>;
            close $lock;
            chomp $pid;
            if (!$rmlock && (!$pid || !-e "/proc/$pid")) {
                $lock_name->remove;
                $rmlock = 1;
                next;
            }
            $self->next_cleanup($time + ADVANCE_ON_FAILURE);
            return 0;
        }
        sleep(0.01); # TODO: better spin locking
    } continue {
        $ctr++;
    }
    $lock->say($$);
    $lock->close;

    my $ret = eval {
        use autodie;

        open(my $info, -e $info_name ? '+<' : '+>', $info_name);
        my $next_time = $info->getline;
        $next_time = 0 unless ($next_time//'') =~ /^\d+$/;
        chomp $next_time;
        if ($next_time > $time) {
            $info->close;
            $self->next_cleanup($next_time);
            return 0;
        }
        else {
            $info->truncate(0);
            $info->seek(0, SEEK_SET);
            $info->say($time + $self->cleanup_interval);
            $info->close;
            $self->next_cleanup($time + $self->cleanup_interval);
            return 1;
        }
    };
    $lock_name->remove;
    return $ret;
}


sub cleanup_files {
    my $self = shift;

    my $t = time;
    if ($self->next_cleanup < $t && $self->_rw_cleanup_file($t)) {
        for ($self->session_directory->list->each) {
            if ( $_->stat->mtime + $self->expiration < $t ) {
                $_->remove;
            }
        }
    }
}


sub s3d {
    my $self = shift;
    my $c = shift;
    my ($key, $val) = @_;

    # cleanup old sessions
    $self->cleanup_files;

    my $file = $self->session_directory->child($c->session(S_KEY) || $c->req->request_id . $$);

    if (-e $file) {
        if ($file->stat->mtime + $self->expiration < time) {
            truncate $file, 0;
        }
        else {
            $file->touch;
        }
    }
    elsif (defined $val) {
        $file->touch;
        $file->chmod(0600);
        $c->session(S_KEY, $file->basename);
    }

    my $data = decode_json($file->slurp) if (-s $file);

    if (defined $val) { # set
        $data = ref $data ? $data : {};
        $data->{$key} = $val;

        $file->spurt(encode_json $data, "\n");
    }
    else { # get
        return defined $key ? $data->{$key} : $data;
    }
}


sub register {
    my ($self, $app, $conf) = @_;

    $self->session_directory(Mojo::File->new($conf->{directory} || "/tmp/" . $app->moniker));
    $self->expiration($conf->{expiration} || $app->sessions->default_expiration);
    $self->cleanup_interval($conf->{cleanup_interval} || $self->expiration);

    unless (-d $self->session_directory) {
        mkdir($self->session_directory)
            or $! ? die "failed to create directory: $!" : 1;
    }

    $self->cleanup_files;

    $app->helper( s3d => sub { $self->s3d(@_) } );
}


1

__END__

=encoding utf-8

=head1 NAME

ServeSideSessionData - Stores session data on the server (alias SSSD or S3D)

=head1 SYNOPSIS

  $app->plugin('ServeSideSessionData', {expiration => 20*60});

  $c->s3d(data => 'Hello, S3D');
  $c->s3d('data');

=head1 DESCRIPTION

Store data temporarily on the server.
The only protection on the server are strict user access rights
so you need to still be careful with your secrets.

=head1 OPTIONS

=head2 directory

directory where session data is stored

default C<< 'tmp/' . $app->moniker >>

=head2 expiration

how long is a server side session valid in seconds (calculated after last access)

defaults to session expiration

=head2 cleanup_interval

a recurring time interval when old session data gets cleaned up

defaults to expiration

=head1 HELPERS

=head2 s3d

Stores and retrieves values.

  $c->s3d(data => 'Hello, S3D');
  $c->s3d('data');
  $c->s3d->{data};

=cut
