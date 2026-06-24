# The Thai script

Thai is an abugida: consonants carry an inherent vowel, and vowel signs attach
around the consonant. There are **no spaces between words** — spaces mark phrase
or sentence breaks. Reading order within a syllable is not strictly
left-to-right, because some vowels are written *before* the consonant they're
pronounced after.

## Consonant classes (the tone-relevant grouping)

Every consonant belongs to one of three classes; class + tone mark determines tone
(see tones.md). The 44 consonants split as:

- **Mid (อักษรกลาง, 9):** ก จ ฎ ฏ ด ต บ ป อ
- **High (อักษรสูง, 11):** ข ฃ ฉ ฐ ถ ผ ฝ ศ ษ ส ห
- **Low (อักษรต่ำ, 24):** ค ฅ ฆ ง ช ซ ฌ ญ ฑ ฒ ณ ท ธ น พ ฟ ภ ม ย ร ล ว ฬ ฮ

Learn each consonant with: its name (e.g. ก ไก่ *gɔɔ gài*), its initial sound, its
**class**, and its *final* sound (many consonants sound different when closing a
syllable — e.g. final ด/ต/ถ all → /t/, final ก/ข/ค → /k/, final บ/ป/พ → /p/).

## Vowels — written around the consonant

For consonant ก, the vowel sign's position varies:
- **After:** กา (aa), กอ (ɔɔ)
- **Before (written first, said after):** เก (ee), แก (ɛɛ), โก (oo), ไก/ใก (ai)
- **Above:** กิ (i), กี (ii), กึ (ɯ), กื (ɯɯ), กั (a)
- **Below:** กุ (u), กู (uu)
- **Surrounding combinations:** เกะ (e short), เกีย (ia), เกือ (ɯa), กัว/กว (ua)

**Vowel length is phonemic** (short vs long changes meaning and can change tone),
so always learn the pair: ะ/า, ิ/ี, ุ/ู, etc.

## Syllable structure and segmentation
- A syllable = (initial consonant or cluster) + vowel + (optional final).
- Because there are no spaces, segment text before teaching it — use
  `scripts/thai-translit.py`, which returns syllable boundaries.
- Clusters: คร, ปล, กว, etc. behave as a single onset; the *first* consonant's
  class usually governs tone.

## Other marks
- **Tone marks** ่ ้ ๊ ๋ sit above the consonant (above an upper vowel if present).
- **ฯ** abbreviation, **ๆ** repetition (say the previous word twice), **์**
  (thanthakhat / karan) silences its consonant.

## Reading-practice sequence
1. Mid-class consonants + long vowels, no tone mark (predictable mid tone).
2. Add high/low class; contrast rising vs mid on live syllables.
3. Add finals (live vs dead) and short vowels.
4. Add tone marks. By now the learner can read most simple words aloud with tone.
