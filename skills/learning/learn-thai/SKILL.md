---
name: learn-thai
description: Tutor the user in Thai — tones, the Thai script, and Paiboon romanization for beginners. Use when the user wants to learn, study, or practice Thai, drill Thai vocabulary, tones, or the alphabet, wants Thai example sentences or minimal pairs, asks how to read or pronounce Thai, or wants help with Thai tone rules. Includes a transliteration/segmentation helper (script + tone). Runs sessions and tracks progress through the tutor-engine skill (subject id `thai`).
---

# learn-thai

Subject expertise for Thai tutoring. **Session mechanics and progress tracking
come from the `tutor-engine` skill** (subject id `thai`) — load it for any
session. This skill supplies *what* to teach and Thai's specific hurdles.

## The three things that make Thai hard (teach in this order of attention)

1. **Tones.** Thai has **five tones — mid, low, falling, high, rising** — and tone
   is phonemic: same consonants+vowel, different tone, different word
   (ข้าว *khâao* rice / ข่าว *khàao* news / เขา *khǎo* he). Tone is non-negotiable
   from day one. See `references/tones.md`.
2. **The script.** 44 consonants (in three *classes* that determine tone), vowels
   written above/below/before/after the consonant, and **no spaces between
   words.** See `references/script.md`.
3. **Romanization chaos.** Multiple systems exist; pick one and be consistent.

## Romanization policy: Paiboon for learners

- Use **Paiboon** (or another tone-marked system) when teaching pronunciation —
  it encodes tone and vowel length with diacritics, so learners can *say* the word
  from the romanization.
- **Avoid RTGS for learning**: the Royal Thai General System drops tone and vowel
  length, so ข้าว, ข่าว, เขา all become "khao" — useless for a learner. RTGS is
  fine only for recognizing signs/place-names.
- Introduce **reading the actual Thai script early** (alongside Paiboon), and wean
  off romanization as script fluency grows. Reserve **IPA** for advanced phonetic
  detail. Mapping table: `references/romanization.md`.

## The transliteration helper

`scripts/thai-translit.py` segments Thai text (it has no spaces) and returns, per
syllable, the Thai, RTGS romanization, and the **computed tone**:

```
scripts/thai-translit.py "ผมกินข้าว"      # or: echo "…" | scripts/thai-translit.py -
```

It runs via a `uv` shebang (PEP 723 inline deps: PyThaiNLP); first run downloads
packages, so it needs `uv` and network once. The tone classifier is reliable when
a tone mark is present and for simple live syllables; it returns `"tone": null`
rather than guessing on ambiguous syllables. It does **not** emit Paiboon — derive
Paiboon from the tone + romanization using `references/romanization.md` and your
own knowledge.

## Teaching moves specific to Thai

- **Drill tones with minimal pairs** (same syllable, different tone) and mark each
  with its tone name + a pitch-contour cue (dual coding: ↗ rising, ↘ falling,
  → mid, low, high). Tag cards by tone (`tone-falling`, etc.).
- **Teach consonant *class* with each consonant** — class (mid/high/low) plus any
  tone mark determines the tone, so class is not optional trivia.
- **Build syllable cards** showing Thai script + Paiboon + tone + meaning; quiz in
  both directions (script→sound and sound→script).
- **Segment before you teach a phrase**: run the helper so the learner sees where
  syllables break.
- **Comprehensible input**: short, high-frequency mini-dialogues; keep new words
  ~1–2 per sentence (see `references/resources.md`).

## Verification
- [ ] Pronunciation taught in Paiboon (not bare RTGS); tone named for every word.
- [ ] Vocabulary cards tagged by tone and include the Thai script.
- [ ] Tone/script mistakes logged via `tutor-engine` (`learn.go log-error`).
