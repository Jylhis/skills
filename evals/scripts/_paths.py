"""Suite path resolution for co-located evals.

Each eval suite lives at ``skills/<category>/<name>/evals/`` next to the
skill it exercises. Suite names (the ``--suite`` CLI argument and the
``EVAL_SUITE`` env var) remain a single token like ``ast-grep`` —
the resolver globs the canonical skill tree to find the owning dir.

Skill names are globally unique (enforced by ``scripts/validate.py``)
so a single-token suite name is unambiguous.
"""
from __future__ import annotations

from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
SKILLS_DIR = REPO_ROOT / "skills"


def resolve_suite_dir(suite: str) -> Path:
    """Return ``skills/<category>/<suite>/evals/`` for ``suite``.

    Raises ``FileNotFoundError`` if no matching ``cases.yaml`` exists.
    """
    matches = sorted(SKILLS_DIR.glob(f"*/{suite}/evals/cases.yaml"))
    if not matches:
        raise FileNotFoundError(
            f"no skill evals dir found for suite={suite!r} "
            f"(looked under skills/*/{suite}/evals/cases.yaml)"
        )
    if len(matches) > 1:
        raise RuntimeError(
            f"multiple skills claim suite={suite!r}: {matches}"
        )
    return matches[0].parent


def discover_suites() -> list[str]:
    """List every co-located eval suite by its skill name."""
    return sorted(p.parent.parent.name for p in SKILLS_DIR.glob("*/*/evals/cases.yaml"))
