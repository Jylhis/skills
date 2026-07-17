#!/usr/bin/env python3
"""Package canonical skills into per-skill `.zip` archives for claude.ai upload.

claude.ai's Skills feature takes a self-contained `.zip` per skill (the
`SKILL.md` plus its optional `scripts/`, `references/`, `assets/` siblings).
This walks `skills/<category>/<name>/` and writes `dist/skills/<name>.zip` for
each, archived as `<name>/...` so it unpacks into a single top-level directory.

`evals/` siblings are recording fixtures, not skill content, and are excluded.
The canonical tree under `skills/` holds real files (only the per-plugin
`plugins/*/skills/` farms are symlinks), so each archive is self-contained.

Usage:
  python3 scripts/package-skill.py [--out DIR] [NAME ...]

With no NAME args, packages every skill. NAME selects skills by directory
basename (e.g. `tdd security`).
"""
from __future__ import annotations

import sys
import zipfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SKILLS_DIR = REPO_ROOT / "skills"
DEFAULT_OUT = REPO_ROOT / "dist" / "skills"

# Directory/file names never shipped inside a claude.ai skill archive.
EXCLUDE_DIRS = {"evals", "__pycache__", ".git"}
EXCLUDE_SUFFIXES = {".pyc"}


def discover_skills() -> list[Path]:
    """Return every canonical skill directory (`skills/<category>/<name>/`)."""
    return sorted(p.parent for p in SKILLS_DIR.glob("*/*/SKILL.md"))


def _iter_members(skill_dir: Path) -> list[Path]:
    """Files to include, excluding fixture/cache noise."""
    out: list[Path] = []
    for path in sorted(skill_dir.rglob("*")):
        if not path.is_file():
            continue
        rel_parts = path.relative_to(skill_dir).parts
        if any(part in EXCLUDE_DIRS for part in rel_parts):
            continue
        if path.suffix in EXCLUDE_SUFFIXES:
            continue
        out.append(path)
    return out


def package_one(skill_dir: Path, out_dir: Path) -> tuple[Path, int]:
    """Write `<out_dir>/<name>.zip` for one skill; return (path, file-count)."""
    name = skill_dir.name
    out_dir.mkdir(parents=True, exist_ok=True)
    archive = out_dir / f"{name}.zip"
    members = _iter_members(skill_dir)
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as zf:
        for path in members:
            arcname = Path(name) / path.relative_to(skill_dir)
            zf.write(path, arcname.as_posix())
    return archive, len(members)


def _display(path: Path) -> str:
    """Path relative to the repo root when possible, else absolute."""
    try:
        return str(path.relative_to(REPO_ROOT))
    except ValueError:
        return str(path)


def main(argv: list[str]) -> int:
    args = argv[1:]
    out_dir = DEFAULT_OUT
    names: list[str] = []
    i = 0
    while i < len(args):
        if args[i] == "--out":
            if i + 1 >= len(args):
                print("package-skill.py: --out requires a directory", file=sys.stderr)
                return 2
            out_dir = Path(args[i + 1]).resolve()
            i += 2
            continue
        names.append(args[i])
        i += 1

    if not SKILLS_DIR.is_dir():
        print(f"package-skill.py: skills/ not found at {SKILLS_DIR}", file=sys.stderr)
        return 1

    skills = discover_skills()
    if names:
        wanted = set(names)
        skills = [s for s in skills if s.name in wanted]
        missing = wanted - {s.name for s in skills}
        if missing:
            print(f"package-skill.py: unknown skill(s): {sorted(missing)}", file=sys.stderr)
            return 1

    if not skills:
        print("package-skill.py: no skills to package")
        return 0

    for skill_dir in skills:
        archive, count = package_one(skill_dir, out_dir)
        print(f"packaged {_display(archive)} ({count} file(s))")

    print(f"package-skill.py: wrote {len(skills)} archive(s) to {_display(out_dir)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
