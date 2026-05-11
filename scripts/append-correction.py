#!/usr/bin/env python3
"""Append a single correction entry to the improvement-memory JSONL.

Default path: ${XDG_STATE_HOME:-$HOME/.local/state}/jylhis-skills/improvement-memory.jsonl
"""

from __future__ import annotations

import argparse
import fcntl
import json
import os
import sys
from datetime import datetime
from pathlib import Path
from typing import Any, Final, NoReturn

EXIT_USAGE: Final[int] = 2
EXIT_VALIDATION: Final[int] = 3
EXIT_IO: Final[int] = 4

SCHEMA_VERSION: Final[int] = 1
CATEGORIES: Final[frozenset[str]] = frozenset(
    {"behavior", "scope", "trigger", "output_format", "other"}
)
REQUIRED_KEYS: Final[tuple[str, ...]] = (
    "schema_version", "timestamp", "session_id", "skill",
    "category", "what_went_wrong", "correction", "proposed_skill_change",
)
NULLABLE_STR_KEYS: Final[frozenset[str]] = frozenset({"session_id", "skill", "proposed_skill_change"})
NON_NULL_STR_KEYS: Final[frozenset[str]] = frozenset({"timestamp", "category", "what_went_wrong", "correction"})


def _fail(msg: str, code: int) -> NoReturn:
    print(f"append-correction: {msg}", file=sys.stderr)
    sys.exit(code)


def _validate(obj: Any) -> dict[str, Any]:  # noqa: ANN401 - JSON input is dynamic
    if not isinstance(obj, dict):
        _fail("top-level JSON value must be an object", EXIT_VALIDATION)
    missing = [k for k in REQUIRED_KEYS if k not in obj]
    if missing:
        _fail(f"missing required keys: {', '.join(missing)}", EXIT_VALIDATION)
    extra = [k for k in obj if k not in REQUIRED_KEYS]
    if extra:
        _fail(f"unknown keys: {', '.join(extra)}", EXIT_VALIDATION)
    if obj["schema_version"] != SCHEMA_VERSION:
        _fail(f"schema_version must be {SCHEMA_VERSION}, got {obj['schema_version']!r}", EXIT_VALIDATION)
    if obj["category"] not in CATEGORIES:
        _fail(f"category must be one of {sorted(CATEGORIES)}, got {obj['category']!r}", EXIT_VALIDATION)
    for key in NULLABLE_STR_KEYS:
        val = obj[key]
        if val is not None and not isinstance(val, str):
            _fail(f"{key} must be string or null, got {type(val).__name__}", EXIT_VALIDATION)
    for key in NON_NULL_STR_KEYS:
        val = obj[key]
        if not isinstance(val, str) or not val:
            _fail(f"{key} must be a non-empty string", EXIT_VALIDATION)
    ts = obj["timestamp"]
    assert isinstance(ts, str)
    try:
        datetime.fromisoformat(ts.replace("Z", "+00:00"))
    except ValueError as exc:
        _fail(f"timestamp not RFC3339/ISO-8601: {exc}", EXIT_VALIDATION)
    return obj


def _default_path() -> Path:
    raw = os.environ.get("XDG_STATE_HOME")
    base = Path(raw) if raw else Path.home() / ".local" / "state"
    return base / "jylhis-skills" / "improvement-memory.jsonl"


def _append(path: Path, obj: dict[str, Any]) -> None:
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
    except OSError as exc:
        _fail(f"cannot create {path.parent}: {exc.strerror or exc}", EXIT_IO)
    line = json.dumps(obj, sort_keys=True, ensure_ascii=False, separators=(",", ":")) + "\n"
    try:
        fd = os.open(str(path), os.O_APPEND | os.O_CREAT | os.O_WRONLY, 0o600)
    except OSError as exc:
        _fail(f"cannot open {path}: {exc.strerror or exc}", EXIT_IO)
    try:
        try:
            fcntl.flock(fd, fcntl.LOCK_EX)
            os.write(fd, line.encode("utf-8"))
        except OSError as exc:
            _fail(f"write failed on {path}: {exc.strerror or exc}", EXIT_IO)
    finally:
        os.close(fd)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="append-correction.py",
        description="Append a single correction entry to the improvement-memory JSONL.",
        epilog=(
            "Schema v1 keys: schema_version (=1), timestamp (RFC3339 UTC), session_id, "
            "skill, category (behavior|scope|trigger|output_format|other), what_went_wrong, "
            "correction, proposed_skill_change. Default path: "
            "${XDG_STATE_HOME:-$HOME/.local/state}/jylhis-skills/improvement-memory.jsonl. "
            "Exit codes: 0 OK, 2 usage, 3 validation, 4 IO."
        ),
    )
    parser.add_argument("--json", dest="payload", required=True, metavar="(- | <inline-json>)",
                        help="JSON object to append. Use '-' to read from stdin.")
    parser.add_argument("--path", type=Path, default=None, help="Override the default JSONL path.")
    args = parser.parse_args(argv)
    raw = sys.stdin.read() if args.payload == "-" else args.payload
    if not raw.strip():
        _fail("no JSON provided", EXIT_VALIDATION)
    try:
        parsed: Any = json.loads(raw)
    except json.JSONDecodeError as exc:
        _fail(f"invalid JSON: {exc.msg} (line {exc.lineno}, col {exc.colno})", EXIT_VALIDATION)
    target = args.path if args.path is not None else _default_path()
    _append(target, _validate(parsed))
    print(f"appended to {target}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
