# Session protocol — ready-to-use phases

A session is ~30 minutes by default; scale the phase budgets proportionally.
Always run the four phases in order. Drive review timing from the scheduler.

## 0. Open (before phase 1)
```
learn.go stats --subject <s>     # orient: due_now, weak concepts, level
learn.go due   --subject <s>      # the cards to clear in warm-up
```
Greet briefly, state today's focus (1 line), and confirm the learner's energy
(short vs full session).

## 1. Warm-up review (~20%)
- Present each due card as a retrieval prompt (front only). Let the learner
  answer, then reveal the back.
- Grade honestly: `learn.go review --subject <s> --id <id> --grade again|hard|good|easy`.
- Re-touch 1–2 recent weak concepts from `error_counts`.
- Goal: momentum and a clean review queue.

## 2. New material (~30%)
- Introduce **one** new point at i+1. Show 1–2 worked examples in mostly-known
  vocabulary; gloss the new bits.
- Elicit: ask the learner to predict, complete, or generate an example before you
  confirm the rule (active recall + Socratic).
- Turn the new point into cards: `learn.go add --subject <s>` (cloze preferred,
  tagged by concept).

## 3. Practice (~40%)
- **Interleave**: mix the new point with earlier ones in a varied set.
- Immediate feedback on every item. On an error:
  1. ask a guiding question,
  2. if still stuck, give a counterexample,
  3. then state the rule,
  4. `learn.go log-error --subject <s> --concept <c> --note <what happened>`,
  5. re-ask a fresh variant to confirm the fix.
- Keep difficulty at the edge — adjust up/down based on the running hit rate.

## 4. Recap (~10%)
- "Explain it back": learner states today's rule in their own words. Log gaps.
- Record the session:
  `learn.go session --subject <s> --minutes <m> --covered "<topics>" --score <0..1>`
  (score ≈ fraction of practice items correct).
- Preview next session's focus in one line.

## Pacing heuristics
- Hit rate <60% in practice → drop back to isolated drilling; you moved too fast.
- Hit rate >90% across two sessions → raise i+1; introduce interleaving if not yet.
- If `due_now` is large, spend the whole session on review — new material can wait.
