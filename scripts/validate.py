#!/usr/bin/env python3
"""Portable SKILL.md lint.

Walks `skills/` at two levels deep (`skills/<category>/<name>/SKILL.md`) and
validates every SKILL.md against the portability profile from
docs/skills-spec-v3.md §6.

Also cross-checks that every discovered skill path is listed in
`.claude-plugin/plugin.json`.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SKILLS_DIR = REPO_ROOT / "skills"
PLUGIN_JSON = REPO_ROOT / ".claude-plugin" / "plugin.json"
UPSTREAM_MANIFEST = REPO_ROOT / "upstream" / "sources.yaml"

NAME_RE = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
DESC_MIN = 50
DESC_MAX = 1024

ALLOWED_FRONTMATTER_KEYS = {"name", "description", "license", "compatibility", "metadata"}

REJECTED_FRONTMATTER_KEYS = {
    "allowed-tools", "disable-model-invocation", "user-invocable",
    "argument-hint", "arguments", "paths", "hooks", "context", "agent",
    "model", "effort", "tools", "disallowedTools", "mcpServers",
    "permissionMode", "isolation", "shell",
}

REJECTED_BODY_PATTERNS = [
    re.compile(r"\$\{CLAUDE_PLUGIN_ROOT\}"),
    re.compile(r"\$\{CLAUDE_SKILL_DIR\}"),
    re.compile(r"\$\{extensionPath\}"),
    re.compile(r"\$\{workspacePath\}"),
    re.compile(r"!`[^`]*`"),
    re.compile(r"!\{[^}]*\}"),
]

BLOCK_SCALAR_INDICATORS = ("|", ">", "")


# ── Frontmatter parsing ────────────────────────────────────────────────


def _split_frontmatter(text: str) -> tuple[str, str] | None:
    if not text.startswith("---\n"):
        return None
    end = text.find("\n---\n", 4)
    if end == -1:
        return None
    return text[4:end], text[end + 5:]


def _is_skippable(line: str) -> bool:
    return not line.strip() or line.lstrip().startswith("#")


def _is_top_level_key(line: str) -> bool:
    return bool(line) and line[0] not in (" ", "\t") and ":" in line


def _flush_block(fm: dict, key: str | None, block: list[str]) -> None:
    if key is not None and block:
        fm[key] = "\n".join(block).strip()


def _handle_top_level(line: str, fm: dict) -> str | None:
    key, _, val = line.partition(":")
    key, val = key.strip(), val.strip()
    if val in BLOCK_SCALAR_INDICATORS:
        if val == "":
            fm[key] = ""
        return key
    fm[key] = val.strip("\"'")
    return None


def _parse_yaml_lines(fm_text: str) -> dict:
    fm: dict = {}
    current_key: str | None = None
    block: list[str] = []

    for line in fm_text.splitlines():
        if _is_skippable(line):
            continue
        if _is_top_level_key(line):
            _flush_block(fm, current_key, block)
            block = []
            current_key = _handle_top_level(line, fm)
        elif current_key is not None:
            block.append(line.lstrip())

    _flush_block(fm, current_key, block)
    return fm


def parse_frontmatter(text: str) -> tuple[dict, str] | None:
    split = _split_frontmatter(text)
    if split is None:
        return None
    fm_text, body = split
    return _parse_yaml_lines(fm_text), body


# ── Per-skill checks ───────────────────────────────────────────────────


def _check_encoding(rel: Path, raw: bytes) -> tuple[list[str], str | None]:
    errors: list[str] = []
    if raw.startswith(b"\xef\xbb\xbf"):
        errors.append(f"{rel}: BOM detected; files must be UTF-8 without BOM")
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError as exc:
        errors.append(f"{rel}: not valid UTF-8: {exc}")
        return errors, None
    if "\r\n" in text:
        errors.append(f"{rel}: CRLF line endings; use LF")
    return errors, text


def _check_name(rel: Path, name: str, expected: str) -> list[str]:
    if not name:
        return [f"{rel}: missing `name`"]
    if name != expected:
        return [f"{rel}: name `{name}` does not match dir basename `{expected}`"]
    if not NAME_RE.match(name):
        return [f"{rel}: name `{name}` must be lowercase letters/numbers/hyphens, no leading/trailing/consecutive hyphens"]
    return []


def _check_description(rel: Path, desc: str) -> list[str]:
    if not desc:
        return [f"{rel}: missing `description`"]
    n = len(desc)
    if n < DESC_MIN or n > DESC_MAX:
        return [f"{rel}: description length {n} out of range [{DESC_MIN}, {DESC_MAX}]"]
    return []


def _check_frontmatter_keys(rel: Path, keys: set[str]) -> list[str]:
    errors: list[str] = []
    rejected = keys & REJECTED_FRONTMATTER_KEYS
    if rejected:
        errors.append(f"{rel}: rejected target-specific frontmatter keys: {sorted(rejected)}")
    unknown = keys - ALLOWED_FRONTMATTER_KEYS - REJECTED_FRONTMATTER_KEYS
    if unknown:
        errors.append(f"{rel}: unknown frontmatter keys: {sorted(unknown)} (allowed: {sorted(ALLOWED_FRONTMATTER_KEYS)})")
    return errors


def _check_body(rel: Path, body: str) -> list[str]:
    errors: list[str] = []
    for pat in REJECTED_BODY_PATTERNS:
        m = pat.search(body)
        if m:
            errors.append(f"{rel}: rejected target-specific syntax in body: {m.group(0)!r}")
    return errors


def validate_skill(skill_md: Path) -> list[str]:
    rel = skill_md.relative_to(REPO_ROOT)
    encoding_errors, text = _check_encoding(rel, skill_md.read_bytes())
    if text is None:
        return encoding_errors

    parsed = parse_frontmatter(text)
    if parsed is None:
        return encoding_errors + [f"{rel}: missing or malformed YAML frontmatter (must start with `---`)"]
    fm, body = parsed

    return [
        *encoding_errors,
        *_check_name(rel, fm.get("name", ""), skill_md.parent.name),
        *_check_description(rel, fm.get("description", "")),
        *_check_frontmatter_keys(rel, set(fm.keys())),
        *_check_body(rel, body),
    ]


# ── plugin.json cross-check ────────────────────────────────────────────


def check_plugin_json(skill_files: list[Path]) -> list[str]:
    """Warn about skills missing from .claude-plugin/plugin.json."""
    if not PLUGIN_JSON.exists():
        return [f"{PLUGIN_JSON.relative_to(REPO_ROOT)}: file not found"]

    try:
        manifest = json.loads(PLUGIN_JSON.read_text())
    except json.JSONDecodeError as exc:
        return [f"{PLUGIN_JSON.relative_to(REPO_ROOT)}: invalid JSON: {exc}"]

    listed = {
        (REPO_ROOT / p.lstrip("./")).resolve()
        for p in manifest.get("skills", [])
    }
    errors: list[str] = []
    for skill_md in skill_files:
        skill_dir = skill_md.parent.resolve()
        if skill_dir not in listed:
            rel = skill_md.parent.relative_to(REPO_ROOT)
            errors.append(
                f"{rel}: not listed in .claude-plugin/plugin.json"
                f' (add \"./skills/{rel}\")'
            )
    return errors


# ── Optional: upstream-tracker advisory pass ───────────────────────────


def _start_new_source(body: str) -> str | None:
    inner = body[2:].lstrip()
    if not inner.startswith("id:"):
        return None
    return inner.split(":", 1)[1].strip().strip('"\'')


def _parse_field(body: str) -> tuple[str, str]:
    k, _, v = body.partition(":")
    return k.strip(), v.strip().strip('"\'')


def _read_manifest_ids() -> tuple[set[str], dict[str, str]]:
    """Return ({source-ids}, {id: reviewed-rev}) from upstream/sources.yaml.

    Restricted parser identical in shape to skills/meta/upstream-tracker/
    scripts/_lib.py — keeps validate.py dependency-free.
    """
    ids: set[str] = set()
    reviewed: dict[str, str] = {}
    current_id: str | None = None
    in_skills = False

    for raw in UPSTREAM_MANIFEST.read_text().splitlines():
        line = raw.rstrip()
        stripped = line.strip()
        if not stripped or stripped.startswith("#") or line == "sources:":
            continue
        ind = len(line) - len(line.lstrip(" "))

        if ind == 2 and stripped.startswith("- "):
            current_id = _start_new_source(stripped)
            if current_id:
                ids.add(current_id)
            in_skills = False
            continue
        if current_id is None or in_skills:
            if ind == 4 and stripped == "skills:":
                in_skills = True
            continue
        if ind == 4 and stripped == "skills:":
            in_skills = True
            continue
        if ind == 4 and ":" in stripped:
            key, value = _parse_field(stripped)
            if key == "reviewed-rev":
                reviewed[current_id] = value
    return ids, reviewed


def _extract_metadata(fm: dict) -> dict:
    raw = fm.get("metadata")
    if isinstance(raw, dict):
        return raw
    if not isinstance(raw, str) or not raw.strip():
        return {}
    out: dict[str, str] = {}
    for line in raw.splitlines():
        if ":" in line:
            k, _, v = line.partition(":")
            out[k.strip()] = v.strip().strip('"\'')
    return out


def _check_upstream_advisory(skill_files: list[Path], strict: bool) -> tuple[int, int]:
    """Returns (warnings, hard_errors).

    Advisory by default: emits to stderr and never raises the exit code.
    Strict mode promotes warnings to hard errors.
    """
    if not UPSTREAM_MANIFEST.exists():
        return 0, 0
    try:
        ids, reviewed = _read_manifest_ids()
    except (OSError, ValueError) as exc:
        print(f"validate.py: cannot parse {UPSTREAM_MANIFEST.relative_to(REPO_ROOT)}: {exc}",
              file=sys.stderr)
        return 0, (1 if strict else 0)

    warnings = sum(
        _check_one_upstream(skill_md, ids, reviewed) for skill_md in skill_files
    )
    return warnings, (warnings if strict else 0)


def _check_one_upstream(skill_md: Path, ids: set[str], reviewed: dict[str, str]) -> int:
    parsed = parse_frontmatter(skill_md.read_text(errors="replace"))
    if parsed is None:
        return 0
    fm, _ = parsed
    meta = _extract_metadata(fm)
    upstream_id = meta.get("upstream-id")
    if not upstream_id:
        return 0
    rel = skill_md.relative_to(REPO_ROOT)
    if upstream_id not in ids:
        print(f"{rel}: upstream-id {upstream_id!r} not in upstream/sources.yaml",
              file=sys.stderr)
        return 1
    skill_rev = meta.get("upstream-rev", "")
    cursor = reviewed.get(upstream_id, "")
    if cursor and skill_rev and not cursor.startswith(skill_rev) and not skill_rev.startswith(cursor):
        print(f"{rel}: baseline upstream-rev {skill_rev[:12]!r} differs from "
              f"manifest reviewed-rev {cursor[:12]!r} — backport may be due",
              file=sys.stderr)
        return 1
    return 0


# ── Entry point ────────────────────────────────────────────────────────


def main() -> int:
    strict_upstream = "--strict-upstream" in sys.argv[1:]

    if not SKILLS_DIR.is_dir():
        print(f"validate.py: skills/ not found at {SKILLS_DIR}", file=sys.stderr)
        return 1

    # Two-level glob: skills/<category>/<name>/SKILL.md
    skill_files = sorted(SKILLS_DIR.glob("*/*/SKILL.md"))
    if not skill_files:
        print("validate.py: no skills to validate (skills/ is empty)")
        return 0

    all_errors: list[str] = []
    for skill_md in skill_files:
        all_errors.extend(validate_skill(skill_md))

    all_errors.extend(check_plugin_json(skill_files))

    upstream_warnings, upstream_hard = _check_upstream_advisory(skill_files, strict_upstream)

    if all_errors:
        for err in all_errors:
            print(err, file=sys.stderr)
        print(f"\nvalidate.py: {len(all_errors)} error(s) across {len(skill_files)} skill(s)", file=sys.stderr)
        return 1

    if upstream_hard:
        print(f"\nvalidate.py: {upstream_hard} upstream advisory error(s) (strict mode)",
              file=sys.stderr)
        return 1

    suffix = ""
    if upstream_warnings:
        suffix = f"; {upstream_warnings} upstream advisory warning(s)"
    print(f"validate.py: OK ({len(skill_files)} skill(s)){suffix}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
