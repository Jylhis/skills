# Skills-organization review (mattpocock comparison)

Brief recommendation memo per the upstream-import plan, after
vendoring 9 of Matt Pocock's skills into `skills/engineering/` and
`skills/productivity/`.

> **Historical snapshot.** The category names and counts below are frozen at
> the time of that import pass and are not maintained. The repo has since grown
> to 10 categories (adds `product` and `business`) and many more skills. For the
> current taxonomy see `AGENTS.md` and `docs/install.md`; for the authoritative
> plugin set see `.claude-plugin/marketplace.json`.

## What mattpocock does

`mattpocock/skills` organises around 3 top-level categories:

- `engineering/` — practices used during code work (tdd, triage,
  diagnose, prototype, zoom-out, to-prd, to-issues,
  improve-codebase-architecture, grill-with-docs).
- `productivity/` — workflow tools not tied to code (caveman,
  grill-me, handoff, write-a-skill).
- `misc/` — sundries.

Each skill is **single-purpose**: one folder, one `SKILL.md`,
optionally with a `references/` sibling for deep-dive material that
the SKILL.md links to on demand. Skills are *verbs* — they describe
an action the agent should perform, not a topic to know about.

There are no umbrella skills. There are no language-specific skills.
Even TypeScript-specific content (the upstream's main domain) is
framed as a practice (e.g. "diagnose a TS error") rather than a
language reference.

## How we currently differ

After this import pass, the 8-category layout is:

```
skills/
  engineering/  - 11 skills (mattpocock-style practices + ast-grep, offline-docs, semgrep, microsoft-docs)
  languages/    - 5 umbrella skills (python, typescript, go, jvm, nix)
  domains/      - 2 umbrella skills (security, taste)
  services/     - 16 skills (gitlab, terraform-*, azure-*, grafana-*)
  stack/        - 1 skill (filesystems — APFS/Btrfs/ZFS)
  productivity/ - 3 skills (humanizer, handoff, caveman)
  personal/     - 5 skills (obsidian-*)
  misc/         - 1 skill (emacs)
  ...meta/skill-extractor (relocated from skills/misc/)
```

Two structural differences from mattpocock:

1. **Umbrella skills exist** under `languages/` and `domains/`. Each
   wraps multiple sub-topics in `references/<topic>.md`. e.g.
   `skills/languages/python/SKILL.md` triggers on Python work in
   general; the agent then reads the right `references/<topic>.md`
   on demand. mattpocock would split these into per-topic skills.
2. **More categories**. We have 8 vs mattpocock's 3. The extras
   (`languages`, `domains`, `services`, `stack`, `personal`) carry
   conceptual differentiation — service-specific guidance is not the
   same shape as a practice, even if both are "things the agent
   should know".

## What works well from mattpocock's pattern

- **Practices as standalone skills.** `tdd`, `diagnose`, `triage`,
  `prototype` are each a distinct skill, and the agent picks the
  right verb for the situation. Easier to discover, easier to
  evaluate, easier to evolve independently. Now adopted in our
  `engineering/` category for the 9 mattpocock imports.
- **Tight `SKILL.md` bodies.** Mattpocock's bodies are short and
  link out to `references/` for depth — the entry-point is
  discoverability-shaped, not encyclopedia-shaped. We already
  follow this for `engineering/ast-grep` and the language umbrellas.
- **No `agents/` or `hooks/` inside a skill folder.** Skills stay
  portable. We already enforce this via `scripts/validate.py`.

## Where umbrellas earn their keep

Umbrella skills are worth keeping when:

- The umbrella's *description* triggers naturally as a category
  ("Python work", "security review"). The umbrella SKILL.md acts as
  a lightweight router that lists topics; references carry depth.
- The sub-topics share enough cross-references (e.g.
  `python/references/{async,types,dataclasses-pydantic}` all
  reference each other) that splitting them would multiply
  cross-skill chatter.
- The agent often wants the "overview" rather than a specific
  sub-topic, and an umbrella gives it that without N triggers.

Our `languages/<lang>/` and `domains/security/` umbrellas all fit
these criteria. Splitting them would lose the routing affordance.

## Where we should split

Some of our umbrellas may benefit from extraction in the future:

- `skills/domains/security/`: now has 6 references (jvm, python,
  typescript, best-practices, ownership-map, threat-model,
  static-analysis-codeql). The 3 latest (best-practices,
  ownership-map, threat-model) are *practices* in mattpocock's
  sense — they could each become a standalone skill in
  `engineering/security-<practice>/` with the umbrella reduced to
  the per-language references. Worth re-evaluating in a follow-up.
- `skills/services/azure-*` (6 imported): these are platform-specific
  practices. They're fine as siblings under `services/`, but a
  `services/azure/` umbrella that routes among them would surface
  Azure work as one trigger rather than 6. Currently no umbrella —
  the 6 skills are independent.
- Similarly for `skills/services/terraform-*` (4 imported) and
  `skills/services/grafana-*` (5 imported).

## Recommendation

Keep the 8-category layout. Adopt mattpocock's "practices as
standalone skills" pattern fully — we already do for the 9
imported, and any *new* engineering-practice skill should follow
the same single-purpose shape rather than getting folded into an
umbrella.

Defer two things for a follow-up:

1. Move security's 3 openai practice imports (best-practices,
   ownership-map, threat-model) into `engineering/security-*/`
   standalone skills. The umbrella retains the per-language
   references.
2. Add lightweight umbrella `SKILL.md` entries for `services/azure`,
   `services/terraform`, and `services/grafana` that route to the
   imported sub-skills, so the agent can trigger the cluster from
   high-level prompts (e.g. "help with Azure") without naming a
   specific sub-skill.

Both are content edits, not infrastructure changes; the importer
already supports both shapes via `merge-strategy: umbrella-references`.
