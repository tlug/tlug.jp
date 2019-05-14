Hosting for this Website
========================

> For information on how to release a new version of the website, see the
> ["Production Deployment"][deployment] section of the `README` file at the
> top level of this repo.

Current Status
--------------

Currently, <http://tlug.jp> and <http://www.tlug.jp> are still being served
by the old server (`akari`) supplied by Asahi-Net. When the switch to the
new hosting is done, it will be configured as follows.


Contacting Site Administrators
------------------------------

Send a message to the [TLUG mailing list] or try the [TLUG Gitter room].


Release Branch
--------------

Currently we always compile the web site locally on a developer machine and
commit the compiled website to a release branch. For the `master` branch
code this is `gh-pages` (used for compatibility with [GitHub Pages][ghp],
should we wish to experiment with that) and for the developer branches it's
the developer branch name with `-release` appended. The procedure for
building recompiling the site and deloying the release to a branch is
discussed in the [README](../README.md).

We've considered having the site be rebuilt from source by an external
server after each commit to the `master` branch, but there are certain
technical difficulties with that which are discussed in `proposals.md`
section ["Alternate Deployment Options"][alt-deploy].


Netlify Hosting
---------------

We use [Netlify] for our hosting mainly because it's free and it allows us
to configure (in [`/docroot/netlify.toml`][netlify.toml]) the `/wiki` path
to serve files without extensions as `text/html`. This lets us maintain the
same `/wiki/...` links as the old MediaWiki site uses.

The following Netlify documentation pages may be useful:
- [Netlify Documentation Home][nfd]
- [GitHub Permissions][nfd-githubperms]
- [`netlify.toml` Reference][nfd-toml] for the Netlify configuration file.
- [Headers][nfd-headers]

### Netlify GitHub App

> NOTE: The exact workings of the Netlify GitHub App have not been
> completely confirmed; this information may need to be corrected.

The [Netlify GitHub app][github/apps/netlify] is what allows Netlify
to gain access to read repos and update status on GitHub. This is
installed and configured separately for each GitHub account or
organization and the installation status or settings for one
account/org cannot affect any other account/org. The app can be
configured (in the settings for that GitHub account/org) to allow
Netlify to read all repos or just selected ones. Uninstalling the app
will remove all access to repos owned by that account/org.

Installation and mangement of the app is done by using any GitHub
account that has admin access to the account/org that owns the repos.
There is no connection between the GitHub account you use to do these
management actions and the accounts/orgs to which Netlify is given
access when configuring a Netlify site. In particular this means that,
__even though you log in to GitHub with your account when configuring
a Netlify site, Netlify will not gain access to any repos outside of
the `tlug` org, whether in your account or other orgs,__ unless you
explicitly install the app in your account or other orgs. (Of course,
if someone else has already installed the app in other accounts/orgs,
Netlify will already have read access to the configured repos.)

The Netlify app has been installed for the `tlug` organization on GitHub;
this is administered via the [`tlug` Netlify App settings
page][github/tlug/settings/installations/netlify] reachable from the
[`tlug` settings page][github/tlug/settings] on the [Installed GitHub
Apps][github/tlug/settings/installations] tab.

The app always has the following access to any repos for which it's
enabled; this cannot be changed:
- Read access to code.
- Read access to metadata.
- Read and write access to checks, commit statues and pull requests.

The app is currently configured to have the above access to all repos
(public and private) in the GitHub `tlug` organization; if necessary access
can be restricted (using the admin pages above) to specific repos. However,
even with the app having access to all repos, users will not be able to
configure Netlify sites for any accounts they can't personally see with
their own GitHub accounts.

To configure a new site on the Netlify `tlug-admin` account:
1. Log out of any Netlify account you're currently using and log in to the
   `tlug-admin` Netlify account.
2. When setting up the new site you will be prompted to link it to a
   repository. Choose the "GitHub" button and you will be prompted to log
   into GitHub, which you do with your personal account. (This will not
   grant Netlify access to repos in your personal account unless you
   specifically enable that; see above.)
3. At the repo selection screen there will be a dropdown allowing you to
   select the GitHub account or organization whose repos you want to look
   at; choose `tlug` here.
4. Choose the appropriate repo and it will be used for that site.
5. Log out of the `tlug-admin` account.

### Netlify Account

Because only paid ($45/month) Netlify plans offer the ability to let
multiple Netlify accounts manage a site, we use a separate Netlify free
account, here called `tlug-admin`, to host the site, with the password
shared amongst the admins. For details on access to this, contact one of
the following people:
- Edward Middleton (`@emiddleton`) <mailto:edward.middleton@vortorus.net>
- Curt Sampson (`@0cjs`) <mailto:cjs@cynic.net>

### Netlify Site

In the shared Netlify account above, the `tlug-jp` site, which is labeled
`www.tlug.jp` in the master site list, is our production site.
- Admin URL: <https://app.netlify.com/sites/tlug-jp>
- Site ID: `fc766593-520c-4f3d-89a2-20809ffffcab`
- Test URL: <https://tlug-jp.netlify.com>

#### Domain Names

The [`tlug-jp` domain configuration][domconfig-tlug] on the Netlify is set
up to serve the following domain names:
- <http://www.tlug.jp>: Primary domain serving the site content.
- <http://tlug.jp>: Redirects automatically to the primary domain.
- <http://new.tlug.jp>: Domain alias for testing.
- <https://tlug-jp.netlify.com>: "Default subdomain"; Netlify serves the
  site on this as well as the domain names above this cannot be disabled.
  (It also serves as the target for the real domain's `CNAME` record.)

Note that the `tlug.jp` URLs are not yet HTTPS. Netlify can automatically
configure Let's Encrypt certificates for those, but only when they are
already pointing to Netlify.

The following steps, described in more detail in Netlify's [custom
domain][nfd-domains] documentation, still need to be done:
1. __Immediately:__
   - Configure `new.tlug.jp` as a `CNAME` to `tlug-jp.netlify.com`.
   - This will allow us to test the service on a custom domain name and
     configure an HTTPS certificate to test that.
2. __When changing over the production site:__
   - Configure `www.tlug.jp` as a `CNAME` to `tlug-jp.netlify.com`.
   - Change the `tlug.jp` `A` record to `104.198.14.52`, the address of
     Netlify's load balancer. (We may actually be able to do this before
     the production changeover to have the `tlug.jp` start redirecting to
     the old `www` earlier.)
3. __Later__: Remove `new.tlug.jp` after the new production site is
   confirmed to be running ok.

#### A Note on Handling the Root Domain

On the previous site we had both `tlug.jp` and `www.tlug.jp` separately
serving the full site content, rather than having a canonical version to
which the other redirected. Netlify does not recommend doing this, instead
suggesting that the root domain redirects to the `www` subdomain, and we
follow that recommendation for two reasons:

1. Better speed and reliability as described in Netlify's [Custom
   Domains][nfd-domains] documentation. The `www` subdomain uses a CNAME
   record pointing to Netlify, which serves different results based on the
   current CDN server configuraiton and the requester's location. However,
   we must use an `A` record for the root domain meaning that all requests
   to that will always terminate on a specific load balancer, reducing
   speed and reliability.

2. Search engine optimization: serving the same content from two different
   domain names (`tlug.jp` and `www.tlug.jp`) spreads external links to the
   site across the new names, reducing the "popularity" of each individual
   name, and search engines also tend to discount content served from
   multiple domain names because this is a technique used by domain
   squatters.



<!-------------------------------------------------------------------->
[TLUG Gitter room]: https://gitter.im/tlug/tlug
[TLUG mailing list]: https://lists.tlug.jp/list.html
[alt-deploy]: proposals.md#alternate-deployment-options
[deployment]: ../README.md#production-deployment
[domconfig-tlug]: https://app.netlify.com/sites/tlug-jp/settings/domain#custom-domains
[gh-depkey]: https://github.com/tlug/tlug.jp/settings/keys
[ghp-projectpg]: https://help.github.com/en/articles/user-organization-and-project-pages#project-pages-sites
[ghp-pubconfig]: https://help.github.com/en/articles/configuring-a-publishing-source-for-github-pages
[ghp]: https://help.github.com/pages/
[github pages]: https://pages.github.com/
[github/tlug/settings/installations/netlify]: https://github.com/organizations/tlug/settings/installations/735931
[github/tlug/settings/installations]: https://github.com/organizations/tlug/settings/installations
[github/tlug/settings]: https://github.com/organizations/tlug/settings/profile
[github/apps/netlify]: https://github.com/apps/netlify
[master repo]: https://github.com/tlug/tlug.jp
[netlify.toml]: ../docroot/netlify.toml
[netlify]: https://www.netlify.com/
[nfd-domains]: https://www.netlify.com/docs/custom-domains/
[nfd-githubperms]: https://www.netlify.com/docs/github-permissions/
[nfd-headers]: https://www.netlify.com/docs/headers-and-basic-auth/
[nfd-redirects]: https://www.netlify.com/docs/redirects/
[nfd-toml]: https://www.netlify.com/docs/netlify-toml-reference/
[nfd]: https://www.netlify.com/docs/
