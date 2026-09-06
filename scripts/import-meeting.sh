#!/usr/bin/env bash
#
#   import-meeting.sh - convert old MediaWiki meeting pages to Hugo content
#
#   Usage:
#       scripts/import-meeting.sh Meetings:YYYY:MM [Meetings:YYYY:MM ...]
#       scripts/import-meeting.sh path/to/wiki/file
#
#   Wiki source is read from `master:wiki/<page>` in this repository's git
#   history (the pre-Hugo site), unless an existing file path is given.
#
#   Output is written to content/en/meetings/YYYY-MM-DD-<slug>.md (or
#   YYYY-MM-meeting.md when the event date cannot be parsed). The script
#   makes a best-effort conversion:
#     - MediaWiki markup is converted to Markdown with pandoc.
#     - The event date is parsed from the "==== Date ====" section when
#       possible; otherwise it falls back to the 1st of the month and leaves
#       a TODO comment.
#     - A connpass registration URL is extracted if present.
#     - `{{Meetings:Categories|...}}` transclusions are dropped; any other
#       `{{...}}` template transclusion is replaced with a TODO note, since
#       wiki templates are not migrated. Fill these in by hand (usually the
#       venue address; see `master:wiki/Template:<name>`).
#
#   Always review and edit the result. In particular set `time` and
#   `location` (a key into data/locations.yaml, adding the venue there if it
#   recurs), and check the title/date.
#
set -euo pipefail

cd "$(dirname "$0")/.."

command -v pandoc >/dev/null 2>&1 || {
    echo "error: pandoc is required (https://pandoc.org)" >&2
    exit 1
}

outdir=content/en/meetings

import_one() {
    local page=$1 name src
    if [[ -f $page ]]; then
        name=$(basename "$page")
        src=$(cat "$page")
    else
        name=$page
        src=$(git show "master:wiki/$page")
    fi

    # Expect names like "Meetings:2025:09".
    if [[ ! $name =~ ^Meetings:([0-9]{4}):([0-9]{2})$ ]]; then
        echo "error: cannot derive year/month from '$name'" >&2
        return 1
    fi
    local year=${BASH_REMATCH[1]} month=${BASH_REMATCH[2]}

    # Title, type, and filename slug from the first section heading.
    local title=Meeting type="" slug=meeting
    if grep -q '^== *Technical Meeting *==' <<<"$src"; then
        title="Technical Meeting" type=technical slug=technical-meeting
    elif grep -q '^== *Nomikai *==' <<<"$src"; then
        title="Nomikai" type=nomikai slug=nomikai
    fi

    # Event date from the line following "==== Date ====", e.g.
    # "July 11, 2025 (Friday)".
    local rawdate date="" date_todo="" out
    rawdate=$(awk '/^=+ *Date *=+/{getline; while (NF == 0) getline; print; exit}' \
                  <<<"$src" | sed 's/(.*)//')
    if [[ -n $rawdate ]] && date -d "$rawdate" >/dev/null 2>&1; then
        date=$(date -d "$rawdate" +%Y-%m-%d)
        out=$outdir/$date-$slug.md
        if [[ ${date%%-*} != "$year" ]]; then
            date_todo="  # TODO: source says '$rawdate' but page is $year-$month"
        fi
    else
        date=$year-$month-01
        out=$outdir/$year-$month-meeting.md
        date_todo="  # TODO: could not parse event date, verify"
    fi

    # Registration URL (connpass or doorkeeper).
    local registration
    registration=$(grep -oE 'https://(tlug\.(connpass|doorkeeper)\.jp|tlug\.connpass\.com)[^ ]*' \
                       <<<"$src" | head -1 | sed 's/[]).,]*$//') || true

    # Drop category transclusions; tokenize other templates so they survive
    # pandoc, then turn them into TODO notes afterwards.
    local body
    body=$(perl -0pe '
        s/\{\{\s*Meetings:Categories[^{}]*\}\}\s*//gs;
        s/\{\{\s*([^{}|]+?)\s*(?:\|[^{}]*)?\}\}/TLUGTEMPLATETODO(($1))/gs;
    ' <<<"$src" \
        | pandoc -f mediawiki -t gfm --wrap=none \
        | perl -pe '
            s/TLUGTEMPLATETODO\\?\(\\?\((.*?)\\?\)\\?\)/
                my $n = $1; $n =~ s|\\||g;
                "> **TODO(import):** insert content of wiki template `$n` (see `git show \"master:wiki\/Template:$n\"`)"
            /gex;
        ')

    {
        printf -- '---\n'
        printf 'title: "%s"\n' "$title"
        printf 'date: %sT00:00:00+09:00%s\n' "$date" "${date_todo}"
        printf '# TODO: set the start time above (T00:00:00) and fill these in:\n'
        printf 'params:\n'
        [[ -n $type ]] && printf '  meetingType: %s\n' "$type"
        printf '  endDate: ""   # event end, e.g. %sT16:00:00+09:00\n' "$date"
        printf '  location: ""  # key into data/locations.yaml, or literal address\n'
        [[ -n $registration ]] && printf '  registration: %s\n' "$registration"
        printf -- '---\n\n'
        printf '%s\n' "$body"
    } >"$out"

    echo "wrote $out"
}

for page in "$@"; do
    import_one "$page"
done
