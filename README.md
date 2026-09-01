Tokyo Linux Users Group Website
===============================

This repository contains the source for [tlug.jp], a static site built with
[Hugo].

Development
-----------

Install [Hugo] (extended edition, see `HUGO_VERSION` in [`netlify.toml`] for
the version used in production), then:

    hugo server        # local preview at http://localhost:1313/
    hugo               # production build into public/

Layout:

- `content/en/`, `content/ja/` — page content (Markdown). The site is
  multilingual; add a file at the same path under `content/ja/` to translate
  a page.
- `data/locations.yaml` — the venue registry for meeting pages.
- `data/links.yaml` — community/social links (footer icons and homepage
  buttons; icons live in `assets/icons/`, from [Simple Icons]).
- `layouts/` — hand-written templates, no theme.
- `assets/css/style.css` — the stylesheet.
- `i18n/` — translated UI strings.
- `static/` — files copied verbatim (images, etc.).

Meetings
--------

Meeting pages live in `content/en/meetings/`, one file per meeting, named
`YYYY-MM-DD-slug.md` (e.g. `2026-09-05-technical-meeting.md`). The `date` in
the frontmatter is the **event** date/time; meetings with a future date are
automatically listed under "Upcoming Events" on the homepage (this is why
`buildFuture = true` is set in `hugo.toml`).

Frontmatter parameters:

    ---
    title: Technical Meeting        # or Nomikai, Software Freedom Day, ...
    date: 2026-07-11T13:00:00+09:00 # event start
    params:
      meetingType: technical        # or nomikai
      time: "13:00–16:00"           # human-readable time range
      location: axsh                # key into data/locations.yaml
      registration: https://...    # connpass event (optional)
      registrationName: Connpass   # optional label override; auto-detected
                                   # from the URL otherwise
      cfp: false                    # optional; see below
    ---

A "Call for Presenters — open" notice is shown automatically on future
technical meetings (never on past ones or nomikai). Set `cfp: false` to turn
it off for a meeting whose program is already full.

Venues are defined once in [`data/locations.yaml`] (name, address, map
links, website) and referenced by key. For a one-off venue, skip the
registry and inline the details instead:

      location: |-                  # first line = venue name
        Some Event Space
        1-2-3 Somewhere
        Chiyoda-ku, Tokyo
      locationApple: https://...    # optional map/venue links
      locationGoogle: https://...
      venue: https://...

To announce a new meeting, copy the most recent similar meeting page, update
the frontmatter and body, and push. No other changes are needed.

Deployment
----------

The site is deployed by [Netlify] from the `main` branch: every push to
`main` triggers `hugo --gc --minify` (see [`netlify.toml`]). Redirects from
old `/wiki/*` URLs are also configured there.


[Hugo]: https://gohugo.io/
[Netlify]: https://www.netlify.com/
[pandoc]: https://pandoc.org/
[Simple Icons]: https://simpleicons.org/
[tlug.jp]: https://tlug.jp/
[`data/locations.yaml`]: ./data/locations.yaml
[`netlify.toml`]: ./netlify.toml
