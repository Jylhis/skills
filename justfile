default:
    @just --list --justfile {{justfile()}}

# Lint shell scripts and portable skill frontmatter
check:
    shellcheck scripts/install.sh evals/providers/*.sh evals/judges/*.sh
    python3 scripts/validate.py

# Portable skill lint only
validate:
    python3 scripts/validate.py

# Symlink repo root as plugin into each tool's plugin directory
install:
    bash scripts/install.sh

# List discovered skills (one SKILL.md per skill directory)
list:
    @find skills -name SKILL.md | sort

# Run evals against stubbed SUT + stubbed judge (CI-safe; no network)
eval-stub suite="ast-grep":
    python3 evals/scripts/expand.py {{suite}} --stub-sut --stub-judge --no-rubric
    python3 evals/scripts/invariants.py --provider stub --judge stub --suite {{suite}}
    promptfoo eval --config evals/.generated/{{suite}}.yaml --no-cache --output evals/results/{{suite}}-stub.json

# Live four-CLI matrix; requires each CLI to be logged in (no API keys in harness).
# Runs all four providers — the labelled "four-CLI matrix".
eval suite="ast-grep" judge="gemini":
    python3 evals/scripts/expand.py {{suite}} --judge {{judge}}
    python3 evals/scripts/invariants.py --provider claude --judge {{judge}} --suite {{suite}}
    promptfoo eval --config evals/.generated/{{suite}}.yaml --no-cache --output evals/results/{{suite}}.json

# Single-provider live run; useful for triaging one CLI in isolation.
eval-one suite="ast-grep" provider="claude" judge="gemini":
    python3 evals/scripts/expand.py {{suite}} --judge {{judge}}
    python3 evals/scripts/invariants.py --provider {{provider}} --judge {{judge}} --suite {{suite}}
    promptfoo eval --config evals/.generated/{{suite}}.yaml --filter-providers {{provider}} --no-cache --output evals/results/{{suite}}-{{provider}}.json

# Half-live: stubbed SUT, live judge — useful for tuning rubric.md
eval-judge suite="ast-grep" judge="gemini":
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
