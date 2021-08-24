package JWebmail v1.1.0;

use Mojo::Base 'Mojolicious';

use JWebmail::Controller::Webmail;
use JWebmail::Model::ReadMails;
use JWebmail::Model::Driver::QMailAuthuser;
use JWebmail::Model::WriteMails;

use JWebmail::Model::Driver::MockJSON;
use JWebmail::Model::Driver::MockMaildir;


sub startup {
    my $self = shift;

    $self->moniker('jwebmail');

    my $mode = $self->mode;
    $self->log->path($self->home->child('log', "$mode.log"));

    # load plugins
    push @{$self->plugins->namespaces}, 'JWebmail::Plugin';

    $self->plugin('INIConfig');
    $self->plugin('ServerSideSessionData');
    $self->plugin('Helper');
    my $i18n_route = $self->plugin('I18N2', $self->config('i18n'));

    $self->secrets( [$self->config('secret')] ) if $self->config('secret');
    delete $self->config->{secret};

    # initialize models
    no warnings "experimental::smartmatch";
    my $driver = do {
        given ($self->config->{development}{use_read_mock}) {
            when (/^json/)    { JWebmail::Model::Driver::MockJSON->new() }
            when (/^maildir/) { JWebmail::Model::Driver::MockMaildir->new(extractor => 'rust') }
            default { 
                JWebmail::Model::Driver::QMailAuthuser->new(
                    logfile => $self->home->child('log', 'extract.log'),
                    %{ $self->config->{model}{read}{driver} // {} })
            }
        }
    };
    my $read_mails = JWebmail::Model::ReadMails->new(driver => $driver);
    $self->helper(users => sub { $read_mails });
    $self->helper(send_mail => sub { my ($c, $mail) = @_; JWebmail::Model::WriteMails::sendmail($mail) });
    $JWebmail::Model::WriteMails::Block_Writes = 1 if $self->config->{development}{block_writes};

    $self->defaults(version => __PACKAGE__->VERSION);

    $self->route($i18n_route);
}


sub route {
    my $self = shift;

    my $r = shift // $self->routes;

    $r->get('/' => 'noaction')->to('Webmail#noaction');
    $r->get('/about')->to('Webmail#about');
    $r->post('/login')->to('Webmail#login');
    $r->get('/logout')->to('Webmail#logout');

    my $a = $r->under('/')->to('Webmail#auth');
    $a->get('/home/:folder')->to('Webmail#displayheaders', folder => '')->name('displayheaders');
    $a->get('/read/#id' => 'read')->to('Webmail#readmail');
    $a->get('/write')->to('Webmail#writemail');
    $a->post('/write' => 'send')->  to('Webmail#sendmail');
    $a->post('/move')->to('Webmail#move');
    $a->get('/raw/#id')->to('Webmail#raw');
}


1

__END__

=encoding utf-8

=head1 NAME

JWebmail - Provides a web based e-mail client meant to be used with s/qmail.

=head1 SYNOPSIS

  hypnotoad script/jwebmail

And use a server in reverse proxy configuration. 

=head1 DESCRIPTION

=head1 CONFIGURATION

Use the jwebmail.conf file.

=head1 AUTHORS

Copyright (C) 2020 Jannis M. Hoffmann L<jannis@fehcom.de>

=head1 BASED ON

Copyright (C) 2001 Olivier Müller L<om@omnis.ch> (GPLv2+ project: oMail Webmail)

Copyright (C) 2000 Ernie Miller (GPL project: Neomail)

See the CREDITS file for project contributors.

=head1 LICENSE

This module is licensed under the terms of the GPLv3 or any later version at your option.
Please take a look at the provided LICENSE file shipped with this module.

=cut
