#!/usr/bin/env python3
"""Fill gaps in meeting pages from the mailing list announcements.

Reads the announcement index built from the list archive and fills in
`endDate`, `location` and `schedule` on meeting pages that are missing
them. Existing values are never overwritten: the page is the source of
truth, the archive only fills blanks.

Usage:
    scripts/enrich-from-list.py [--dry-run] [--from YYYY] [--to YYYY]

The announcement index is produced by the helper described in the README
and defaults to /tmp/opencode/ml/announce.json.
"""
from __future__ import annotations

import argparse
import json
import os
import pathlib
import re
import sys

REPO = pathlib.Path(__file__).resolve().parent.parent
MEETINGS = REPO / "content" / "en" / "meetings"
INDEX = os.environ.get("TLUG_ANNOUNCE_INDEX", "/tmp/opencode/ml/announce.json")

TIME_RANGE = re.compile(r"(\d{1,2}):(\d{2})\s*[-–~]+\s*(\d{1,2}):(\d{2})")
TIME_ONE = re.compile(r"\b(\d{1,2}):(\d{2})\b")

# Topic lines look like: 1. "Crypto and Security"   Speaker: Chris Sekiya
#                        2. FreeBSD By Tod McQuillin
# Topic lines look like: 1. "Crypto and Security"   Speaker: Chris Sekiya
#                        2. FreeBSD By Tod McQuillin
#                        1) "Japanese TrueType Fonts"
#                           by Adrian Havill (TurboLinux)
TOPIC = re.compile(
    r"^\s*(?:\d+[.)]|[-*#])?\s*(?P<title>.+?)"
    r"(?:\s*(?:speaker\s*:|\bby\b|,)\s*(?P<who>[A-Z][\w.'-]*(?:\s+[A-Z][\w.'-]*){0,3}))?\s*$",
    re.I)
JUNK = re.compile(r"^(t\.?b\.?[ad]|to be|tba|none|n/a|etc\.?|and more)\b", re.I)
# Lead-ins, signatures and list furniture that are not talks.
NOT_TOPIC = re.compile(
    r"(will feature|following speakers|more info|sponsor\s*:|^-{4,}|^={4,}|"
    r"^\**$|mailing list|http|^next (technical )?meeting|^place\b|^time\b|"
    r"^date\b|^cost\b|^fee\b|unsubscribe|^tlug\b.*group$)", re.I)
CONT = re.compile(r"^\s*(?:by|speaker\s*:)\s+(?P<who>.+)$", re.I)
# A plausible personal name: one to four capitalised words.
NAME = re.compile(r"^[A-Z][\w.'-]*(?:\s+[A-Z][\w.'-]*){0,3}"
                  r"(?:\s+and\s+[A-Z][\w.'-]*(?:\s+[A-Z][\w.'-]*){0,3})?$")
STOP = {"and", "or", "the", "how", "they", "with", "for", "of", "in", "on",
        "will", "talk", "about", "what", "who", "this", "that"}


def clean_title(t: str) -> str:
    t = t.strip().strip('\u201c\u201d"\'')
    t = re.sub(r"\s*\((?:[^()]*)\)\s*$", "", t).strip()
    return t.strip(' ",.-')


def load_locations() -> dict[str, str]:
    """Map lowercase venue name fragments to registry keys."""
    import yaml
    data = yaml.safe_load((REPO / "data" / "locations.yaml").read_text())
    out = {}
    for key, v in data.items():
        name = (v.get("name") or "").lower()
        if name:
            out[name] = key
    return out


def squash(s: str) -> str:
    return re.sub(r"[^a-z0-9]", "", s.lower())


def venue_key(text: str, locs: dict[str, str]) -> str | None:
    t = re.sub(r"\s+", " ", text).strip().lower()
    if not t:
        return None
    ts = squash(t)
    for name, key in locs.items():
        head = name.split(",")[0].strip()
        if not head or len(head) < 4:
            continue
        hs = squash(head)
        if head in t or (len(hs) >= 8 and hs in ts):
            return key
    return None


def parse_times(text: str) -> tuple[str | None, str | None]:
    m = TIME_RANGE.search(text or "")
    if m:
        return f"{int(m.group(1)):02d}:{m.group(2)}", f"{int(m.group(3)):02d}:{m.group(4)}"
    m = TIME_ONE.search(text or "")
    if m:
        return f"{int(m.group(1)):02d}:{m.group(2)}", None
    return None, None


def parse_topics(lines: list[str]) -> list[dict]:
    """Turn announcement topic lines into schedule entries.

    Presenters are written inline ("Title by Name", \'"Title", Name\') or on
    the following line ("by Adrian Havill"), so continuation lines are
    folded into the preceding title before parsing."""
    cleaned: list[str] = []
    for raw in lines:
        # Quoted replies repeat the original announcement; skip them.
        if raw.lstrip().startswith(">"):
            continue
        t = raw
        # Undo quoted-printable leftovers from the archive.
        t = re.sub(r"=\r?\n", "", t)
        t = t.replace("=20", " ").replace("=3D", "=").replace("=09", " ")
        t = re.sub(r"=[0-9A-F]{2}", "", t)
        t = re.sub(r"\s+", " ", t).strip()
        t = re.sub(r"https?://\S+", "", t).strip()
        if not t or NOT_TOPIC.search(t):
            continue
        m = CONT.match(t)
        if m and cleaned:
            cleaned[-1] = cleaned[-1] + " by " + m.group("who")
            continue
        # Long titles wrap; a line opening lower case continues the one above.
        if cleaned and re.match(r"^[a-z]", t) and not re.match(r"^\d", t):
            cleaned[-1] = cleaned[-1].rstrip(",") + " " + t
            continue
        cleaned.append(t)

    out: list[dict] = []
    for t in cleaned:
        # A trailing affiliation or stray quote would defeat the end anchor.
        t = re.sub(r"\s*\([^()]*\)\s*$", "", t).strip()
        t = t.rstrip('"\u201d\'').strip()
        if JUNK.match(t) or len(t) < 5:
            continue
        m = TOPIC.match(t)
        if not m:
            continue
        title = clean_title(m.group("title") or "")
        who = (m.group("who") or "").strip().strip('",')
        if len(title) < 5 or JUNK.match(title) or NOT_TOPIC.search(title):
            continue
        # Titles are standalone headings, not sentence fragments.
        if not re.match(r"^[A-Z0-9\"\u201c]", title) or len(title) > 110:
            continue
        if re.search(r"\b(and|or|with|the|a|to)$", title, re.I):
            continue
        entry = {"title": title}
        who = clean_title(who)
        if (who and NAME.match(who)
                and not any(w.lower() in (STOP - {"and"}) for w in who.split())
                and who.lower() not in ("tlug", "all", "everyone", "tba")):
            entry["presenter"] = who
        out.append(entry)

    best: dict[str, dict] = {}
    for e in out:
        k = e["title"].lower()
        if k not in best or (e.get("presenter") and not best[k].get("presenter")):
            best[k] = e
    items = list(best.values())
    # "F/OSS Licensing" and "F/OSS Licensing by X" are the same talk.
    items.sort(key=lambda e: -len(e["title"]))
    kept: list[dict] = []
    for e in items:
        t = e["title"].lower()
        if any(t in k["title"].lower() and t != k["title"].lower() for k in kept):
            continue
        kept.append(e)
    kept.sort(key=lambda e: out.index(e) if e in out else 0)
    return kept[:8]


def yaml_scalar(v: str) -> str:
    if re.search(r'[:#\[\]{}&*!|>%@`"\']|^\s|\s$', v):
        return '"' + v.replace("\\", "\\\\").replace('"', '\\"') + '"'
    return v


def enrich(path: pathlib.Path, cands: list[dict], locs: dict[str, str]) -> list[str]:
    text = path.read_text()
    fm, sep, body = text.partition("\n---\n")
    if not sep:
        return []
    changes: list[str] = []

    merged: dict[str, str] = {}
    topics: list[str] = []
    for c in cands:
        for k, v in c["fields"].items():
            if v and k not in merged:
                merged[k] = v
        topics.extend(c["topics"])

    date = path.parent.name[:10]
    lines = fm.split("\n")

    def has(key: str) -> bool:
        return any(re.match(rf"^  {key}:", l) for l in lines)

    def insert_after_params(new: list[str]) -> None:
        i = next(i for i, l in enumerate(lines) if l.strip() == "params:")
        lines[i + 1:i + 1] = new

    def append_to_params(new: list[str]) -> None:
        end = len(lines)
        while end > 0 and not lines[end - 1].strip():
            end -= 1
        lines[end:end] = new

    if not has("endDate"):
        start, end = parse_times(merged.get("time", ""))
        if end:
            insert_after_params([f"  endDate: {date}T{end}:00+09:00"])
            changes.append(f"endDate {end}")

    if not has("location"):
        place = merged.get("place") or merged.get("location") or merged.get("venue") or ""
        key = venue_key(place, locs)
        if key:
            insert_after_params([f"  location: {key}"])
            changes.append(f"location {key}")
        elif place and len(place) > 4:
            insert_after_params([f"  location: {yaml_scalar(place[:70])}"])
            changes.append("location (literal)")

    if "schedule:" not in fm:
        talks = parse_topics(topics)
        if talks:
            block = ["  schedule:"]
            for t in talks:
                block.append(f"    - title: {yaml_scalar(t['title'])}")
                if t.get("presenter"):
                    block.append(f"      presenter: {yaml_scalar(t['presenter'])}")
            append_to_params(block)
            changes.append(f"schedule ({len(talks)} items)")

    if changes:
        path.write_text("\n".join(lines) + sep + body)
    return changes


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--from", dest="yfrom", default="1994")
    ap.add_argument("--to", dest="yto", default="2026")
    args = ap.parse_args()

    ann = json.load(open(INDEX))
    byd: dict[str, list[dict]] = {}
    for a in ann:
        byd.setdefault(a["date"], []).append(a)
    locs = load_locations()

    touched = 0
    for p in sorted(MEETINGS.glob("*/index.md")):
        name = p.parent.name
        if not (args.yfrom <= name[:4] <= args.yto):
            continue
        cands = byd.get(name[:10])
        if not cands:
            continue
        if args.dry_run:
            before = p.read_text()
            changes = enrich(p, cands, locs)
            p.write_text(before)
        else:
            changes = enrich(p, cands, locs)
        if changes:
            touched += 1
            print(f"  {name}: {', '.join(changes)}")
    print(f"{'would update' if args.dry_run else 'updated'} {touched} pages")
    return 0


if __name__ == "__main__":
    sys.exit(main())
