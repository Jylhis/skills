# shellcheck shell=bash
# Shared helpers for evals/providers/*.sh and evals/judges/*.sh.
#
# `exec:` wrapper contract for promptfoo:
#   argv[1]            the rendered prompt
#   stdout             the assistant text (becomes `output`)
#   stderr             single-line JSON trace; promptfoo exposes this as
#                      context.providerResponse.metadata.stderr
#   exit code          0 on success; non-zero is treated as a test failure
#
# Trace shape (single line of JSON, last line of stderr):
#   {"triggered": "<skill>"|null, "elapsed_ms": <int>, "family": "<vendor>",
#    "provenance": {"cli": "<name>", "cli_version": "...",
#                   "model_snapshot": "...", "temperature": 0,
#                   "host": "...", "platform": "...", "recorded_at": "..."}}

set -euo pipefail

# Emit family token and exit when called as `<wrapper> --print-family`.
# Used by evals/scripts/invariants.py to enforce the same-family judge ban.
emit_family_if_requested() {
  local family="$1"
  if [[ "${1+x}" = "x" && "${2:-}" = "--print-family" ]]; then
    printf '%s\n' "$family"
    exit 0
  fi
  return 0
}

trace_provenance() {
  # args: cli cli_version model_snapshot
  local cli="$1" version="$2" model="$3"
  local host platform recorded
  host="$(hostname 2>/dev/null || echo unknown)"
  platform="$(uname -srm 2>/dev/null || echo unknown)"
  recorded="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  jq -nc \
    --arg cli "$cli" \
    --arg version "$version" \
    --arg model "$model" \
    --arg host "$host" \
    --arg platform "$platform" \
    --arg recorded "$recorded" \
    '{cli:$cli, cli_version:$version, model_snapshot:$model, temperature:0,
      host:$host, platform:$platform, recorded_at:$recorded}'
}

emit_trace() {
  # args: triggered_value(json) elapsed_ms family cli cli_version model_snapshot
  # `triggered_value` must already be a JSON value (e.g. "\"<skill>\"" or "null").
  local triggered="$1" elapsed="$2" family="$3" cli="$4" version="$5" model="$6"
  local provenance
  provenance="$(trace_provenance "$cli" "$version" "$model")"
  jq -nc \
    --argjson triggered "$triggered" \
    --argjson elapsed "$elapsed" \
    --arg family "$family" \
    --argjson provenance "$provenance" \
    '{triggered:$triggered, elapsed_ms:$elapsed, family:$family, provenance:$provenance}' \
    1>&2
}

millis_now() {
  python3 -c 'import time; print(int(time.time()*1000))'
}

require_cmd() {
  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      printf 'evals: required command not found: %s\n' "$cmd" >&2
      exit 127
    fi
  done
}

# Extract config.env from the promptfoo options JSON (argv[2]) and
# export them into the current shell environment. promptfoo exec:
# providers receive the config as a JSON string on argv[2] but do not
# set config.env entries as actual environment variables.
import_promptfoo_env() {
  local config_json="${1:-}"
  if [[ -z "$config_json" ]]; then
    return 0
  fi
  # Parse config.env keys and export them, but only if they are not
  # already set — explicit environment takes precedence.
  local keys
  keys="$(printf '%s' "$config_json" | jq -r '.config.env // {} | keys[]' 2>/dev/null)" || return 0
  local key val
  while IFS= read -r key; do
    [[ -z "$key" ]] && continue
    if [[ -z "${!key+x}" ]]; then
      val="$(printf '%s' "$config_json" | jq -r --arg k "$key" '.config.env[$k]')"
      export "$key=$val"
    fi
  done <<< "$keys"
}
