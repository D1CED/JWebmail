JWebmail
========

This is a rewrite of oMail by Oliver Müller <om@omnis.ch>.

oMail has not seen much progress in the last two decades
so my <jannis@fehcom.de> goal is to bring it up to date.

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


v1.0.0 release plan
-------------------
* consider renaming, relicensing
  ✓ License
    ✓ GPLv3+ and enter copyright info
    * Maybe the translation/documentation can be made available under a different
    * may relicense this under the AGPL.
  * Rename
    * jwebmail
* make github ready
  * create base configuration
  * remove sensitive files
  * add git vcs
  ✓ remove part of the english translation
* check legal requirements
* INV: wrong subject being shown
✓ BUG: home not displaying
✓ BUG: empty folder not displaying correctly
✓ better documentation
  ✓ document i18n snippets
  ✓ cleanup comments
  ✓ list functionality for ReadMails#communicate
  ✓ OMail 
  ✓ OMail::Helper
  ✓ OMail::Controller::All
  ✓ OMail::Plugin::I18N
  ✓ OMail::Plugin::INIConfig
  ✓ OMail::Plugin::ServerSideSessionData
  ✓ OMail::Model::WriteMails
  ✓ OMail::Model::ReadMails
  ✓ OMail::Model::Driver::QMailAuthuser
  ✓ OMail::Model::Driver::QMailAuthuser::Extract
✓ better pagination
  ✓ BUG: pagination forward -> backward is shifting by 1 (page start needs to be decremented)
  ✓ move out to helper
  ✓ more generic names
✓ advance ini config plugin
  ✓ set global section to global scope 
  ✓ introduce arrays
  ✓ make nesting sections more explicit
✓ write more tests
  ✓ test pagination
  ✓ test mail_line
  ✓ test for ini parser
  ✓ basic test for application
✓ improve i18n
  ✓ german translation
  ✓ look into i18n configuration
  ✓ remove TXT alias
✓ more configuration (for model)
  ✓ disable cram
  ✓ select mock read model
  ✓ lazy init for mock model
  ✓ add switch disabling message send
  ✓ Extract: user to switch to
  ✓ Extract: adjustable maildir directory
  * separate development and production configuration
✓ read secret from config file
✓ Extract: configurable perl lib
✓ Extract: encoding issues
✓ improve session data security
  ✓ use a server side cookie implementation
  ✓ use a one time pad
  ✓ resolve server/client session duration issues
  ✓ use cryptographically secure random data
  ✓ hide password length
✓ handle empty folders
✓ logging support for Extract.pm
✓ true perl 5.16 support
✓ cpan build and deploy script
✓ remove prefs
✓ file upload for attachment
  ✓ file type detection
  ✓ move WriteMails from Email::Simple to Email::MIME
✓ configuration as plugin (Mojo::Plugin::Config)
✓ model as helpers, initialized in startup
✓ send
  ✓ multiple mails for cc etc.
  * content-transfer encoding, research (currently 8bit)
✓ better design for send and read
  ✓ send 
  ✓ read
✓ sandbox html mails
✓ i18n as ini files
✓ rework mail folders
✓ rewrite about
✓ search in subject


v1.1.0 release plan
-------------------
* improve session data security
  * improve server side session cleanup process coordination
  * add a delete session function for s3d, maybe
* improve i18n
  * add localization of dates and time
* advance ini config plugin
  * BUG: toplevel section cant be an array
  * allow non-leaf nodes to be arrays
  * allow quotes
  * allow continuation over multiple lines
  * warn about overrides
  * add template support, maybe
* repurpose status field in displayheader
* better pagination
  * merge with partial templates, maybe


v1.2.0 release plan
-------------------
* add config validation
* show new messages per folder
* moving mails to other folders
  * creating new folders
  * backend
* click on sender to answer
* mobile optimize
* download mail and attachments
* cleanup css
* allow multiple attachments
* improve performance, consider alternatives to Extract.pm
  * based on Maildir::Light
* add more mime types
  * jpeg
  * png
  * giv
* consider using more mojo functions
  * base64
  * encoding
  * json
  * filepaths
  * dump
  * Mojolicious::Types
  * mail?
* consider using Crypt::URandom instead of Crypt::Random
* improve session data security
* add mails to Sent folder


v1.3.0 release plan
-------------------
* smtp send model, maybe
* pop read model, maybe
* add icons for navigation


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
  - Digest::HMAC_MD5 (optional)
  - File::Type
  - Crypt::Random
- C
  - Mail::Box::Manager
  - Email::MIME