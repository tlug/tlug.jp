tlug.jp: Tokyo Linux Users Group Website
========================================

This is an experimental work in progress for one possible new version
of <https://tlug.jp>, the Tokyo Linux Users Group website. It's a
fully static site generated using [Hakyll], intended to be deployed to
a CDN such as [Netlify]. It's possible to add dynamic elements by having
JS call an API on another server.

The current developers/maintainers are:
- Curt Sampson ([`@0cjs`]) <cjs@cynic.net>
- Jim Tittsler ([`@jimt`]) <jimt@onjapan.net>
- [`@sssjjjnnn`]

### Discussion Forums

* [TLUG Gitter room]. Web or desktop/mobile app. Read without
  authentication; GitHub/GitLab/Twitter authentication needed to post.
  Full history visible to all. Private channels also available.
* `irc:chat.freenode.net/#tlug.jp`. No history (?).
* [TLUG mailing list]. [Archives] on the web.

### Site Organization and Future Development

Documentation related to this site is stored in various files under
the [`doc/`](doc/) directory. In order of importance, these include:

- [`ORGANIZATION`](doc/ORGANIZATION.md): Information on the current
  organization of the site, organization of the previous site(s) and
  ideas for where to move forward from here.
- [`proposals`](doc/proposals.md): Discussion of random ideas that we
  could implement.
- [`hakyll`](doc/hakyll.md): Information about hacking on the site
  compiler itself (`app/SiteCompiler.hs`). You can safely skip this if
  you're working only on site content.


Building
--------

The top-level `Test` script (usually run with the command `./Test`)
does a build, test and optional release. The steps it performs are:

1. Install/update [Haskell Stack] if necessary. Stack will be
   installed to `~/.local/bin/`, but if it requires OS package
   dependencies that you don't have installed on your system you may
   be required to respond to a sudo password prompt for the package
   installer. This can also be done manually with:

       #    Install Stack
       curl -sSL https://get.haskellstack.org/ | sh
       wget -qO- https://get.haskellstack.org/ | sh
       #    Update existing Stack version
       stack upgrade

2. Build Hakyll if necessary (this can take some time) and build the
   site into the `_site/` directory. This can also be done manually
   with:

       stack build --test
       stack exec site-compiler build

3. Run tests (of which we currently have none).

Hakyll also includes a preview server that will serve the
locally-built site and rebuild it when the source files change:

    stack exec site-compiler watch -- --host HOST --port PORT

`--host` and `--port` are optional. The server will not automatically
load or refresh pages in your browser when the site changes.


Staging Deployment
------------------

Staging deployments of local builds can currently be done to any
system that can serve the files on the `gh-pages` branch of a copy of
this repo, including [GithHub Pages][ghp] (on `github.io`) and
[Netlify].

Running `./Test --dev-release` will compile the site and commit a copy
to a branch named for the current branch with `-release` appended. You
must be on a branch starting with `dev/` (e.g., `dev/cjs/my-changes`)
and your working tree must be completely clean, with no uncommited
changes, and no untracked files. (`git stash --all` can help with
this.)

When complete, the `Test` script will print out the command to use to
push up your release branch; configure Netlify to serve this branch
and you're set.

#### GitHub Pages Deployment

<https://tlug.github.io/tlug.jp/> is a deployment of the `gh-pages`
branch from the [master repo], and is updated automatically with new
pushes to that branch.

Anybody with a fork of the repo can also deploy to [GitHub Pages][ghp]
in the same way. [The documentation][ghp] has full details, but is
missing a few important points.

First, remember that even if your repo is private, the GitHub Pages
deployed from that repo is fully public and anybody can fetch any
contents from the `gh-pages` branch if they know the name.
Additionally, some pages may continue to be served even after the repo
has been deleted.

After you fork the repo it may appear already to be configured for
deployment under a [project pages][ghp-projectpg] URL, but it isn't.
As per the documentation on [configuring a publishing
source][ghp-pubconfig] you should go to "Settings", ensure "Options"
is selected at the left, and scroll down to the "GitHub Pages"
section.

The "Source" dropdown already says "gh-pages branch", but this seems
to be the case even when it's not configured; you need to drop down
the menu and select "gh-pages branch" (again) anyway. This should
automatically save and you should then see a message at the top of
that section saying "Your site is ready to be published at
<http://USER.github.io/tlug.jp>>, where `USER` is your GitHub user name.

You then need to commit something to the `gh-pages` branch to trigger
deployment of the site; the easiest way to do this is to select the
branch from the drop-down at the main page for the site (i.e., taking
you to <https://github.com/USER/tlug.jp/tree/gh-pages>) and use the
"Create new file" button to add an empty file with any name,
committing it directly to the `gh-pages` branch to triger deployment.

#### Netlify

There is currently work in progress to do staging deployments on
[Netlify]. We don't have a shared organization account on Netlify
because they seem to offer only paid options for that at the moment,
but we do have staging URLs set up under personal accounts:

- <https://tlug.netlify.com> using Jim's Netlify account.
- <https://cjs-tlug.netlify.com>> using cjs's Netlify account.

### Non-local Builds/Build Servers

Some proof-of-concept work has been done on this. See
[PROPOSALS](PROPOSALS.md) for more details.


Production Deployment
---------------------

Production deployment is done by commiting the compiled site to the
`gh-pages` branch. Run `./Test --prod-release` to compile the site and
commit the compiled code to that branch. (You must be on `master`
branch to do this, and you must have a completely clean working copy,
i.e., no modified files and no untracked files.)

Once this is done you can push the branch up with `git push origin
gh-pages` and Netlify will automatically pick up the changes and
start serving them.



<!-------------------------------------------------------------------->
[`@0cjs`]: https://github.com/0cjs
[`@jimt`]: https://github.com/jimt
[`@sssjjjnnn`]: https://github.com/sssjjjnnn

[TLUG Gitter room]: https://gitter.im/tlug/tlug
[TLUG mailing list]: https://lists.tlug.jp/list.html
[archives]: https://lists.tlug.jp/ML/index.html
[master repo]: https://github.com/tlug/tlug.jp

[Hakyll]: https://jaspervdj.be/hakyll/
[Haskell Stack]: https://docs.haskellstack.org/

[Netlify]: https://www.netlify.com/
[ghp-projectpg]: https://help.github.com/en/articles/user-organization-and-project-pages#project-pages-sites
[ghp-pubconfig]: https://help.github.com/en/articles/configuring-a-publishing-source-for-github-pages
[ghp]: https://help.github.com/pages/
