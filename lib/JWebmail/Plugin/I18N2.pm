package JWebmail::Plugin::I18N2;

use Mojo::Base 'Mojolicious::Plugin';


package JWebmail::Plugin::I18N2::Translator {

    use Mojo::File;

    use Config::Tiny;

    sub new {
        my $cls = shift;
        my $conf = @_ == 1 ? shift : {@_};
        my $self = {};

        my @languages = keys %{$conf->{languages} // {}};

        unless (@languages) {
            @languages = map { s|^.*/(..)\.lang$|$1|r } glob("'$conf->{directory}/*.lang'");
        }

        # load languages
        for my $l (@languages) {
            if (my $dict = __loadi18n($conf->{directory}, $l)) {
                $self->{$l} = $dict;
            }
        }

        return bless $self, $cls;
    }

    sub languages {
        my $self = shift;
        if (@_) {
            return exists $self->{$_[0]};
        }
        return wantarray ? sort keys $self->%* : scalar keys $self->%*;
    }

    sub translate {
        my $self = shift;
        my $lang = shift;
        my $word = shift;
        return $self->{$lang}{$word};
    }

    sub __loadi18n {
        my $langsubdir = shift;
        my $lang = shift;

        my $langFile = "$langsubdir/$lang.lang";
        my $TXT;

        if ( -f $langFile ) {
            $TXT = Config::Tiny->read($langFile, 'utf8')->{'_'};
            if ($@) {
                die "error reading file $langFile: $@";
            }
        }
        return $TXT;
    }
}


package JWebmail::Plugin::I18N2::Match {
    use Mojo::Base 'Mojolicious::Routes::Match';

    has '_i18n2_stash';

    sub __add_option_no_override {
        my $key = shift;
        my $value = shift;

        if (ref $_[0] eq 'HASH' && @_ == 1) {
            $_[0]->{$key} ||= $value;
        }
        elsif (ref $_[1] eq 'HASH' && @_ == 2) {
            $_[1]->{$key} ||= $value;
        }
        else {
            my ($dom, %args) = @_%2 == 0 ? (undef, @_) : @_;
            $args{$key} ||= $value;
            @_ = ($dom, %args);
            shift @_ unless defined $_[0];
        }
        return @_;
    }

    sub path_for {
        my $self = shift;
        my @args = @_;
        if (my $lang = $self->_i18n2_stash->{lang}) {
            @args = __add_option_no_override(lang => $lang, @args);
        }
        return $self->SUPER::path_for(@args);
    }
}


sub register {
    my ($self, $app, $conf) = @_;
    $conf //= {};

    my $i18n_log = $app->log->context('[' . __PACKAGE__ . ']');

    my $translator = $conf->{translator} || sub { JWebmail::Plugin::I18N2::Translator->new(@_) };
    my $defaultLang = $conf->{default_language} || 'en';
    my $fileLocation = $conf->{directory} && Mojo::File->new($conf->{directory})->is_abs
                     ? $conf->{directory}
                     : $app->home->child($conf->{directory} || 'lang');

    my $t = $translator->(
        default_language => $defaultLang,
        directory => $fileLocation,
        %{$conf->{rest} // {}}
    );

    {
        local $" = ',';
        $i18n_log->debug("loaded languages (@{[$t->languages]})");

        if (keys $conf->{languages}->%* > $t->languages) {
            $i18n_log->warn("missing languages");
        }
    }

    $app->defaults(default_language => $defaultLang);
    $app->defaults(languages => [$t->languages]);

    # add translator as helper
    $app->helper(l => sub {
        my $c = shift;
        my $lang = @_ == 2 ? $_[0] : $c->stash->{lang};
        my $word = @_ == 2 ? $_[1] : $_[0];

        my $res = $t->translate($lang, $word);
        unless ($res) {
            local $" = ' ';
            $app->log->warn('[' . __PACKAGE__ . "] missing translation for '$lang':'$word' @{[ caller(1) ]}[0..2]");
        }
        return $res;
    });

    # modify incoming url
    $app->hook(before_dispatch => sub {
        my $c = shift;
        unshift @{ $c->req->url->path->parts }, ''
            unless $t->languages($c->req->url->path->parts->[0] || '');
    });

    # modify generated url
    $app->hook(before_dispatch => sub {
        my $c = shift;
        $c->match(JWebmail::Plugin::I18N2::Match->new(
            root         => $c->app->routes,
            _i18n2_stash => $c->stash,
        ));
    });

    return $app->routes->any('/:lang' => {lang => $defaultLang});
}

1

__END__

=encoding utf8 

=head1 NAME

JWebmail::Plugin::I18N2 - Custom Made I18N Support an alternative to JWebmail::Plugin::I18N

=head1 SYNOPSIS

    $app->plugin('I18N2', {
        languages => [qw(en de es)],
        default_language => 'de',
        directory => 'path/to/language/files/',
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

This Plugin only works with Mojolicious version 8.64 or higher.

=head1 OPTIONS

=head2 default_language

The default language when no other information is provided.

=head2 directory

Directory to look for language files.

=head2 languages

List of allowed languages.
As a default, files of the pattern "$lang.lang" will be looked for.

=head1 HELPERS

=head2 l

This is used for your translations.

    $c->l('hello')

=cut
