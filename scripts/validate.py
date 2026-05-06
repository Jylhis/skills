#!/usr/bin/env python3
"""Portable SKILL.md lint.

Walks `skills/` (skipping `staging/`) and validates every SKILL.md against
the portability profile from docs/skills-spec-v3.md §6.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SKILLS_DIR = REPO_ROOT / "skills"

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


def parse_frontmatter(text: str) -> tuple[dict, str] | None:
    """Return (frontmatter_dict, body) or None if no frontmatter."""
    if not text.startswith("---\n"):
        return None
    end = text.find("\n---\n", 4)
    if end == -1:
        return None
    fm_text = text[4:end]
    body = text[end + 5:]

    # Minimal YAML parser: supports `key: value` and `key:` followed by
    # indented block scalar / mapping. Good enough for the allowed keys.
    fm: dict = {}
    current_key: str | None = None
    block_lines: list[str] = []
    for line in fm_text.splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if line[0] not in (" ", "\t") and ":" in line:
            if current_key is not None and block_lines:
                fm[current_key] = "\n".join(block_lines).strip()
                block_lines = []
            key, _, val = line.partition(":")
            key = key.strip()
            val = val.strip()
            if val in ("|", ">", ""):
                current_key = key
                block_lines = []
                if val == "":
                    fm[key] = ""
            else:
                fm[key] = val.strip("\"'")
                current_key = None
        elif current_key is not None:
            block_lines.append(line.lstrip())
    if current_key is not None and block_lines:
        fm[current_key] = "\n".join(block_lines).strip()
    return fm, body


def validate_skill(skill_md: Path) -> list[str]:
    errors: list[str] = []
    rel = skill_md.relative_to(REPO_ROOT)
    raw = skill_md.read_bytes()

    if raw.startswith(b"\xef\xbb\xbf"):
        errors.append(f"{rel}: BOM detected; files must be UTF-8 without BOM")
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError as exc:
        errors.append(f"{rel}: not valid UTF-8: {exc}")
        return errors
    if "\r\n" in text:
        errors.append(f"{rel}: CRLF line endings; use LF")

    parsed = parse_frontmatter(text)
    if parsed is None:
        errors.append(f"{rel}: missing or malformed YAML frontmatter (must start with `---`)")
        return errors
    fm, body = parsed

    name = fm.get("name", "")
    expected_name = skill_md.parent.name
    if not name:
        errors.append(f"{rel}: missing `name`")
    elif name != expected_name:
        errors.append(f"{rel}: name `{name}` does not match dir basename `{expected_name}`")
    elif not NAME_RE.match(name):
        errors.append(f"{rel}: name `{name}` must be lowercase letters/numbers/hyphens, no leading/trailing/consecutive hyphens")

    desc = fm.get("description", "")
    if not desc:
        errors.append(f"{rel}: missing `description`")
    else:
        n = len(desc)
        if n < DESC_MIN or n > DESC_MAX:
            errors.append(f"{rel}: description length {n} out of range [{DESC_MIN}, {DESC_MAX}]")

    rejected = set(fm.keys()) & REJECTED_FRONTMATTER_KEYS
    if rejected:
        errors.append(f"{rel}: rejected target-specific frontmatter keys: {sorted(rejected)}")

    unknown = set(fm.keys()) - ALLOWED_FRONTMATTER_KEYS - REJECTED_FRONTMATTER_KEYS
    if unknown:
        errors.append(f"{rel}: unknown frontmatter keys: {sorted(unknown)} (allowed: {sorted(ALLOWED_FRONTMATTER_KEYS)})")

    for pat in REJECTED_BODY_PATTERNS:
        m = pat.search(body)
        if m:
            errors.append(f"{rel}: rejected target-specific syntax in body: {m.group(0)!r}")

    return errors


def main() -> int:
    if not SKILLS_DIR.is_dir():
        print(f"validate.py: skills/ not found at {SKILLS_DIR}", file=sys.stderr)
        return 1

    skill_files = sorted(SKILLS_DIR.glob("*/SKILL.md"))
    if not skill_files:
        print("validate.py: no skills to validate (skills/ is empty)")
        return 0

    all_errors: list[str] = []
    for skill_md in skill_files:
        all_errors.extend(validate_skill(skill_md))

    if all_errors:
        for err in all_errors:
            print(err, file=sys.stderr)
        print(f"\nvalidate.py: {len(all_errors)} error(s) across {len(skill_files)} skill(s)", file=sys.stderr)
        return 1

    print(f"validate.py: OK ({len(skill_files)} skill(s))")
    return 0


if __name__ == "__main__":
    sys.exit(main())
