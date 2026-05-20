#!/usr/bin/env python3
"""Pre-flight invariant lint for the eval harness.

Runs before every `promptfoo eval`. Rejects:

- `--judge` resolves to the same wrapper as `--provider` (self-bias).
- `--judge` resolves to the same `family` token as `--provider`
  (e.g. Pi configured to route to Claude judging Claude). Family is
  read by invoking `evals/providers/run_<name>.sh --print-family`.
- `trigger_*` cases scheduled against non-Claude providers without an
  explicit `cases[].providers` override.
- any `trigger_negative` whose prompt does not contain a
  `near_miss_vocabulary` term.
- committed `golden/*.json` lacking the required provenance keys
  (`cli`, `cli_version`, `model_snapshot`, `temperature`, `host`,
  `recorded_at`).
- cassettes older than 30 days (warning only, not a hard fail).

Exit non-zero with all errors printed.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

import yaml

from _paths import resolve_suite_dir

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
EVALS_DIR = REPO_ROOT / "evals"
PROVIDERS_DIR = EVALS_DIR / "providers"
JUDGES_DIR = EVALS_DIR / "judges"

CASSETTE_WARN_DAYS = 30


def provider_family(name: str, kind: str = "provider") -> str:
    """Read the family token a wrapper advertises via `--print-family`.

    `kind` is "provider" (uses run_<name>.sh) or "judge"
    (judge_<name>.sh). Falls back to a static map when the wrapper is
    not executable in this sandbox or doesn't implement the flag.
    """
    static_map = {
        "claude": "anthropic",
        "codex": "openai",
        "antigravity": "google",
        "pi": "unknown",  # Pi can route to any backend
        "stub": "stub",
    }
    script = (PROVIDERS_DIR if kind == "provider" else JUDGES_DIR) / (
        ("run_" if kind == "provider" else "judge_") + name + ".sh"
    )
    if script.exists():
        try:
            proc = subprocess.run(
                [str(script), "--print-family"],
                capture_output=True, text=True, timeout=5,
            )
            if proc.returncode == 0 and proc.stdout.strip():
                return proc.stdout.strip()
        except (OSError, subprocess.TimeoutExpired):
            pass
    return static_map.get(name, "unknown")


def check_cross_judge(provider: str, judge: str) -> list[str]:
    errors: list[str] = []
    # Stubs are deterministic replays — no model is learning anything,
    # so the self-bias / same-family checks don't apply.
    if "stub" in (provider, judge):
        return errors
    if provider == judge:
        errors.append(
            f"cross-judge invariant: --provider and --judge are both {provider!r}; "
            "self-judging inflates win rates 5–15pp (Doc 2 §5)."
        )
        return errors
    p_fam = provider_family(provider, "provider")
    j_fam = provider_family(judge, "judge")
    if p_fam != "unknown" and p_fam == j_fam:
        errors.append(
            f"same-family invariant: provider {provider!r} ({p_fam}) and "
            f"judge {judge!r} ({j_fam}) are the same model family. Pick a "
            "different vendor for the judge."
        )
    return errors


def _check_near_miss(case: dict) -> list[str]:
    cid = case.get("id", "<unnamed>")
    vocab = case.get("near_miss_vocabulary") or []
    if not vocab:
        return [f"{cid}: trigger_negative requires near_miss_vocabulary (Doc 2 §4)."]
    prompt = (case.get("prompt") or "").lower()
    if any(term.lower() in prompt for term in vocab):
        return []
    return [
        f"{cid}: trigger_negative prompt does not contain any "
        f"near_miss_vocabulary term {vocab!r}; this is not a near-miss, "
        "it's an off-topic prompt."
    ]


def _check_trigger_providers(case: dict) -> list[str]:
    providers = case.get("providers")
    if not providers or all(p == "claude" for p in providers):
        return []
    cid = case.get("id", "<unnamed>")
    return [
        f"{cid}: trigger_* cases default to claude only; non-claude "
        f"providers in {providers!r} require documented justification — "
        "set providers: [claude] or remove the kind tag."
    ]


def _check_one_case(case: dict) -> list[str]:
    kind = case.get("kind")
    errors: list[str] = []
    if kind == "trigger_negative":
        errors.extend(_check_near_miss(case))
    if kind in ("trigger_positive", "trigger_negative"):
        errors.extend(_check_trigger_providers(case))
    return errors


def check_cases(suite: str) -> list[str]:
    try:
        cases_path = resolve_suite_dir(suite) / "cases.yaml"
    except FileNotFoundError as exc:
        return [str(exc)]
    raw = yaml.safe_load(cases_path.read_text(encoding="utf-8")) or {}
    return [msg for case in raw.get("cases", []) for msg in _check_one_case(case)]


def check_goldens(suite: str) -> list[tuple[str, Path, list[str]]]:
    """Return a list of (severity, path, messages) tuples."""
    out: list[tuple[str, Path, list[str]]] = []
    try:
        golden_dir = resolve_suite_dir(suite) / "golden"
    except FileNotFoundError:
        return out
    if not golden_dir.exists():
        return out
    for path in sorted(golden_dir.glob("*.json")):
        if path.name.endswith(".judge.json"):
            continue
        try:
            envelope = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            out.append(("error", path, [f"invalid JSON: {exc}"]))
            continue

        # Lazy import to avoid a hard dep when only checking cases.yaml.
        from cassette import validate_provenance, cassette_age_days

        msgs = validate_provenance(envelope)
        if msgs:
            out.append(("error", path, msgs))
        prov = envelope.get("provenance") or {}
        if prov.get("cli") == "synthetic-bootstrap":
            # Synthetic placeholders carry an epoch timestamp on purpose;
            # they advertise themselves via cli="synthetic-bootstrap".
            # Surface a single one-shot reminder per run, not per file.
            out.append(("synthetic", path, ["synthetic-bootstrap placeholder"]))
            continue
        age = cassette_age_days(envelope)
        if age is not None and age > CASSETTE_WARN_DAYS:
            out.append(("warning", path, [f"cassette age {age:.0f}d > {CASSETTE_WARN_DAYS}d"]))
    return out


def main() -> int:
    parser = argparse.ArgumentParser(prog="invariants.py")
    parser.add_argument("--provider", required=True)
    parser.add_argument("--judge", required=True)
    parser.add_argument("--suite", required=True)
    args = parser.parse_args()

    sys.path.insert(0, str(EVALS_DIR / "scripts"))

    errors: list[str] = []
    errors.extend(check_cross_judge(args.provider, args.judge))
    errors.extend(check_cases(args.suite))

    warnings: list[str] = []
    synthetic_count = 0
    for severity, path, msgs in check_goldens(args.suite):
        rel = path.relative_to(REPO_ROOT)
        if severity == "synthetic":
            synthetic_count += 1
            continue
        for m in msgs:
            line = f"{rel}: {m}"
            if severity == "error":
                errors.append(line)
            else:
                warnings.append(line)

    for w in warnings:
        print(f"warning: {w}", file=sys.stderr)
    if synthetic_count:
        print(
            f"warning: {synthetic_count} synthetic-bootstrap cassette(s) in "
            "play; replace with real recordings via `just eval-record` "
            "before treating any score as a measurement.",
            file=sys.stderr,
        )
    if errors:
        for e in errors:
            print(f"error: {e}", file=sys.stderr)
        print(f"\ninvariants.py: {len(errors)} error(s), {len(warnings)} warning(s)",
              file=sys.stderr)
        return 1

    print(f"invariants.py: OK (suite={args.suite}, provider={args.provider}, "
          f"judge={args.judge}, warnings={len(warnings)}, "
          f"synthetic={synthetic_count})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
