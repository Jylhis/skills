---
name: learn-german
description: Tutor the user in German — Standard German (Hochdeutsch) first, with a path toward Swiss German (Schweizerdeutsch). Use when the user wants to learn, study, or practice German, asks to drill German vocabulary or grammar (cases, genders, separable verbs, word order, tenses), wants German example sentences, cloze cards, or dialogues, asks you to correct their written German, or wants Swiss German guidance. Covers CEFR levels A1–C2 and pronunciation (IPA). Runs sessions and tracks progress through the tutor-engine skill (subject id `german`).
---

# learn-german

Subject expertise for German tutoring. **Session mechanics, the four-phase loop,
and progress tracking come from the `tutor-engine` skill** (subject id `german`)
— load it for any session. This skill supplies *what* to teach and the German
gotchas.

## Strategy: Hochdeutsch first, Swiss German second

The user is in Switzerland, so the end goal includes Swiss German. But:
- **Schweizerdeutsch is a group of spoken dialects, not a standardized written
  language.** Almost everything written in Switzerland (newspapers, signs,
  official text) is Hochdeutsch.
- Standard German and Swiss German overlap heavily; Swiss German is best learned
  as a *spoken overlay* once Hochdeutsch grammar is solid.

So: teach **Hochdeutsch grammar and writing throughout**, scaffolded by CEFR
level. Layer Swiss German pronunciation, greetings, and high-frequency dialect
words for listening/speaking from ~A2 onward, clearly flagged as dialect. See
`references/swiss-german.md`.

## Where learners struggle (prioritize these)

1. **The four cases** (Nominative, Accusative, Dative, Genitive) and how they
   reshape articles, adjectives, and pronouns. This is the central hurdle.
2. **Grammatical gender** (der/die/das) — must be learned *with* every noun.
3. **Separable verbs** (aufstehen → "ich stehe … auf") and the prefix's trip to
   the end of the clause.
4. **Word order** — verb-second (V2) in main clauses, verb-final in subordinate
   clauses, and the time-manner-place ordering.

Full tables and rules: `references/grammar.md`. What to teach at each level:
`references/cefr-syllabus.md`.

## Teaching moves specific to German

- **Always teach a noun with its article and plural**: not "Haus" but
  "das Haus, die Häuser". Make gender part of the card front/back.
- **Color-code or label cases** when introducing them (dual coding): subject =
  Nominative, direct object = Accusative, indirect object = Dative.
- **Generate cloze cards on the case-bearing word**, e.g.
  `Ich gebe {{c1::dem}} Mann ein Buch.` tagged `dative`. Prefer minimal pairs that
  isolate one contrast (accusative vs dative: "in die Küche" vs "in der Küche").
- **Comprehensible input**: build example sentences from high-frequency vocabulary
  at the learner's level; gloss anything new inline (see `references/resources.md`).
- **Pronunciation**: give IPA for tricky sounds — ü /yː/, ö /øː/, ch /ç/ vs /x/,
  the uvular r /ʁ/, final-obstruent devoicing (Tag /taːk/). Flag where Swiss
  German diverges.

## Correcting the learner's German

When the user writes German, don't just fix it:
1. Echo the corrected sentence.
2. Name the rule violated (case, gender, verb position, separable prefix…).
3. Ask a Socratic question that would have surfaced the rule.
4. `learn.go log-error --subject german --concept <case|gender|word-order|…> --note "…"`.
5. Offer one fresh sentence to apply the fix.

## Verification
- [ ] New vocabulary cards include article + plural and a concept tag.
- [ ] Case/gender/word-order mistakes were logged via `tutor-engine`.
- [ ] Swiss German content was flagged as spoken dialect, not written standard.
