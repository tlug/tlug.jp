TLUG Site Organization
======================

New Design
----------

See the following sections for an overview of the directories and
files in this repository.

### To-do Ideas

- Get missing parts of old site dump added to [akari.tlug.jp]:
  - MediaWiki source markup from database.
  - List archives.
- Work out details of `tlug.jp` → `www.tlug.jp` redirect (see below).
- Look through the current site logs for incoming deep links that we should
  consider maintaining.
- Sort out what CSS is used by which parts of the old site (in particular
  the top page and MediaWiki pages), and consolidate this into a single CSS
  file or set of files used everywhere in the new site.
- Consider creating a "historical curiousities" area of the site to dump
  old content without too much reformatting work.


Repository Organization
-----------------------

The repository contains the following directories and files:
- `*.md`: Documentation, such as `README.md` and this document.
- `Test`: A script that builds and tests everything and compiles the site.
- `bin/`: Tools used as part of the build and/or deploy process.
- `app/`, `src/`: Haskell source code and tests for the site compiler.
  - `src/` is code shared amongst all programs we build
  - `app/SiteCompiler.hs` is the main module for `site-compiler`.
  - `app/Test.hs` is the main module for the unit test runner.
- `docroot/`: Static files copied directly to the compiled site.
- `example/`: Files for the example blog site for Hakyll.
- `wiki/`: MediaWiki markup source for pages from the old wiki.
- `stack.yaml`: Haskell Stack configuration.
- `tlug-website.cabal`: Build configuration for this project.

In addition, the following will appear as part of the build process:
- `_site/`: The output directory for the compiled site.
- `_cache/`: Cached information to speed the site compiler.
- `.stack-work/`: Haskell Stack's output dir for programs, object files, etc.
- `.HTF/`: Cache for the Haskell Test Framework.

The `docroot/` currently contains only a bit of content copied from
the old site, enough to display the home page.

The `wiki/` directory is currently empty, but has some pages on
development branches where we're working on the code to render them.


Previous Site(s)
----------------

Dumps of the previous site content from various sources and in various
forms are in the (private) [akari.tlug.jp] repo. Request access from
@jimt.

Our old system runs on two servers:
- `akari.tlug.jp`(`202.224.46.215`): Running the `tlug.jp` website
  with static content and MediaWiki.
- `kirakira.tlug.jp` (`202.224.46.216`) for `lists.tlug.jp`, running
  the Mailman web interface and serving the mail archives.

Sources of information include:
- [Special:Version] gives version information for our server software.
  It's all circa 2006: MediaWiki 1.8.2, PHP 5.1.6 and MySQL 5.0.95-log.
- [TlugAdmin:StartPage] links to various admin-related information.

### Akari Static Assets ("docroot")

The docroot for `akari` contains the code for the current site and
several older versions of the site, as well as various backup copies
of pages and other content. Most of the older content can still be
served (e.g., [`/meeting.php`]), other pages are intercepted by
redirects in the Apache configuration (e.g., [`/meetings.php`]).
We need to go through all of this and figure out what parts we want
to migrate to the new site.

Following are the components we've currently identified. For content
in the wiki, [Special:Allpages] and [Special:Specialpages] are
probably helpful here.

- Top pages (Japanese and English):
  - `/index.html`, `/index.jp.html`
  - Images etc. associated with the top pages
- Static CSS and JavaScript
  - Need to check what is used by static site and what by Wiki
- Meeting information:
  - Wiki pages
  - Wiki templates included in Wiki Pages (e.g., meeting locations)
  - Additional static content files (images, presentation slides,
    etc.) under `/meetings/`.
- Non-meeting Wiki Pages
  - User pages
- Old site content that is still linked, e.g., `/docs.php`.
- Other Static Content?


Multilingual Support
--------------------

By "alternative multilingual content" below we mean additional pages
served under different URLs that contain translations of the English
version of that page.

The Wiki has no special support for alternative multilingual content;
in the few areas where we use Japanese we simply put it on the same
page, e.g., [Meetings:Locations:Yoga:Sun].

To handle the very limited amount of alternative multilingual content
on the static parts of the old site, Apache is configured to serve
pages with a final language code extension with a MIME type of the
preceeding component, e.g., `introduction.html.en` and
`introduction.html.jp`. There's no special redirect code otherwise:
`introduction.html` doesn't exist and will return a 404.

For the new site's top page have reversed the convention above (using
`index.html` and `index.jp.html`) to avoid having to configure hosting
providers to use the old site's convention. (It's not clear whether
all hosting providers could even support `akari`'s convention.) As
well, the site generator could be programmed to generate files under
different names from the source files.

Most or all of the static alternative multilingual content is unlinked
and probably no longer needed. Moving forward it's probably easiest to
take the Wiki course of putting all language content on a single page,
perhaps with a few exceptions where there's a particularly large
amount of content.


Site Names/URLs
---------------

Currently `tlug.jp` and `www.tlug.jp` are both serving the same site. For
reasons to be explained later by cjs (if anybody needs them), `tlug.jp`
should only issue redirects to `www.tlug.jp`.



<!-------------------------------------------------------------------->
[Meetings:Locations:Yoga:Sun]: http://www.tlug.jp/wiki/Meetings:Locations:Yoga:Sun
[Special:Allpages]: http://tlug.jp/wiki/Special:Allpages
[Special:Specialpages]: http://tlug.jp/wiki/Special:Specialpages
[Special:Version]: http://tlug.jp/wiki/Special:Version
[TlugAdmin:StartPage]: http://tlug.jp/wiki/TlugAdmin:StartPage
[`/meeting.php`]: https://www.tlug.jp/meeting.php
[`/meetings.php`]: https://www.tlug.jp/meetings.php
[akari.tlug.jp]: https://github.com/jimt/akari.tlug.jp
