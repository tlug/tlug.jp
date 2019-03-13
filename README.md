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
this repo, including [GithHub Pages] \(on `github.io`) and [Netlify].

If you have a local `gh-pages` branch in your repo (usually created
with `git checkout gh-pages`), you can pass the `-B` option to `Test`
to do a new build and commit it to that branch. You must not have any
uncommitted changes on the current (source) branch when doing this.
You can then push your source and build branches with `git push
--all`. (Consider adding `--dry-run` to test this.)

If you're doing staging deployments of the [master repo], please
ensure you co-ordinate with the other developers using that repo,
since everyone will be sharing that `gh-pages` branch. It's usually
better to do staging deployments using your own fork repo.

#### GitHub Pages Deployment

<https://tlug.github.io/tlug.jp/> is a deployment of the `gh-pages`
branch from the [master repo], and is updated automatically with new
pushes to that branch.

Anybody with a fork of the repo can also deploy to GitHub pages in
the same way; see the [GitHub Pages] documentation for details.

#### Netlify

There is currently work in progress to do staging deployments on
[Netlify]. We don't have a shared organization account on Netlify
because they seem to offer only paid options for that at the moment,
but we do have staging URLs set up under personal accounts:

- <https://tlug.netlify.com> using Jim's Netlify account.
- <https://cjs-tlug.netlify.com>> using cjs's Netlify account.

### Non-local Builds

[Netlify] and other services can build and deploy the site from
source, rather than serving a pre-built `gh-pages` branch.
Unfortunately the current build doesn't work for that because the
initial build exceeds the 30-minute Netlify build robot timeout; work
on this is in progress.


Production Deployment
---------------------

There is currently no production deployment system, since this is an
experimental version of the TLUG site. However, it's intended that in
the future the "master" version of the site code from which the
production version is deployed will be the version of this repo stored
at <https://github.com/tlug/tlug.jp>.



<!-------------------------------------------------------------------->
[GithHub Pages]: https://help.github.com/categories/github-pages-basics/
[Hakyll]: https://jaspervdj.be/hakyll/
[Haskell Stack]: https://docs.haskellstack.org/
[Netlify]: https://www.netlify.com/
[TLUG Gitter room]: https://gitter.im/tlug/tlug
[TLUG mailing list]: https://lists.tlug.jp/list.html
[archives]: https://lists.tlug.jp/ML/index.html
[master repo]: https://github.com/tlug/tlug.jp
