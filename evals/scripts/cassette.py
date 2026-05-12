#!/usr/bin/env python3
"""Hash-keyed VCR cassette helpers for the eval harness.

A cassette is a recorded SUT or judge response stored under
`evals/suites/<suite>/golden/<key>.json`. The key is

    sha256(provider + "\\n" + prompt + "\\n" + model_snapshot + "\\n" + fixtures_digest)[:16]

so editing a prompt invalidates the cassette and the stub provider
fails loud rather than replaying a stale recording (Doc 3
"Interaction Recording via VCR Cassettes").

CLI surface:

    cassette.py key --provider <p> --prompt-file <f> [--model M] [--fixtures D]
    cassette.py read --suite <s> --key <k>

The recording flow lives in `cassette.py --record`, which is invoked by
`just eval-record`. It calls the live provider wrapper, captures
stdout + stderr, validates that stderr is one-line JSON with a
provenance block, and writes the envelope to disk.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import platform
import shutil
import socket
import subprocess
import sys
import tempfile
import time
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
EVALS_DIR = REPO_ROOT / "evals"
SUITES_DIR = EVALS_DIR / "suites"

REQUIRED_PROVENANCE = {"cli", "cli_version", "model_snapshot", "temperature",
                        "host", "recorded_at"}


def fixtures_digest(fixtures_dir: Path | None) -> str:
    """sha256 over a stable manifest of fixture filenames + bytes.

    Returns 'none' when no fixtures dir is given so the cassette key is
    still well-defined for cases that take no input files.
    """
    if fixtures_dir is None or not fixtures_dir.exists():
        return "none"
    h = hashlib.sha256()
    for path in sorted(fixtures_dir.rglob("*")):
        if not path.is_file():
            continue
        rel = path.relative_to(fixtures_dir).as_posix()
        h.update(rel.encode("utf-8"))
        h.update(b"\x00")
        h.update(path.read_bytes())
        h.update(b"\x00")
    return h.hexdigest()


def compute_key(provider: str, prompt: str, model_snapshot: str,
                fixtures_dir: Path | None = None) -> str:
    # Normalize prompt: strip trailing whitespace so the key is stable
    # regardless of whether the caller preserves YAML block-scalar
    # trailing newlines (seed_synthetic, expand.py) or not (promptfoo
    # exec: providers, which strip trailing newlines from argv).
    prompt = prompt.rstrip()
    parts = [provider, prompt, model_snapshot, fixtures_digest(fixtures_dir)]
    h = hashlib.sha256("\n".join(parts).encode("utf-8")).hexdigest()
    return h[:16]


def cassette_path(suite: str, key: str, judge: bool = False) -> Path:
    suffix = ".judge.json" if judge else ".json"
    return SUITES_DIR / suite / "golden" / f"{key}{suffix}"


def read_cassette(suite: str, key: str, judge: bool = False) -> dict:
    p = cassette_path(suite, key, judge=judge)
    if not p.exists():
        raise FileNotFoundError(f"cassette stale or missing: {p.relative_to(REPO_ROOT)}")
    return json.loads(p.read_text(encoding="utf-8"))


def write_cassette(suite: str, key: str, envelope: dict, judge: bool = False) -> Path:
    p = cassette_path(suite, key, judge=judge)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(envelope, indent=2, sort_keys=True) + "\n",
                 encoding="utf-8")
    return p


def make_provenance(cli: str, cli_version: str, model_snapshot: str,
                    temperature: float = 0.0) -> dict:
    return {
        "cli": cli,
        "cli_version": cli_version,
        "model_snapshot": model_snapshot,
        "temperature": temperature,
        "host": socket.gethostname() or "unknown",
        "platform": platform.platform(),
        "recorded_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    }


def validate_provenance(envelope: dict) -> list[str]:
    errors: list[str] = []
    prov = envelope.get("provenance")
    if not isinstance(prov, dict):
        return ["missing or non-dict 'provenance' block"]
    missing = REQUIRED_PROVENANCE - set(prov.keys())
    if missing:
        errors.append(f"provenance missing fields: {sorted(missing)}")
    return errors


def cassette_age_days(envelope: dict) -> float | None:
    """Return days since recording, or None if unparseable."""
    prov = envelope.get("provenance") or {}
    ts = prov.get("recorded_at")
    if not isinstance(ts, str):
        return None
    try:
        recorded = datetime.strptime(ts, "%Y-%m-%dT%H:%M:%SZ").replace(
            tzinfo=timezone.utc)
    except ValueError:
        return None
    delta = datetime.now(timezone.utc) - recorded
    return delta.total_seconds() / 86400.0


# ── Recording flow ─────────────────────────────────────────────────────


def _provider_script(provider: str) -> Path:
    return EVALS_DIR / "providers" / f"run_{provider}.sh"


def record_one(suite: str, provider: str, prompt: str,
               fixtures_src: Path | None,
               model_snapshot: str = "unspecified") -> Path:
    """Invoke the live provider wrapper and persist the result.

    The wrapper is an `exec:` provider: `argv[1]` is the prompt,
    stdout is the assistant text, stderr is single-line trace JSON
    with a provenance block.
    """
    wrapper = _provider_script(provider)
    if not wrapper.exists():
        raise FileNotFoundError(f"provider wrapper not found: {wrapper}")

    workdir = Path(tempfile.mkdtemp(prefix=f"eval-{suite}-{provider}-"))
    try:
        if fixtures_src and fixtures_src.exists():
            shutil.copytree(fixtures_src, workdir / "fixtures",
                            dirs_exist_ok=True)

        env = os.environ.copy()
        env.setdefault("EVAL_PROVIDER", provider)
        env.setdefault("EVAL_SUITE", suite)
        env.setdefault("EVAL_WORKDIR", str(workdir))

        started = time.perf_counter()
        # The wrapper takes the prompt on argv[1] only. Workdir is passed
        # via EVAL_WORKDIR env var so we don't collide with promptfoo's
        # exec: argv[2] options-JSON contract.
        proc = subprocess.run(
            [str(wrapper), prompt],
            cwd=str(workdir), env=env, capture_output=True, text=True,
            timeout=600,
        )
        elapsed_ms = int((time.perf_counter() - started) * 1000)
    finally:
        shutil.rmtree(workdir, ignore_errors=True)

    if proc.returncode != 0:
        sys.stderr.write(proc.stderr)
        raise RuntimeError(
            f"provider {provider} exited {proc.returncode} during recording"
        )

    text = proc.stdout
    # The wrapper contract is: the trace JSON is one line on stderr. Some
    # wrappers also log warnings; scan from the end for the first parseable
    # JSON object so trailing log lines don't mask the trace.
    trace = None
    parse_err: Exception | None = None
    for line in reversed(proc.stderr.strip().splitlines()):
        line = line.strip()
        if not line:
            continue
        try:
            trace = json.loads(line)
            break
        except json.JSONDecodeError as exc:
            parse_err = exc
    if trace is None:
        raise RuntimeError(
            f"provider {provider} stderr has no JSON trace line: {parse_err}"
        ) from parse_err

    envelope = {
        "text": text,
        "triggered": trace.get("triggered"),
        "elapsed_ms": trace.get("elapsed_ms", elapsed_ms),
        "family": trace.get("family", "unknown"),
        "provenance": trace.get("provenance") or make_provenance(
            cli=provider,
            cli_version=trace.get("cli_version", "unknown"),
            model_snapshot=trace.get("model_snapshot", model_snapshot),
        ),
    }
    errors = validate_provenance(envelope)
    if errors:
        raise RuntimeError(
            f"provider {provider} envelope failed provenance check: {errors}"
        )

    key = compute_key(provider, prompt, envelope["provenance"]["model_snapshot"],
                      fixtures_src)
    return write_cassette(suite, key, envelope)


# ── CLI ───────────────────────────────────────────────────────────────


def _read_text(path: str) -> str:
    return Path(path).read_text(encoding="utf-8")


def _cmd_key(args: argparse.Namespace) -> int:
    prompt = _read_text(args.prompt_file) if args.prompt_file else args.prompt
    fixtures = Path(args.fixtures) if args.fixtures else None
    print(compute_key(args.provider, prompt, args.model, fixtures))
    return 0


def _cmd_read(args: argparse.Namespace) -> int:
    envelope = read_cassette(args.suite, args.key, judge=args.judge)
    if args.field == "text":
        sys.stdout.write(envelope["text"])
    elif args.field == "trace":
        trace = {k: v for k, v in envelope.items() if k != "text"}
        json.dump(trace, sys.stdout)
        sys.stdout.write("\n")
    else:
        json.dump(envelope, sys.stdout, indent=2, sort_keys=True)
        sys.stdout.write("\n")
    return 0


def _cmd_record(args: argparse.Namespace) -> int:
    """Read a cases.yaml and record every case against the live provider.

    Records SUT cassettes (`<key>.json`) only. **Judge cassettes
    (`<key>.judge.json`) are NOT produced here**: promptfoo's `g-eval`
    constructs its own internal prompt at runtime, and the harness
    cannot predict that string ahead of time, so a recorded judge prompt
    would not key-match what `judge_stub.sh` looks up at replay. Until
    we migrate the rubric assertion type to one whose prompt we own,
    judge cassettes must be captured live by running `just eval-judge`
    once with the wrappers patched to write their cassette as a
    side-effect — tracked as a follow-up. CI today uses `--no-rubric`,
    so the gap does not affect `just eval-stub`.
    """
    import yaml  # imported lazily so `key` and `read` work without PyYAML

    cases_path = SUITES_DIR / args.suite / "cases.yaml"
    cases = (yaml.safe_load(cases_path.read_text(encoding="utf-8")) or {}).get("cases", [])
    fixtures_root = SUITES_DIR / args.suite / "fixtures"

    rubric_cases = 0
    for case in cases:
        if args.provider == "claude" and case.get("kind", "").startswith("trigger_"):
            providers = case.get("providers") or ["claude"]
        else:
            providers = case.get("providers") or [args.provider]
        if args.provider not in providers:
            continue
        if (case.get("assert") or {}).get("rubric"):
            rubric_cases += 1
        sub = case.get("fixtures_subdir")
        fixtures_src = fixtures_root / sub if sub else None
        path = record_one(args.suite, args.provider, case["prompt"], fixtures_src,
                           model_snapshot=args.model)
        print(f"recorded {case['id']:<32} -> {path.relative_to(REPO_ROOT)}")
    if rubric_cases:
        print(
            f"note: {rubric_cases} case(s) carry rubric assertions; judge "
            "cassettes are not generated by `record` (g-eval prompt is not "
            "deterministic by harness — see _cmd_record docstring).",
            file=sys.stderr,
        )
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(prog="cassette.py")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_key = sub.add_parser("key", help="compute a cassette key")
    p_key.add_argument("--provider", required=True)
    p_key.add_argument("--prompt", default=None)
    p_key.add_argument("--prompt-file", default=None)
    p_key.add_argument("--model", default="unspecified")
    p_key.add_argument("--fixtures", default=None)
    p_key.set_defaults(func=_cmd_key)

    p_read = sub.add_parser("read", help="read a cassette envelope")
    p_read.add_argument("--suite", required=True)
    p_read.add_argument("--key", required=True)
    p_read.add_argument("--judge", action="store_true")
    p_read.add_argument("--field", choices=["text", "trace", "all"], default="all")
    p_read.set_defaults(func=_cmd_read)

    p_rec = sub.add_parser("record", help="record live cassettes for a suite")
    p_rec.add_argument("--suite", required=True)
    p_rec.add_argument("--provider", required=True)
    p_rec.add_argument("--model", default="unspecified")
    p_rec.set_defaults(func=_cmd_record)

    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
