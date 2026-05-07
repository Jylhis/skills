#!/usr/bin/env python3
"""Fetch upstream skill repos and report pending commits.

For each source in upstream/sources.yaml:
- ensures a bare partial clone under .cache/upstream/<id>.git
- runs `git fetch origin <branch>`
- lists commits in `reviewed-rev..origin/<branch>` filtered to <subpath>
- updates manifest `upstream-rev` and `last-fetched`
- never touches `reviewed-rev`

Idempotent: re-running shows the same pending list until commits are
decided via review.py.
"""
from __future__ import annotations

import argparse
import sys

import _lib as L


def report_source(src: dict, dry_run: bool) -> int:
    """Returns the count of pending commits for this source."""
    print(f"## {src['id']}")
    print()
    if dry_run:
        cache = L.cache_path(src["id"])
        if not cache.exists():
            print("_no local clone yet — run without --dry-run to fetch_")
            print()
            return 0
    else:
        L.fetch_origin(src)
        cache = L.cache_path(src["id"])

    new_head = L.resolve_ref(cache, f"origin/{src['branch']}")
    old_reviewed = src.get("reviewed-rev", "") or ""

    if not dry_run:
        src["upstream-rev"] = new_head
        src["last-fetched"] = L.utc_now_iso()

    print(f"reviewed-rev: `{old_reviewed[:12] or '(none)'}`")
    print(f"upstream-rev: `{new_head[:12]}`")
    print(f"last-fetched: {src.get('last-fetched', '(not yet)')}")
    print()

    if not old_reviewed:
        print("_source not yet imported — run import.py to vendor the initial copy_")
        print()
        return 0

    commits = L.commits_between(cache, old_reviewed, new_head, src["subpath"])
    decisions = L.decisions_index(src["id"])
    pending = [c for c in commits if not L.is_resolved(decisions.get(c["sha"], ""))]

    if not pending:
        print("_no pending commits_")
        print()
        return 0

    print(f"**{len(pending)} pending commit(s):**")
    print()
    for commit in pending:
        sha12 = commit["sha"][:12]
        print(f"- `{sha12}` · {commit['author']} · {commit['date']}")
        print(f"  - {commit['subject']}")
        for path in commit["files"]:
            print(f"  - `{path}`")
    print()
    return len(pending)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--dry-run", action="store_true",
                        help="do not run `git fetch`; report against existing cache")
    parser.add_argument("source", nargs="?",
                        help="restrict to a single source id")
    args = parser.parse_args()

    if not L.MANIFEST.exists():
        print(f"upstream-tracker: {L.MANIFEST.relative_to(L.ROOT)} not found",
              file=sys.stderr)
        return 1

    data = L.parse_manifest()
    sources = data.get("sources", [])
    if args.source:
        sources = [s for s in sources if s.get("id") == args.source]
        if not sources:
            print(f"upstream-tracker: source id {args.source!r} not in manifest",
                  file=sys.stderr)
            return 2

    if not sources:
        print("# Upstream pending review\n\n_no sources configured_")
        return 0

    print("# Upstream pending review")
    print()
    total = 0
    for src in sources:
        total += report_source(src, args.dry_run)

    if not args.dry_run:
        L.write_manifest(data)

    print(f"---\n_{total} pending commit(s) across {len(sources)} source(s)_")
    return 0


if __name__ == "__main__":
    sys.exit(main())
