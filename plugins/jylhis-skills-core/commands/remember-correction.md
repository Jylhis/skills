---
description: Append a correction note to the improvement-memory JSONL.
argument-hint: <short note describing the correction>
allowed-tools: Bash(python3:*), Bash(date:*), Read
---

Record a user correction as one schema-v1 entry in the
improvement-memory JSONL. The `skill-improver` meta-skill later reads
this file when iterating on a named skill.

Schema reference: `dev-skills/skill-improver/references/schema.md`.

Steps:

1. Treat `$ARGUMENTS` as the user's correction note (verbatim).

2. Build a schema-v1 JSON object with these eight keys:
   - `schema_version`: `1`.
   - `timestamp`: shell out to `date -u +%FT%TZ`.
   - `session_id`: `null` (Claude Code does not expose a stable id to
     slash commands; do not fabricate).
   - `skill`: best inference from the recent transcript, else `null`.
     Use the on-disk skill directory basename (e.g. `python`,
     `skill-creator-lang`).
   - `category`: pick from the closed enum
     `{behavior, scope, trigger, output_format, other}`. Default to
     `"other"` if uncertain rather than guessing.
   - `what_went_wrong`: a short paraphrase of the agent's prior action
     that was corrected.
   - `correction`: `$ARGUMENTS` verbatim, or paraphrased if very long.
   - `proposed_skill_change`: `null` unless an obvious one-line edit
     is suggested by the correction.

3. Pipe the object to `python3 scripts/append-correction.py --json -`
   via stdin. Pass the JSON through a heredoc or `printf '%s'` from a
   shell variable; do NOT inline the JSON inside the command string
   (quoting hazards).

4. On exit 0, print one acknowledgement line showing the resolved file
   path (the helper echoes it on stderr; surface that to the user). On
   non-zero exit, surface the helper's stderr verbatim — do not retry.

Example invocation:

```bash
python3 scripts/append-correction.py --json - <<'JSON'
{
  "schema_version": 1,
  "timestamp": "2026-05-11T14:23:00Z",
  "session_id": null,
  "skill": "skill-creator-lang",
  "category": "behavior",
  "what_went_wrong": "Offered three layouts instead of picking one.",
  "correction": "Be opinionated. Pick one and justify it in one line.",
  "proposed_skill_change": null
}
JSON
```
