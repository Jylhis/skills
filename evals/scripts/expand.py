#!/usr/bin/env python3
"""Compile evals/suites/<suite>/cases.yaml -> evals/.generated/<suite>.yaml.

Input shape (canonical, per spec-v3 §10 + this plan's extensions):

    cases:
      - id: trigger-positive-1
        kind: trigger_positive          # trigger_positive | trigger_negative | output_quality
        prompt: "..."
        expected_skill: ast-grep
        providers: [claude]             # default: trigger_* -> [claude], output_quality -> all four
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

The wrapper paths in the output are relative to the repo root so the
generated file stays portable: `exec: ./evals/providers/run_claude.sh`.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
EVALS_DIR = REPO_ROOT / "evals"
SUITES_DIR = EVALS_DIR / "suites"
GENERATED_DIR = EVALS_DIR / ".generated"

ALL_PROVIDERS = ["claude", "codex", "gemini", "pi"]


def default_providers(case: dict) -> list[str]:
    if case.get("providers"):
        return list(case["providers"])
    if case.get("kind", "").startswith("trigger_"):
        return ["claude"]
    return list(ALL_PROVIDERS)


def provider_id(name: str) -> str:
    return f"exec:./evals/providers/run_{name}.sh"


def judge_id(name: str) -> str:
    return f"exec:./evals/judges/judge_{name}.sh"


def stub_provider_for(name: str, suite: str) -> dict:
    """Promptfoo provider entry that calls run_stub.sh on behalf of `name`.

    Each cassette is keyed by recorded-provider, so we need a distinct
    provider entry per substituted target with EVAL_PROVIDER set in env.
    """
    return {
        "id": "exec:./evals/providers/run_stub.sh",
        "label": f"stub:{name}",
        "config": {
            "env": {
                "EVAL_PROVIDER": name,
                "EVAL_SUITE": suite,
                "EVAL_MODEL_SNAPSHOT": "default",
            },
        },
    }


def stub_judge(name: str, suite: str) -> dict:
    return {
        "id": "exec:./evals/judges/judge_stub.sh",
        "label": f"judge-stub:{name}",
        "config": {
            "env": {
                "EVAL_JUDGE_PROVIDER": name,
                "EVAL_SUITE": suite,
                "EVAL_MODEL_SNAPSHOT": "default",
            },
        },
    }


def build_assertions(case: dict, suite: str, judge: str,
                      stub_judge_flag: bool = False,
                      no_rubric: bool = False) -> list[dict]:
    asserts: list[dict] = []
    a = case.get("assert") or {}

    for needle in a.get("contains", []) or []:
        asserts.append({"type": "contains", "value": needle})

    if a.get("contains_all"):
        asserts.append({"type": "contains-all", "value": a["contains_all"]})

    for pattern in a.get("regex", []) or []:
        asserts.append({"type": "regex", "value": pattern})

    for pattern in a.get("not_regex", []) or []:
        asserts.append({"type": "not-regex", "value": pattern})

    if a.get("output_match_regex"):
        asserts.append({"type": "regex", "value": a["output_match_regex"]})

    if "triggered" in a:
        expected = a["triggered"]
        asserts.append({
            "type": "javascript",
            "value": _triggered_assert_body(expected),
            "metric": "trigger_rate",
        })

    if a.get("max_latency_ms"):
        asserts.append({"type": "latency", "threshold": a["max_latency_ms"]})

    rubric = a.get("rubric")
    if rubric and not no_rubric:
        rubric_path = SUITES_DIR / suite / "rubric.md"
        rubric_text = rubric_path.read_text(encoding="utf-8") if rubric_path.exists() else ""
        prompt = (rubric_text + "\n\nCriteria:\n- " + "\n- ".join(rubric)).strip()
        if stub_judge_flag:
            judge_provider: dict | str = stub_judge(judge, suite)
        else:
            judge_provider = judge_id(judge)
        asserts.append({
            "type": "g-eval",
            "value": prompt,
            "threshold": case.get("rubric_threshold", 0.7),
            "provider": judge_provider,
        })

    return asserts


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


def expand_suite(suite: str, judge: str = "gemini",
                 stub_sut: bool = False, stub_judge_flag: bool = False,
                 no_rubric: bool = False) -> Path:
    cases_path = SUITES_DIR / suite / "cases.yaml"
    if not cases_path.exists():
        raise FileNotFoundError(f"no cases.yaml at {cases_path.relative_to(REPO_ROOT)}")
    raw = yaml.safe_load(cases_path.read_text(encoding="utf-8")) or {}
    cases = raw.get("cases", [])

    tests: list[dict] = []
    for case in cases:
        provs = default_providers(case)
        threshold = case_threshold(case)
        kind = case.get("kind", "output_quality")
        for p in provs:
            test_assert = build_assertions(case, suite, judge,
                                            stub_judge_flag=stub_judge_flag,
                                            no_rubric=no_rubric)
            if stub_sut:
                provider_entry = stub_provider_for(p, suite)
            else:
                provider_entry = provider_id(p)
            tests.append({
                "description": f"{case['id']} :: {p}",
                "vars": {"prompt": case["prompt"], "case_id": case["id"]},
                "providers": [provider_entry],
                "metadata": {
                    "case_id": case["id"],
                    "kind": kind,
                    "expected_skill": case.get("expected_skill"),
                    "provider": p,
                    "suite": suite,
                },
                "assert": [{
                    "type": "assert-set",
                    "threshold": threshold,
                    "assert": test_assert,
                }] if test_assert else [],
            })

    if stub_sut:
        # de-dup stub provider entries by label
        seen_labels: set[str] = set()
        prov_list: list = []
        for case in cases:
            for p in default_providers(case):
                entry = stub_provider_for(p, suite)
                if entry["label"] in seen_labels:
                    continue
                seen_labels.add(entry["label"])
                prov_list.append(entry)
        provider_block = prov_list
    else:
        provider_block = sorted({
            provider_id(p) for case in cases for p in default_providers(case)
        })

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
    out.write_text(
        "# AUTO-GENERATED from evals/suites/{0}/cases.yaml — do not edit by hand\n".format(suite)
        + yaml.safe_dump(config, sort_keys=False, width=100),
        encoding="utf-8",
    )
    return out


def main() -> int:
    parser = argparse.ArgumentParser(prog="expand.py")
    parser.add_argument("suite", help="suite name under evals/suites/")
    parser.add_argument("--judge", default="gemini",
                        help="judge wrapper name for g-eval assertions")
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
