"""Shared helpers for upstream-tracker scripts.

Pure stdlib. Restricted YAML parsing matches the strategy used by
scripts/validate.py — only the shapes documented in
references/manifest-schema.md and references/frontmatter-block.md
parse correctly.
"""
from __future__ import annotations

import datetime as _dt
import re
import subprocess
import sys
from pathlib import Path
from typing import Any


# ── Repo layout ────────────────────────────────────────────────────────


def repo_root() -> Path:
    """Walk up from this file until we find the repo root."""
    here = Path(__file__).resolve()
    for parent in here.parents:
        if (parent / ".claude-plugin" / "plugin.json").exists():
            return parent
    print("upstream-tracker: cannot locate repo root", file=sys.stderr)
    sys.exit(2)


ROOT = repo_root()
MANIFEST = ROOT / "upstream" / "sources.yaml"
DECISIONS_DIR = ROOT / "upstream" / "decisions"
CACHE_DIR = ROOT / ".cache" / "upstream"


# ── Restricted YAML reader ─────────────────────────────────────────────


SHA_RE = re.compile(r"^[0-9a-f]{4,40}$")


def _strip_quotes(value: str) -> str:
    if len(value) >= 2 and value[0] == value[-1] and value[0] in ('"', "'"):
        return value[1:-1]
    return value


def _indent(line: str) -> int:
    n = 0
    for ch in line:
        if ch == " ":
            n += 1
        else:
            return n
    return n


def _kv_pair(body: str) -> tuple[str, str]:
    k, _, v = body.partition(":")
    return k.strip(), _strip_quotes(v.strip())


def _flush_skill(current: dict[str, Any] | None, skill: dict[str, str] | None) -> None:
    if current is not None and skill is not None:
        current.setdefault("skills", []).append(skill)


class _ManifestParser:
    """Stateful walker for the restricted YAML shape."""

    def __init__(self) -> None:
        self.sources: list[dict[str, Any]] = []
        self.current: dict[str, Any] | None = None
        self.skill: dict[str, str] | None = None
        self.in_skills = False

    def feed(self, line: str) -> None:
        if not line.strip() or line.lstrip().startswith("#") or line == "sources:":
            return
        ind = _indent(line)
        body = line.strip()
        if ind == 2 and body.startswith("- "):
            self._open_source(body[2:].lstrip())
        elif self.current is None:
            return
        elif ind == 4 and body == "skills:":
            _flush_skill(self.current, self.skill)
            self.skill = None
            self.in_skills = True
        elif self.in_skills:
            self._feed_skill_line(ind, body)
        elif ind == 4 and ":" in body:
            _flush_skill(self.current, self.skill)
            self.skill = None
            self.in_skills = False
            k, v = _kv_pair(body)
            self.current[k] = v

    def _open_source(self, head: str) -> None:
        if self.current is not None:
            _flush_skill(self.current, self.skill)
            self.sources.append(self.current)
        self.current = {}
        self.skill = None
        self.in_skills = False
        if ":" in head:
            k, v = _kv_pair(head)
            self.current[k] = v

    def _feed_skill_line(self, ind: int, body: str) -> None:
        if ind == 6 and body.startswith("- "):
            _flush_skill(self.current, self.skill)
            self.skill = {}
            head = body[2:].lstrip()
            if ":" in head:
                k, v = _kv_pair(head)
                self.skill[k] = v
        elif ind == 8 and self.skill is not None and ":" in body:
            k, v = _kv_pair(body)
            self.skill[k] = v

    def finish(self) -> dict[str, Any]:
        if self.current is not None:
            _flush_skill(self.current, self.skill)
            self.sources.append(self.current)
        return {"sources": self.sources}


def parse_manifest(path: Path = MANIFEST) -> dict[str, Any]:
    """Parse upstream/sources.yaml.

    Recognises only the shape documented in references/manifest-schema.md.
    """
    if not path.exists():
        return {"sources": []}
    walker = _ManifestParser()
    for raw in path.read_text().splitlines():
        walker.feed(raw.rstrip())
    return walker.finish()


_FIELD_ORDER = (
    "id", "repo", "branch", "subpath", "license",
    "upstream-rev", "reviewed-rev", "last-fetched",
)


def _emit_source_fields(src: dict[str, Any]) -> list[str]:
    out: list[str] = []
    first = True
    for key in _FIELD_ORDER:
        if key not in src:
            continue
        prefix = "  - " if first else "    "
        out.append(f"{prefix}{key}: {_yaml_value(src[key])}")
        first = False
    for key, value in src.items():
        if key in _FIELD_ORDER or key == "skills":
            continue
        out.append(f"    {key}: {_yaml_value(value)}")
    return out


def _emit_skill_entry(entry: dict[str, Any]) -> list[str]:
    out = [f"      - upstream: {_yaml_value(entry.get('upstream', ''))}"]
    for k, v in entry.items():
        if k == "upstream":
            continue
        out.append(f"        {k}: {_yaml_value(v)}")
    return out


def write_manifest(data: dict[str, Any], path: Path = MANIFEST) -> None:
    """Round-trip the documented shape back to disk.

    Preserves field order from references/manifest-schema.md.
    """
    lines: list[str] = ["sources:"]
    for src in data.get("sources", []):
        lines.extend(_emit_source_fields(src))
        lines.append("    skills:")
        for entry in src.get("skills", []):
            lines.extend(_emit_skill_entry(entry))
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n")


def _yaml_value(value: Any) -> str:
    s = "" if value is None else str(value)
    if s == "" or any(c in s for c in ":#&*?|>!%@`"):
        return f'"{s}"'
    return s


def find_source(data: dict[str, Any], source_id: str) -> dict[str, Any]:
    for src in data.get("sources", []):
        if src.get("id") == source_id:
            return src
    print(f"upstream-tracker: source id {source_id!r} not in manifest", file=sys.stderr)
    sys.exit(2)


# ── Frontmatter helpers (skill SKILL.md) ───────────────────────────────


def _split_frontmatter(text: str) -> tuple[str, str] | None:
    if not text.startswith("---\n"):
        return None
    end = text.find("\n---\n", 4)
    if end == -1:
        return None
    return text[4:end], text[end + 5:]


class _FrontmatterParser:
    def __init__(self) -> None:
        self.fm: dict[str, Any] = {}
        self.metadata: dict[str, str] = {}
        self.block: list[str] = []
        self.current_key: str | None = None
        self.in_metadata = False

    def feed(self, line: str) -> None:
        if not line.strip() or line.lstrip().startswith("#"):
            return
        ind = _indent(line)
        body = line.strip()
        if ind == 0 and ":" in body:
            self._handle_top_level(body)
        elif ind == 2 and self.in_metadata and ":" in body:
            k, v = _kv_pair(body)
            self.metadata[k] = v
        elif self.current_key is not None:
            self.block.append(line.lstrip())

    def _handle_top_level(self, body: str) -> None:
        self._flush_block()
        self.in_metadata = body.startswith("metadata:")
        self.current_key = None
        k, _, v = body.partition(":")
        v = v.strip()
        if v in ("|", ">"):
            self.current_key = k.strip()
        elif self.in_metadata and v == "":
            self.fm["metadata"] = self.metadata
        elif v == "":
            self.fm[k.strip()] = ""
        else:
            self.fm[k.strip()] = _strip_quotes(v)

    def _flush_block(self) -> None:
        if self.current_key is not None and self.block:
            self.fm[self.current_key] = "\n".join(self.block).strip()
        self.block = []

    def finish(self) -> dict[str, Any]:
        self._flush_block()
        if self.metadata and "metadata" not in self.fm:
            self.fm["metadata"] = self.metadata
        return self.fm


def parse_frontmatter(text: str) -> tuple[dict[str, Any], str] | None:
    split = _split_frontmatter(text)
    if split is None:
        return None
    fm_text, body = split
    parser = _FrontmatterParser()
    for line in fm_text.splitlines():
        parser.feed(line)
    return parser.finish(), body


def emit_frontmatter(fm: dict[str, Any], body: str) -> str:
    lines = ["---"]
    for key in ("name", "description", "license", "compatibility"):
        if key in fm:
            lines.append(f"{key}: {_fm_scalar(fm[key])}")
    if "metadata" in fm and isinstance(fm["metadata"], dict):
        lines.append("metadata:")
        for mk, mv in fm["metadata"].items():
            lines.append(f"  {mk}: {_yaml_value(mv)}")
    lines.append("---\n")
    return "\n".join(lines) + body


def _fm_scalar(value: Any) -> str:
    s = "" if value is None else str(value)
    if "\n" in s:
        indented = "\n  ".join(s.splitlines())
        return f"|\n  {indented}"
    if any(c in s for c in ":#&*?|>!%@`") or s.startswith(("[", "{", "-", '"', "'")):
        return f'"{s}"'
    return s


# ── Decision log ──────────────────────────────────────────────────────


def decisions_path(source_id: str) -> Path:
    return DECISIONS_DIR / f"{source_id}.log"


def decisions_read(source_id: str) -> list[tuple[str, str, str, str]]:
    p = decisions_path(source_id)
    if not p.exists():
        return []
    rows: list[tuple[str, str, str, str]] = []
    for line in p.read_text().splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        parts = line.split("\t")
        while len(parts) < 4:
            parts.append("")
        rows.append((parts[0], parts[1], parts[2], parts[3]))
    return rows


def decisions_append(source_id: str, sha: str, decision: str, note: str = "") -> None:
    DECISIONS_DIR.mkdir(parents=True, exist_ok=True)
    p = decisions_path(source_id)
    iso = _dt.datetime.now(_dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    with p.open("a") as fh:
        fh.write(f"{sha}\t{decision}\t{iso}\t{note}\n")


def decisions_index(source_id: str) -> dict[str, str]:
    """sha -> decision (last one wins)."""
    out: dict[str, str] = {}
    for sha, dec, _, _ in decisions_read(source_id):
        out[sha] = dec
    return out


def is_resolved(decision: str) -> bool:
    """A decision counts for cursor advance only when finalized."""
    if decision in ("accept", "skip"):
        return True
    if decision.startswith("cherry-picked:") and decision != "cherry-picked:<pending>":
        return True
    return False


# ── git wrappers ──────────────────────────────────────────────────────


def cache_path(source_id: str) -> Path:
    return CACHE_DIR / f"{source_id}.git"


def git(*args: str, cwd: Path | None = None, check: bool = True,
        capture: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *args],
        cwd=str(cwd) if cwd else None,
        check=check,
        capture_output=capture,
        text=True,
    )


def ensure_clone(src: dict[str, Any]) -> Path:
    cache = cache_path(src["id"])
    if not cache.exists():
        cache.parent.mkdir(parents=True, exist_ok=True)
        print(f"  cloning {src['repo']} → {cache.relative_to(ROOT)}")
        git("clone", "--bare", "--filter=blob:none", src["repo"], str(cache),
            capture=False)
    return cache


def fetch_origin(src: dict[str, Any]) -> Path:
    cache = ensure_clone(src)
    print(f"  fetching origin/{src['branch']}")
    git("fetch", "--quiet", "origin", src["branch"], cwd=cache)
    return cache


def resolve_ref(cache: Path, ref: str) -> str:
    return git("rev-parse", ref, cwd=cache).stdout.strip()


def commits_between(cache: Path, old: str, new: str, subpath: str) -> list[dict[str, str]]:
    """Return commits in old..new that touched files inside subpath."""
    if not old:
        return []
    if old == new:
        return []
    fmt = "%H%x1f%an%x1f%ae%x1f%ad%x1f%s"
    out = git(
        "log", "--reverse", "--name-only",
        f"--pretty=format:{fmt}",
        f"{old}..{new}",
        "--", subpath,
        cwd=cache,
    ).stdout
    commits: list[dict[str, str]] = []
    current: dict[str, Any] | None = None
    for raw in out.splitlines():
        if not raw.strip():
            if current is not None:
                commits.append(current)
                current = None
            continue
        if "\x1f" in raw:
            if current is not None:
                commits.append(current)
            sha, name, email, date, subject = raw.split("\x1f", 4)
            current = {
                "sha": sha,
                "author": f"{name} <{email}>",
                "date": date,
                "subject": subject,
                "files": [],
            }
        elif current is not None:
            current["files"].append(raw)
    if current is not None:
        commits.append(current)
    return commits


def show_commit(cache: Path, sha: str, subpath: str) -> str:
    return git("show", "--format=fuller", sha, "--", subpath, cwd=cache).stdout


# ── cursor advance ────────────────────────────────────────────────────


def advance_cursor(src: dict[str, Any]) -> str:
    """Walk decision log forward through contiguous resolved rows.

    Returns the new reviewed-rev. Caller must persist the manifest.
    """
    cache = cache_path(src["id"])
    if not cache.exists():
        return src.get("reviewed-rev", "")
    decisions = decisions_index(src["id"])
    cursor = src.get("reviewed-rev", "") or ""
    upstream = src.get("upstream-rev", "") or ""
    if not cursor or not upstream or cursor == upstream:
        return cursor
    pending = commits_between(cache, cursor, upstream, src["subpath"])
    for commit in pending:
        sha = commit["sha"]
        decision = decisions.get(sha, "")
        if is_resolved(decision):
            cursor = sha
            continue
        break
    return cursor


def utc_now_iso() -> str:
    return _dt.datetime.now(_dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
