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
- [`netlify.toml` Reference][nfd-toml] for the Netlify configuration file.
- [Headers][nfd-headers]

### Netlify Account

Because only paid ($45/month) Netlify plans offer the ability to let
multiple Netlify accounts manage a site, we use a separate Netlify free
account to host the site, with the password shared amongst the admins. For
details on access to this, contact one of the following people:
- Edward Middleton (`@emiddleton`) <mailto:edward.middleton@vortorus.net>
- Curt Sampson (`@0cjs`) <mailto:cjs@cynic.net>

### Netlify Site

The Netlify site in the shared account above is `tlug-jp`:
- Admin URL: <https://app.netlify.com/sites/tlug-jp>
- Site ID: `fc766593-520c-4f3d-89a2-20809ffffcab`
- Test URL: <https://tlug-jp.netlify.com>

To avoid similarly having to set up a shared GitHub account, Netlify is
configured to read the the repo using plain SSH and the [master repo] is
[configured with Netlify's deploy key][gh-depkey] giving read-only access.

However, at this point Netlify seems unable to pull the repo from GitHub;
we don't even see a use of the configured deploy key. Curt has submitted a
support request (as of 2019-05-12 evening) to Netlify about this.

### Domain Names

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
[master repo]: https://github.com/tlug/tlug.jp
[netlify.toml]: ../docroot/netlify.toml
[netlify]: https://www.netlify.com/
[nfd-domains]: https://www.netlify.com/docs/custom-domains/
[nfd-headers]: https://www.netlify.com/docs/headers-and-basic-auth/
[nfd-redirects]: https://www.netlify.com/docs/redirects/
[nfd-toml]: https://www.netlify.com/docs/netlify-toml-reference/
[nfd]: https://www.netlify.com/docs/
