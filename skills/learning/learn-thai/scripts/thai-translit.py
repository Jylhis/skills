#!/usr/bin/env -S uv run --quiet --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["pythainlp>=5.0,<6", "python-crfsuite>=0.9"]
# ///
"""thai-translit — segment Thai text and report romanization + tone per syllable.

For a tonal, space-free script, the two things a learner most needs from a chunk
of Thai are (a) where the syllable boundaries are and (b) the tone of each
syllable. This tool provides both, plus RTGS romanization, as JSON on stdout.

Pipeline:
  * syllable + word segmentation via PyThaiNLP (lightweight, no torch),
  * RTGS romanization via PyThaiNLP's `royin` engine,
  * tone via a built-in Thai tone-rule classifier (pure Python, no deps).

Tone classification is reliable when a tone mark is present (the case learners
most need) and for simple live syllables; ambiguous syllables report
`"tone": null` rather than guessing. Paiboon romanization is intentionally not
emitted (no faithful programmatic source); derive it from the IPA/tone here plus
references/romanization.md.

Usage:
  thai-translit.py TEXT                 # romanize/segment a string
  echo TEXT | thai-translit.py -        # read from stdin
  thai-translit.py --help

Output: JSON {input, words, syllables:[{thai, rtgs, tone}]}.
stdout is data; stderr is diagnostics. Exit codes: 0 ok, 2 usage, 4 runtime.
"""
from __future__ import annotations  # type: validated (mypy --strict clean)

import json
import sys

# ── Thai tone-rule engine (no external deps) ───────────────────────────────

MID = set("กจฎฏดตบปอ")
HIGH = set("ขฃฉฐถผฝศษสห")
LOW = set("คฅฆงชซฌญฑฒณทธนพฟภมยรลวฬฮ")
CONSONANTS = MID | HIGH | LOW

EK = "่"  # ่  mai ek
THO = "้"  # ้  mai tho
TRI = "๊"  # ๊  mai tri
CHAT = "๋"  # ๋  mai chattawa
TONE_MARKS = {EK, THO, TRI, CHAT}

# Final consonants that close a "dead" syllable (stop endings /k/, /p/, /t/).
DEAD_FINALS = set("กขคฆบปพฟภจฉชซฌฎฏฐฑฒดตถทธศษส")
# Final consonants that close a "live" syllable (sonorant endings).
LIVE_FINALS = set("งญณนรลฬมยว")

# Short-vowel signs (subset that disambiguates the low-class dead case).
SHORT_VOWEL_SIGNS = set("ะัิึุ็ํ")  # ะ ั ิ ึ ุ ็ ํ
LONG_VOWEL_SIGNS = set("าีืูำ")  # า ี ื ู ำ
LEADING_VOWELS = set("เแโใไ")  # เ แ โ ใ ไ


def _strip_marks(syl: str) -> str:
    return "".join(c for c in syl if c not in TONE_MARKS)


def _initial_class(cons: list[str]) -> str | None:
    """Effective initial-consonant class, handling silent leaders ห-/อ-."""
    if not cons:
        return None
    first = cons[0]
    # ห นำ: silent ห raises a following low-class consonant to high class.
    if first == "ห" and len(cons) >= 2 and cons[1] in LOW:
        return "high"
    # อ นำ: silent อ lends mid class to following ย (อย่า อยู่ อย่าง อยาก).
    if first == "อ" and len(cons) >= 2 and cons[1] == "ย":
        return "mid"
    if first in MID:
        return "mid"
    if first in HIGH:
        return "high"
    if first in LOW:
        return "low"
    return None


def _is_dead_and_length(syl: str, cons: list[str]) -> tuple[bool | None, bool | None]:
    """Return (is_dead, is_long). Either may be None when undeterminable."""
    bare = _strip_marks(syl)
    chars = list(bare)
    has_long = any(c in LONG_VOWEL_SIGNS for c in chars)
    has_short = any(c in SHORT_VOWEL_SIGNS for c in chars)
    last = chars[-1] if chars else ""
    # A trailing consonant after the initial is the final.
    final = last if (last in CONSONANTS and len(cons) >= 2 and chars[-1] == last) else ""
    if final in DEAD_FINALS:
        return True, (has_long and not has_short)
    if final in LIVE_FINALS or final == "":
        if final in LIVE_FINALS:
            return False, None  # sonorant-closed syllables are live
        # open syllable: live if long vowel, dead if short vowel
        if has_long and not has_short:
            return False, True
        if has_short and not has_long:
            return True, False
    return None, None


def classify_tone(syl: str) -> str | None:
    """Return 'mid'|'low'|'falling'|'high'|'rising', or None if uncertain."""
    cons = [c for c in syl if c in CONSONANTS]
    cls = _initial_class(cons)
    if cls is None:
        return None
    mark = next((m for m in syl if m in TONE_MARKS), None)
    if mark == TRI:
        return "high"
    if mark == CHAT:
        return "rising"
    if mark == EK:
        return "low" if cls in ("mid", "high") else "falling"
    if mark == THO:
        return "falling" if cls in ("mid", "high") else "high"
    # No tone mark: depends on live/dead (+ vowel length for low class).
    is_dead, is_long = _is_dead_and_length(syl, cons)
    if is_dead is None:
        return None
    if not is_dead:  # live
        return "rising" if cls == "high" else "mid"
    # dead
    if cls in ("mid", "high"):
        return "low"
    if is_long is None:
        return None
    return "falling" if is_long else "high"


# ── main ───────────────────────────────────────────────────────────────────


def run(text: str) -> dict[str, object]:
    from pythainlp.tokenize import syllable_tokenize, word_tokenize
    from pythainlp.transliterate import romanize

    words = [w for w in word_tokenize(text) if w.strip()]
    syllables: list[dict[str, object]] = []
    for syl in syllable_tokenize(text):
        if not syl.strip():
            continue
        syllables.append(
            {
                "thai": syl,
                "rtgs": romanize(syl, engine="royin"),
                "tone": classify_tone(syl),
            }
        )
    return {"input": text, "words": words, "syllables": syllables}


def main(argv: list[str]) -> int:
    args = [a for a in argv[1:] if a not in ("--",)]
    if not args or args[0] in ("-h", "--help"):
        sys.stdout.write(__doc__ or "")
        return 0 if args[:1] in (["-h"], ["--help"]) else 2
    text = sys.stdin.read().strip() if args[0] == "-" else " ".join(args)
    if not text:
        sys.stderr.write("thai-translit: empty input\n")
        return 2
    try:
        result = run(text)
    except Exception as exc:  # noqa: BLE001 — surface any runtime/import failure
        sys.stderr.write(f"thai-translit: {exc!r}\n")
        return 4
    json.dump(result, sys.stdout, ensure_ascii=False, indent=2)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
