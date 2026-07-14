# Spaced repetition with FSRS-5

`scripts/learn.go` implements **FSRS-5** (Free Spaced Repetition Scheduler) using
only the Go standard library, so it runs offline. You never compute intervals by
hand — you grade recall and the scheduler reschedules.

## The grading rubric (map honestly)

After the learner attempts a card, grade their recall:

| Grade  | Code | When |
|--------|------|------|
| `again`| 1 | Forgot / wrong. Card lapses, drops to `relearning`, short interval. |
| `hard` | 2 | Recalled, but with serious effort or hesitation. |
| `good` | 3 | Recalled correctly with normal effort. **The default success grade.** |
| `easy` | 4 | Instant, effortless recall. Lengthens the interval more. |

Grade the *recall*, not the *answer's importance*. A barely-remembered correct
answer is `hard`, not `good`.

## How scheduling works (intuition)

- Each card has **stability** (S, ≈ days until recall probability falls to your
  retention target) and **difficulty** (D, 1–10).
- Recall probability after `t` days: `R(t) = (1 + (19/81)·t/S)^-0.5`, which equals
  0.9 exactly when `t = S`.
- A successful review multiplies S upward (more so for `easy`, less for `hard`,
  and more when the card was nearly forgotten — desirable difficulty). A lapse
  shrinks S and bumps D.
- The next interval is the `t` where `R(t) = desired_retention` (default 0.9),
  rounded to whole days, minimum 1.

## Retention target

`desired_retention` (set at `init --retention`, default 0.90) trades reviews for
recall:
- 0.85–0.90 — efficient for most learning; fewer reviews.
- 0.92–0.95 — for high-stakes material (e.g. exam-critical vocab); more reviews.

Stay within 0.70–0.97; extremes make the schedule degenerate.

## What you own vs what the scheduler owns

- **You own:** card *content* (good cloze/minimal-pair fronts, concept tags), and
  the honest grade.
- **The scheduler owns:** stability/difficulty math, due dates, and all file
  writes. Don't hand-edit the state file.
