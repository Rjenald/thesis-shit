"""Does the text layer survive this catalog's actual lyrics?

Every case here is a word or line taken from backend/lyrics/, not an
invented one, because the failures that matter are the ones these ten
songs contain: apostrophe elisions (`ako'y`, `'yo`, `puso't`), the `ng`
digraph, hyphenated reduplication (`araw-araw`, `dahan-dahang`), English
loan lines in Fallen and Randomantic, and the parenthesised backing
vocals that would drift a forced alignment if they were kept.

    python backend/test_lyric_text.py
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import lyric_text as L                                       # noqa: E402

fails = []


def check(name, cond, detail=''):
    print(f"  {'OK  ' if cond else 'FAIL'} {name}"
          f"{'  ' + str(detail) if detail else ''}")
    if not cond:
        fails.append(name)


def sylls(word):
    """The syllable texts a word reports, e.g. ako'y -> [a, ko'y]."""
    return [s[0] for s in L.LyricWord(word).syllables]


print('syllables, by the open-syllable rules')
cases = {
    'nasa': ['na', 'sa'],
    'lahat': ['la', 'hat'],
    'minamahal': ['mi', 'na', 'ma', 'hal'],
    'pagkat': ['pag', 'kat'],
    'iyo': ['i', 'yo'],
    'puso': ['pu', 'so'],
    'kita': ['ki', 'ta'],
    'tapat': ['ta', 'pat'],
    'buwan': ['bu', 'wan'],
    'sigaw': ['si', 'gaw'],
}
for word, want in cases.items():
    got = sylls(word)
    check(f'{word} -> {"-".join(want)}', got == want, got)

print('\nthe ng digraph is one consonant, so it is never split')
# "ng" is the ONSET of the following syllable, so hangin is ha-ngin
# (/ˈha.ŋin/) -- not hang-in. This assertion had it backwards first time.
check('hangin -> ha-ngin', sylls('hangin') == ['ha', 'ngin'],
      sylls('hangin'))
check('pangarap -> pa-nga-rap', sylls('pangarap') == ['pa', 'nga', 'rap'],
      sylls('pangarap'))
check('ang is one syllable', sylls('ang') == ['ang'], sylls('ang'))
check('ng alone survives as a syllable', sylls('ng') == ['ng'],
      sylls('ng'))

print('\napostrophes stay with the syllable they belong to')
check("ako'y -> a-ko'y", sylls("ako'y") == ['a', "ko'y"], sylls("ako'y"))
check("'yo is one syllable, apostrophe kept",
      sylls("'yo") == ["'yo"], sylls("'yo"))
check("nag-iisa -> nag-i-i-sa (the hyphen is a syllable boundary)",
      sylls('nag-iisa') == ['nag', 'i', 'i', 'sa'], sylls('nag-iisa'))
check("araw-araw -> a-raw-a-raw",
      sylls('araw-araw') == ['a', 'raw', 'a', 'raw'], sylls('araw-araw'))
check("trailing punctuation is trimmed off a token",
      [w.text for w in L.lyric_words('ang lahat, puso ko?')]
      == ['ang', 'lahat', 'puso', 'ko'],
      [w.text for w in L.lyric_words('ang lahat, puso ko?')])
check("puso't -> pu-so't", sylls("puso't") == ['pu', "so't"],
      sylls("puso't"))
check("ito'y -> i-to'y", sylls("ito'y") == ['i', "to'y"], sylls("ito'y"))
check("'pagkat keeps its apostrophe",
      sylls("'pagkat")[0].startswith("'"), sylls("'pagkat"))

print('\nnormalisation keeps a map back to the original spelling')
norm, idx = L.normalize_word("ako'y")
check('ako\'y normalises to akoy', norm == 'akoy', norm)
check('  and each letter knows where it came from', idx == [0, 1, 2, 4], idx)
check('a token with no letters is not alignable',
      not L.LyricWord('?').alignable)
check('  nor is a bare dash', not L.LyricWord('--').alignable)

print('\nevery syllable span covers the word, once, in order')
for word in ['minamahal', "ako'y", 'araw-araw', 'maliligaw', 'nag-iisa',
             'kumikinang-kinang', 'haharanahin', 'kailangan']:
    w = L.LyricWord(word)
    spans = [(s, e) for _, s, e in w.syllables]
    contiguous = (spans[0][0] == 0
                  and spans[-1][1] == len(w.norm)
                  and all(a[1] == b[0] for a, b in zip(spans, spans[1:])))
    check(f'{word} ({len(spans)} syllables) tiles {w.norm!r}', contiguous,
          spans if not contiguous else '')

print('\nEnglish lines do not crash it')
for word in ['fallen', "I'll", 'breakfast', 'post-it', 'romantic',
             'interested']:
    got = sylls(word)
    check(f'{word} -> {"-".join(got)}', len(got) >= 1 and all(got))

print('\nsection markers are dropped, lyrics are not')
text = '[Chorus]\nNasa \'yo na ang lahat\n\n[Verse 1]\nPati ang puso ko\n'
lines = L.clean_lyrics(text)
check('two lines kept, no markers', lines == ["Nasa 'yo na ang lahat",
                                              'Pati ang puso ko'], lines)
check('  a bracket mid-line is not a marker',
      L.clean_lyrics('ang [sic] lahat') == ['ang [sic] lahat'])

print('\nparenthesised backing vocals are dropped by default')
line = "Sa dilaw na buwan (Umaabot sa buwan)"
check('lead vocal only', L.clean_lyrics(line) == ['Sa dilaw na buwan'],
      L.clean_lyrics(line))
check('  kept when asked for',
      L.clean_lyrics(line, keep_parentheticals=True)
      == ['Sa dilaw na buwan Umaabot sa buwan'],
      L.clean_lyrics(line, keep_parentheticals=True))
check('  and whitespace is collapsed, not doubled',
      '  ' not in L.clean_lyrics(line)[0])
check('  a line that is nothing but a parenthetical disappears',
      L.clean_lyrics('(Never mind, never mind)') == [],
      L.clean_lyrics('(Never mind, never mind)'))
check('  an unclosed paren does not swallow the line',
      L.clean_lyrics('Kahit wala na (oh') == ['Kahit wala na oh'],
      L.clean_lyrics('Kahit wala na (oh'))

print('\nthe real files load and tile cleanly')
lyrics_dir = Path(__file__).parent / 'lyrics'
sheets = sorted(lyrics_dir.glob('*.txt'))
check(f'{len(sheets)} lyrics file(s) found', len(sheets) == 10, len(sheets))
total_words = total_sylls = 0
for path in sheets:
    words = L.lyric_words(path.read_text(encoding='utf-8'))
    broken = [w for w in words
              if not w.syllables
              or ''.join(s[0] for s in w.syllables).replace("'", '')
              .lower().replace('-', '')
              != w.text.replace("'", '').lower().replace('-', '')
              .strip('?,."')]
    total_words += len(words)
    total_sylls += sum(len(w.syllables) for w in words)
    check(f'{path.stem[:34]:<34} {len(words):4d} words',
          len(words) > 0 and not broken,
          f'{len(broken)} rebuild wrong: {broken[:4]}' if broken else '')
print(f'\n  {total_words} words -> {total_sylls} syllables '
      f'({total_sylls / max(total_words, 1):.2f} per word)')

print('\nparentheticals are a real share of two songs, not a theory')
for stem in ['Mundo - IV Of Spades', 'Buwan - Juan Karlos']:
    text = L.load_lyrics(stem, lyrics_dir)
    lead = len(L.lyric_words(text))
    both = len(L.lyric_words(text, keep_parentheticals=True))
    check(f'{stem[:28]:<28} {lead} lead vs {both} with backing',
          both > lead, f'+{both - lead} words would be forced in sequence')

print()
print('FAILURES:', fails if fails else 'none')
sys.exit(1 if fails else 0)
