---
name: skill-improver
description: |
  Use this skill when the user asks to improve, iterate on, audit, or
  refine a specific skill in this repo. Reads filtered entries from the
  improvement-memory JSONL, buckets them by category, and proposes
  concrete SKILL.md edits. Triggers on phrases like "improve <skill>",
  "iterate on <skill>", "what did I correct about <skill>", "tune the
  <skill> skill", or any direct ask about reviewing past corrections.
---

# skill-improver

Iterate on an existing skill using recorded user corrections.

## Inputs

- `$ARGUMENTS` — the target skill's directory basename (e.g. `python`,
  `skill-creator-lang`). If missing, ask the user once which skill to
  iterate on, then proceed.
- The improvement-memory JSONL at
  `${XDG_STATE_HOME:-$HOME/.local/state}/jylhis-skills/improvement-memory.jsonl`.
  If the file does not exist, report "no recorded corrections yet" and
  stop — there is nothing to iterate on.

## Steps

1. **Resolve the target.** Confirm the skill exists on disk under
   `skills/<category>/<name>/SKILL.md` or `dev-skills/<name>/SKILL.md`.
   If the name is ambiguous (e.g. `gitlab` matches both an umbrella and
   nothing else), pick the on-disk match; if no match, surface the
   typo and stop.

2. **Filter the JSONL by `skill == <target>`.** Example:

   ```bash
   jq -c 'select(.skill == "python")' \
     "${XDG_STATE_HOME:-$HOME/.local/state}/jylhis-skills/improvement-memory.jsonl"
   ```

3. **Bucket by `category`.** Report counts across the five enum
   values (`behavior`, `scope`, `trigger`, `output_format`, `other`).
   A one-line summary is enough — the full entries appear under each
   proposed edit in step 6.

4. **For the top 3 categories by count, propose concrete `SKILL.md`
   edits.** Each proposal must name one of:
   - a new **gotcha** to add (gotchas live in `SKILL.md`, not
     references, so the agent sees them before triggering);
   - a **scope clarification** (what the skill does / does NOT cover);
   - a **description tweak** (re-trigger the skill on the right phrases);
   - an **output-template change** (the format the agent should emit).

   Quote 1–2 entries verbatim under each proposal so the user can audit
   the inference.

5. **If proposed edits change the trigger surface** (the
   `description:` block, or new trigger phrases in the body), suggest
   re-running `evals/suites/<skill>/` if it exists, and link
   `evals/README.md` for the harness recipe.

6. **Output.** Emit an edit plan as a numbered list, each item
   accompanied by the JSONL entries that triggered it. Do NOT apply
   edits without explicit user confirmation — this skill is advisory.

## Limits

- This meta-skill is loaded by Claude Code and Gemini CLI via the
  project-local `.claude/skills/skill-improver` symlink. **It is NOT
  loaded by Codex** — Codex's recursive scan stays inside per-plugin
  `skills/` and does not see `dev-skills/`. Codex users get the JSONL
  workflow through `AGENTS.md § Recording corrections` only.
- This skill is advisory: it never edits `SKILL.md` files directly.
  The user decides which proposals to apply.
- The JSONL is host-private. Do not paste entries into shared diffs,
  PRs, or chat without the user's confirmation.

## References

- `dev-skills/skill-improver/references/schema.md` — JSONL schema v1.
- `docs/skill-authoring-guide.md` § Patterns — gotchas, templates,
  validation loops; the shapes a proposed edit should slot into.
