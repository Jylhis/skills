#!/usr/bin/env python3
"""Vendor a manifest source's skills into ``skills/<category>/<name>/``.

Reads ``upstream/sources.yaml``, fetches the source, and for each
``skills[]`` mapping:

1. Resolves the destination from ``category:`` + ``name:`` (or the
   legacy ``local: <category>/<name>``).
2. Applies the entry's ``merge-strategy:`` —
   - ``standalone`` (default): copy upstream skill tree to
     ``skills/<category>/<name>/`` as a new skill.
   - ``umbrella-references``: copy the upstream ``SKILL.md`` body to
     ``skills/<category>/<umbrella>/references/<topic>.md`` instead
     of creating a new skill. Requires ``umbrella:`` and ``topic:``.
   - ``replace``: like ``standalone`` but overwrites silently.
3. For ``standalone`` / ``replace``: injects the ``metadata.upstream-*``
   block into the imported SKILL.md, creates the
   ``plugins/<target-plugin>/skills/<name>`` symlink, and adds
   ``./skills/<name>`` to that plugin's ``.claude-plugin/plugin.json``
   ``skills`` array.

Refuses to overwrite existing destinations under ``standalone`` without
``--force``. ``replace`` overwrites silently.
"""
from __future__ import annotations

import argparse
import contextlib
import json
import re
import shutil
import subprocess
import sys
import tempfile
from datetime import date
from pathlib import Path

import _lib as L


VALID_CATEGORIES = {
    "engineering", "languages", "domains", "services",
    "stack", "productivity", "personal", "misc",
}

VALID_STRATEGIES = {"standalone", "umbrella-references", "replace"}
NAME_RE = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
PLUGIN_RE = re.compile(r"^jylhis-[a-z0-9]+(-[a-z0-9]+)*$")


def _require_safe_segment(field: str, value: str) -> str:
    if not isinstance(value, str) or not NAME_RE.fullmatch(value):
        print(f"  invalid {field} {value!r}; expected lowercase "
              "letters/numbers/hyphens path segment", file=sys.stderr)
        sys.exit(3)
    return value


def _upstream_path(subpath: str, upstream_subdir: str) -> str:
    """Join manifest ``subpath`` + ``upstream`` into a repo-relative path.

    Handles ``subpath: "."`` (repo root) cleanly so the result is just
    ``<upstream_subdir>`` rather than ``./<upstream_subdir>`` — git
    archive does not accept the leading ``./`` form.
    """
    base = subpath.strip().rstrip("/")
    if base in ("", "."):
        return upstream_subdir
    return f"{base}/{upstream_subdir}"


def _reject_symlinks(root: Path, rel_root: str) -> None:
    if root.is_symlink():
        print(f"  refusing to import symlink {rel_root}", file=sys.stderr)
        sys.exit(3)
    for path in root.rglob("*"):
        if path.is_symlink():
            rel = path.relative_to(root)
            print(f"  refusing to import symlink {rel_root}/{rel}",
                  file=sys.stderr)
            sys.exit(3)


def _resolve_dest(mapping: dict) -> tuple[str, str]:
    """Return (category, name) from a skills[] mapping.

    Accepts either ``category:`` + ``name:`` (preferred) or the legacy
    ``local: <category>/<name>``.
    """
    if "category" in mapping and "name" in mapping:
        category = mapping["category"]
        name = _require_safe_segment("name", mapping["name"])
    elif "local" in mapping:
        local_val = mapping["local"]
        if not isinstance(local_val, str):
            print(f"  invalid local: {local_val!r} (expected string)", file=sys.stderr)
            sys.exit(3)
        parts = local_val.split("/")
        if len(parts) != 2:
            print(f"  invalid local: {mapping['local']!r} "
                  f"(expected <category>/<name>)", file=sys.stderr)
            sys.exit(3)
        category, name = parts
        name = _require_safe_segment("name", name)
    else:
        print(f"  mapping missing category+name (or legacy local): "
              f"{mapping!r}", file=sys.stderr)
        sys.exit(3)

    if category not in VALID_CATEGORIES:
        print(f"  invalid category {category!r}; expected one of "
              f"{sorted(VALID_CATEGORIES)}", file=sys.stderr)
        sys.exit(3)
    return category, name


@contextlib.contextmanager
def _extracted_upstream(cache: Path, sha: str, upstream_full: str):
    """Yield Path to the extracted ``upstream_full`` tree at ``sha``.

    Uses ``git archive | tar -x`` into a temporary directory that is
    cleaned up on exit.
    """
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
        yield upstream_tree


def _inject_metadata(skill_md: Path, name: str, src: dict,
                     sha: str, upstream_subdir: str, today: str) -> None:
    text = skill_md.read_text()
    parsed = L.parse_frontmatter(text)
    if parsed is None:
        print(f"  {skill_md.relative_to(L.ROOT)} has no parseable frontmatter",
              file=sys.stderr)
        sys.exit(3)
    fm, body = parsed
    fm["name"] = name
    metadata = dict(fm.get("metadata") or {})
    metadata.update({
        "upstream-id": src["id"],
        "upstream-rev": sha,
        "upstream-path": upstream_subdir,
        "upstream-imported": today,
    })
    fm["metadata"] = metadata
    skill_md.write_text(L.emit_frontmatter(fm, body))


def _import_standalone(cache: Path, src: dict, mapping: dict,
                       category: str, name: str, sha: str,
                       today: str, force: bool) -> Path:
    upstream_subdir = mapping["upstream"]
    upstream_full = _upstream_path(src['subpath'], upstream_subdir)
    dest = L.ROOT / "skills" / category / name
    strategy = mapping.get("merge-strategy", "standalone")

    if dest.exists() and strategy == "standalone" and not force:
        print(f"  refusing to overwrite {dest.relative_to(L.ROOT)} "
              f"(use --force or merge-strategy: replace)", file=sys.stderr)
        sys.exit(3)

    with _extracted_upstream(cache, sha, upstream_full) as upstream_tree:
        _reject_symlinks(upstream_tree, upstream_full)
        if dest.exists():
            shutil.rmtree(dest)
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copytree(upstream_tree, dest)

    skill_md = dest / "SKILL.md"
    if not skill_md.exists():
        print(f"  imported {dest.relative_to(L.ROOT)} but no SKILL.md found",
              file=sys.stderr)
        sys.exit(3)
    _inject_metadata(skill_md, name, src, sha, upstream_subdir, today)
    return dest


def _import_umbrella_reference(cache: Path, src: dict, mapping: dict,
                                category: str, sha: str,
                                today: str, force: bool) -> Path:
    """Drop upstream SKILL.md body into an umbrella's references/.

    Requires ``umbrella:`` (the existing umbrella skill's name) and
    ``topic:`` (filename stem under that umbrella's references/).
    """
    umbrella = mapping.get("umbrella")
    topic = mapping.get("topic")
    if not (umbrella and topic):
        print("  merge-strategy: umbrella-references requires "
              "umbrella: <name> and topic: <filename-stem>", file=sys.stderr)
        sys.exit(3)
    umbrella = _require_safe_segment("umbrella", umbrella)
    topic = _require_safe_segment("topic", topic)

    umbrella_dir = L.ROOT / "skills" / category / umbrella
    if not (umbrella_dir / "SKILL.md").exists():
        print(f"  umbrella {umbrella_dir.relative_to(L.ROOT)} does not exist",
              file=sys.stderr)
        sys.exit(3)

    upstream_subdir = mapping["upstream"]
    upstream_full = _upstream_path(src['subpath'], upstream_subdir)
    dest_file = umbrella_dir / "references" / f"{topic}.md"
    if dest_file.exists() and not force:
        print(f"  refusing to overwrite {dest_file.relative_to(L.ROOT)} "
              f"(use --force)", file=sys.stderr)
        sys.exit(3)

    with _extracted_upstream(cache, sha, upstream_full) as upstream_tree:
        _reject_symlinks(upstream_tree, upstream_full)
        src_skill = upstream_tree / "SKILL.md"
        if not src_skill.exists():
            print(f"  upstream SKILL.md missing under {upstream_full}",
                  file=sys.stderr)
            sys.exit(3)
        parsed = L.parse_frontmatter(src_skill.read_text())
        body = parsed[1] if parsed else src_skill.read_text()

        dest_file.parent.mkdir(parents=True, exist_ok=True)
        provenance = (
            f"<!-- imported from {src['repo']}@{sha[:12]} "
            f"path={upstream_full} on {today} -->\n\n"
        )
        dest_file.write_text(provenance + body.lstrip())

    return dest_file


def _wire_plugin(plugin: str, category: str, name: str) -> list[str]:
    """Make ``plugins/<plugin>/skills/<name>`` resolve and listed.

    Returns a list of human-readable status lines for the importer log.
    """
    out: list[str] = []
    if not isinstance(plugin, str) or not PLUGIN_RE.fullmatch(plugin):
        print(f"  invalid target-plugin {plugin!r}; expected jylhis-<name>",
              file=sys.stderr)
        sys.exit(3)
    plugin_dir = L.ROOT / "plugins" / plugin
    if not plugin_dir.exists():
        print(f"  plugin dir {plugin_dir.relative_to(L.ROOT)} does not exist; "
              f"create it (with the two per-tool manifests) before re-running",
              file=sys.stderr)
        sys.exit(3)

    # Symlink.
    skills_dir = plugin_dir / "skills"
    skills_dir.mkdir(parents=True, exist_ok=True)
    link = skills_dir / name
    target = Path("..") / ".." / ".." / "skills" / category / name
    if link.is_symlink() or link.exists():
        existing = link.readlink() if link.is_symlink() else None
        if existing == target:
            out.append(f"  symlink ok: plugins/{plugin}/skills/{name}")
        else:
            link.unlink()
            link.symlink_to(target)
            out.append(f"  symlink retargeted: plugins/{plugin}/skills/{name} -> {target}")
    else:
        link.symlink_to(target)
        out.append(f"  symlink created: plugins/{plugin}/skills/{name} -> {target}")

    # Claude plugin.json — add to skills[] if missing.
    claude_manifest = plugin_dir / ".claude-plugin" / "plugin.json"
    if claude_manifest.exists():
        data = json.loads(claude_manifest.read_text())
        skills = data.get("skills") or []
        entry = f"./skills/{name}"
        if entry not in skills:
            skills.append(entry)
            skills.sort()
            data["skills"] = skills
            claude_manifest.write_text(json.dumps(data, indent=2) + "\n")
            out.append(f"  claude manifest: added {entry}")
        else:
            out.append(f"  claude manifest ok: {entry} already listed")

    # Codex manifest uses recursive `skills: "./skills/"` — symlink alone is enough.
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("source_id", help="source id in upstream/sources.yaml")
    parser.add_argument("--force", action="store_true",
                        help="overwrite existing local destinations")
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

    imported_skills: list[tuple[str, str, str]] = []   # (category, name, target-plugin)
    imported_refs: list[Path] = []

    for mapping in src.get("skills", []):
        category, name = _resolve_dest(mapping)
        strategy = mapping.get("merge-strategy", "standalone")
        if strategy not in VALID_STRATEGIES:
            print(f"  invalid merge-strategy {strategy!r}; expected one of "
                  f"{sorted(VALID_STRATEGIES)}", file=sys.stderr)
            return 3

        target_plugin = mapping.get("target-plugin")

        if strategy == "umbrella-references":
            dest = _import_umbrella_reference(cache, src, mapping, category,
                                               sha, today, args.force)
            imported_refs.append(dest)
            print(f"  + {dest.relative_to(L.ROOT)} (umbrella-ref)")
        else:
            dest_dir = _import_standalone(cache, src, mapping, category, name,
                                           sha, today, args.force)
            print(f"  + {dest_dir.relative_to(L.ROOT)}")
            if target_plugin:
                for line in _wire_plugin(target_plugin, category, name):
                    print(line)
                imported_skills.append((category, name, target_plugin))
            else:
                print(f"  warn: no target-plugin set; skipping plugin wiring",
                      file=sys.stderr)

    src["upstream-rev"] = sha
    src["reviewed-rev"] = sha
    src["last-fetched"] = L.utc_now_iso()
    L.write_manifest(data)
    L.decisions_append(args.source_id, sha, "accept",
                       note=f"initial-import {today}")

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
