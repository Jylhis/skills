#!/usr/bin/env python3
"""Validate skill directories for structure and risky instruction patterns."""
from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path

TOOL_TOKEN_RE = re.compile(r"^[A-Za-z][A-Za-z0-9_-]{0,63}$")
BANNED_PATTERNS: list[tuple[str, re.Pattern[str], str]] = [
    ("remote-execution", re.compile(r"(?:curl|wget)\s+[^\n|]+\|\s*(?:bash|sh|zsh)"), "Avoid pipe-to-shell; download and inspect before executing."),
    ("obfuscated-exec", re.compile(r"(?:base64\s+-d|python\s+-c).*\|\s*(?:bash|sh)\b"), "Remove obfuscated execution chains and provide transparent commands."),
    ("prompt-exfiltration", re.compile(r"ignore (?:all|previous) instructions", re.IGNORECASE), "Do not include instruction-override or exfiltration language in skills."),
]

@dataclass(frozen=True)
class Finding:
    path: Path
    message: str


def parse_frontmatter(text: str) -> dict[str, str] | None:
    if not text.startswith("---\n"):
        return None
    end = text.find("\n---\n", 4)
    if end == -1:
        return None
    block = text[4:end].strip().splitlines()
    data: dict[str, str] = {}
    current_key: str | None = None
    for line in block:
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if line.startswith((" ", "\t")):
            if current_key is None:
                raise ValueError(f"Unparseable frontmatter line: {line}")
            data[current_key] = (data[current_key] + " " + line.strip()).strip()
            continue
        if ":" not in line:
            raise ValueError(f"Unparseable frontmatter line: {line}")
        k, v = line.split(":", 1)
        current_key = k.strip()
        data[current_key] = v.strip().strip('"')
    return data


def validate_tool_syntax(path: Path, text: str, findings: list[Finding]) -> None:
    for i, line in enumerate(text.splitlines(), start=1):
        if "allowedTools" not in line:
            continue
        m = re.search(r"allowedTools\s*[=:]\s*[\"']([^\"']+)[\"']", line)
        if not m:
            findings.append(Finding(path, f"{path}:{i}: malformed allowedTools declaration"))
            continue
        tokens = [t for t in re.split(r"[\s,]+", m.group(1).strip()) if t]
        bad = [t for t in tokens if not TOOL_TOKEN_RE.match(t)]
        if bad:
            findings.append(Finding(path, f"{path}:{i}: invalid tool token(s): {', '.join(bad)}"))


def validate_skill_dir(skill_dir: Path, findings: list[Finding]) -> None:
    skill_file = skill_dir / "SKILL.md"
    if not skill_file.exists():
        findings.append(Finding(skill_dir, f"{skill_dir}: missing required SKILL.md"))
        return

    text = skill_file.read_text(encoding="utf-8")
    fm = parse_frontmatter(text)
    if fm is None:
        findings.append(Finding(skill_file, f"{skill_file}: missing or unclosed YAML frontmatter"))
    else:
        for key in ("name", "description"):
            if key not in fm or not fm[key].strip():
                findings.append(Finding(skill_file, f"{skill_file}: frontmatter missing required field '{key}'"))

    validate_tool_syntax(skill_file, text, findings)

    for path in skill_dir.rglob("*"):
        if not path.is_file() or path.suffix.lower() not in {".md", ".sh", ".py", ".yml", ".yaml", ".json"}:
            continue
        content = path.read_text(encoding="utf-8", errors="replace")
        for label, pattern, remediation in BANNED_PATTERNS:
            for i, line in enumerate(content.splitlines(), start=1):
                if pattern.search(line):
                    findings.append(Finding(path, f"{path}:{i}: [{label}] {line.strip()}\n  remediation: {remediation}"))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default="skills", help="Directory containing skill subdirectories")
    args = parser.parse_args()

    root = Path(args.root)
    if not root.exists():
        print(f"error: root not found: {root}", file=sys.stderr)
        return 1

    findings: list[Finding] = []
    for child in sorted(root.iterdir()):
        if child.is_dir() and not child.name.startswith("."):
            validate_skill_dir(child, findings)

    if findings:
        print("Skill validation failed with actionable findings:\n")
        for finding in findings:
            print(f"- {finding.message}")
        return 2

    print(f"Skill validation passed for {root}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
