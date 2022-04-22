package JWebmail::Model::WriteMails;

use v5.18;
use warnings;
use utf8;

use Exporter 'import';
our @EXPORT_OK = qw(sendmail);

use Email::MIME;


our $Block_Writes = 0;


sub _build_mail {
    my $mail = shift;

    my $text_part = Email::MIME->create(
        attributes => {
            content_type => 'text/plain',
            charset      => 'utf-8',
            encoding     => '8bit',
        },
        body_str => $mail->{message},
    );
    my $attach = Email::MIME->create(
        attributes => {
            content_type => $mail->{attach_type},
            encoding     => 'base64',
        },
        body => $mail->{attach}->asset->slurp,
    ) if $mail->{attach};

    my $email = Email::MIME->create(
        header_str => [
            From       => $mail->{from},
            To         => $mail->{to},
            Subject    => $mail->{subject},
            'X-Mailer' => 'JWebmail',
        ],
        parts => [ $text_part, $attach // () ],
    );
    $email->header_str_set(CC => @{$mail->{cc}}) if $mail->{cc};
    $email->header_str_set('Reply-To' => $mail->{reply}) if $mail->{reply};

    return $email->as_string;
}


sub _send {
    my ($mime, @recipients) = @_;

    open(my $m, '|-', 'sendmail', '-i', @recipients)
        or die 'Connecting to sendmail failed. Is it in your PATH?';
    $m->print($mime->as_string);
    close($m);
    return $? >> 8;
}


sub sendmail {
    my $mail = shift;

    my $mime = _build_mail($mail);

    my @recipients;
    push @recipients, @{ $mail->{to} } if $mail->{to};
    push @recipients, @{ $mail->{cc} } if $mail->{cc};
    push @recipients, @{ $mail->{bcc} } if $mail->{bcc};

    if ($Block_Writes) {
        say $mime;
        return 1;
    }

    return _send($mime, @recipients);
}


1

__END__

=encoding utf-8

=head1 NAME

WriteMails - Build and send mails via a sendmail interface

=head1 SYNOPSIS

  JWebmail::Model::WriteMails::sendmail {
    from    => ...,
    to      => ...,
    subject => ...,
  };

=head1 DESCRIPTION

Build and send mails.

=head1 FUNCTIONS

=head2 sendmail

Send the mail immediately.

=head3 from

The sender.

=head3 to

The recipient(s).

=head3 reply

The address the recipient is meant to reply to (optinal, if missing from is assumed).

=head3 cc

Secondary recipients, visible to other.

=head3 bcc

Secondary recipients, invisible to other.

=head3 subject

=head3 message

The message body. Should be plain text encoded as utf-8.

=head3 attach

Optinal attachment.

=head3 attach_type

The mime type of the attachment.

=cut
