package JWebmail::Plugin::I18N2;

use Mojo::Base 'Mojolicious::Plugin';

use Mojolicious::Controller;
use Mojo::File;
use Mojo::Util 'monkey_patch';


has '_language_loaded' => sub { {} };


sub register {
    my ($self, $app, $conf) = @_;

    my $i18n_log = $app->log->context('[' . __PACKAGE__ . ']');

    # config
    # 1. what languages
    # 2. where are the files
    # 3. fallback language
    #
    # look for languages automatically
    my $defaultLang = $conf->{default_language} || 'en';
    my $fileLocation = $conf->{directory} && Mojo::File->new($conf->{directory})->is_abs
                       ? $conf->{directory}
                       : $app->home->child($conf->{directory} || 'lang');
    my @languages = keys %{$conf->{languages} // {}};

    unless (@languages) {
        @languages = map { $_ =~ s|^.*/(..)\.lang$|$1|r } glob("$fileLocation/*.lang");
    }

    $app->defaults(languages => [@languages]);

    # load languages
    my $TXT;
    for my $l (@languages) {
        $TXT->{$l} = _loadi18n($fileLocation, $l, $i18n_log);
    }

    {
        local $" = ',';
        $i18n_log->debug("loaded languages (@languages)");
    }

    $self->_language_loaded( { map { $_ => 1 } @languages } );

    # add translator as helper
    my $i18n = sub {
        my ($lang, $word) = @_;
        $TXT->{$lang}{$word} || scalar(
            local $" = ' ',
            $lang && $word ? $app->log->debug('[' . __PACKAGE__ . "] missing translation for $lang:$word @{[ caller(2) ]}[0..2]") : (),
            '',
        )
    };
    $app->helper( l => sub { my $c = shift; $i18n->($c->stash->{lang}, shift) } );

    $app->hook(before_dispatch => sub {
        my $c = shift;
        unshift @{ $c->req->url->path->parts }, ''
            unless $self->_language_loaded->{$c->req->url->path->parts->[0] || ''};
    });

    # patch url_for
    my $mojo_url_for = Mojolicious::Controller->can('url_for');
    my $i18n_url_for = sub {
        my $c = shift;
        if (ref $_[0] eq 'HASH') {
            $_[0]->{lang} ||= $c->stash('lang');
        }
        elsif (ref $_[1] eq 'HASH') {
            $_[1]->{lang} ||= $c->stash('lang');
        }
        elsif (@_) {
            push @_, lang => $c->stash('lang');
        }
        else {
            @_ = {lang => $c->stash('lang')};
        }
        return $mojo_url_for->($c, @_);
    };
    monkey_patch 'Mojolicious::Controller', url_for => $i18n_url_for;

    return $app->routes->any('/:lang' => {lang => 'en'});
}


sub _loadi18n {

    my $langsubdir = shift;
    my $lang = shift;
    my $log = shift;

    my $langFile = "$langsubdir/$lang.lang";
    my $TXT;

    if ( -f $langFile ) {
        $TXT = Config::Tiny->read($langFile, 'utf8')->{'_'};
        if ($@ || !defined $TXT) {
            $log->error("error reading file $langFile: $@");
        }
    }
    else {
        $log->warn("language file $langFile does not exist!");
    }
    return $TXT;
}


1

__END__

=encoding utf8 

=head1 NAME

JWebmail::Plugin::I18N2 - Custom Made I18N Support an alternative to JWebmail::Plugin::I18N

=head1 SYNOPSIS

  $app->plugin('I18N2', {
    languages => [qw(en de es)],
    default_language => 'en',
    directory => '/path/to/language/files/',
  })

  # in your controller
  $c->l('hello')

  # in your templates
  <%= l 'hello' %>

  @@ de.lang
  login = anmelden
  userid = nuzerkennung
  passwd = passwort
  failed = fehlgeschlagen
  about = über

  example.com/de/myroute # $c->stash('lang') eq 'de'
  example.com/myroute    # $c->stash('lang') eq $defaultLanguage

  # on example.com/de/myroute
  url_for('my_other_route') #=> example.com/de/my_other_route

  url_for('my_other_route', lang => 'es') #=> example.com/es/my_other_route

=head1 DESCRIPTION

L<JWebmail::Plugin::I18N2> provides I18N support.

The language will be taken from the first path segment of the url.
Be carefult with colliding routes.

Mojolicious::Controller::url_for is patched so that the current language will be kept for
router named urls.

=head1 OPTIONS

=head2 default_language

The default language when no other information is provided.

=head2 directory

Directory to look for language files.

=head2 languages

List of allowed languages.
Files of the pattern "$lang.lang" will be looked for.

=head1 HELPERS

=head2 l

This is used for your translations.

  $c->l('hello')
  $app->helper('hello')->()

=cut