JWebmail
========

This is a rewrite of oMail by Oliver Müller <om@omnis.ch>.

oMail has not seen much progress in the last two decades
so my <jannis@fehcom.de> goal is to bring it up to date.
OMail was tied to qmail. JWebmail is not so tightly bound.

## This includes:
- Using a perl web framework and leave the deprecated CGI behind.
  You can still use it in a cgi setup if you like but you now
  have the option of plack/psgi and fcgi as well as the
  build in server hypnotoad.
- Set up a MVC architecture instead of spaghetti.
- Improve security by only running a small part of the
  model with elevated privileges.
- Make sure it works well with sqmail and its authuser
  authenticator and maildir but also permit other setups
  (currently not supported but adding more should be easy).
  Maybe I even add a POP or IMAP based backends instead
  of reading them from disk.

## License
JWebmail is available under the GNU General Public License
version 3 or later.

## JWebmail-webmail - INSTALL
You still need to install sqmail and setup
an external web server.

## Future feature list
- [ ] address book support

### Read
- [ ] bounce
- [ ] add links on email addresses in header : click = add into addressbook


Posts
-----
* Complain about IPC::Open2 ignoring 'open' pragma
* Complain about undef references causing errors, and non-fine granular switch no strict 'refs'
* Thank for perldoc.org


I18N patch url_for
------------------
I have taken the monkey patching approach that was taken by Mojolicious::Plugin::I18N.
I used `can` to get the old method for looser coupling and used the Mojo::Util::monkey_patch
instead of manually doing it. This is probably overkill.

I'm desperately looking for a different approach. Yeah the monkey patching works great,
but it violates the open-closed principal. But I cannot find an appropriate alternative.
Extending the controller and overriding url_for does not work cleanly as the user directly
inherits from Mojolicious::Controller.
Also going the 'better' approach of solving at the root by using an extension of
Mojolicious::Routes::Match->path_for and supplying it to the controller by setting
match does not work as it is on the one hand extremely difficult to inject it in
the first place and the attribute is overwritten in the dispatching process anyways.
One issue when taking the Match approach is that it needs knowledge of the stash
values which can cause cyclic references.

I thought of three approaches injecting the modified Match instance into the class:
1. Extending the Mojolicious::Controller and overriding the new method.
   This has the issue that inheritance is static but one can use Roles that
   are dynamically consumed.
2. Overriding build_controller in Mojolicious. To make this cleanly it needs to be monkey patched
   by the plugin which is exactly what we want to avoid. :(
3. The matcher can be set in a hook relatively early in its lifetime
   and hooks compose well.

A completely different option is to use the router directly and register a global
route that has the language as parameter. But omitting the language leads to problems.

One can use a redirect on root. Very easy but also not very effective.

I am now using a global route containing the language after the changes to
matching have been published. No need to monkey_patch and it works well enough.


Concepts
--------
- Router
- Configuration
- Middleware (auth)
- Controller/Handler
- Templates
- Template helpers
- i18n (url rewriting)
- Sessions (server side)
- Flash, maybe
- Pagination
- Validation
- Logging
- Debug printing
- Development server
- MIME handling


Dependencies
------------
- M & V
  - Mojolicious
  - Config::Tiny
  - Crypt::URandom
- C
  - Mail::Box::Manager
  - Email::MIME
