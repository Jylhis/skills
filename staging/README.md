# staging/

Holding pen for content awaiting per-skill review.

Contents preserved untouched from the previous repo layout:

- `skills/` — 64 locally-maintained skills
- `agents/` — subagent definitions
- `commands/` — slash commands
- `evals/` — eval harness scaffolding
- `research/` — design research notes
- `templates/` — placeholder templates

Each item is reviewed individually and either:

1. **Promoted** — moved to `../skills/<name>/` (or repurposed elsewhere) and
   updated to current conventions.
2. **Dropped** — deleted with a note in the commit message.

Nothing in `staging/` is built, linted as catalogue content, or deployed.
