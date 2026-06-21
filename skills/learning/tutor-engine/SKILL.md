---
name: tutor-engine
description: Shared pedagogical engine for tutoring the user on any subject — runs structured study sessions, drills flashcards with spaced repetition (FSRS), tracks a per-subject learner profile, error log, and progress between sessions. Use when the user wants to learn, study, practice, review, drill, or be quizzed/coached on a topic, asks you to "teach me X", "test me on Y", "run my review", "track my progress", or starts a learning session. The learn-german, learn-thai, learn-rust, and learn-jj skills build on this engine for session mechanics and progress tracking; load this whenever you run any learning session.
---

# tutor-engine

The reusable core for AI tutoring: a session protocol, evidence-based teaching
techniques, and an agent-native spaced-repetition store (FSRS) that persists a
learner profile, card deck, error log, and session history **outside the repo**.
Subject skills (`learn-german`, `learn-thai`, `learn-rust`, `learn-jj`) supply
the content; this skill supplies the *how*.

## When you start any learning session

1. Identify the **subject id** (e.g. `german`, `thai`, `rust`, `jj`). One
   state file per subject.
2. Load state and check what's due: run the scheduler (below). If the subject
   has no state yet, `init` it.
3. Run the **four-phase session loop** — do not skip phases:

   1. **Warm-up review** (~20%) — clear due cards and revisit recent weak items
      from the error log. Quick wins first to build momentum.
   2. **New material** (~30%) — introduce content at **i+1**: one step beyond
      current level, kept 95–98% comprehensible. Elicit, don't lecture.
   3. **Practice** (~40%) — **interleave** old and new; mix problem types so the
      learner must *choose* the rule, not just apply a primed one. Give
      immediate, specific corrective feedback.
   4. **Recap** (~10%) — have the learner **explain it back** in their own words.
      Record the session and any new weak items.

4. Persist everything: grade each reviewed card, append mistakes to the error
   log, and record the session. Never keep progress only in chat.

## Core techniques (apply by default)

- **Active recall / testing effect** — ask before you tell. Quiz first, reveal
  after. Retrieval *is* the learning.
- **Spaced repetition** — let FSRS decide what's due; don't re-drill what's fresh.
- **Comprehensible input (i+1)** — gloss unknown words inline; keep input mostly
  understandable so meaning carries the grammar.
- **Interleaving** — only after basics are solid; mix topics within a session.
- **Deliberate practice** — target the learner's specific gap (from the error
  log), give immediate feedback, repeat the corrected behaviour.
- **Socratic questioning** — when the learner errs, ask a guiding question
  ("what role does this word play here?") before giving the rule.
- **Dual coding** — pair words with a diagram, table, or vivid example.

See `references/pedagogy.md` for each technique with concrete agent moves, and
`references/session-protocol.md` for ready-to-use phase prompts.

## Spaced-repetition scheduler

`scripts/learn.go` is a single-file Go program (FSRS-5, standard library only —
no network). Run it with a Go toolchain or via Nix:

```
go run scripts/learn.go <subcommand> [flags]
# or, on a host with Nix but no Go installed:
nix run nixpkgs#go -- run scripts/learn.go <subcommand> [flags]
```

State path (host-private, never committed):
`${XDG_STATE_HOME:-$HOME/.local/state}/jylhis-skills/learning/<subject>.json`

Typical session flow (below, `learn.go` is shorthand for `go run scripts/learn.go`
— that prefix is required to run it; it is not an installed command):

```
learn.go init   --subject german --level A2 --target B1 --focus "dative,gender"
learn.go due    --subject german --limit 20        # what to review now
learn.go review --subject german --id <id> --grade again|hard|good|easy
echo '{"front":"Ich gebe {{c1::dem}} Mann …","back":"dative","tags":["dative"]}' \
  | learn.go add --subject german                  # also accepts a JSON array
learn.go log-error --subject german --concept dative_prepositions --note "…"
learn.go session   --subject german --minutes 30 --covered "dative" --score 0.82
learn.go stats     --subject german
```

Grades map to FSRS: `again`=1 (forgot), `hard`=2, `good`=3, `easy`=4. The
scheduler owns all FSRS math and file writes; you generate the card *content*
(cloze sentences, minimal pairs, exercises). Mutating commands accept
`--dry-run`. See `references/srs.md` for the grading rubric and
`references/state-schema.md` for the file format.

## Authoring good cards

- One fact per card; prefer **cloze** (`{{c1::…}}`) and minimal pairs over
  open-ended prompts.
- Make the front a genuine retrieval cue; put the rule/explanation on the back.
- Tag by concept (`dative`, `tone-falling`, `lifetimes`) so reviews can be
  filtered and weak concepts targeted.

## Verification before ending a session

- [ ] Every card you reviewed was graded via `learn.go review`.
- [ ] New mistakes were captured with `learn.go log-error`.
- [ ] The session was recorded with `learn.go session`.
- [ ] You closed with an "explain it back" recap.
