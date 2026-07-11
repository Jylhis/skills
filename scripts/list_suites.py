#!/usr/bin/env python3
"""List co-located eval suites, one skill name per line, sorted.

A suite is any ``skills/<category>/<name>/evals/cases.yaml``; the suite
name is the owning skill directory's basename. Exits 1 with a message
on stderr when no suites exist, so shell loops over the output cannot
silently pass on an empty result. Stdlib only; no third-party deps.
"""
from __future__ import annotations

import sys
from pathlib import Path

REPO_ROOT: Path = Path(__file__).resolve().parent.parent
SKILLS_DIR: Path = REPO_ROOT / "skills"


def discover_suites() -> list[str]:
    return sorted(p.parent.parent.name for p in SKILLS_DIR.glob("*/*/evals/cases.yaml"))


def main() -> int:
    suites = discover_suites()
    if not suites:
        print(
            "list_suites.py: no eval suites found under skills/*/*/evals/cases.yaml",
            file=sys.stderr,
        )
        return 1
    for suite in suites:
        print(suite)
    return 0


if __name__ == "__main__":
    sys.exit(main())
