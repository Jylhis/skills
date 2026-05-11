# improvement-memory JSONL schema

This file is the single source of truth for the schema written by
`scripts/append-correction.py` and the `/remember-correction` slash
command. The JSONL lives at
`${XDG_STATE_HOME:-$HOME/.local/state}/jylhis-skills/improvement-memory.jsonl`
— deliberately outside the repo, so machine-private corrections never
leak into commits, marketplaces, or shared diffs.

## Schema v1

Each line is one JSON object with exactly these keys:

| Key | Type | Nullable | Allowed values / format | Meaning |
|---|---|---|---|---|
| `schema_version` | integer | no | currently `1` | Bumps only on a breaking change; consumers MUST reject unknown versions. |
| `timestamp` | string | no | RFC 3339 UTC, e.g. `2026-05-11T14:23:00Z` | When the correction was recorded. |
| `session_id` | string \| null | yes | opaque host-local id, or `null` | Best-effort. Claude Code does not expose a stable id to slash commands; use `null` rather than fabricating. |
| `skill` | string \| null | yes | a skill directory basename (e.g. `python`, `skill-creator-lang`), or `null` | Which skill the correction is about. `null` if no specific skill applies. |
| `category` | string | no | closed enum: `behavior`, `scope`, `trigger`, `output_format`, `other` | What kind of correction. |
| `what_went_wrong` | string | no | short paraphrase | The agent's prior action that was corrected. |
| `correction` | string | no | the user's directive, verbatim or lightly paraphrased | What the user told the agent to do instead. |
| `proposed_skill_change` | string \| null | yes | one-line edit hint, or `null` | Optional concrete SKILL.md edit suggestion. |

## Example entry

```json
{
  "schema_version": 1,
  "timestamp": "2026-05-11T14:23:00Z",
  "session_id": null,
  "skill": "skill-creator-lang",
  "category": "behavior",
  "what_went_wrong": "Offered three alternative skill layouts instead of picking one.",
  "correction": "Be opinionated. Pick one layout and justify it in one line.",
  "proposed_skill_change": "Step 8 'Be opinionated': add bullet 'pick one option, justify in one line'."
}
```

## Validation

`scripts/append-correction.py` validates strictly: missing keys, wrong
types, unknown `category`, or a non-RFC-3339 `timestamp` cause exit
code `3` with a clear stderr message. Exit codes: `0` OK, `2` usage,
`3` validation, `4` IO.

## Versioning

`schema_version` is an integer. Bump only on a breaking change (key
renamed / removed / retyped, or `category` enum narrowed). Additive
changes that keep existing entries valid do not require a bump.
Consumers MUST reject entries whose `schema_version` they do not
recognise rather than silently coerce.
