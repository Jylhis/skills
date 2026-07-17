#!/usr/bin/env python3
"""Compile evals/suites/<suite>/cases.yaml -> evals/.generated/<suite>.yaml.

Input shape (canonical, per spec-v3 §10 + this plan's extensions):

    cases:
      - id: trigger-positive-1
        kind: trigger_positive          # trigger_positive | trigger_negative | output_quality
        prompt: "..."
        expected_skill: ast-grep
        providers: [claude]             # default: trigger_* -> [claude], output_quality -> all three
        fixtures_subdir: ts-snippet     # optional path under suite's fixtures/
        pass_threshold: 0.5
        near_miss_vocabulary: [...]
        assert:
          contains: ["..."]
          contains_all: ["...", "..."]
          regex: ["..."]
          not_regex: ["..."]
          triggered: ast-grep
          output_match_regex: "..."
          max_latency_ms: 30000
          rubric: ["criterion 1", "criterion 2"]    # optional g-eval

Output shape: a promptfooconfig.yaml with `providers` (one per
requested target plus the stub) and a flat `tests` array. Each
generated test carries `metadata` so promptfoo's filter logic can
narrow down by case id, kind, or expected skill.

Wrapper paths in the output are absolute, resolved at generation time
against REPO_ROOT. promptfoo's `getFileHashes` (in scriptCompletion.js)
calls `fs.existsSync` from the *invocation* cwd (repo root), while its
`execFile` uses `config.basePath` (the config file's directory,
`evals/.generated/`). Absolute paths satisfy both. `.generated/` is
gitignored and regenerated on every `just eval*`, so this is not a
portability hazard.
"""
from __future__ import annotations

import argparse
import shlex
import sys
from pathlib import Path

import yaml

from _paths import resolve_suite_dir

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
EVALS_DIR = REPO_ROOT / "evals"
GENERATED_DIR = EVALS_DIR / ".generated"

ALL_PROVIDERS = ["claude", "pi"]


def default_providers(case: dict) -> list[str]:
    """Return the provider list for a case.

    The cases.yaml field ``providers`` is purely a recording hint (which
    CLIs to *record* against); it does not restrict which providers
    appear in the promptfoo matrix.  We always expand to all
    providers so that promptfoo's top-level × test cross-product has a
    cassette for every cell.
    """
    return list(ALL_PROVIDERS)


def provider_id(name: str) -> str:
    return _exec_id(EVALS_DIR / "providers" / f"run_{name}.sh")


def judge_id(name: str) -> str:
    return _exec_id(EVALS_DIR / "judges" / f"judge_{name}.sh")


def _exec_id(path: Path) -> str:
    return f"exec:{shlex.quote(path.as_posix())}"


def stub_provider_for(name: str, suite: str,
                       fixtures_subdir: str | None = None) -> dict:
    """Promptfoo provider entry that calls run_stub.sh on behalf of `name`.

    Each cassette is keyed by (provider, prompt, model, fixtures-digest),
    so any case with `fixtures_subdir` needs `EVAL_FIXTURES_DIR` propagated
    into the provider's subprocess env — otherwise replay computes a
    no-fixtures key while record computed a with-fixtures key, and the
    cassette is reported as "stale or missing". The label embeds the
    fixtures dir so the de-dup in expand_suite() keeps a distinct entry
    per (target, fixtures) tuple.
    """
    suite_dir = resolve_suite_dir(suite)
    env = {
        "EVAL_PROVIDER": name,
        "EVAL_SUITE": suite,
        "EVAL_SUITE_DIR": str(suite_dir.relative_to(REPO_ROOT)),
        "EVAL_MODEL_SNAPSHOT": "default",
    }
    label = f"stub:{name}"
    if fixtures_subdir:
        env["EVAL_FIXTURES_DIR"] = str(
            suite_dir.relative_to(REPO_ROOT) / "fixtures" / fixtures_subdir
        )
        label = f"stub:{name}:{fixtures_subdir}"
    return {
        "id": _exec_id(EVALS_DIR / "providers" / "run_stub.sh"),
        "label": label,
        "config": {"env": env},
    }


def stub_judge(name: str, suite: str) -> dict:
    suite_dir = resolve_suite_dir(suite)
    return {
        "id": _exec_id(EVALS_DIR / "judges" / "judge_stub.sh"),
        "label": f"judge-stub:{name}",
        "config": {
            "env": {
                "EVAL_JUDGE_PROVIDER": name,
                "EVAL_SUITE": suite,
                "EVAL_SUITE_DIR": str(suite_dir.relative_to(REPO_ROOT)),
                "EVAL_MODEL_SNAPSHOT": "default",
            },
        },
    }


def _string_match_asserts(a: dict) -> list[dict]:
    out: list[dict] = []
    for needle in a.get("contains") or []:
        out.append({"type": "contains", "value": needle})
    if a.get("contains_all"):
        out.append({"type": "contains-all", "value": a["contains_all"]})
    for pattern in a.get("regex") or []:
        out.append({"type": "regex", "value": pattern})
    for pattern in a.get("not_regex") or []:
        out.append({"type": "not-regex", "value": pattern})
    if a.get("output_match_regex"):
        out.append({"type": "regex", "value": a["output_match_regex"]})
    return out


def _trigger_assert(a: dict) -> list[dict]:
    if "triggered" not in a:
        return []
    return [{
        "type": "javascript",
        "value": _triggered_assert_body(a["triggered"]),
        "metric": "trigger_rate",
    }]


def _latency_assert(a: dict) -> list[dict]:
    if not a.get("max_latency_ms"):
        return []
    return [{"type": "latency", "threshold": a["max_latency_ms"]}]


def _rubric_assert(case: dict, suite: str, judge: str | None,
                    stub_judge_flag: bool, no_rubric: bool) -> list[dict]:
    a = case.get("assert") or {}
    rubric = a.get("rubric")
    if not rubric or no_rubric or judge is None:
        return []
    rubric_path = resolve_suite_dir(suite) / "rubric.md"
    rubric_text = rubric_path.read_text(encoding="utf-8") if rubric_path.exists() else ""
    prompt = (rubric_text + "\n\nCriteria:\n- " + "\n- ".join(rubric)).strip()
    judge_provider: dict | str = (
        stub_judge(judge, suite) if stub_judge_flag else judge_id(judge)
    )
    return [{
        "type": "g-eval",
        "value": prompt,
        "threshold": case.get("rubric_threshold", 0.7),
        "provider": judge_provider,
    }]


def build_assertions(case: dict, suite: str, judge: str | None,
                      stub_judge_flag: bool = False,
                      no_rubric: bool = False) -> list[dict]:
    a = case.get("assert") or {}
    return [
        *_string_match_asserts(a),
        *_trigger_assert(a),
        *_latency_assert(a),
        *_rubric_assert(case, suite, judge, stub_judge_flag, no_rubric),
    ]


def _triggered_assert_body(expected) -> str:
    """JS body for a promptfoo `javascript` assertion.

    Reads the wrapper's stderr trace JSON via
    context.providerResponse.metadata.stderr (promptfoo populates this
    for `exec:` providers).
    """
    if expected is None:
        check = "trace.triggered === null"
        msg = "expected no skill to trigger"
    else:
        check = f"trace.triggered === {expected!r}"
        msg = f"expected triggered={expected!r}"
    return (
        "const stderr = (context.providerResponse && "
        "context.providerResponse.metadata && "
        "context.providerResponse.metadata.stderr) || '';\n"
        "const last = stderr.trim().split(/\\r?\\n/).pop() || '{}';\n"
        "let trace = {};\n"
        "try { trace = JSON.parse(last); } catch (e) { return { pass: false, reason: 'trace JSON parse failed: ' + e.message }; }\n"
        f"return {{ pass: {check}, reason: {msg!r} + ' got ' + JSON.stringify(trace.triggered) }};"
    )


def case_threshold(case: dict) -> float:
    t = case.get("pass_threshold")
    return float(t) if t is not None else 1.0


def _provider_entry(name: str, suite: str, fixtures_sub: str | None,
                     stub_sut: bool) -> dict | str:
    if stub_sut:
        return stub_provider_for(name, suite, fixtures_sub)
    return provider_id(name)


def _provider_label(name: str, stub_sut: bool,
                     fixtures_subdir: str | None = None) -> str:
    """Return the label that matches the top-level provider entry."""
    if stub_sut:
        label = f"stub:{name}"
        if fixtures_subdir:
            label = f"stub:{name}:{fixtures_subdir}"
        return label
    return provider_id(name)


def _make_test(case: dict, provider: str, suite: str, judge: str | None,
                stub_sut: bool, stub_judge_flag: bool, no_rubric: bool) -> dict:
    test_assert = build_assertions(case, suite, judge,
                                    stub_judge_flag=stub_judge_flag,
                                    no_rubric=no_rubric)
    label = _provider_label(provider, stub_sut, case.get("fixtures_subdir"))
    test = {
        "description": f"{case['id']} :: {provider}",
        "vars": {"prompt": case["prompt"], "case_id": case["id"]},
        "providers": [label],
        "metadata": {
            "case_id": case["id"],
            "kind": case.get("kind", "output_quality"),
            "expected_skill": case.get("expected_skill"),
            "provider": provider,
            "suite": suite,
        },
        "assert": [],
    }
    if test_assert:
        test["assert"] = [{
            "type": "assert-set",
            "threshold": case_threshold(case),
            "assert": test_assert,
        }]
    return test


def _stub_provider_block(cases: list[dict], suite: str) -> list[dict]:
    """De-dup stub provider entries by label.

    The label includes the fixtures subdir so each unique
    (target, fixtures) tuple gets its own entry with the right
    EVAL_FIXTURES_DIR in env.
    """
    seen: set[str] = set()
    out: list[dict] = []
    for case in cases:
        sub = case.get("fixtures_subdir")
        for p in default_providers(case):
            entry = stub_provider_for(p, suite, sub)
            if entry["label"] in seen:
                continue
            seen.add(entry["label"])
            out.append(entry)
    return out


def _live_provider_block(cases: list[dict]) -> list[str]:
    return sorted({
        provider_id(p) for case in cases for p in default_providers(case)
    })


def expand_suite(suite: str, judge: str | None = None,
                 stub_sut: bool = False, stub_judge_flag: bool = False,
                 no_rubric: bool = False) -> Path:
    cases_path = resolve_suite_dir(suite) / "cases.yaml"
    raw = yaml.safe_load(cases_path.read_text(encoding="utf-8")) or {}
    cases = raw.get("cases", [])

    tests = [
        _make_test(case, p, suite, judge, stub_sut, stub_judge_flag, no_rubric)
        for case in cases
        for p in default_providers(case)
    ]
    provider_block = (
        _stub_provider_block(cases, suite) if stub_sut
        else _live_provider_block(cases)
    )

    config = {
        "description": f"jylhis-skills evals: {suite}",
        "providers": provider_block,
        "prompts": ["{{prompt}}"],
        "tests": tests,
        "defaultTest": {
            "options": {
                # Trigger-style cases benefit from repeats; output_quality
                # cases default to 1 and may be overridden via CLI.
                "repeat": 1,
            },
        },
    }

    GENERATED_DIR.mkdir(parents=True, exist_ok=True)
    out = GENERATED_DIR / f"{suite}.yaml"
    suite_rel = resolve_suite_dir(suite).relative_to(REPO_ROOT)
    out.write_text(
        f"# AUTO-GENERATED from {suite_rel}/cases.yaml — do not edit by hand\n"
        + yaml.safe_dump(config, sort_keys=False, width=100),
        encoding="utf-8",
    )
    return out


def main() -> int:
    parser = argparse.ArgumentParser(prog="expand.py")
    parser.add_argument("suite", help="suite name under evals/suites/")
    parser.add_argument("--judge", default=None,
                        help="judge wrapper name for g-eval assertions "
                             "(omit to skip rubric assertions entirely)")
    parser.add_argument("--stub-sut", action="store_true",
                        help="rewrite SUT providers to run_stub.sh "
                             "(per-test EVAL_PROVIDER carries the original)")
    parser.add_argument("--stub-judge", action="store_true",
                        help="rewrite g-eval judge to judge_stub.sh")
    parser.add_argument("--no-rubric", action="store_true",
                        help="elide g-eval rubric assertions entirely "
                             "(deterministic-only, used by CI)")
    args = parser.parse_args()

    out = expand_suite(args.suite, judge=args.judge,
                        stub_sut=args.stub_sut,
                        stub_judge_flag=args.stub_judge,
                        no_rubric=args.no_rubric)
    print(f"wrote {out.relative_to(REPO_ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
