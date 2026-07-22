# Skill evaluations

Offline, no-API-key evaluation harness for the `jylhis-skills` catalogue.
Drives the two agent-skill CLIs (Claude Code and
`pi-coding-agent`) through `promptfoo` `exec:` providers, with
deterministic assertions as the merge gate and an optional LLM-as-a-judge
layer for rubric-style checks. See `docs/skills-spec-v4.md` §8 for the
overall design and `cases.yaml` schema; see this README for how to
actually run anything.

## Targets

| CLI | Auth | Headless invocation |
| --- | --- | --- |
| Claude Code | OAuth from `claude login` (kept in keychain) | `claude -p` |
| Pi (`pi-coding-agent`) | `pi login` against existing Claude Pro / ChatGPT / Copilot subscription | `pi -p` |

`pi` here means `@earendil-works/pi-coding-agent`
(github.com/badlogic/pi-mono), npm-only. **Not Inflection's Pi (pi.ai)**
— that product has no CLI and is out of scope.

The harness inherits `$HOME`, so each CLI must already be logged in
before you run live evals. The harness itself never sees an API key.

## Install

```sh
# CLIs (npm-global; not bundled in devenv because each needs user auth)
npm i -g @anthropic-ai/claude-code
npm i -g @earendil-works/pi-coding-agent

# Then log each one in once:
claude        # OAuth in browser
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
just eval           # Live: real Claude SUT, deterministic asserts only
just eval-judge     # Half-live: stubbed SUT, live judge (rubric tuning; opt-in via judge=…)
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
                                            ├── run_pi.sh
                                            └── run_stub.sh   (cassette replay)
                                                        ▲
                                                        │
                                  skills/<cat>/<name>/evals/golden/<key>.json
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
event, while Pi inlines into the system prompt. These are different
denominators.

Only `output_quality` cases run in the two-CLI matrix.

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

Eval suites live next to the skill they exercise, at
`skills/<category>/<name>/evals/`. The suite key is the skill's `name:`
(unique repo-wide).

1. `mkdir -p skills/<category>/<name>/evals/{fixtures,golden}` (next to
   the skill's `SKILL.md`).
2. Write `skills/<category>/<name>/evals/cases.yaml` (see
   `skills/engineering/ast-grep/evals/cases.yaml`).
3. Write `skills/<category>/<name>/evals/rubric.md` (only required if
   any case uses an LLM-judge `rubric:` block; otherwise deterministic
   asserts are enough).
4. `just eval-record suite=<name>` once locally to populate
   `golden/` (only needed for live-recorded suites; for deterministic-
   only suites this step is optional).
5. Commit `cases.yaml`, `rubric.md` if present, `fixtures/`, and the
   recorded `golden/<key>.json` + `golden/<key>.judge.json` files.

## Running evals

The default recipe is judge-free — no API keys or live judge CLIs
required:

```
just eval suite=<name>      # deterministic asserts only (--no-rubric)
just eval-stub suite=<name> # deterministic asserts + stubbed SUT
```

Judged runs are opt-in:

```
just eval-judged suite=<name> judge=pi   # live two-CLI matrix
just eval-one suite=<name> provider=claude judge=pi
just eval-judge suite=<name> judge=pi    # tune the rubric only
```
