package JWebmail::Model::ReadMails;

use Mojo::Base -base;

use Class::Struct AuthReadMails => {
    user => '$',
    password => '$',
    challenge => '$',
};


has 'driver';


sub verify_user {

    my $self = shift;

    my ($user, $password) = @_;

    return !scalar $self->driver->communicate(
        user => $user,
        password => $password,
        mode => 'auth',
    )
}


sub read_headers_for {

    my $self = shift;

    my %h = @_;
    my ($auth, $folder, $start, $end, $sort) = @h{qw(auth folder start end sort)};

    my ($resp, $rc) = $self->driver->communicate(
        user => $auth->user,
        password => $auth->password,
        challenge => $auth->challenge,
        mode => 'list',
        args => [$start // 0, $end // 0, $sort // 'date', $folder // ''],
    );
    die "connection error: $resp->{error}" if $rc;
    return $resp;
}


sub count {

    my $self = shift;

    my ($auth, $folder) = @_;

    my ($resp, $rc) = $self->driver->communicate(
        user      => $auth->user,
        password  => $auth->password,
        challenge => $auth->challenge,
        mode      => 'count',
        args      => [$folder],
    );
    die "connection error: $resp->{error}" if $rc;
    return ($resp->{size}, $resp->{count}, $resp->{new});
}


sub show {
    my $self = shift;

    my ($auth, $mid) = @_;

    my ($resp, $rc) = $self->driver->communicate(
        user => $auth->user,
        password => $auth->password,
        challenge => $auth->challenge,
        mode => 'read-mail',
        args => [$mid],
    );
    die "connection error: $resp->{error}, $resp->{mid}" if $rc;
    return $resp;
}


sub search {
    my $self = shift;

    my ($auth, $pattern, $folder) = @_;

    my ($resp, $rc) = $self->driver->communicate(
        user => $auth->user,
        password => $auth->password,
        challenge => $auth->challenge,
        mode => 'search',
        args => [$pattern, $folder],
    );
    die "connection error: $resp->{error}" if $rc;
    return $resp;
}


sub folders {
    my $self = shift;

    my ($auth) = @_;

    my ($resp, $rc) = $self->driver->communicate(
        user => $auth->user,
        password => $auth->password,
        challenge => $auth->challenge,
        mode => 'folders',
    );
    die "connection error: $resp->{error}" if $rc;
    return $resp;
}


sub move {
    my $self = shift;

    my ($auth, $mid, $folder) = @_;

    my ($resp, $rc) = $self->driver->communicate(
        user => $auth->user,
        password => $auth->password,
        challenge => $auth->challenge,
        mode => 'move',
        args => [$mid, $folder],
    );
    die "connection error: $resp->{error}" if $rc;
    return 1;
}


1

__END__

=encoding utf-8

=head1 NAME

ReadMails - Read received mails

=head1 SYNOPSIS

  my $m = JWebmail::Model::ReadMails->new(driver => ...);
  $m->search($auth, qr/Hot singles in your area/, '');

=head1 DESCRIPTION

This module is a facade for the actions of its driver.
All actions are delegated to it.

The first parameter is authentication info as AuthReadMails
whith the rest varying.

The communication is stateless.

=head1 ATTRIBUTES

=head2 driver

The driver does the actual work of reading the mailbox.

=head1 METHODS

=head2 new

Instantiate a new object. The 'driver' option is required.

=head2 verify_user

Checks user name and password.

=head2 read_headers_for

Provides bundeled information on a subset of mails of a mailbox.
Can be sorted and of varying size.

Arguments:
  start..end   inclusive 0 based range

=head2 count

Returns size of the mail box folder in bytes the number of mails.

=head2 show

Returns a sepecific mail as a perl hash.

=head2 search

Searches for a message with the given pattern.

=head2 folders

List all mailbox sub folders.

=head2 move

Move mails between folders.

=head1 CLASSES

=head2 AuthReadMails

A struct that bundles auth data.

=head3 Attributes

=head4 user

The user name.

=head4 password

The users password in plaintext or as hmac if cram is used.

=head4 challenge

Optinal challange for when you use cram authentication.

=head3 Methods

=head4 new

=head1 SEE ALSO

L<JWebmail::Model::Driver::QMailAuthuser>, L<JWebmail::Model::Driver::Mock>, L<JWebmail>

=cut
