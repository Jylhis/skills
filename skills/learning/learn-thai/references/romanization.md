# Thai romanization systems

There is no single official learner romanization. Pick one and stay consistent.
For *learning pronunciation*, use a tone-marked system (Paiboon). For *recognizing
signs*, RTGS is what you'll see in the wild. Use IPA for precision.

## Side-by-side

| | RTGS | Paiboon | IPA |
|--|------|---------|-----|
| Tone shown? | **No** | **Yes** (diacritics) | Yes (marks/numbers) |
| Vowel length shown? | No | Yes (doubled vowel) | Yes (ː) |
| Audience | road signs, place names | **learners** | linguists, precision |
| ข้าว (rice) | khao | khâao | kʰâːw |
| ข่าว (news) | khao | khàao | kʰàːw |
| เขา (he) | khao | khǎo | kʰǎw |

Note all three Thai words collapse to "khao" in RTGS — that's why **RTGS is unfit
for learning**.

## Paiboon conventions (use these when teaching)
- **Tone diacritics on the vowel:** mid = none (a), low = à, falling = â,
  high = á, rising = ǎ.
- **Vowel length by doubling:** short *a* vs long *aa*; *i*/*ii*; *u*/*uu*;
  *e*/*ee*; *ɔ*/*ɔɔ* (often written *aw/aaw*).
- **Consonants:** aspirated stops written with *h* (kh, ph, th — note **ph = /pʰ/**,
  NOT /f/; **th = /tʰ/**, NOT English "th"); unaspirated bp /p/ and dt /t/ for
  ป and ต; ng for ง; final stops are unreleased.

## Deriving Paiboon from the helper output
`scripts/thai-translit.py` gives RTGS + the computed tone per syllable. To produce
Paiboon:
1. Start from the RTGS syllable.
2. Fix the consonant/vowel spelling toward Paiboon conventions above (e.g. mark
   aspiration, double long vowels).
3. Add the tone diacritic from the helper's `tone` field (à/â/á/ǎ / none).

State the tone *by name* as well as the diacritic, since the diacritics are easy
to misread.

## IPA quick reference (for advanced detail)
- Tones via contour marks or numbers: mid ˧, low ˨˩, falling ˥˩, high ˦˥, rising ˩˩˦.
- Long vowels with ː (aː, iː, uː). Aspiration with ʰ (kʰ, pʰ, tʰ). Glottal stop ʔ
  closes short open syllables.
