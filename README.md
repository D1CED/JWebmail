JWebmail
========

This is based on concepts of oMail by Oliver Müller <om@omnis.ch>.

JWebmail is a webmail server build on top of Mojolicious.

This includes:
- Using a Perl web framework and leave the deprecated CGI behind. You can
  still use it in a CGI setup if you like but you now have the option of
  plack/psgi and fcgi as well as the build in server hypnotoad.
- Set up a MVC architecture instead of a single file.
- Improve security by only running a small part of the model with elevated
  privileges.
- Make sure it works well with sqmail and its authuser authenticator and
  maildir but also permit other setups (currently not supported but adding
  more should be easy). Maybe I even add a POP or IMAP based back-ends instead
  of reading them from disk.


## License
JWebmail is available under the GNU General Public License version 3.

## JWebmail-webmail - INSTALL
You need a moderately new version of Perl (v5.22+)
You need access to CPAN.
You need to install sqmail.
It is recommended to use an external web server like Apache or Nginx.


Posts
-----

- Complain about IPC::Open2 ignoring 'open' pragma
- Complain about undef references causing errors, and non-fine granular
  switch no strict 'refs'
- Thank for perldoc.org


I18N patch url_for
------------------

I have taken the monkey patching approach that was taken by
Mojolicious::Plugin::I18N. I used `can` to get the old method for looser
coupling and used the Mojo::Util::monkey_patch instead of manually doing it.
This is probably overkill.

I'm desperately looking for a different approach. Yeah the monkey patching
works great, but it violates the open-closed principal. But I cannot find
an appropriate alternative. Extending the controller and overriding url_for
does not work cleanly as the user directly inherits from Mojolicious::Controller.
Also going the 'better' approach of solving at the root by using an extension
of Mojolicious::Routes::Match->path_for and supplying it to the controller
by setting match does not work as it is on the one hand extremely difficult
to inject it in the first place and the attribute is overwritten in the
dispatching process anyways. One issue when taking the Match approach is
that it needs knowledge of the stash values which can cause cyclic references.

I thought of three approaches injecting the modified Match instance into the class:

1. Extending the Mojolicious::Controller and overriding the new method.
   This has the issue that inheritance is static but one can use Roles that
   are dynamically consumed.
2. Overriding build_controller in Mojolicious. To make this cleanly it needs
   to be monkey patched by the plugin which is exactly what we want to avoid. :(
3. The matcher can be set in a hook relatively early in its lifetime and
   hooks compose well.

A completely different option is to use the router directly and register a
global route that has the language as parameter. But omitting the language
leads to problems.

One can use a redirect on root. Very easy but also not very effective.

I am now using a global route containing the language after the changes to
matching have been published. No need to monkey_patch and it works well enough.


## Concepts

    Router                        Mojolicious build-in 
    Configuration                 INI via Config::Tiny
    Middleware (auth)             Mojo under
    Controller/Handler            Mojolicious::Controller
    Templates                     Mojo format ep
    Template helpers              Mojolicious->helper
    i18n (url rewriting)          see 'I18N patch url_for'
    Sessions (server side)        self developed plug-in
    Flash                         Mojo
    Pagination                    self developed
    Validation                    Mojo
    Logging                       Mojo::Log
    Debug printing                Data::Dumper
    Development server            Mojo
    MIME handling


Dependencies
------------

- M & V
  - Mojolicious
  - Config::Tiny
  - Crypt::URandom
- C
  - Mail::Box::Manager
  - Email::MIME


## Architecture

    Webserver <--> Application
                     Server
                       |
                   Application <--> Extractor

The Webserver acts as a proxy to the Application Server.

The Extractor is a stateless process that reads mails from a source.
