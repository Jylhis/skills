#!/usr/bin/env python3
"""Walk pending upstream commits and record per-commit decisions.

For each pending commit (or just one named via --sha):
- print metadata + path-filtered diff
- prompt [a]ccept / [s]kip / [d]efer / [c]herry-pick / [q]uit
- append the decision to upstream/decisions/<id>.log
- advance the manifest's reviewed-rev through contiguous resolved rows

`--confirm <upstream-sha> <local-sha>` finalizes a previously
cherry-picked row from `cherry-picked:<pending>` to
`cherry-picked:<local-sha>`, then advances the cursor.
"""
from __future__ import annotations

import argparse
import subprocess
import sys
import tempfile
from pathlib import Path

import _lib as L


def confirm_cherry_pick(args: argparse.Namespace) -> int:
    data = L.parse_manifest()
    src = L.find_source(data, args.source_id)
    upstream_sha = args.confirm[0]
    local_sha = args.confirm[1]
    L.decisions_append(src["id"], upstream_sha,
                       f"cherry-picked:{local_sha}",
                       note="confirmed")
    src["reviewed-rev"] = L.advance_cursor(src)
    L.write_manifest(data)
    print(f"recorded {upstream_sha[:12]} → cherry-picked:{local_sha[:12]}")
    print(f"reviewed-rev now {src['reviewed-rev'][:12]}")
    return 0


def cherry_pick_apply(cache: Path, src: dict, sha: str) -> str | None:
    """Extract a path-filtered patch and apply to the working tree.

    Returns the local skill path the patch targeted, or None if nothing
    in subpath actually changed.
    """
    with tempfile.NamedTemporaryFile("w", suffix=".patch", delete=False) as fh:
        patch_path = Path(fh.name)
        result = subprocess.run(
            ["git", "show", "--binary", sha, "--", src["subpath"]],
            cwd=str(cache), capture_output=True, text=True, check=True,
        )
        if not result.stdout.strip():
            patch_path.unlink(missing_ok=True)
            return None
        fh.write(result.stdout)

    skill_local: str | None = None
    for mapping in src.get("skills", []):
        upstream_full = f"{src['subpath'].rstrip('/')}/{mapping['upstream']}".lstrip("/")
        check = subprocess.run(
            ["grep", "-q", upstream_full, str(patch_path)],
            check=False,
        )
        if check.returncode == 0:
            local_path = L.skill_local_path(mapping)
            if local_path is None:
                print(f"  mapping missing category+name (or legacy local): "
                      f"{mapping!r}", file=sys.stderr)
                return None
            skill_local = local_path
            target_dir = L.ROOT / "skills" / local_path
            depth = upstream_full.count("/") + 1
            apply_rc = subprocess.run(
                ["git", "apply",
                 f"-p{depth}",
                 f"--directory=skills/{local_path}",
                 str(patch_path)],
                cwd=str(L.ROOT), check=False,
            ).returncode
            if apply_rc != 0:
                print(f"  patch did not apply cleanly to {target_dir.relative_to(L.ROOT)}",
                      file=sys.stderr)
                print(f"  patch saved at {patch_path}", file=sys.stderr)
                return None
            break

    patch_path.unlink(missing_ok=True)
    return skill_local


def prompt_decision() -> str:
    while True:
        try:
            answer = input("[a]ccept / [s]kip / [d]efer / [c]herry-pick / [q]uit > ").strip().lower()
        except EOFError:
            return "q"
        if answer in ("a", "accept"):
            return "accept"
        if answer in ("s", "skip"):
            return "skip"
        if answer in ("d", "defer"):
            return "defer"
        if answer in ("c", "cherry-pick", "cherry"):
            return "cherry-pick"
        if answer in ("q", "quit", ""):
            return "q"
        print("  unrecognised — pick one of a/s/d/c/q")


def review_commit(src: dict, cache: Path, commit: dict) -> str:
    sha = commit["sha"]
    diff = L.show_commit(cache, sha, src["subpath"])
    print()
    print("─" * 72)
    print(f"commit  {sha}")
    print(f"author  {commit['author']}")
    print(f"date    {commit['date']}")
    print(f"subject {commit['subject']}")
    print()
    for path in commit["files"]:
        print(f"  ~ {path}")
    print()
    print(diff[:8000])
    if len(diff) > 8000:
        print(f"\n[diff truncated; full {len(diff)} chars in cache]")
    print("─" * 72)
    decision = prompt_decision()
    if decision == "q":
        return "q"
    if decision == "cherry-pick":
        target = cherry_pick_apply(cache, src, sha)
        if target is None:
            print("  cherry-pick deferred (apply failed or no overlap)")
            L.decisions_append(src["id"], sha, "defer",
                               note="cherry-pick failed")
            return "defer"
        print(f"  patch applied to skills/{target}/. Review, edit, commit, then run:")
        print(f"    review.py {src['id']} --confirm {sha[:12]} <local-sha>")
        L.decisions_append(src["id"], sha, "cherry-picked:<pending>",
                           note=f"target=skills/{target}")
        return "cherry-picked"
    L.decisions_append(src["id"], sha, decision)
    return decision


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("source_id")
    parser.add_argument("--sha", help="restrict to a single upstream sha")
    parser.add_argument("--confirm", nargs=2, metavar=("UPSTREAM", "LOCAL"),
                        help="finalize a previous cherry-pick")
    args = parser.parse_args()

    if args.confirm:
        return confirm_cherry_pick(args)

    if not L.MANIFEST.exists():
        print(f"upstream-tracker: {L.MANIFEST.relative_to(L.ROOT)} not found",
              file=sys.stderr)
        return 1

    data = L.parse_manifest()
    src = L.find_source(data, args.source_id)

    cache = L.cache_path(src["id"])
    if not cache.exists():
        print(f"upstream-tracker: no cache at {cache.relative_to(L.ROOT)} — "
              f"run fetch.py first", file=sys.stderr)
        return 2

    cursor = src.get("reviewed-rev", "")
    head = src.get("upstream-rev", "")
    if not cursor or not head:
        print("upstream-tracker: source not yet imported", file=sys.stderr)
        return 2

    commits = L.commits_between(cache, cursor, head, src["subpath"])
    decisions = L.decisions_index(src["id"])
    pending = [c for c in commits if not L.is_resolved(decisions.get(c["sha"], ""))]
    if args.sha:
        pending = [c for c in pending if c["sha"].startswith(args.sha)]
        if not pending:
            print(f"upstream-tracker: {args.sha} not found in pending list",
                  file=sys.stderr)
            return 2

    if not pending:
        print(f"# {src['id']}\n\n_no pending commits_")
        return 0

    print(f"# {src['id']} — {len(pending)} pending commit(s)")
    for commit in pending:
        result = review_commit(src, cache, commit)
        if result == "q":
            print("\n_session interrupted; resume with `review.py "
                  f"{src['id']}`_")
            break
        if result == "defer":
            print("\n_cursor blocked at defer; re-run when ready_")
            break

    src["reviewed-rev"] = L.advance_cursor(src)
    L.write_manifest(data)
    print(f"\nreviewed-rev now {src['reviewed-rev'][:12]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
