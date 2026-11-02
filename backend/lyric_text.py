"""Turning a lyrics sheet into something an aligner and a scorer agree on.

Forced alignment needs three things from a lyrics file, and they are not
the same thing:

  - **the word sequence to align** -- stripped of section markers and, by
    default, of parenthesised backing vocals (see `clean_lyrics`)
  - **a normalised spelling per word** -- lowercase a-z, because the MMS
    forced aligner is a character CTC model over a fixed Latin alphabet
    and has no token for an apostrophe or a hyphen
  - **the original spelling to display** -- `ako'y`, not `akoy`, since the
    label is read by a human checking a file against a recording

So every word carries both forms plus the mapping between them, which is
what lets a character-level alignment be reported as syllables with their
apostrophes intact.

The syllabifier is here rather than in the notebook because the local
validator scores labels against these same files, and a scorer that
normalised text differently from the extractor would report disagreements
that only exist in the normalisation.
"""
from __future__ import annotations

import re
import unicodedata
from pathlib import Path

VOWELS = set('aeiou')

# Tagalog's "ng" is one consonant (one letter, pre-1987 alphabet), so
# "hangin" is hang-in and not han-gin. English loanwords in this catalog
# ("things", "wrong") are unaffected: in both readings the digraph stays
# inside one syllable.
DIGRAPHS = ('ng',)

_SECTION_RE = re.compile(r'^\s*\[[^\]]*\]\s*$')
_PAREN_RE = re.compile(r'\([^)]*\)')


def clean_lyrics(text: str, keep_parentheticals: bool = False) -> list[str]:
    """A lyrics sheet -> the lines to align, in order.

    Section markers (`[Chorus]`) are dropped: they are navigation aids for
    whoever is checking the file by ear, not sung.

    Parenthesised text is dropped by default, which is the non-obvious
    one. In this catalog the parentheses mark backing vocals sung *at the
    same time* as the lead -- "Sa dilaw na buwan (Umaabot sa buwan)". A
    forced aligner consumes its transcript strictly in order, so it has no
    way to represent two things at once; handed both, it must place the
    backing line somewhere after the lead line, and every later word
    inherits that error. Dropping them keeps the lead vocal's timing
    honest, and the star token absorbs the audio they would have claimed.
    """
    lines = []
    for raw in text.splitlines():
        if _SECTION_RE.match(raw):
            continue
        line = raw if keep_parentheticals else _PAREN_RE.sub(' ', raw)
        line = line.replace('(', ' ').replace(')', ' ')
        # Removing a parenthetical leaves the space on either side of it,
        # so collapse runs rather than emitting "buwan  Umaabot".
        line = ' '.join(line.split())
        if line:
            lines.append(line)
    return lines


# Stripped from either end of a token before it becomes a word. An
# apostrophe is NOT in here: in this catalog it marks an elision that is
# part of the word ('yo, 'pagkat, ako'y), and dropping it would show the
# singer a syllable they are not reading. A hyphen is not either -- it
# marks a morpheme boundary that LyricWord uses.
_TRIM = ',.?!;:"“”…'


def normalize_word(word: str) -> tuple[str, list[int]]:
    """A word -> (letters the aligner can consume, index of each in `word`).

    The index list is what makes the round trip possible: character 2 of
    `akoy` is character 3 of `ako'y`, so a span over normalised characters
    can be reported with the apostrophe the singer is actually reading.
    """
    out, idx = [], []
    for i, ch in enumerate(word):
        # Decomposing first means an accented vowel contributes its base
        # letter instead of being dropped as unknown.
        for part in unicodedata.normalize('NFKD', ch):
            low = part.lower()
            if 'a' <= low <= 'z':
                out.append(low)
                idx.append(i)
    return ''.join(out), idx


def syllabify(norm: str) -> list[tuple[int, int]]:
    """Normalised letters -> [(start, end)] character spans, one per syllable.

    Tagalog orthography is close to phonemic, so the ordinary open-syllable
    rules get this right without a dictionary:

        V|V     two adjacent vowels split            i|yo
        V|CV    one consonant onsets the next        na|sa, la|hat
        VC|CV   two or more, the first is a coda     pag|kat

    Trailing consonants attach to the last syllable as a coda, and a word
    with no vowel at all (`ng`) stays one piece rather than disappearing.

    This is reported, never scored. Note boundaries come from the pitch
    contour, so a syllable split in the wrong place costs a label.
    """
    if not norm:
        return []

    # Treat each digraph as a single unit so it cannot be split across a
    # boundary; `positions` holds the index in `norm` each unit starts at.
    units, positions, i = [], [], 0
    while i < len(norm):
        for d in DIGRAPHS:
            if norm.startswith(d, i):
                units.append(d)
                positions.append(i)
                i += len(d)
                break
        else:
            units.append(norm[i])
            positions.append(i)
            i += 1

    vowel_at = [u in VOWELS for u in units]
    if not any(vowel_at):
        return [(0, len(norm))]

    # Boundaries, as unit indices where a new syllable starts.
    starts = [0]
    vowels = [k for k, v in enumerate(vowel_at) if v]
    for a, b in zip(vowels, vowels[1:]):
        gap = b - a - 1                      # consonant units between them
        if gap == 0:
            cut = b                          # i|yo
        elif gap == 1:
            cut = b - 1                      # na|sa
        else:
            cut = a + 2                      # pag|kat: first consonant codas
        if cut > starts[-1]:
            starts.append(cut)

    spans = []
    for k, s in enumerate(starts):
        e = starts[k + 1] if k + 1 < len(starts) else len(units)
        spans.append((positions[s],
                      positions[e] if e < len(units) else len(norm)))
    return spans


class LyricWord:
    """One word of a lyrics sheet, in both spellings, with its syllables.

    `syllables` is a list of (text, norm_start, norm_end): the text to
    show, and the half-open span of normalised characters it covers, which
    is the unit a character-level alignment returns.
    """

    __slots__ = ('text', 'norm', 'syllables', 'line')

    def __init__(self, text: str, line: int = 0):
        self.text = text
        self.line = line
        self.norm, idx = normalize_word(text)

        # A hyphen in Tagalog marks a morpheme boundary, and that boundary
        # is always a syllable boundary too: `nag-iisa` is nag-i-i-sa, not
        # the na-gi-i-sa the open-syllable rules alone would give, because
        # the hyphen stands for a glottal stop that cannot be an onset.
        # So each hyphenated part is syllabified in its own right.
        spans, offset = [], 0
        for part in re.split(r'[-‐-―]', text):
            pnorm, _ = normalize_word(part)
            if not pnorm:
                continue
            spans += [(s + offset, e + offset) for s, e in syllabify(pnorm)]
            offset += len(pnorm)

        self.syllables = []
        for k, (s, e) in enumerate(spans):
            # The displayed syllable runs from the original character the
            # span's first letter came from to its last. The first
            # syllable starts at the beginning of the token instead, so a
            # leading apostrophe rides along with it -- `'yo`, not `yo`.
            lo = 0 if k == 0 else idx[s]
            self.syllables.append((text[lo:idx[e - 1] + 1], s, e))

    @property
    def alignable(self) -> bool:
        """False for a token with no letters at all, e.g. `?` or `--`."""
        return bool(self.norm)

    def __repr__(self) -> str:                           # pragma: no cover
        return f'LyricWord({self.text!r}, {self.norm!r})'


def lyric_words(text: str, keep_parentheticals: bool = False) \
        -> list[LyricWord]:
    """A lyrics sheet -> the alignable words, in order."""
    words = []
    for n, line in enumerate(clean_lyrics(text, keep_parentheticals)):
        for token in line.split():
            w = LyricWord(token.strip(_TRIM), n)
            if w.alignable:
                words.append(w)
    return words


def load_lyrics(stem: str, lyrics_dir: Path | None = None) -> str | None:
    """The lyrics sheet for a `<Title> - <Artist>` stem, or None."""
    lyrics_dir = lyrics_dir or (Path(__file__).parent / 'lyrics')
    path = lyrics_dir / f'{stem}.txt'
    if not path.exists():
        return None
    return path.read_text(encoding='utf-8')
