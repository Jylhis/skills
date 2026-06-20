# Evidence-based learning techniques (and how the agent applies them)

These are the techniques the tutor-engine operationalizes. Each entry pairs the
principle with a concrete agent move.

## Spaced repetition (FSRS)
Memory decays predictably; reviewing just before you'd forget is maximally
efficient. FSRS personalizes the schedule and needs ~20–30% fewer reviews than
the older SM-2 for the same retention.
- **Agent move:** never decide review timing by hand — call `learn.go due` and
  grade with `learn.go review`. Trust the scheduler; don't re-drill fresh cards.

## Active recall / testing effect
Retrieving information strengthens memory far more than re-reading it. The
*effort* of recall is the mechanism.
- **Agent move:** ask before telling. Present the prompt, let the learner
  attempt, *then* reveal. Convert facts into questions and cloze deletions.

## Comprehensible input — Krashen's i+1
Acquisition happens when input is slightly beyond current level (*i+1*) yet
still ~95–98% understandable, so context carries the new piece.
- **Agent move:** track level (CEFR for languages); generate text mostly in known
  vocabulary with a few new items glossed inline. Don't lecture grammar — embed
  it in understandable examples.

## Interleaving
Mixing problem types within a session forces discrimination ("which rule
applies?") and improves transfer — but it backfires before basics are solid.
- **Agent move:** after a topic is introduced and drilled in isolation, mix it
  with earlier topics (e.g. accusative + dative + nominative in one set; moves +
  lifetimes + traits). Vary surface features so it's not rote.

## Deliberate practice
Focused effort at the edge of ability, with immediate feedback on errors and
repetition of the corrected behaviour.
- **Agent move:** read the error log, pick the learner's actual weak spot, design
  a tight drill on exactly that, correct immediately, and repeat until clean.

## Dual coding
Combining verbal and visual representations lays two retrieval routes.
- **Agent move:** pair words with a table, diagram, pitch contour, or ownership
  flow. For languages, attach IPA and a vivid image/example to vocabulary.

## Socratic questioning
Guiding questions that lead the learner to derive the rule outperform being
handed the answer.
- **Agent move:** on an error, ask a probing question first ("what's the object
  here? what case marks it?"). Offer a counterexample. State the rule only after
  the learner has explored. (For code, point at the compiler message, don't fix
  it for them.)

## Explain-it-back (the protégé effect / self-explanation)
Explaining a concept exposes gaps and consolidates it.
- **Agent move:** end every session by asking the learner to summarize the new
  rule in their own words; log anything shaky as a weak item.
