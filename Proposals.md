Major Proposals for Changes/Features
====================================

New ideas for how to run the TLUG site are always interesting, but for
serious consideration they need to take into account their effect on
site management, maintenance and hosting now and into the future. This
file is for deeper discussions of various options we've used, looked
at or have been proposed.


Database-driven Site
--------------------

From the 1990s until about 2006 the site was static HTML and PHP files
in a directory on some sort of hosting. In late 2006/early 2007
MediaWiki (running over a MySQL database) was added and most new
content was put in the wiki, with old content mostly left in place,
with some new files outside the wiki, such as presentation PDFs and
photos, being added occasionally.

The proposal to move to a static generated site built from a Git repo
offers some huge advantages:
1. Openness: the material needed to (re-)build the full site is
   publicly available.
2. Backup/DR: the openness above also serves as an effective backup
   and offers a clear path to recovering from almost any kind of site
   disaster.
3. Change control: the history of the site and who made changes is
   tracked, and it's easy for any member of the general public to
   propose changes/additions/etc.

To cjs (and perhaps others) the above advantages far overwhelm any
inconvenience introduced by no longer being database-driven (such as
not having or making more difficult immediate online editing of the
site).

That said, if there's significant support for continuing with
MediaWiki or something similar, that's still a path forward. Any
proposal for this should consider the points above and also the points
in the "Alternative Site Builders" section below.

It's also possible to do a mixed-mode site that's mostly
statically-generated but with certain "dynamic" features added,
usually impelemented via Javascript calling external APIs hosted on
other servers (stand-alone servers, AWS Lambda, whatever). Some
hosting services, such as [Netlify], even offer a standard set of
these features for static sites they host.


Alternative Site Builders
-------------------------

There are a zillion different static site builders out there. We
currently use [Hakyll], written in Haskell and built with [Haskell
Stack], becuase cjs suggested it and Jim was interested in the idea.

Any seriously proposed alternative needs to take into account support
and building and hosting.

Support:
- Which TLUG members are stepping up to do (or learn to do) the
  majority of development and maintenance for the forseeable future?
- How much training do people outside of the above need to be able
  to manage and update web site content, and who will provide the
  training and support for them?
- What people not heavily involved in the site maintanence have the
  skills to deal with emergencies when the main maintainers are not
  available.

Building/hosting:
- Where will the site be hosted, what will it cost and who will have
  adminstrative access?
- What/who will build the site, and how will it be deployed from there?
- What facilities are available (especially to non-admins) for staging
  and testing new versions of the site (both content and build process).

#### Discussed Alternatives

* Jim uses [Gatsby], running on Node.js, for some of his sites. This
  seems to have a _lot_ of features, including various built-in
  modules to pull in content from outside the repo and use it to
  generate the site.
* cjs, Steve Turnbull and perhaps other folks in TLUG are professional
  Python programmers. There is a [long list][py-staticsite] of static
  site generators written and extensible in Python.

[Gatsby]: https://www.gatsbyjs.org/
[Hakyll]: https://jaspervdj.be/hakyll/
[Haskell Stack]: https://docs.haskellstack.org/
[py-staticsite]: https://www.fullstackpython.com/static-site-generator.html


Alternate Deployment Options
----------------------------

Some concern has been expressed about the need for developers to do
the site build on their Linux, Windows or Mac development hosts.
People have pointed out that it might be nice to be able to update the
production website via edits done through the GitHub web interface or
some other means usable from a phone.

While currently there hasn't been a strong demand for this, here we
document some options for this.

In all cases below where speed of build is an issue (e.g., the Netlify
thirty minute time limit), one (somewhat drastic) option to work
around this is to drop Hakyll in favor of an interpreted build system
(e.g., Python-, Ruby- or Node.js-based) or one that has more
pre-compiled support (language and/or framwork) from the build option
we choose. This usually brings in its own, different trade-offs, such
slowing down the site compile itself (the most common build case) and
limiting where the site can be built.

### Build Steps

1. Haskell Stack
   - Download: 10 MB. Build: prebuilt binary.
   - Responsible for controlling the rest of the build system, up to
     and including (optionally) the site compiler.
2. GHC (Haskell compiler)
   - Download: >100 MB. Build: prebuilt binary.
3. Hakyll and dependencies.
   - Download: 10s of MB. Build: 10 min.
4. TLUG site compiler (`site.hs`):
   - Build: 5 sec.
5. Compile TLUG site itself
   - Build: 5 sec.
   - Can be run standalone, without Stack or non-system libs.

### Build Options

Overview:
1. Ask someone else to do the build/release.
2. Use an external build service.
3. Use site hosting build service.
4. Use custom application.

#### Ask Someone Else

The person updating the content can commit on a development branch
(optionally submitting a Pull Request) or on the `master` branch and
request someone else do the build. This has the advantage of adding
review of the change by whomever does the build release, but slows the
process by a small or large amount depending on who's available to do
the build/release.

#### External Build Service

Services such as [Circle CI] and [Travis CI] should be capable of
quickly doing a full build when new commits are added to the repo and
are free for "open source" projects. This would be independent of our
hosting option. This hasn't been tested.

[Circle CI]: https://circleci.com/
[Travis CI]: https://docs.travis-ci.com/user/migrate/open-source-on-travis-ci-com/

#### Site Hosting Build Service

__Self-hosted:__ We could set up our own build server, if someone is
willing to supply hosting.

__[GitHub Pages][ghp]__ appears to support only Jekyll (Ruby) builds.

__[Netlify]__ offers pre-installed Ruby, Python, Node.js, Go and Java
interpreters/compilers. Unfortunately they have no pre-installed
support for Haskell Stack or Hakyll, and a full build of Hakyll takes
more than the 30 minute time limit on their build hosts. There are two
workarounds:
1. Build the site compiler and commit it, having Netlify run only
   that. (Tested on the `cjs/190316/site-binary` branch.) It takes
   only a few seconds, but the binary is about 20 MB (causing repo
   bloat over time) and people changing the site compiler itself
   (`stack.hs` or any of its dependencies) must remember to commit the
   new binary.
2. Download a pre-built Hakyll into Netlify's build container cache if
   it's not already there. Significant work has been done on this on
   the `dev/cjs/190313/sastack` branch.

[Netlify]: https://www.netlify.com/
[ghp]: https://help.github.com/pages/

#### Custom Application

Editing markdown on GitHub's web site from a mobile browser isn't a
terribly good experience. It would be relatively simple (for some of
us) to write a small web app that would provide some nice dropdowns to
select date and location etc., making this much easier from mobile; if
we had such a thing that site could also do the build.
