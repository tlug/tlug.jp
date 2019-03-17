tlug.jp: Tokyo Linux Users Group Website
========================================

This is an experimental work in progress for one possible new version
of <https://tlug.jp>, the Tokyo Linux Users group website. It's a
fully static site generated using [Hakyll], intended to be deployed to
a CDN such as [Netlify]. It's possible to add dynamic elements by having
JS call an API on another server.

The current developers/maintainers are Curt Sampson (`@0cjs`)
<cjs@cynic.net> and Jim Tittsler (`@jimt`) <jimt@onjapan.net>.

### Discussion Forums

For real-time chat, [TLUG Gitter room] can be read on the web without
authentication; posting messages requires authentication with a
GitHub, GitLab or Twitter account.

There is also the [TLUG mailing list], with [archives] on the web.

### Site Organization and Future Development

See the [ORGANIZATION.md](ORGANIZATION.md) file for information on the
current organization of the site, organization of the previous site(s)
and ideas for where to move forward from here. See also
[PROPOSALS](PROPOSALS.md) for discussion of random ideas that we could
implement.


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
       stack exec site build

3. Run tests (of which we currently have none).

Hakyll also includes a preview server that will serve the
locally-built site and rebuild it when the source files change:

    stack exec site watch -- --host HOST --port PORT

`--host` and `--port` are optional. The server will not automatically
load or refresh pages in your browser when the site changes.


Staging Deployment
------------------

Staging deployments of local builds can currently be done to any
system that can serve the files on the `gh-pages` branch of a copy of
this repo, including [GithHub Pages][ghp] (on `github.io`) and
[Netlify].

If you have a local `gh-pages` branch in your repo (usually created
with `git checkout gh-pages`), you can pass the `--branch-release`
option to `Test` to do a new build and commit it to that branch. You
must not have any uncommitted changes on the current (source) branch
when doing this. You can then push your source and build branches with
`git push --all`. (Consider adding `--dry-run` to test this.)

If you're doing staging deployments of the [master repo], please
ensure you co-ordinate with the other developers using that repo,
since everyone will be sharing that `gh-pages` branch. It's usually
better to do staging deployments using your own fork repo.

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

There is currently no production deployment system, since this is an
experimental version of the TLUG site. However, it's intended that in
the future the "master" version of the site code from which the
production version is deployed will be the version of this repo stored
at <https://github.com/tlug/tlug.jp>.



<!-------------------------------------------------------------------->
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
