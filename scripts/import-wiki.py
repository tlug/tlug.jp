#!/usr/bin/env python3
"""Import the historical MediaWiki meeting pages into Hugo page bundles.

The pre-Hugo site kept each meeting as a flat MediaWiki file under `wiki/`
on the `master` branch. This script converts those pages, spanning four
generations of page format between 1994 and 2026, into
`content/en/meetings/<YYYY-MM-DD-slug>/index.md` bundles and collects the
venues they reference into `data/locations.yaml`.

Usage:
    scripts/import-wiki.py [--dry-run] [--only PAGE ...]

Requires `pandoc` on PATH for the MediaWiki to Markdown conversion.

What it extracts
----------------
date        `{{Meetings:Vitals|date=...}}`, a prose date matching the page's
            own year and month, or a day named in a section heading
            ("What happened on 10th of September?"). Failing all of that the
            first of the month is used and `dateApprox: true` is set so
            templates render "September 1994" rather than inventing a day.
endDate     parsed from a `time=` parameter or a "Time" section.
location    a key into data/locations.yaml, resolved from
            `{{Meetings:Locations:Ward:Venue}}` or a Vitals `location=`.
schedule    talks parsed out of the `Meetings:Itinerary:Tech:YYYYMM`
            templates, with presenter and abstract.

Privacy
-------
Meetings:Contacts* templates, personal mobile numbers (090/080/070) and
email addresses are stripped. Venue landlines are kept, as they belong to
businesses rather than people.
"""

from __future__ import annotations

import argparse
import os

import re
import subprocess
import sys
import unicodedata
from dataclasses import dataclass, field
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
WIKI = Path(os.environ.get("TLUG_WIKI_SRC", "/tmp/opencode/wikisrc/wiki"))
OUT = REPO / "content" / "en" / "meetings"
LOCATIONS = REPO / "data" / "locations.yaml"
PANDOC = os.environ.get("PANDOC", "pandoc")

# Pages already present as hand-maintained content, or deliberately removed.
SKIP_PAGES = {
    "Meetings:2025:06",
    "Meetings:2025:07",
    "Meetings:2025:08",
    "Meetings:2025:09",
    "Meetings:2026:07",
}

# Special (non YYYY:MM) pages worth importing, with their slug.
SPECIAL_PAGES = {
    "Meetings:15th_Anniversary_Event": "15th-anniversary-event",
    "Meetings:20th_Anniversary_Party": "20th-anniversary-party",
    "Meetings:Tech_Holiday_Party_09": "tech-holiday-party",
}

# Venue template names that duplicate venues already in data/locations.yaml.
LOCATION_ALIASES = {
    "shibuya-axsh": "axsh",
    "daikanyama-zest-cantina": "zest-cantina-daikanyama",
}

MONTHS = [
    "january", "february", "march", "april", "may", "june",
    "july", "august", "september", "october", "november", "december",
]
MONTH_NUM = {m: i + 1 for i, m in enumerate(MONTHS)}
for _i, _m in enumerate(MONTHS):
    MONTH_NUM[_m[:3]] = _i + 1
MONTH_NUM["sept"] = 9
MONTH_RE = "|".join(sorted(MONTH_NUM, key=len, reverse=True))

RE_MONTH_DAY = re.compile(
    rf"\b({MONTH_RE})\.?\s+(\d{{1,2}})(?:st|nd|rd|th)?\b", re.I)
RE_DAY_MONTH = re.compile(
    rf"\b(\d{{1,2}})(?:st|nd|rd|th)?\s+(?:of\s+)?({MONTH_RE})\b", re.I)
RE_TIME_RANGE = re.compile(r"(\d{1,2}):(\d{2})\s*[-–~]\s*(\d{1,2}):(\d{2})")
RE_TIME_START = re.compile(r"\b(\d{1,2}):(\d{2})\b")

# Link labels and stray lines that are navigation, not venue information.
RE_NAV = re.compile(r"^(?:google|apple|yahoo)?\s*"
                    r"(details?|maps?|info(rmation)?|web\s?site|home\s?page|"
                    r"venue|directions?|photos?|access|japanese|english)\b"
                    r"[\s\w/(),.&+|-]{0,40}$", re.I)

RE_MOBILE = re.compile(r"\b0[789]0[-\s]?\d{4}[-\s]?\d{4}\b")
RE_EMAIL = re.compile(r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b")
RE_CONNPASS = re.compile(
    r"https?://(?:tlug\.)?(?:connpass\.com|doorkeeper\.jp)[^\s\]|}>]*")


def slugify(text: str) -> str:
    text = unicodedata.normalize("NFKD", text)
    text = text.encode("ascii", "ignore").decode()
    text = re.sub(r"[^A-Za-z0-9]+", "-", text).strip("-").lower()
    return re.sub(r"-{2,}", "-", text)


def read_page(name: str) -> str | None:
    path = WIKI / name
    if not path.exists():
        return None
    return path.read_text(encoding="utf-8", errors="replace")


# --------------------------------------------------------------------------
# template parsing

def find_templates(src: str, prefix: str) -> list[tuple[str, dict[str, str]]]:
    """Return (name, params) for each {{prefix...}} transclusion."""
    out = []
    for m in re.finditer(r"\{\{\s*(" + re.escape(prefix) + r"[^|}]*)((?:\|[^{}]*)?)\}\}",
                         src, re.S):
        name = m.group(1).strip()
        params: dict[str, str] = {}
        for part in m.group(2).split("|")[1:]:
            if "=" in part:
                k, v = part.split("=", 1)
                params[k.strip()] = v.strip()
        out.append((name, params))
    return out


def strip_templates(src: str) -> str:
    """Remove every transclusion; their content is handled separately."""
    prev = None
    while prev != src:
        prev = src
        src = re.sub(r"\{\{[^{}]*\}\}", "", src, flags=re.S)
    return src


# --------------------------------------------------------------------------
# field extraction

def section_text(src: str, heading: str) -> str | None:
    m = re.search(rf"^=+\s*{heading}\s*=+\s*$(.*?)(?=^=|\Z)",
                  src, re.M | re.S | re.I)
    return m.group(1).strip() if m else None


def primary_scope(src: str) -> str:
    """The part of the page describing the event we are importing. On pages
    that also cover a cancelled or secondary event this keeps the date and
    venue from being taken from the wrong one."""
    live = [s for s in live_sections(src) if s["kind"]]
    if len(live) == 1:
        return live[0]["heading"] + "\n" + live[0]["body"]
    for s in live:
        if s["kind"] == "technical":
            return s["heading"] + "\n" + s["body"]
    return src


def extract_date(src: str, year: int, month: int) -> tuple[str | None, bool]:
    """Return (YYYY-MM-DD, approximate?)."""
    candidates: list[str] = []

    for _n, params in find_templates(src, "Meetings:"):
        if "date" in params:
            candidates.append(params["date"])

    for label in ("Date", "Dates"):
        s = section_text(src, label)
        if s:
            candidates.append(s)

    candidates += definition_block(src).get("date", [])
    candidates.append(src)

    def fuzzy_month(word: str) -> int | None:
        import difflib
        hit = difflib.get_close_matches(word.lower(), MONTHS, n=1, cutoff=0.8)
        return MONTH_NUM[hit[0]] if hit else None

    for text in candidates:
        for rx, order in ((RE_MONTH_DAY, "md"), (RE_DAY_MONTH, "dm")):
            for m in rx.finditer(text):
                if order == "md":
                    mon, day = m.group(1), m.group(2)
                else:
                    day, mon = m.group(1), m.group(2)
                num = MONTH_NUM.get(mon.lower())
                if num != month:
                    continue
                day_i = int(day)
                if 1 <= day_i <= 31:
                    return f"{year:04d}-{month:02d}-{day_i:02d}", False

    # Fall back to a misspelled month name before giving up on the day.
    for text in candidates:
        for m in re.finditer(r"\b([A-Za-z]{4,10})\.?\s+(\d{1,2})"
                             r"(?:st|nd|rd|th)?,?\s*(?:\d{4})?", text):
            if fuzzy_month(m.group(1)) == month:
                day_i = int(m.group(2))
                if 1 <= day_i <= 31:
                    return f"{year:04d}-{month:02d}-{day_i:02d}", False
    return f"{year:04d}-{month:02d}-01", True


# Any "Label:" line inside an indented block starts a new field, even if we
# do not capture that particular label.
RE_ANYLABEL = re.compile(r"^[ \t]+[A-Za-z][A-Za-z /]{0,24}:")

RE_DEFLINE = re.compile(
    r"^[ \t]+(?:\w+[ \t]+)?"
    r"(Date|Time|Place|Location|Venue)s?[ \t]*:"
    r"[ \t]*(.*)$", re.I | re.M)


def definition_block(src: str) -> dict[str, list[str]]:
    """Parse the indented `Date: ... / Time: ... / Place: ...` blocks used by
    pages from roughly 1999 to 2006, including their continuation lines."""
    fields: dict[str, list[str]] = {}
    lines = src.split("\n")
    current: str | None = None
    for line in lines:
        m = RE_DEFLINE.match(line)
        if m:
            current = m.group(1).lower()
            fields.setdefault(current, []).append(m.group(2).strip())
        elif current and re.match(r"^[ \t]{2,}\S", line) \
                and not RE_ANYLABEL.match(line):
            fields[current].append(line.strip())
        elif RE_ANYLABEL.match(line):
            current = None
        elif line.strip() == "":
            current = None
    return fields


def extract_times(src: str) -> tuple[str | None, str | None]:
    """Return (start HH:MM, end HH:MM) if stated."""
    texts: list[str] = []
    for _n, params in find_templates(src, "Meetings:"):
        if "time" in params:
            texts.append(params["time"])
    s = section_text(src, "Time")
    if s:
        texts.append(s)
    texts += definition_block(src).get("time", [])
    for text in texts:
        m = RE_TIME_RANGE.search(text)
        if m:
            return f"{int(m.group(1)):02d}:{m.group(2)}", f"{int(m.group(3)):02d}:{m.group(4)}"
        m = RE_TIME_START.search(text)
        if m:
            return f"{int(m.group(1)):02d}:{m.group(2)}", None
    return None, None


def extract_location(src: str) -> str | None:
    """Return a raw 'Ward:Venue' location reference."""
    for name, _params in find_templates(src, "Meetings:Locations:"):
        return name.split("Meetings:Locations:", 1)[1]
    for name, params in find_templates(src, "Template:Meetings:Locations:"):
        return name.split("Meetings:Locations:", 1)[1]
    for _n, params in find_templates(src, "Meetings:"):
        if "location" in params and params["location"]:
            return params["location"]
    return None


def literal_location(src: str) -> list[str] | None:
    """Venue lines for pages that name a place in prose rather than via a
    template. Returned as literal address lines; the site templates accept
    those in place of a registry key."""
    fields = definition_block(src)
    for key in ("place", "location", "venue"):
        if fields.get(key):
            lines = [re.sub(r"\s{2,}", " ", x).strip()
                     for x in fields[key] if x.strip()]
            lines = [RE_MOBILE.sub("", x).strip() for x in lines]
            lines = [x for x in lines if x and not re.match(r"^https?://", x)]
            lines = [re.sub(r"\s*\[?https?://\S+\]?", "", x).strip() for x in lines]
            lines = [tidy_fragment(x) for x in lines]
            lines = [x for x in lines if x]
            if lines:
                return lines[:4]
    s = section_text(src, "Location") or section_text(src, "Place")
    if s:
        s = strip_templates(s)
        lines = [clean_wiki_inline(x) for x in re.split(r"<br\s*/?>|\n", s)]
        lines = [re.sub(r"\s*\[?https?://\S+\]?", "", x).strip(" []")
                 for x in lines]
        lines = [RE_MOBILE.sub("", x).strip() for x in lines if x.strip(" []")]
        lines = [tidy_fragment(x) for x in lines]
        lines = [x for x in lines if x]
        if lines:
            return lines[:4]
    return None


def prose_location(src: str) -> bool:
    """True when the Location section is prose rather than an address, as on
    the 2020-21 online meetings ("Meeting room is https://gather.town/...").
    Such sections stay in the body instead of becoming a location field."""
    s = section_text(src, "Location") or section_text(src, "Place")
    if not s:
        return False
    s = strip_templates(s).strip()
    return bool(re.search(r"https?://", s)) or len(s) > 110


def expand_location_templates(src: str) -> str:
    """Inline venue templates as text, used where the venue cannot be put in
    frontmatter (pages describing two meetings with two venues)."""
    def repl(m: re.Match) -> str:
        venue = parse_venue(m.group(1))
        if not venue:
            return ""
        out = "'''" + venue.name + "'''<br />" + "<br />".join(venue.address)
        if venue.note:
            out += "<br />" + venue.note
        return out
    return re.sub(r"\{\{\s*Meetings:Locations:([^|}]+)(?:\|[^{}]*)?\}\}",
                  repl, src)


def tidy_fragment(text: str) -> str:
    """Clean up remnants left by stripping URLs, e.g. a trailing '(map at'."""
    text = re.sub(r"\(\s*(?:map|info|details?)\s*(?:at|:)?\s*\)?\s*$", "",
                  text, flags=re.I).strip()
    if text.count("(") > text.count(")"):
        text = text[:text.rfind("(")].strip()
    return text.strip(" ,;:-")


def meeting_type(src: str) -> str:
    live = [s for s in live_sections(src) if s["kind"]]
    if live:
        # A technical meeting is the headline event when one took place.
        for s in live:
            if s["kind"] == "technical":
                return "technical"
        return live[0]["kind"]
    if find_templates(src, "Meetings:Nomikai:Vitals"):
        return "nomikai"
    if find_templates(src, "Meetings:Itinerary:Tech"):
        return "technical"
    # The standard intro boilerplate mentions "Technical Meetings", so type
    # keywords are only trusted outside it.
    low = strip_boilerplate(src).lower()
    if "nomikai" in low and "technical meeting" not in low:
        return "nomikai"
    if "technical meeting" in low:
        return "technical"
    return "meeting"


def strip_boilerplate(src: str) -> str:
    for b in BOILERPLATE:
        src = re.sub(re.escape(b) + r"[^\n]*", "", src)
    return src


def extract_title(src: str, mtype: str) -> str:
    """Prefer a descriptive heading over the generic type name."""
    live = [s for s in live_sections(src) if s["kind"]]
    if both_events(src):
        return "Technical Meeting and Nomikai"
    if len(live) == 1:
        h = live[0]["heading"]
        # "Bonenkai Year-End Party" beats a generic "Nomikai", but
        # "January Nomikai Information" does not.
        if re.search(r"bonenkai|shinnenkai|anniversary|installfest|seminar|"
                     r"conference|hackathon|new\s*year", h, re.I):
            return re.sub(r"\s+(information|details?)$", "", h, flags=re.I)
    generic = {"technical": "Technical Meeting",
               "nomikai": "Nomikai", "meeting": "Meeting"}[mtype]
    if mtype != "meeting":
        return generic
    for m in re.finditer(r"^=+\s*([^=\n]{3,70}?)\s*=+\s*$", src, re.M):
        h = m.group(1).strip()
        if re.match(r"^(what happened|introduction|overview|references|"
                    r"summary of events|food place|meeting place)", h, re.I):
            continue
        if re.search(r"installfest|party|bof|conference|anniversary|seminar",
                     h, re.I):
            return h
    return generic


# --------------------------------------------------------------------------
# itinerary talks

RE_TALK_BY = re.compile(r'^"?(?P<title>.+?)"?\s*\(\s*by\s+(?P<who>.+?)\s*\)\s*$', re.I)
RE_TALK_BY2 = re.compile(r'^"(?P<title>.+?)"\s+by\s+(?P<who>.+?)\s*$', re.I)
RE_TALK_BY3 = re.compile(r'^(?P<title>.+?)\s+by\s+\[\[(?P<who>[^\]]+)\]\]\s*$', re.I)


def clean_wiki_inline(text: str) -> str:
    text = re.sub(r"\[\[([^\]|]+)\|([^\]]+)\]\]", r"\2", text)
    text = re.sub(r"\[\[([^\]]+)\]\]", r"\1", text)
    text = re.sub(r"'''?", "", text)
    text = re.sub(r"<[^>]+>", "", text)
    return text.strip()


RE_INLINE_TALK = re.compile(
    r"^[*#]\s*(?P<rest>.+?)\s*$", re.M)


def parse_inline_talks(src: str) -> list[dict]:
    """A few pages list the programme in the transclusion parameters rather
    than in the itinerary template."""
    talks: list[dict] = []
    for _n, params in find_templates(src, "Meetings:Itinerary"):
        for key in ("presentations", "lightning_talks", "demos"):
            val = params.get(key, "")
            if not val:
                continue
            # Items are bullets, but some lists put the presenter on the
            # following line ("\"History of TLUG\"\n   By Edward Middleton").
            val = re.sub(r"\n\s*(By\s+)", r" \1", val, flags=re.I)
            chunks = [c for part in re.split(r"^[*#]\s*", val, flags=re.M)
                      for c in re.split(r"\n\s*\n", part) if c.strip()]
            for item in chunks:
                # Lists often end with a "T.B.D." placeholder slot.
                if re.match(r"^\W*t\.?b\.?[ad]", item.strip(), re.I):
                    continue
                head, _, tail = item.partition("<br />")
                head = clean_wiki_inline(head)
                m = re.match(r"^(?P<title>.+?)[,;]?\s+by\s+(?P<who>.+?)$",
                             head, re.I)
                if not m:
                    continue
                title = re.sub(r"\s*t\.?b\.?[ad]\.?$", "",
                               m.group("title").strip(), flags=re.I)
                title = title.strip().strip('"\'')
                who = re.sub(r"\s*t\.?b\.?[ad]\.?.*$", "",
                             m.group("who").strip(), flags=re.I)
                who = who.strip().strip('"\'')
                if not (title and who) or len(title) < 4:
                    continue
                entry = {"title": title, "presenter": who}
                abstract = re.sub(r"\s+", " ", clean_wiki_inline(tail)).strip()
                if len(abstract) > 30:
                    entry["abstract"] = abstract[:600]
                talks.append(entry)
    return talks


def parse_itinerary(year: int, month: int) -> list[dict]:
    name = f"Template:Meetings:Itinerary:Tech:{year:04d}{month:02d}"
    src = read_page(name)
    if src is None:
        return []
    src = re.sub(r"<noinclude>.*?</noinclude>", "", src, flags=re.S)

    talks: list[dict] = []
    parts = re.split(r"^======\s*(.+?)\s*======\s*$", src, flags=re.M)
    # parts: [before, heading, body, heading, body, ...]
    for i in range(1, len(parts), 2):
        heading = parts[i].strip()
        body = parts[i + 1] if i + 1 < len(parts) else ""
        if re.match(r"^<<", heading) or re.match(r"^\s*break\s*$", heading, re.I):
            continue
        if re.search(r"^\s*(t\.?b\.?[ad]\.?|to be decided|open panel)\s*$",
                     heading, re.I):
            continue
        presenter = None
        title = heading
        for rx in (RE_TALK_BY2, RE_TALK_BY, RE_TALK_BY3):
            m = rx.match(heading)
            if m:
                title = m.group("title")
                presenter = m.group("who")
                break
        title = clean_wiki_inline(title).strip('"')
        if not title:
            continue
        entry: dict = {"title": title}
        if presenter:
            presenter = clean_wiki_inline(presenter)
            presenter = re.sub(r"\s*\band\b\s*", ", ", presenter)
            entry["presenter"] = presenter
        body = re.split(r"^=+[^=\n]+=+\s*$", body, maxsplit=1, flags=re.M)[0]
        abstract = clean_wiki_inline(strip_templates(body))
        abstract = re.sub(r"\s+", " ", abstract).strip()
        abstract = RE_EMAIL.sub("", RE_MOBILE.sub("", abstract)).strip()
        if abstract and len(abstract) > 30:
            entry["abstract"] = abstract[:600]
        talks.append(entry)
    return talks


# --------------------------------------------------------------------------
# venues

@dataclass
class Venue:
    key: str
    name: str
    address: list[str] = field(default_factory=list)
    links: dict[str, str] = field(default_factory=dict)
    note: str = ""


def parse_venue(ref: str) -> Venue | None:
    """Load Template:Meetings:Locations:<ref> and parse it."""
    for candidate in (ref, ref.replace(" ", "_")):
        src = read_page(f"Template:Meetings:Locations:{candidate}")
        if src is not None:
            break
    else:
        return None
    src = re.sub(r"<noinclude>.*?</noinclude>", "", src, flags=re.S)

    # The venue's own name is usually written as a link, so keep the link
    # text and harvest the URL; navigation links ("map", "details") carry no
    # name text and are dropped.
    links: dict[str, str] = {}

    def take_link(m: re.Match) -> str:
        url, label = m.group(1), m.group(2).strip()
        if RE_NAV.match(label):
            if re.search(r"map", label, re.I):
                links.setdefault("google", url)
            else:
                links.setdefault("venue", url)
            return ""
        links.setdefault("venue", url)
        return label

    src = re.sub(r"\[(https?://[^\s\]]+)\s+([^\]]+)\]", take_link, src)
    src = re.sub(r"\[https?://\S+\]", "", src)
    src = re.sub(r"https?://\S+", "", src)

    lines = [clean_wiki_inline(x) for x in re.split(r"<br\s*/?>|\n", src)]
    lines = [x.strip(" []|,") for x in lines]
    lines = [x for x in lines if x and not RE_NAV.match(x) and len(x) > 2]
    # Some templates open with an editorial note rather than the venue name.
    note_lines: list[str] = []
    while lines and (lines[0].upper().startswith("NOTE") or len(lines[0]) > 90):
        note_lines.append(lines.pop(0))
    if not lines:
        return None

    name = lines[0]
    address = [RE_MOBILE.sub("", a).strip() for a in lines[1:]]
    address = [a for a in address if a and not re.match(r"^tel[:\s]*$", a, re.I)]

    ward, _, venue = ref.partition(":")
    key = slugify(f"{ward}-{venue}" if venue else ward)
    key = LOCATION_ALIASES.get(key, key)
    return Venue(key=key, name=name, address=address, links=links,
                 note=" ".join(note_lines).strip())


# --------------------------------------------------------------------------
# body conversion

# Sections whose content is captured in frontmatter or is generic
# boilerplate repeated across a hundred pages.
DROP_SECTIONS = (
    "Introduction", "Date", "Dates", "Time", "Location", "Place", "Venue",
    "Contact Info", "Contact Information", "Contact", "Contacts",
    "References", "reference", "Vitals", "Itinerary",
)

BOILERPLATE = (
    "All Linux lovers, and supporters of open source",
    "TLUG meetings are traditionally small and unstructured",
    "As a general rule, the Technical Meetings are held",
    "This event is open to all Linux users, friends, and first-timers",
)


# How a top-level section heading maps to a meeting type.
EVENT_KINDS = (
    (r"technical\s+meeting|tech\s+meeting", "technical"),
    (r"nomikai|bonenkai|shinnenkai|year[- ]end|new\s*year|party|drink", "nomikai"),
    (r"seminar|installfest|bof|conference|anniversary", "meeting"),
)

SKIP_HEADINGS = re.compile(
    r"^(introduction|overview|references?|reference|contact|contacts|details?|"
    r"see also|notes?|agenda|other items|links?|media|summary)", re.I)


def event_sections(src: str) -> list[dict]:
    """Split a page into its top-level `== ... ==` event sections.

    Pages routinely describe more than one event (a technical meeting and
    the nomikai that followed), and sometimes one of them was cancelled, so
    the type, title, date and venue all have to be read per section rather
    than from the page as a whole."""
    parts = re.split(r"^==\s*([^=\n]+?)\s*==\s*$", src, flags=re.M)
    out: list[dict] = []
    for i in range(1, len(parts), 2):
        heading = re.sub(r'["\u201c\u201d]', "", parts[i]).strip()
        body = parts[i + 1] if i + 1 < len(parts) else ""
        if SKIP_HEADINGS.match(heading):
            continue
        kind = None
        for rx, k in EVENT_KINDS:
            if re.search(rx, heading, re.I):
                kind = k
                break
        cancelled = bool(re.search(
            r"cancell?ed|postponed|will not be held|there will be no\b",
            heading + body[:400], re.I))
        out.append({"heading": heading, "body": body,
                    "kind": kind, "cancelled": cancelled})
    return out


def live_sections(src: str) -> list[dict]:
    return [s for s in event_sections(src) if not s["cancelled"]]


def both_events(src: str) -> bool:
    """True when a page describes two distinct events that both took place."""
    live = [s for s in live_sections(src) if s["kind"]]
    return len({s["kind"] for s in live}) > 1


def drop_sections(src: str, keep_when_dual: bool = False) -> str:
    """Remove sections whose values are captured in frontmatter.

    On pages describing two events the Date/Time/Location sections are the
    only way to tell the two apart, so they stay in the body."""
    names = DROP_SECTIONS
    if keep_when_dual:
        names = tuple(n for n in names
                      if n.lower() not in {"date", "dates", "time",
                                           "location", "place", "venue"})
    for name in names:
        src = re.sub(
            rf"^(=+)\s*{re.escape(name)}\s*:?\s*\1\s*$.*?(?=^=|\Z)",
            "", src, flags=re.M | re.S | re.I)
    return src


def looks_like_code(run: list[str]) -> bool:
    """Distinguish a genuine preformatted block (config samples) from prose
    that merely happens to be indented."""
    body = [x for x in run if x.strip()]
    if not body:
        return False
    techy = sum(1 for x in body if "=" in x or "/" in x)
    avg = sum(len(x.strip()) for x in body) / len(body)
    return techy >= len(body) * 0.6 and avg < 75


def unindent_run(run: list[str]) -> list[str]:
    """Unindent a block of prose. Runs of short lines are lists or tabular
    data, so keep their line breaks; long lines are wrapped prose and may be
    reflowed into a paragraph."""
    body = [x.strip() for x in run if x.strip()]
    if not body:
        return [x.strip() for x in run]
    short = sum(1 for x in body if len(x) < 80)
    if len(body) >= 2 and short >= len(body) * 0.7:
        return [x + "<br />" for x in body[:-1]] + [body[-1]]
    return [x.strip() for x in run]


def deindent_prose(src: str) -> str:
    """MediaWiki renders leading-space lines as preformatted text, which
    turns indented prose into code blocks. Unindent such runs."""
    lines = src.split("\n")
    out: list[str] = []
    i = 0
    while i < len(lines):
        if re.match(r"^[ \t]{1,}\S", lines[i]):
            j = i
            while j < len(lines) and (re.match(r"^[ \t]{1,}\S", lines[j])
                                      or (lines[j].strip() == ""
                                          and j + 1 < len(lines)
                                          and re.match(r"^[ \t]{1,}\S", lines[j + 1]))):
                j += 1
            run = lines[i:j]
            if looks_like_code(run):
                out.extend(run)
            else:
                out.extend(unindent_run(run))
            i = j
            continue
        out.append(lines[i])
        i += 1
    return "\n".join(out)


def deindent_labelled(src: str) -> str:
    """MediaWiki renders leading-space lines as preformatted text. Remaining
    indented `Label: value` lines are prose, not code, so unindent them (and
    the lines that continue them)."""
    out: list[str] = []
    buf: list[str] = []

    def flush() -> None:
        if not buf:
            return
        if len(buf) >= 2:
            out.extend([x + "<br />" for x in buf[:-1]] + [buf[-1]])
        else:
            out.extend(buf)
        buf.clear()

    run = False
    for line in src.split("\n"):
        if RE_ANYLABEL.match(line):
            run = True
            buf.append(line.strip())
            continue
        if run and re.match(r"^[ \t]{2,}\S", line):
            buf.append(line.strip())
            continue
        flush()
        if not line.strip():
            run = False
        out.append(line)
    flush()
    return "\n".join(out)


def strip_definition_blocks(src: str) -> str:
    """Drop the indented `Date:/Time:/Place:` runs whose values are now in
    frontmatter, while leaving other indented text (code samples, prize
    lists) untouched."""
    lines = src.split("\n")
    out: list[str] = []
    in_block = False
    for line in lines:
        if RE_DEFLINE.match(line):
            in_block = True
            continue
        if in_block and re.match(r"^[ \t]{2,}\S", line) \
                and not RE_ANYLABEL.match(line):
            continue
        if in_block and RE_ANYLABEL.match(line):
            # A label we do not capture: keep it, and end the run.
            in_block = False
        if not line.strip():
            in_block = False
        out.append(line)
    return "\n".join(out)


def convert_body(src: str) -> str:
    src = re.sub(r"\{\{\s*Meetings:(Categories|Title|Introduction[^|}]*|"
                 r"Nomikai[^:|}]*|Contacts[^|}]*|Vitals|Nomikai:Vitals)"
                 r"(\|[^{}]*)?\}\}", "", src, flags=re.S | re.I)
    # Pages describing two events need both venues inlined before the
    # transclusions are discarded; only one of them fits in frontmatter.
    dual = both_events(src)
    if dual:
        src = expand_location_templates(src)
    src = strip_templates(src)

    # Provenance pointers to the long-dead old site.
    src = re.sub(r"^\s*f[or]{2}m\s+\[.*$", "", src, flags=re.M | re.I)
    keep_detail = dual or (prose_location(src)
                           and extract_location(src) is None)
    src = drop_sections(src, keep_detail)
    src = strip_definition_blocks(src)
    src = deindent_labelled(src)
    src = deindent_prose(src)

    # Privacy: personal numbers and addresses never make it into content.
    src = RE_MOBILE.sub("", src)
    src = RE_EMAIL.sub("", src)
    # ...without leaving "Rainer ()" or dangling punctuation behind.
    src = re.sub(r"\(\s*[,;]?\s*\)", "", src)
    src = re.sub(r"<\s*>", "", src)
    src = re.sub(r"[ \t]+([,;.])", r"\1", src)
    src = re.sub(r",\s*(?=[,.\n])", "", src)
    src = re.sub(r"^[ \t]*(e-?mail|tel|phone|fax)\s*:\s*$", "", src,
                 flags=re.M | re.I)
    src = re.sub(r"\bsend e-?mail to\s*[.,]?\s*$", "", src,
                 flags=re.M | re.I)
    src = re.sub(r"^[ \t]*,\s*", "", src, flags=re.M)

    src = re.sub(r"\[\[Category:[^\]]*\]\]", "", src)
    src = re.sub(r"\[\[Image:[^\]]*\]\]", "", src, flags=re.I)
    # Wiki links point at pages that no longer exist.
    src = re.sub(r"\[\[([^\]|]+)\|([^\]]+)\]\]", r"\2", src)
    src = re.sub(r"\[\[([^\]]+)\]\]", r"\1", src)
    src = re.sub(r"</?b>", "'''", src, flags=re.I)

    proc = subprocess.run(
        [PANDOC, "-f", "mediawiki", "-t", "gfm", "--wrap=none"],
        input=src, capture_output=True, text=True)
    body = proc.stdout if proc.returncode == 0 else ""

    body = re.sub(r"<!-- -->", "", body)
    out = []
    for para in re.split(r"\n\s*\n", body):
        if any(para.lstrip().startswith(b) for b in BOILERPLATE):
            continue
        out.append(para)
    body = "\n\n".join(out)

    # Drop headings left empty once their content moved to frontmatter.
    for _ in range(3):
        body = re.sub(r"^(#+ +.*)\n(?=\s*(#|\Z))", "", body, flags=re.M)
    body = re.sub(r"^\s*<https?://[^>]*>\s*[).,]+\s*$", "", body, flags=re.M)
    body = re.sub(r"\[<(https?://[^>]+)>\]\(\1\)", r"<\1>", body)
    body = re.sub(r"\n{3,}", "\n\n", body)
    return body.strip()


# --------------------------------------------------------------------------
# emit

def yaml_scalar(v: str) -> str:
    if re.search(r'[:#\[\]{}&*!|>%@`"\']|^\s|\s$', v):
        return '"' + v.replace("\\", "\\\\").replace('"', '\\"') + '"'
    return v


@dataclass
class Meeting:
    page: str
    slug: str
    title: str
    date: str
    approx: bool
    mtype: str
    start: str | None
    end: str | None
    location: str | None
    location_lines: list[str] | None
    registration: str | None
    talks: list[dict]
    body: str
    venue_note: str = ""
    canceled: bool = False
    extra: list[str] = field(default_factory=list)


def render(m: Meeting) -> str:
    start = m.start or "00:00"
    out = ["---", f"title: {yaml_scalar(m.title)}",
           f"date: {m.date}T{start}:00+09:00"]
    out.append("params:")
    if m.canceled:
        out.append("  canceled: true")
    if m.approx:
        out.append("  dateApprox: true")
    if m.end:
        out.append(f"  endDate: {m.date}T{m.end}:00+09:00")
    out.append(f"  meetingType: {m.mtype}")
    out.extend(m.extra)
    if m.location:
        out.append(f"  location: {m.location}")
    elif m.location_lines:
        out.append("  location: |-")
        for line in m.location_lines:
            out.append(f"    {line}")
    if m.registration:
        out.append(f"  registration: {m.registration}")
    if m.talks:
        out.append("  schedule:")
        for t in m.talks:
            out.append(f"    - title: {yaml_scalar(t['title'])}")
            if t.get("presenter"):
                out.append(f"      presenter: {yaml_scalar(t['presenter'])}")
            if t.get("abstract"):
                out.append(f"      abstract: {yaml_scalar(t['abstract'])}")
    out.append("---")
    body = m.body.strip()
    # Venue notes ("the sign still says Sun, not Oracle") belong with the
    # meeting they applied to, not in the shared venue registry.
    if m.venue_note and m.venue_note not in body:
        body = (m.venue_note + "\n\n" + body).strip()
    return "\n".join(out) + ("\n\n" + body + "\n" if body else "\n")


def build(page: str, special_slug: str | None = None) -> tuple[Meeting | None, Venue | None]:
    src = read_page(page)
    if src is None:
        return None, None

    if src.lstrip().upper().startswith("#REDIRECT"):
        return None, None

    if special_slug:
        # Special pages carry no date in their name; take it from the body.
        year, month = 0, 0
    else:
        m = re.match(r"Meetings:(\d{4}):(\d{2})$", page)
        year, month = int(m.group(1)), int(m.group(2))


    if special_slug:
        date, approx = None, False
        mt = re.search(
            rf"\b({MONTH_RE})\.?\s+(\d{{1,2}})(?:st|nd|rd|th)?,?\s+(\d{{4}})",
            src, re.I)
        if mt:
            num = MONTH_NUM.get(mt.group(1).lower())
            year, month = int(mt.group(3)), num
            date = f"{year:04d}-{num:02d}-{int(mt.group(2)):02d}"
        if not date:
            return None, None
    else:
        date, approx = extract_date(primary_scope(src), year, month)
        if approx:
            date, approx = extract_date(src, year, month)

    sections = event_sections(src)
    all_cancelled = bool(sections) and all(x["cancelled"] for x in sections)
    mtype = meeting_type(src)
    if special_slug:
        h = re.search(r"^=+\s*([^=\n]{6,80}?)\s*=+\s*$", src, re.M)
        title = h.group(1).strip() if h else special_slug.replace("-", " ").title()
    else:
        title = extract_title(src, mtype)
    scope = primary_scope(src)
    start, end = extract_times(scope)
    if start is None:
        start, end = extract_times(src)
    loc_ref = extract_location(scope) or extract_location(src)
    venue = parse_venue(loc_ref) if loc_ref else None
    literal = None if (venue or prose_location(src)) else literal_location(src)
    reg = None
    mreg = RE_CONNPASS.search(src)
    if mreg:
        cand = mreg.group(0).rstrip(").,]")
        # Only event URLs, not the bare group/site root.
        if re.search(r"/(events?|e)/\w|/\d{4,}", cand):
            reg = cand

    talks = parse_itinerary(year, month) if month else []
    seen = {t["title"].lower() for t in talks}
    for t in parse_inline_talks(src):
        if t["title"].lower() not in seen:
            talks.append(t)
            seen.add(t["title"].lower())
    body = convert_body(src)

    # Some wiki pages were never more than a category tag, or a pointer to
    # the mailing list announcement. Once the provenance link is dropped
    # nothing is left to publish, so do not create a stub for them.
    if not (body or venue or literal or talks or start or end):
        return None, None

    slug = f"{date}-{special_slug}" if special_slug \
        else f"{date}-{slugify(title)}"

    return Meeting(page=page, slug=slug, title=title, date=date, approx=approx,
                   mtype=mtype, start=start, end=end,
                   location=venue.key if venue else None,
                   location_lines=literal,
                   registration=reg, talks=talks, body=body,
                   venue_note=(venue.note if venue else ""),
                   canceled=all_cancelled), venue


CURATED = ("image", "imageAlt", "imageCredit")


def curated_params(path: Path) -> list[str]:
    """Hand-added frontmatter worth keeping when an import is re-run, such
    as a featured image dropped into the bundle by an editor."""
    if not path.exists():
        return []
    out = []
    for line in path.read_text(encoding="utf-8").split("\n---")[0].split("\n"):
        m = re.match(r"^  (\w+):", line)
        if m and m.group(1) in CURATED:
            out.append(line)
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--only", nargs="*", default=None)
    args = ap.parse_args()

    pages = sorted(p.name for p in WIKI.iterdir()
                   if re.match(r"Meetings:\d{4}:\d{2}$", p.name))
    targets: list[tuple[str, str | None]] = [(p, None) for p in pages]
    targets += [(p, s) for p, s in SPECIAL_PAGES.items()]
    if args.only:
        targets = [t for t in targets if t[0] in args.only]

    venues: dict[str, Venue] = {}
    written = skipped = 0
    for page, special in targets:
        if page in SKIP_PAGES:
            continue
        meeting, venue = build(page, special)
        if meeting is None:
            skipped += 1
            continue
        if venue and venue.key not in venues:
            venues[venue.key] = venue
        if not args.dry_run:
            d = OUT / meeting.slug
            d.mkdir(parents=True, exist_ok=True)
            meeting.extra = curated_params(d / "index.md")
            (d / "index.md").write_text(render(meeting), encoding="utf-8")
        written += 1

    print(f"wrote {written} meetings, skipped {skipped} empty pages, "
          f"{len(venues)} venues referenced")

    if not args.dry_run:
        emit_locations(venues)
    return 0


def emit_locations(venues: dict[str, Venue]) -> None:
    existing = LOCATIONS.read_text(encoding="utf-8")
    have = set(re.findall(r"^([a-z0-9-]+):$", existing, re.M))
    new = [v for k, v in sorted(venues.items()) if k not in have]
    if not new:
        print("locations.yaml: no new venues")
        return
    lines = ["", "# Imported from the old wiki's location templates.", ""]
    for v in new:
        lines.append(f"{v.key}:")
        lines.append(f"  name: {yaml_scalar(v.name)}")
        if v.address:
            lines.append("  address:")
            for a in v.address:
                lines.append(f"    - {yaml_scalar(a)}")
        for field_name in ("google", "venue"):
            if v.links.get(field_name):
                lines.append(f"  {field_name}: {v.links[field_name]}")
    LOCATIONS.write_text(existing.rstrip() + "\n" + "\n".join(lines) + "\n",
                         encoding="utf-8")
    print(f"locations.yaml: added {len(new)} venues")


if __name__ == "__main__":
    sys.exit(main())
