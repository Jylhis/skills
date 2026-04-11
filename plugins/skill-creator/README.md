# skill-creator

Anthropic's official skill authoring, eval, and benchmarking framework,
bundled into jstack, plus a jstack-native meta skill for generating
language / stack specialist skills.

## Contents

- `.claude-plugin/plugin.json` — plugin manifest
- `skills/skill-creator/`
  - `SKILL.md` — the skill itself
  - `LICENSE.txt` — Apache 2.0
  - `agents/` — analyzer, comparator, grader subagents
  - `scripts/` — 9 Python scripts (init, package, validate, run-eval, run-loop, etc.)
  - `eval-viewer/` — `generate_review.py` + `viewer.html`
  - `references/` — `claude-ai.md`, `cowork.md`, `schemas.md`
  - `assets/eval_review.html`
  - `tests/` — pytest suite
- `skills/skill-creator-lang/`
  - `SKILL.md` — meta skill that generates language / stack specialist skills

This plugin is part of [jstack](../../) and is installed into
`~/.claude/plugins/skill-creator/` automatically by
`scripts/install.bash`. There is no separate install step.

## Skills

| Skill | Description |
|---|---|
| `skill-creator` | Create new Claude Code skills, improve existing skills, and measure skill quality through evals and benchmarks |
| `skill-creator-lang` | Create an opinionated specialist skill for a programming language or stack (e.g. Python, Ruby on Rails, ROS2). Meta skill that produces other skills. |

**Trigger phrases:** "create a skill", "turn this into a skill", "make a
skill for X", "write a `SKILL.md`", "run evals on my skill", "benchmark
my skill", "optimize my skill description", "improve triggering", "test
my skill".

See [`docs/plugins/skill-creator.mdx`](../../docs/plugins/skill-creator.mdx)
for the full subagent and script reference.

## Local cleanup

`__pycache__/` and `.pytest_cache/` are excluded by jstack's `.gitignore`.
Do not commit them back if pytest runs them locally.

## Sources

- [`anthropics/claude-plugins-official`](https://github.com/anthropics/claude-plugins-official) — `skill-creator` by Anthropic (Apache-2.0)

The Apache 2.0 license is bundled at
`skills/skill-creator/LICENSE.txt`.

## See also

- jstack docs: [`docs/plugins/skill-creator.mdx`](../../docs/plugins/skill-creator.mdx)
