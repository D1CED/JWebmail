package JWebmail::Controller::Webmail;

use Mojo::Base 'Mojolicious::Controller';

use Mojolicious::Types;

use constant S_USER => 'user'; # Key for user name in active session


# no action has been taken, display login page
sub noaction {
    my $self = shift;

    my $user = $self->session(S_USER);
    if ($user) {
        $self->res->code(307);
        $self->redirect_to('home');
    }
}


# middleware
sub auth {
    my $self = shift;

    my $user = $self->session(S_USER);
    my $pw = $self->session_passwd;

    unless ($user && $pw) {
        $self->flash(message => $self->l('no_session'));
        $self->res->code(401);
        $self->redirect_to('logout');
        return 0;
    }

    return 1;
}


sub _time :prototype(&$$) {
    my $code = shift;
    my $self = shift;
    my $name = shift;

    $self->timing->begin($name);

    my @res = $code->();

    my $elapsed = $self->timing->elapsed($name);
    $self->app->log->debug("$name took $elapsed seconds");

    return wantarray ? @res : $res[-1];
}


sub login {
    my $self = shift;

    my $v = $self->validation;
    
    my $user = $v->required('userid')->size(4, 50)->param;
    my $passwd = $v->required('password')->size(4, 50)->like(qr/^.+$/)->param; # no new-lines

    if ($v->has_error) {
        $self->res->code(400);
        return $self->render(action => 'noaction');
    }

    my $valid = _time { $self->users->verify_user($user, $passwd) } $self, 'verify user';

    if ($valid) {
        $self->session(S_USER() => $user);
        $self->session_passwd($passwd);

        $self->res->code(303);
        $self->redirect_to('displayheaders');
    }
    else {
        $self->res->code(401);
        $self->render(action => 'noaction',
            warning => $self->l('login') . ' ' . $self->l('failed') . '!',
        );
    }
}


sub logout {
    my $self = shift;

    delete $self->session->{S_USER()};
    $self->session_passwd('');

    # $self->session(expires => 1);

    $self->res->code(303);
    $self->redirect_to('noaction');
}


sub about {
    my $self = shift;

    $self->stash(
        scriptadmin => $self->config->{defaults}{scriptadmin},
        http_host   => $self->tx->req->url->to_abs->host,
        request_uri => $self->tx->req->url,
        remote_addr => $self->tx->original_remote_address,
    );
}


sub displayheaders {
    no warnings 'experimental::smartmatch';
    my $self = shift;

    my $auth = AuthReadMails->new(
        user      => $self->session(S_USER),
        password  => $self->session_passwd,
        challenge => $self->app->secrets->[0],
    );

    my $folders = _time { $self->users->folders($auth) } $self, 'user folders';
    push @$folders, '';

    unless ( $self->stash('folder') ~~ $folders ) {
        $self->res->code(404);
        $self->render(template => 'error',
            error => $self->l('no_folder'),
            links => [map { $self->url_for(folder => $_) } @$folders],
        );
        return;
    }

    my $v = $self->validation;
    my $sort = $v->optional('sort')->like(qr'^!?(?:date|subject|sender|size)$')->param // '!date';
    my $search = $v->optional('search')->param;

    if ($v->has_error) {
        $self->res->code(400);
        $self->render(template => 'error', error => "errors in @{ $v->failed }");
        return;
    }

    my ($total_byte_size, $cnt, $new) = _time { $self->users->count($auth, $self->stash('folder')) } $self, 'user count';

    my ($start, $end) = $self->paginate($cnt);

    $self->timing->begin('user_headers');
    my $headers;
    if ($search) {
        $headers = $self->users->search(
            $auth, $search, $self->stash('folder'),
        );
    }
    else {
        $headers = $self->users->read_headers_for(
            auth   => $auth,
            folder => $self->stash('folder'),
            start  => $start,
            end    => $end,
            sort   => $sort,
        );
    }
    my $elapsed = $self->timing->elapsed('user_headers');
    $self->app->log->debug("Reading user headers took $elapsed seconds");

    $self->stash(
        msgs         => $headers,
        mail_folders => $folders,
        total_size   => $total_byte_size,
        total_new_mails => $new,
    );
}


sub readmail {
    my $self = shift;

    my $mid = $self->stash('id');

    my $auth = AuthReadMails->new(
        user      => $self->session(S_USER),
        password  => $self->session_passwd,
        challenge => $self->app->secrets->[0],
    );

    my $mail;
    eval { $mail = $self->users->show($auth, $mid) };
    if (my $err = $@) {
        if ($err =~ m/unkown mail-id|no such message/) {
            $self->reply->not_found;
            return;
        }
        die $@;
    }

    $self->render(action => 'readmail',
        msg => $mail,
    );
}


sub writemail { }


sub sendmail {
    my $self = shift;

    my $v = $self->validation;
    $v->csrf_protect;

    my %mail = (
        to      => scalar $v->required('to', 'not_empty')->check('mail_line')->every_param,
        message => scalar $v->required('body', 'not_empty')->param,
        subject => scalar $v->required('subject', 'not_empty')->param,
        cc      => scalar $v->optional('cc', 'not_empty')->check('mail_line')->every_param,
        bcc     => scalar $v->optional('bcc', 'not_empty')->check('mail_line')->every_param,
        reply   => scalar $v->optional('back_to', 'not_empty')->check('mail_line')->param,
        attach  => scalar $v->optional('attach', 'non_empty_ul')->upload->param,
        from    => scalar $self->session(S_USER),
    );
    $mail{attach_type} = Mojolicious::Types->new->file_type($mail{attach}->filename) if $mail{attach};

    if ($v->has_error) {
        $self->log->debug("mail send failed. Error in @{ $v->failed }");

        $self->render(action => 'writemail',
            warning => $self->l('error_send'),
        );
        return;
    }

    my $error = $self->send_mail(\%mail);

    if ($error) {
        $v->error(send => ['internal_error']); # make validation fail so that values are restored

        $self->render(action => 'writemail',
            warning => $self->l('error_send'),
        );
        return;
    }

    $self->flash(message => $self->l('succ_send'));
    $self->res->code(303);
    $self->redirect_to('displayheaders');
}


sub move {
    my $self = shift;

    my $v = $self->validation;
    $v->csrf_protect;

    if ($v->has_error) {
        return;
    }

    my $auth = AuthReadMails->new(
        user      => $self->session(S_USER),
        password  => $self->session_passwd,
        challenge => $self->app->secrets->[0],
    );
    my $folders = $self->users->folders($auth);

    my $mm = $self->every_param('mail');
    my $folder = $self->param('folder');

    no warnings 'experimental::smartmatch';
    die "$folder not valid" unless $folder ~~ $folders;

    $self->users->move($auth, $_, $folder) for @$mm;

    $self->flash(message => $self->l('succ_move'));
    $self->res->code(303);
    $self->redirect_to('displayheaders');
}


sub raw {
    my $self = shift;

    my $mid = $self->stash('id');

    my $auth = AuthReadMails->new(
        user      => $self->session(S_USER),
        password  => $self->session_passwd,
        challenge => $self->app->secrets->[0],
    );

    my $mail = $self->users->show($auth, $mid);

    my $v = $self->validation;
    $v->optional('body')->like(qr/\w+/);
    if ($v->has_error) {
        return;
    }

    if (my $type = $self->param('body')) {
        if ($mail->{head}{content_type} =~ '^multipart/') {
            my ($content) = grep {$_->{head}{content_type} =~ $type} @{ $mail->{body} };
            $self->render(text => $content->{body});
        }
        elsif ($mail->{head}{content_type} =~ $type) {
            $self->render(text => $mail->{body}) ;
        }
        else {
            $self->res->code(404);
        }
    }
    else {
        $self->res->headers->content_type('text/plain');
        $self->render(text => $self->dumper($mail));
    }
}


1

__END__

=encoding utf-8

=head1 NAME 

Webmail - All functions comprising the webmail application.

=head1 SYNOPSIS

  my $r = $app->routes;
  $r->get('/about')->to('Webmail#about');
  $r->post('/login')->to('Webmail#login');

=head1 DESCRIPTION

The controller of JWebmail.

=head1 METHODS

=head2 noaction

The login page. This should be the root.

=head2 auth

  my $a = $r->under('/')->to('Webmail#auth');

  An intermediate route that makes sure a user has a valid session.

=head2 login

Post route that checks login data.

=head2 logout

Route that clears session data.

=head2 about

Public route.

=head2 displayheaders

Provides an overview over messages.

=head2 readmail

Displays a single mail.

=head2 writemail

A mail editor.

=head2 sendmail

Sends a mail written in writemail.

=head2 move

Moves mails between mail forlders.

=head2 raw

Displays the mail raw, ready to be downloaded.

=head1 DEPENCIES

Mojolicious and File::Type

=cut
