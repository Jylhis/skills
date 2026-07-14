# Learner-state file format

One JSON file per subject, written and read only by `scripts/learn.go`. It is
host-private: it lives outside the repo, is never committed, and is not synced.

**Path:** `${XDG_STATE_HOME:-$HOME/.local/state}/jylhis-skills/learning/<subject>.json`

This mirrors the repo's existing improvement-memory convention (see the
"Recording corrections" section of `AGENTS.md`).

## Schema

```json
{
  "subject": "german",
  "created": "2026-06-20T00:00:00Z",
  "profile": {
    "level": "A2",
    "target": "B1",
    "focus": ["dative", "separable-verbs"]
  },
  "fsrs": {
    "desired_retention": 0.9,
    "params": [ /* 19 FSRS-5 weights */ ]
  },
  "cards": [
    {
      "id": "c1eccd27a333",
      "front": "Ich gebe {{c1::dem}} Mann ein Buch.",
      "back": "dative — indirect object",
      "tags": ["dative"],
      "state": "review",
      "due": "2026-06-23T19:33:59Z",
      "stability": 3.173,
      "difficulty": 5.0,
      "reps": 1,
      "lapses": 0,
      "last_review": "2026-06-20T19:33:59Z",
      "created": "2026-06-20T19:33:59Z"
    }
  ],
  "error_log": [
    { "ts": "2026-06-20T19:34:10Z", "concept": "dative_prepositions",
      "note": "used 'in dem' for 'im'" }
  ],
  "sessions": [
    { "date": "2026-06-20", "minutes": 30, "covered": ["dative"], "score": 0.82 }
  ]
}
```

## Field semantics

- **profile.level / target** — free-form level labels (CEFR `A1..C2` for German;
  `beginner/…` otherwise). Used to pitch i+1.
- **profile.focus** — concept tags the learner is prioritizing.
- **fsrs.desired_retention** — target recall probability at review time
  (default 0.9). Higher → shorter intervals, more reviews.
- **fsrs.params** — the 19 FSRS-5 weights. Defaults are baked into the program;
  they can be replaced with values optimized from a longer review history.
- **card.state** — `new` (never reviewed, always due), `review`, or
  `relearning` (after a lapse).
- **card.due** — next review time (RFC 3339). `due` subcommand returns cards
  with `due <= now` plus all `new` cards.
- **card.stability** — days at which recall probability ≈ `desired_retention`.
- **card.difficulty** — 1 (easy) … 10 (hard); drives how much stability grows.
- **card.reps / lapses** — total reviews / times graded `again`.
- **error_log** — append-only mistakes, keyed by `concept`; `stats` aggregates
  these into `error_counts` so warm-ups can target weak spots.
- **sessions** — append-only history for trend tracking.

Treat the file as owned by the program; don't hand-edit it during a session.
