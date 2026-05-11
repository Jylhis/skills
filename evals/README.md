# Skill evaluations

Offline, no-API-key evaluation harness for the `jylhis-skills` catalogue.
Drives the four agent-skill CLIs (Claude Code, Codex, Gemini CLI, and
`pi-coding-agent`) through `promptfoo` `exec:` providers, with
deterministic assertions as the merge gate and an LLM-as-a-judge layer
for rubric-style checks. See `docs/skills-spec-v3.md` §10 for the
overall design and `cases.yaml` schema; see this README for how to
actually run anything.

## Targets

| CLI | Auth | Headless invocation |
| --- | --- | --- |
| Claude Code | OAuth from `claude login` (kept in keychain) | `claude -p` |
| Codex CLI | `~/.codex/auth.json` from `codex login` | `codex exec --json` |
| Gemini CLI | `~/.gemini/oauth_creds.json` (free Code Assist tier) | `gemini -p` |
| Pi (`pi-coding-agent`) | `pi login` against existing Claude Pro / ChatGPT / Copilot subscription | `pi -p` |

`pi` here means `@earendil-works/pi-coding-agent`
(github.com/badlogic/pi-mono), npm-only. **Not Inflection's Pi (pi.ai)**
— that product has no CLI and is out of scope.

The harness inherits `$HOME`, so each CLI must already be logged in
before you run live evals. The harness itself never sees an API key.

## Install

<!-- FIXME: we can assume these are installed -->

```sh
# CLIs (npm-global; not bundled in devenv because each needs user auth)
npm i -g @anthropic-ai/claude-code
npm i -g @openai/codex
npm i -g @google/gemini-cli
npm i -g @earendil-works/pi-coding-agent

# Then log each one in once:
claude   # OAuth in browser
codex login
gemini   # OAuth in browser
pi login
```

The harness itself (promptfoo, jq, python, pyyaml, jsonschema) is
provided by `devenv.nix`. Enter the dev shell with `direnv allow` or
`devenv shell`.

## Eval levels

This harness covers spec-v3 §10 levels 2–3:

| Level | What | How |
| --- | --- | --- |
| L0 | Human review of `SKILL.md` | manual |
| L1 | Static lint + frontmatter validation | `just check` (existing) |
| **L2** | Fixture-based prompt tests | `just eval-stub` (CI-safe) |
| **L3** | Live smoke against real CLIs | `just eval` (local only) |
| L4 | Failure-log regression | future |
| L5 | External benchmark integration | future |

## Recipes

```sh
just eval-stub      # CI-safe: stubbed SUT + stubbed judge, replays from golden/
just eval           # Live: real Claude SUT + live Gemini judge
just eval-judge     # Half-live: stubbed SUT, live Gemini judge (rubric tuning)
just eval-record    # Record fresh goldens against a real CLI
```

## How a run works

```
cases.yaml              promptfoo eval
   │                      │
   ▼                      ▼
expand.py ─► .generated/<suite>.yaml ─► [exec: providers] ─► result
                                            │
                                            ├── run_claude.sh
                                            ├── run_codex.sh
                                            ├── run_gemini.sh
                                            ├── run_pi.sh
                                            └── run_stub.sh   (cassette replay)
                                                        ▲
                                                        │
                                              suites/<s>/golden/<key>.json
                                                        ▲
                                                        │
                                              cassette.py: sha256(provider+
                                                          prompt+model+fixtures)[:16]
```

`invariants.py` runs before every `promptfoo eval` and rejects:
- judge same-name as SUT,
- judge same-family as SUT (`claude` judging Claude-routed-Pi, etc.),
- `trigger_*` cases scheduled against non-Claude providers without an
  explicit `cases[].providers` override,
- `trigger_negative` whose prompt does not contain a
  `near_miss_vocabulary` term,
- committed `golden/*.json` lacking a complete provenance block.

## Cross-CLI comparability

Trigger-accuracy metrics are reported **per provider only** and never
aggregated. Doc 2 §6 anti-pattern: Claude has an explicit `Skill` tool
event, Gemini has `activate_skill`, Codex infers triggering
heuristically from `command_execution`, and Pi inlines into the system
prompt. These are different denominators.

Only `output_quality` cases run in the four-CLI matrix.

## Known limitations

- **Cross-vendor judging is not bias-free.** Same-vendor LLM-judging
  inflates win rates 5–15pp (Doc 2 §5). The harness rejects same-name
  and same-family judging but cannot detect e.g. Pi-routed-to-Claude
  judging Claude.
- **Recorded goldens drift.** Cassettes carry a `recorded_at`
  timestamp and warn at 30 days, but a re-record on a different
  account/host is not guaranteed equivalent.
- **Claude underfires by default.** Sonnet 4.5 baseline auto-trigger is
  ~55%; `UserPromptSubmit` hooks raise to 85%+ and are out of scope.
  The plan measures *natural* triggering.

## Authoring a new suite

1. `mkdir -p evals/suites/<skill>/{fixtures,golden}`
2. Write `evals/suites/<skill>/cases.yaml` (see `suites/ast-grep/cases.yaml`).
3. Write `evals/suites/<skill>/rubric.md` (see `suites/ast-grep/rubric.md`).
4. `just eval-record` once locally to populate `golden/`.
5. Commit `cases.yaml`, `rubric.md`, `fixtures/`, and the recorded
   `golden/<key>.json` + `golden/<key>.judge.json` files.
