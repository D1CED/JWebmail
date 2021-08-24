package JWebmail::Plugin::Helper;

use Mojo::Base 'Mojolicious::Plugin';

use List::Util qw(all min max);
use Mojo::Util qw(encode decode b64_encode b64_decode xml_escape);
use POSIX qw(floor round log ceil);

use constant TRUE_RANDOM => eval { require Crypt::URandom; Crypt::URandom->import('urandom'); 1 };
use constant HMAC => eval { require Digest::HMAC_MD5; Digest::HMAC_MD5->import('hmac_md5'); 1 };


### filter and checks for mojo validator

sub mail_line {
    my ($v, $name, $value, @args) = @_;

    my $mail_addr = qr/\w+\@\w+\.\w+/;
    # my $unescaped_quote = qr/"(*nlb:\\)/; # greater perl version required
    my $unescaped_quote = qr/"(?<!:\\)/;

    return $value !~ /^(
        (
            (
                (
                    $unescaped_quote.*?$unescaped_quote
                ) | (
                    [\w\s]*
                )
            )
            \s*<$mail_addr>
        ) | (
            $mail_addr
        ))$
    /xno;
}


sub filter_empty_upload {
    my ($v, $name, $value) = @_;

    return $value->filename ? $value : undef;
}

### template formatting functions

sub print_sizes10 {
    my $var = shift || return '0 Byte';

    my $i = floor(((log($var)/log(10))+1e-5) / 3);
    my $expo = $i * 3;

    my @PREFIX;
    $PREFIX[0] = 'Byte';
    $PREFIX[1] = 'kByte';
    $PREFIX[2] = 'MByte';
    $PREFIX[3] = 'GByte';
    $PREFIX[4] = 'TByte';
    $PREFIX[5] = 'PByte';

    return sprintf('%.0f %s', $var / (10**$expo), $PREFIX[$i]);
}


sub print_sizes2 {
    my $var = shift || return '0 Byte';

    my $i = floor(((log($var)/log(2))+1e-5) / 10);
    my $expo = $i * 10;
    my %PREFIX = (
        0 => 'Byte',
        1 => 'KiByte',
        2 => 'MiByte',
        3 => 'GiByte',
        4 => 'TiByte',
        5 => 'PiByte',
    );
    my $pref = $PREFIX{$i};
    return round($var / (2**$expo)) . " $pref";
}


sub d { qr/([[:digit:]]{$_[0]})/ }

sub parse_iso_date {
    my @d = shift =~ m/@{[d(4).'-'.d(2).'-'.d(2).'T'.d(2).':'.d(2).':'.d(2)]}/;
    if (!all { defined $_ } @d) {
        # TODO
    }
    return {
        year  => $d[0],
        month => $d[1],
        mday  => $d[2],
        hour  => $d[3],
        min   => $d[4],
        sec   => $d[5],
    };
}

### mime type html render functions

my $render_text_plain = sub {
    my ($c, $content) = @_;

    $content = xml_escape($content);
    $content =~ s/\n/<br>/g;

    return $content;
};


my $render_text_html = sub {
    my $c_ = shift;

    return '<iframe src="' . $c_->url_for('rawid', id => $c_->stash('id'))->query(body => 'html') . '" class=html-mail></iframe>';
};


our %MIME_Render_Subs = (
    'text/plain' => $render_text_plain,
    'text/html'  => $render_text_html,
);


sub mime_render {
    my ($c, $enc, $cont) = @_;

    ($enc) = $enc =~ m"^(\w+/\w+);?";

    my $renderer = $MIME_Render_Subs{$enc} // return '';
    return $renderer->($c, $cont);
};

### session password handling

use constant { S_PASSWD => 'pw', S_OTP_S3D_PW => 'otp_s3d_pw' };

sub _rand_data {
    my $len = shift;

    if (TRUE_RANDOM) {
        #return makerandom_octet(Length => $len, Strength => 0); # was used for Crypt::Random
        return urandom($len);
    }
    else {
        my $res = '';
        for (0..$len-1) {
            vec($res, $_, 8) = int rand 256;
        }

        return $res;
    }
}

sub session_passwd {
    my ($c, $passwd) = @_;

    warn_cram($c);
    warn_crypt($c);

    if (defined $passwd) { # set
        if ( HMAC && lc($c->config->{'session'}{secure} || 'none') eq 'cram' ) {
            $c->session(S_PASSWD() => $passwd ? b64_encode(hmac_md5($passwd, $c->app->secrets->[0]), '') : '');
        }
        elsif (lc($c->config->{'session'}->{secure} || 'none') eq 's3d') {
            unless ($passwd) {
                $c->s3d(S_PASSWD, '');
                delete $c->session->{S_OTP_S3D_PW()};
                return;
            }
            die "'$passwd' contains invalid character \\n" if $passwd =~ /\n/; 
            if (length $passwd < 20) {
                $passwd .= "\n" . " " x (20 - length($passwd) - 1);
            }
            my $rand_bytes = _rand_data(length $passwd);
            $c->s3d(S_PASSWD, b64_encode(encode('UTF-8', $passwd) ^ $rand_bytes, ''));
            $c->session(S_OTP_S3D_PW, b64_encode($rand_bytes, ''));
        }
        else {
            $c->session(S_PASSWD() => $passwd);
        }
    }
    else { # get
        if ( HMAC && lc($c->config->{'session'}->{secure} || 'none') eq 'cram' ) {
            return ($c->app->secrets->[0], $c->session(S_PASSWD));
        }
        elsif (lc($c->config->{'session'}->{secure} || 'none') eq 's3d') {
            my $pw = b64_decode($c->s3d(S_PASSWD) || '');
            my $otp = b64_decode($c->session(S_OTP_S3D_PW) || '');
            my ($res) = split "\n", decode('UTF-8', $pw ^ $otp), 2;
            return $res;
        }
        else {
            return $c->session(S_PASSWD);
        }
    }
}

sub warn_cram {
    my $c = shift;

    state $once = 0;

    if ( !HMAC && !$once && lc($c->config->{'session'}->{secure} || 'none') eq 'cram' ) {
        $c->log->warn("cram requires Digest::HMAC_MD5. Falling back to 'none'.");
    }

    $once = 1;
}

sub warn_crypt {
    my $c = shift;

    state $once = 0;

    if ( !TRUE_RANDOM && !$once && lc($c->config->{'session'}->{secure} || 'none') eq 's3d' ) {
        $c->log->warn("Falling back to pseudo random generation. Please install Crypt::Random");
    }

    $once = 1;
}

### pagination

sub _clamp {
    my ($x, $y, $z) = @_;

    die '!($x <= $z)' unless $x <= $z;

    if ($x <= $y && $y <= $z) {
        return $y;
    }

    return $x if ($y < $x);
    return $z if ($z < $y);
}

sub _paginate {
    my %args = @_;

    my $first_item  = $args{first_item};
    my $page_size   = $args{page_size} || 1;
    my $total_items = $args{total_items};

    my $first_item1 = $total_items ? $first_item+1 : 0;

    my $current_page = ceil($first_item/$page_size);
    my $total_pages  = ceil($total_items/$page_size);

    my $page = sub {
        my $page_ = shift;
        return [0, 0] unless $total_items;
        $page_ = _clamp(0, $page_, $total_pages-1);
        [_clamp(1, $page_*$page_size + 1, $total_items), _clamp(1, ($page_+1)*$page_size, $total_items)]
    };

    return (
        first_item  => $first_item1,
        last_item   => _clamp($first_item1, $first_item + $page_size, $total_items),
        total_items => $total_items,
        page_size   => $page_size,

        total_pages  => $total_pages,
        current_page => $current_page + 1,

        first_page => $page->(0),
        prev_page  => $page->($current_page-1),
        next_page  => $page->($current_page+1),
        last_page  => $page->($total_pages-1),
    );
}

sub paginate {
    my $c = shift;
    my $count = shift;

    my $v = $c->validation;
    my $start = $v->optional('start')->num(0, undef)->param // 0;
    my $psize = $v->optional('page_size')->num(1, undef)->param // 50;

    $start = _clamp(0, $start, max($count-1, 0));
    my $end = _clamp($start, $start+$psize-1, max($count-1, 0));

    $c->stash(_paginate(first_item => $start, page_size => $psize, total_items => $count));

    return $start, $end;
}

### registering

sub register {
    my ($self, $app, $conf) = @_;
    $conf //= {};

    if (ref $conf->{import} eq 'ARRAY' and my @import = @{ $conf->{import} }) {
        no warnings 'experimental::smartmatch';

        # selective import
        $app->helper(print_sizes10  => sub { shift; print_sizes10(@_) })
            if 'print_sizes10' ~~ @import;
        $app->helper(parse_iso_date => sub { shift; parse_iso_date(@_) })
            if 'parse_iso_date' ~~ @import;
        $app->helper(print_sizes2  => sub { shift; print_sizes2(@_) })
            if 'print_sizes2' ~~ @import;
        $app->helper(mime_render    => \&mime_render)
            if 'mime_render' ~~ @import;
        $app->helper(session_passwd => \&session_passwd)
            if 'session_passwd' ~~ @import;
        $app->helper(paginate => \&paginate)
            if 'paginate' ~~ @import;
        $app->validator->add_check(mail_line => \&mail_line)
            if 'mail_line' ~~ @import;
        $app->validator->add_filter(non_empty_ul => \&filter_empty_upload)
            if 'non_empty_ul' ~~ @import;
    }
    elsif (!$conf->{import}) { # default imports
        $app->helper(print_sizes10  => sub { shift; print_sizes10(@_) });
        $app->helper(parse_iso_date => sub { shift; parse_iso_date(@_) });
        $app->helper(mime_render    => \&mime_render);
        $app->helper(session_passwd => \&session_passwd);
        $app->helper(paginate       => \&paginate);

        $app->validator->add_check(mail_line => \&mail_line);

        $app->validator->add_filter(non_empty_ul => \&filter_empty_upload);
    }
}


1

__END__

=encoding utf-8

=head1 NAME

Helper - Functions used as helpers in controller and templates and additional validator checks and filters

=head1 SYNOPSIS

  use Mojo::Base 'Mojolicious';

  use JWebmail::Plugin::Helper;

  sub startup($self) {
    $self->helper(mime_render => \&JWebmail::Plugin::Helper::mime_render);
  }

  # or

  $app->plugin('Helper');

=head1 DESCRIPTION

L<JWebmail::Helper> provides useful helper functions and validator cheks and filter for
L<JWebmail::Controller::All> and various templates.

=head1 FUNCTIONS

=head2 mail_line

A check for validator used in mail headers for fields containing email addresses.

  $app->validator->add_check(mail_line => \&JWebmail::Plugin::Helper::mail_line);

  my $v = $c->validation;
  $v->required('to', 'not_empty')->check('mail_line');

=head2 filter_empty_upload

A filter for validator used to filter out empty uploads.

  $app->validator->add_filter(non_empty_ul => \&JWebmail::Plugin::Helper::filter_empty_upload);

  my $v = $c->validation;
  $v->required('file_upload', 'non_empty_ul');

=head2 print_sizes10

A helper for templates used to format byte sizes.

  $app->helper(print_sizes10 => sub { shift; JWebmail::Plugin::Helper::print_sizes10(@_) });

  %= print_sizes10 12345 # => 12 kB

=head2 print_sizes2

A helper for templates used to format byte sizes.

  %= print_sizes10 12345 # => 12 KiB

This is not registered by default.

=head2 paginate

A helper for calculationg page bounds.

Takes the total number of items as argument.

Reads in 'start' and 'page_size' query arguments.
start is 0 based.

Returns the calculated start and end points as 0 based inclusive range.

Sets the stash values (all 1 based inclusive):

  first_item
  last_item
  total_items
  page_size
  total_pages
  current_page
  first_page
  prev_page
  next_page
  last_page

=head2 mime_render

A helper for templates used to display the content of a mail for the browser.
The output is valid html and should not be escaped.

  $app->helper(mime_render => \&JWebmail::Plugin::Helper::mime_render);

  %== mime_render 'text/plain' $content

=head2 session_passwd

A helper used to set and get the session password. The behaivour can be altered by
setting the config variable C<< session => {secure => 's3d'} >>.

  $app->helper(session_passwd => \&JWebmail::Plugin::Helper::session_passwd);

  $c->session_passwd('s3cret');

Currently the following modes are supported:

=over 6

=item none 

password is plainly stored in session cookie

=item cram 

challenge response authentication mechanism uses the C<< $app->secret->[0] >> as nonce.
This is optional if Digest::HMAC_MD5 is installed.

=item s3d 

data is stored on the server. Additionally the password is encrypted by an one-time-pad that is stored in the user cookie.

=back

=head1 DEPENDENCIES

Mojolicious, Crypt::Random and optianally Digest::HMAC_MD5.

=head1 SEE ALSO

L<JWebmail>, L<JWebmail::Controller::All>, L<Mojolicious>, L<Mojolicious::Controller>

=head1 NOTICE

This package is part of JWebmail.

=cut
