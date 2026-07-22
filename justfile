default:
    @just --list --justfile {{justfile()}}

# Lint shell scripts and portable skill frontmatter
check:
    git ls-files '*.sh' | xargs shellcheck
    python3 scripts/validate.py

# Portable skill lint only
validate:
    python3 scripts/validate.py

# Vet and test every Go module in the repo (one go.mod per module dir)
test-go:
    #!/usr/bin/env bash
    set -euo pipefail
    # --cached --others --exclude-standard: tracked plus not-yet-committed
    # modules, still honouring .gitignore (skips .devenv, caches).
    for modfile in $(git ls-files --cached --others --exclude-standard '*go.mod'); do
        mod=$(dirname "$modfile")
        echo "# $mod"
        (cd "$mod" && go vet ./... && go test ./...)
    done

# Register the marketplace and install jylhis-skills-core into each tool
install:
    bash scripts/install.sh

# List discovered skills (one SKILL.md per skill directory)
list:
    @find skills -name SKILL.md | sort

# Package skills into per-skill dist/skills/<name>.zip for claude.ai upload.
# Pass skill names to package a subset (e.g. `just package tdd security`).
package *names:
    python3 scripts/package-skill.py {{names}}

# Run evals against stubbed SUT + stubbed judge (CI-safe; no network)
eval-stub suite="ast-grep":
    python3 evals/scripts/expand.py {{suite}} --stub-sut --stub-judge --no-rubric
    python3 evals/scripts/invariants.py --provider stub --judge stub --suite {{suite}}
    promptfoo eval --config evals/.generated/{{suite}}.yaml --no-cache --output evals/results/{{suite}}-stub.json

# Default: deterministic-only live run. No LLM judge — no API keys or
# judge CLIs required. Rubric-based g-eval assertions are elided.
eval suite="ast-grep":
    python3 evals/scripts/expand.py {{suite}} --no-rubric
    python3 evals/scripts/invariants.py --provider claude --judge stub --suite {{suite}}
    promptfoo eval --config evals/.generated/{{suite}}.yaml --no-cache --output evals/results/{{suite}}.json

# Live multi-CLI matrix. Judge defaults to `stub` so the recipe is
# CI-safe by default; pass judge=claude|pi to enable
# rubric-based g-eval assertions against a live judge CLI (which must
# be logged in).
eval-judged suite="ast-grep" judge="stub":
    python3 evals/scripts/expand.py {{suite}} --judge {{judge}}
    python3 evals/scripts/invariants.py --provider claude --judge {{judge}} --suite {{suite}}
    promptfoo eval --config evals/.generated/{{suite}}.yaml --no-cache --output evals/results/{{suite}}-judged.json

# Single-provider live run; useful for triaging one CLI in isolation.
eval-one suite="ast-grep" provider="claude" judge="stub":
    python3 evals/scripts/expand.py {{suite}} --judge {{judge}}
    python3 evals/scripts/invariants.py --provider {{provider}} --judge {{judge}} --suite {{suite}}
    promptfoo eval --config evals/.generated/{{suite}}.yaml --filter-providers {{provider}} --no-cache --output evals/results/{{suite}}-{{provider}}.json

# Half-live: stubbed SUT, live judge — useful for tuning rubric.md
eval-judge suite="ast-grep" judge="stub":
    python3 evals/scripts/expand.py {{suite}} --stub-sut --judge {{judge}}
    python3 evals/scripts/invariants.py --provider stub --judge {{judge}} --suite {{suite}}
    promptfoo eval --config evals/.generated/{{suite}}.yaml --no-cache --output evals/results/{{suite}}-judge-{{judge}}.json

# Record fresh goldens against a real CLI (replaces synthetic placeholders)
eval-record suite="ast-grep" provider="claude":
    python3 evals/scripts/cassette.py record --suite {{suite}} --provider {{provider}}

# Lightweight Python-only smoke test for the harness itself; useful in CI
# even when promptfoo or the CLIs aren't available.
eval-smoke suite="ast-grep":
    python3 evals/scripts/expand.py {{suite}} --stub-sut --no-rubric
    python3 evals/scripts/invariants.py --provider stub --judge stub --suite {{suite}}
    @echo "eval-smoke OK"
