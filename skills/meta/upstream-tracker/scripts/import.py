#!/usr/bin/env python3
"""Vendor a manifest source's skills into skills/<local>/.

Reads `upstream/sources.yaml`, fetches the source, copies each
`skills[].upstream` directory at the resolved upstream HEAD into
`skills/<skills[].local>/`, injects the `metadata.upstream-*` block
into each imported SKILL.md, sets manifest `upstream-rev` and
`reviewed-rev` to the resolved sha, appends an `accept` row to the
decision log, and prints the lines to register in
`.claude-plugin/plugin.json`.

Refuses to overwrite existing local skill directories without --force.
"""
from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
import tempfile
from datetime import date
from pathlib import Path

import _lib as L


def import_one_skill(cache: Path, src: dict, mapping: dict, sha: str,
                     today: str, force: bool) -> Path:
    upstream_subdir = mapping["upstream"]
    local_subdir = mapping["local"]
    upstream_full = f"{src['subpath'].rstrip('/')}/{upstream_subdir}".lstrip("/")
    dest = L.ROOT / "skills" / local_subdir

    if dest.exists() and not force:
        print(f"  refusing to overwrite {dest.relative_to(L.ROOT)} "
              f"(use --force)", file=sys.stderr)
        sys.exit(3)

    with tempfile.TemporaryDirectory() as td:
        td_path = Path(td)
        archive = td_path / "upstream.tar"
        with archive.open("wb") as fh:
            subprocess.run(
                ["git", "archive", "--format=tar", sha, upstream_full],
                cwd=str(cache), check=True, stdout=fh,
            )
        extract_root = td_path / "extracted"
        extract_root.mkdir()
        subprocess.run(
            ["tar", "-xf", str(archive), "-C", str(extract_root)],
            check=True,
        )
        upstream_tree = extract_root / upstream_full
        if not upstream_tree.exists():
            print(f"  upstream path {upstream_full} not found at {sha[:12]}",
                  file=sys.stderr)
            sys.exit(3)
        if dest.exists():
            shutil.rmtree(dest)
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copytree(upstream_tree, dest)

    skill_md = dest / "SKILL.md"
    if not skill_md.exists():
        print(f"  imported {dest.relative_to(L.ROOT)} but no SKILL.md found",
              file=sys.stderr)
        sys.exit(3)

    text = skill_md.read_text()
    parsed = L.parse_frontmatter(text)
    if parsed is None:
        print(f"  {skill_md.relative_to(L.ROOT)} has no parseable frontmatter",
              file=sys.stderr)
        sys.exit(3)
    fm, body = parsed
    fm["name"] = dest.name
    metadata = dict(fm.get("metadata") or {})
    metadata.update({
        "upstream-id": src["id"],
        "upstream-rev": sha,
        "upstream-path": upstream_subdir,
        "upstream-imported": today,
    })
    fm["metadata"] = metadata
    skill_md.write_text(L.emit_frontmatter(fm, body))
    return dest


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("source_id", help="source id in upstream/sources.yaml")
    parser.add_argument("--force", action="store_true",
                        help="overwrite existing local skill directories")
    parser.add_argument("--no-validate", action="store_true",
                        help="skip running scripts/validate.py afterwards")
    args = parser.parse_args()

    if not L.MANIFEST.exists():
        print(f"upstream-tracker: {L.MANIFEST.relative_to(L.ROOT)} not found",
              file=sys.stderr)
        return 1

    data = L.parse_manifest()
    src = L.find_source(data, args.source_id)

    cache = L.fetch_origin(src)
    sha = L.resolve_ref(cache, f"origin/{src['branch']}")
    today = date.today().isoformat()

    print(f"importing {args.source_id} @ {sha[:12]}")
    imported: list[Path] = []
    for mapping in src.get("skills", []):
        dest = import_one_skill(cache, src, mapping, sha, today, args.force)
        imported.append(dest)
        print(f"  + skills/{mapping['local']}/")

    src["upstream-rev"] = sha
    src["reviewed-rev"] = sha
    src["last-fetched"] = L.utc_now_iso()
    L.write_manifest(data)
    L.decisions_append(args.source_id, sha, "accept",
                       note=f"initial-import {today}")

    print()
    print("Add to .claude-plugin/plugin.json (alphabetical):")
    for dest in imported:
        rel = dest.relative_to(L.ROOT)
        print(f'    "./{rel}",')
    print()

    if not args.no_validate:
        rc = subprocess.run(
            ["python3", str(L.ROOT / "scripts" / "validate.py")],
            check=False,
        ).returncode
        if rc != 0:
            print("upstream-tracker: validate.py reported errors above",
                  file=sys.stderr)
            return rc

    return 0


if __name__ == "__main__":
    sys.exit(main())
