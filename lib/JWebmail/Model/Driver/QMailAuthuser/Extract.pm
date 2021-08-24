#!/usr/bin/env perl
package JWebmail::Model::Driver::QMailAuthuser::Extract;

use v5.18;
use strict;
use warnings;
use utf8;

use POSIX ();
use JSON::PP;
use Carp;
use List::Util 'min';
use Encode v2.88 'decode';

use open IO => ':encoding(UTF-8)', ':std';
no warnings 'experimental::smartmatch';

use Mail::Box::Manager;

use constant ROOT_MAILDIR => '.';


sub main {
    my ($maildir) = shift(@ARGV) =~ m/(.*)/;
    my ($su) = shift(@ARGV) =~ m/(.*)/;
    my ($user) = shift(@ARGV) =~ m/([[:alpha:]]+)/;
    my $mode = shift @ARGV; _ok($mode =~ m/([[:alpha:]-]{1,20})/);
    my @args = @ARGV;

    delete $ENV{PATH};

    my $netfehcom_uid = getpwnam($su);
    #$> = $netfehcom_uid;
    die "won't stay as root" if $netfehcom_uid == 0;
    POSIX::setuid($netfehcom_uid);
    if ($!) {
        warn 'error setting uid';
        exit(1);
    }

    my $folder = Mail::Box::Manager->new->open(
        folder => "$maildir/$user/",
        type => 'maildir',
        access => 'rw',
    );

    my $reply = do {
        given ($mode) {
            when('list')      { list($folder, @args) }
            when('read-mail') { read_mail($folder, @args) }
            when('count')     { count_messages($folder, @args) }
            when('search')    { search($folder, @args) }
            when('folders')   { folders($folder, @args) }
            when('move')      { move($folder, @args) }
            default           { {error => 'unkown mode', mode => $mode} }
        }
    };
    $folder->close;

    print encode_json $reply;
    if (ref $reply eq 'HASH' && $reply->{error}) {
        exit 3;
    }
}


sub _sort_mails {
    my $sort = shift // '';
    my $reverse = 1;

    if ($sort =~ m/^!/) {
        $reverse = -1;
        $sort = substr $sort, 1;
    }

    given ($sort) {
        when ('date')    { return sub { ($a->timestamp <=> $b->timestamp) * $reverse } }
        when ('sender')  { return sub { ($a->from->[0] cmp $b->from->[0]) * $reverse } }
        when ('subject') { return sub { ($a->subject cmp $b->subject) * $reverse } }
        when ('size')    { return sub { ($a->size <=> $b->size) * $reverse } }
        when ('')        { return sub { ($a->timestamp <=> $b->timestamp) * $reverse } }
        default          { warn "unkown sort-verb '$sort'"; return sub { ($a->timestamp <=> $b->timestamp) * $reverse } }
    }
}


sub _ok {
    if (!shift) {
        carp 'verify failed';
        exit 4;
    }
}


sub list {
    my ($f, $start, $end, $sortby, $folder) = @_;
    $folder = ".$folder";

    _ok($start =~ m/^\d+$/);
    _ok($end =~ m/^\d+$/);
    _ok(0 <= $start && $start <= $end);
    _ok($sortby =~ m/^(!?\w+|\w*)$/n);
    _ok($folder ~~ [$f->listSubFolders, ROOT_MAILDIR]);

    $f = $f->openSubFolder($folder) if $folder ne ROOT_MAILDIR;

    return [] if $start == $end;

    my $sref = _sort_mails($sortby);
    my @msgs = $f->messages;
    @msgs = sort { &$sref } @msgs;
    @msgs = @msgs[$start..min($#msgs, $end)];

    my @msgs2;

    for my $msg (@msgs) {
        my $msg2 = {
            subject => decode('MIME-Header', $msg->subject),
            from => _addresses($msg->from),
            to => _addresses($msg->to),
            cc => _addresses($msg->cc),
            bcc => _addresses($msg->bcc),
            date_received => _iso8601_utc($msg->timestamp),
            size => $msg->size,
            content_type => ''. $msg->contentType,
            mid => $msg->messageId,
            new => $msg->label('seen'),
        };
        push @msgs2, $msg2;
    }

    return \@msgs2;
}


sub count_messages {
    my ($f, $folder) = @_;
    $folder = ".$folder";

    _ok($folder ~~ [$f->listSubFolders, ROOT_MAILDIR]);

    $f = $f->openSubFolder($folder) if $folder ne ROOT_MAILDIR;

    return {
        count => scalar($f->messages('ALL')),
        size => $f->size,
        new => scalar $f->messages('!seen'),
    }
}


sub _iso8601_utc {
    my @date_time = gmtime(shift);
    $date_time[5] += 1900;
    $date_time[4]++;
    return sprintf('%6$04d-%5$02d-%4$02dT%3$02d:%2$02d:%1$02dZ', @date_time);
}

sub _unquote { my $x = shift; [$x =~ m/"(.*?)"(?<!\\)/]->[0] || $x }

sub _addresses {
    [map { {address => $_->address, name => _unquote(decode('MIME-Header', $_->phrase))} } @_]
}


sub read_mail {
    my ($folder, $mid) = @_;
    
    my $msg = $folder->find($mid);
    return {error => 'no such message', mid => $mid} unless $msg;
    return {
        subject => decode('MIME-Header', $msg->subject),
        from => _addresses($msg->from),
        to => _addresses($msg->to),
        cc => _addresses($msg->cc),
        bcc => _addresses($msg->bcc),
        date_received => _iso8601_utc($msg->timestamp),
        size => $msg->size,
        content_type => ''. $msg->contentType,
        body => do {
            if ($msg->isMultipart) {
                [map {{type => ''. $_->contentType, val => '' . $_->decoded}} $msg->body->parts]
            }
            else {
                '' . $msg->body->decoded
            }
        },
    }
}


sub search {
    my ($f, $search_pattern, $folder) = @_;
    $folder = ".$folder";

    $f = $f->openSubFolder($folder) if $folder ne ROOT_MAILDIR;

    my @msgs = $f->messages(sub {
        my $m = shift;

        return scalar(grep { $_->decoded =~ /$search_pattern/ || (decode('MIME-Header', $_->subject)) =~ /$search_pattern/ } $m->body->parts)
            if $m->isMultipart;
        $m->body->decoded =~ /$search_pattern/ ||(decode('MIME-Header', $m->subject)) =~ /$search_pattern/;
    });

    my @msgs2;
    for my $msg (@msgs) {
        my $msg2 = {
            subject => decode('MIME-Header', $msg->subject),
            from => _addresses($msg->from),
            to => _addresses($msg->to),
            cc => _addresses($msg->cc),
            bcc => _addresses($msg->bcc),
            date_received => _iso8601_utc($msg->timestamp),
            size => $msg->size,
            content_type => ''. $msg->contentType,
            mid => $msg->messageId,
        };
        push @msgs2, $msg2;
    }

    return \@msgs2;
}


sub folders {
    my $f = shift;

    return [grep { $_ =~ m/^\./ && $_ =~ s/\.// } $f->listSubFolders];
}


sub move {
    my ($f, $mid, $dst) = @_;
    $dst = ".$dst";

    _ok($dst ~~ [$f->listSubFolders, ROOT_MAILDIR]);

    $f->moveMessage($dst, $dst->find($mid));
}


main() if !caller;

1

__END__

=encoding utf-8

=head1 NAME

JWebmail::Model::Driver::QMailAuthuser::Extract - Maildir reader

=head1 SYNOPSIS

Extract delivers information about emails.
Runs with elevated priviliges.

=head1 DESCRIPTION

This programm is started by qmail-authuser with elevated priviliges after
a succsessful login.
Input directives are provided as command line arguments.
Output is delivered via STDOUT and log information via STDERR.

=head1 ARGUMENTS

  prog <maildir> <system-user> <mail-user> <mode> <args...>

=head2 Modes

  list <start> <end> <sort-by> <folder>
  count <folder>
  read-mail <mid>
  search <pattern> <folder>
  folders
  move <mid> <dst-folder>

All arguments must be supplied for a given mode even if empty (as '').

=head1 DEPENDENCIES

Currently Mail::Box::Manager does all the hard work.

=head1 SEE ALSO

L<JWebmail::Model::Driver::QMailAuthuser>

=cut
