#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash): run the portable skill lint before any
# `git commit`. Non-commit commands pass through untouched. The parser
# below tokenizes the command and requires "commit" to be the git
# subcommand, so `git log commit` or `git show commit` never trigger it.
set -u
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
input=$(cat)
case "$input" in *commit*) ;; *) exit 0 ;; esac
python3 - "$input" <<'PY' || exit 0
import json
import shlex
import sys

try:
    cmd = json.loads(sys.argv[1]).get("tool_input", {}).get("command", "")
    lex = shlex.shlex(cmd, posix=True, punctuation_chars=True)
    lex.whitespace_split = True
    tokens = list(lex)
except (ValueError, json.JSONDecodeError):
    sys.exit(1)  # unparseable input: treat as not a commit

GLOBAL_OPTS_WITH_ARG = {"-C", "-c", "--git-dir", "--work-tree", "--namespace", "--exec-path"}
WRAPPERS = {"sudo", "env", "command", "nohup"}


def segments(toks: "list[str]"):
    seg: "list[str]" = []
    for tok in toks:
        if tok and all(ch in "();<>|&" for ch in tok):
            if seg:
                yield seg
            seg = []
        else:
            seg.append(tok)
    if seg:
        yield seg


def is_git_commit(seg: "list[str]") -> bool:
    i = 0
    while i < len(seg) and (seg[i] in WRAPPERS or ("=" in seg[i] and not seg[i].startswith("-"))):
        i += 1
    if i >= len(seg) or seg[i].rsplit("/", 1)[-1] != "git":
        return False
    i += 1
    while i < len(seg):
        tok = seg[i]
        if tok.startswith("-"):
            i += 2 if tok in GLOBAL_OPTS_WITH_ARG else 1
            continue
        return tok == "commit"
    return False


sys.exit(0 if any(is_git_commit(s) for s in segments(tokens)) else 1)
PY
if ! out=$(python3 scripts/validate.py 2>&1); then
  printf '%s\n' "$out" >&2
  echo "Blocked: scripts/validate.py failed. Fix skill lint errors before committing." >&2
  exit 2
fi
exit 0
