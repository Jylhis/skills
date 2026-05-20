#!/usr/bin/env python3
"""Seed synthetic golden cassettes so CI's `just eval-stub` can run
before any human has done a `just eval-record`. Each cassette is
clearly marked `provenance.cli = "synthetic-bootstrap"` so a reviewer
spots them and replaces them with real recordings.

Run once during the bootstrap commit, then delete or overwrite via
`just eval-record` when the developer is logged into a real CLI.

Usage:
    python3 evals/scripts/seed_synthetic.py <suite>
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(REPO_ROOT / "evals" / "scripts"))
from cassette import compute_key, write_cassette  # noqa: E402
from _paths import resolve_suite_dir  # noqa: E402

# Hand-tailored synthetic outputs that pass the deterministic asserts
# in skills/engineering/ast-grep/evals/cases.yaml. Keys are case ids.
SYNTHETIC_TEXT = {
    "trigger-pos-console-log":
        "Use ast-grep with a structural pattern:\n"
        "ast-grep -p 'console.log($ARG)' -l ts src/\n",
    "trigger-pos-codemod-var-let":
        "Run a codemod with ast-grep:\n"
        "ast-grep -p 'var $X = $V;' -r 'let $X = $V;' -l js src/\n",
    "trigger-pos-useState-no-default":
        "ast-grep can match React hook calls without arguments:\n"
        "ast-grep -p 'useState()' -l tsx src/\n",
    "trigger-neg-grep-todo":
        "Plain text search is fine here — use grep:\n"
        "grep -rn 'TODO' .\n",
    "trigger-neg-edit-config":
        "Open the file in your editor:\n"
        "$EDITOR sgconfig.yml\n",
    "trigger-neg-explain-comby":
        "ast-grep is tree-sitter-based and language-agnostic via "
        "language packs; Comby is parser-agnostic and uses a custom "
        "syntactic matcher. Both target structural search and rewrite, "
        "but ast-grep emphasises a YAML rule format and CI integration "
        "while Comby leans on its own DSL.\n",
    "output-quality-runnable-pattern":
        "ast-grep -p 'console.log($ARG)' -l ts src/\n",
    "output-quality-yaml-rule":
        "id: no-eval\n"
        "language: js\n"
        "rule:\n"
        "  pattern: eval($ARG)\n",
}

SYNTHETIC_TRIGGERED = {
    "trigger-pos-console-log": "ast-grep",
    "trigger-pos-codemod-var-let": "ast-grep",
    "trigger-pos-useState-no-default": "ast-grep",
    "trigger-neg-grep-todo": None,
    "trigger-neg-edit-config": None,
    "trigger-neg-explain-comby": None,
    "output-quality-runnable-pattern": "ast-grep",
    "output-quality-yaml-rule": "ast-grep",
}

FAMILY_BY_PROVIDER = {
    "claude": "anthropic",
    "codex": "openai",
    "antigravity": "google",
    "pi": "unknown",
}


def synthetic_provenance(provider: str) -> dict:
    return {
        "cli": "synthetic-bootstrap",
        "cli_version": "0.0.0",
        "model_snapshot": "default",
        "temperature": 0,
        "host": "synthetic",
        "platform": "synthetic",
        "recorded_at": "1970-01-01T00:00:00Z",
        "note": (
            "Synthetic placeholder so CI can run before a real "
            f"`just eval-record` against {provider}. Replace with real "
            "recording before treating any score as a measurement."
        ),
    }


def seed(suite: str) -> int:
    cases_path = resolve_suite_dir(suite) / "cases.yaml"
    raw = yaml.safe_load(cases_path.read_text(encoding="utf-8")) or {}
    written = 0
    for case in raw.get("cases", []):
        cid = case["id"]
        prompt = case["prompt"]
        text = SYNTHETIC_TEXT.get(cid)
        if text is None:
            print(f"warn: no synthetic text for case {cid}; skipping", file=sys.stderr)
            continue
        triggered = SYNTHETIC_TRIGGERED.get(cid)

        # Always seed all four providers so the promptfoo matrix has a
        # cassette for every cell.  The cases.yaml ``providers`` field is
        # a recording hint, not a matrix restriction.
        providers = ["claude", "codex", "antigravity", "pi"]

        for p in providers:
            key = compute_key(p, prompt, "default", None)
            envelope = {
                "text": text,
                "triggered": triggered,
                "elapsed_ms": 1234,
                "family": FAMILY_BY_PROVIDER.get(p, "unknown"),
                "provenance": synthetic_provenance(p),
            }
            path = write_cassette(suite, key, envelope)
            print(f"  {cid:<32} {p:<8} -> {path.relative_to(REPO_ROOT)}")
            written += 1

    print(f"seeded {written} synthetic cassettes for suite {suite!r}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("suite")
    args = parser.parse_args()
    return seed(args.suite)


if __name__ == "__main__":
    sys.exit(main())
