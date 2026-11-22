"""Runs the notebook's forced-alignment cell against a stub MMS_FA.

torchaudio is not installed here and the real weights are 1.2GB, so the
model, tokenizer and aligner are faked -- but faked to MMS_FA's actual
contract, which is what the cell's own code depends on:

  bundle.sample_rate                      16000
  bundle.get_model(with_star=)            -> model(wav) -> (emission, lens)
  bundle.get_tokenizer()                  -> f(list[str]) -> tokens
  bundle.get_aligner()                    -> f(emission, tokens)
                                             -> [[TokenSpan]] per word
  TokenSpan                               .token .start .end .score

What this actually checks is the code in the notebook, not Meta's: the
chunking arithmetic in emission_for, the frame->second mapping, and the
character-span-to-syllable split in align_words. Those are where the bugs
would be. It also pins the cell's embedded copy of the text layer to
backend/lyric_text.py, so the two cannot drift apart unnoticed.

    python backend/test_aligner_cell.py
"""
from __future__ import annotations

import json
import sys
import types
from dataclasses import dataclass
from pathlib import Path

import numpy as np
import torch

BACKEND = Path(__file__).resolve().parent
REPO = BACKEND.parent
sys.path.insert(0, str(BACKEND))
import lyric_text as L                                       # noqa: E402

SR = 16000
STRIDE = 320
VOCAB = 30

fails = []


def check(name, cond, detail=''):
    print(f"  {'OK  ' if cond else 'FAIL'} {name}"
          f"{'  ' + str(detail) if detail else ''}")
    if not cond:
        fails.append(name)


# ----------------------------------------------------------- the stubs
@dataclass
class TokenSpan:
    token: int
    start: int
    end: int
    score: float


class FakeModel:
    """Emits one frame per STRIDE samples, the way wav2vec2 does.

    Deliberately NOT exact: a real conv stack loses a few frames at the
    tail, so one is dropped here too. emission_for must not assume
    samples/STRIDE.
    """

    def __init__(self):
        self.calls = []

    def to(self, device):
        return self

    def eval(self):
        return self

    def __call__(self, wav):
        n = wav.shape[-1]
        frames = max(1, n // STRIDE - 1)
        self.calls.append((n, frames))
        return torch.zeros(1, frames, VOCAB), None


class FakeTokenizer:
    """One token per character, as a character CTC model's tokenizer does."""

    def __call__(self, words):
        return [[ord(c) - ord('a') for c in w] for w in words]


class FakeAligner:
    """Lays the tokens out evenly across the emission, in order.

    Even layout is the point: it makes every returned span predictable, so
    a syllable span that comes out wrong is the cell's arithmetic and not
    the stub's.
    """

    def __init__(self, drop_a_token_in=()):
        self.drop_in = set(drop_a_token_in)

    def __call__(self, emission, tokens):
        total = sum(len(t) for t in tokens)
        frames = emission.shape[0]
        per = max(1, frames // max(total, 1))
        out, f = [], 0
        for i, toks in enumerate(tokens):
            if i in self.drop_in:
                toks = toks[:-1]              # tokenizer lost a character
            spans = []
            for t in toks:
                spans.append(TokenSpan(t, f, f + per, 0.9))
                f += per
            out.append(spans)
        return out


def install_stubs(model, aligner, wav_seconds, sample_rate=SR):
    """A torchaudio module just complete enough for the cell."""
    bundle = types.SimpleNamespace(
        sample_rate=SR,
        get_model=lambda with_star=False: model,
        get_tokenizer=lambda: FakeTokenizer(),
        get_aligner=lambda: aligner,
    )
    n = int(wav_seconds * sample_rate)
    ta = types.ModuleType('torchaudio')
    ta.__version__ = '0.0-stub'
    ta.pipelines = types.SimpleNamespace(MMS_FA=bundle)
    ta.load = lambda path: (torch.zeros(2, n), sample_rate)
    ta.functional = types.SimpleNamespace(
        resample=lambda w, a, b: torch.zeros(
            w.shape[0], int(w.shape[1] * b / a)))
    sys.modules['torchaudio'] = ta
    return ta


# ------------------------------------------------- load the cell's code
nb = json.loads((BACKEND / 'ground_truth_from_stems.ipynb')
                .read_text(encoding='utf-8'))
aligner_src = None
for c in nb['cells']:
    s = ''.join(c['source'])
    if c['cell_type'] == 'code' and 'def align_words(' in s:
        aligner_src = s
assert aligner_src, 'no cell defines align_words'

LYRICS = {p.stem: p.read_text(encoding='utf-8')
          for p in sorted((BACKEND / 'lyrics').glob('*.txt'))}


def to_mono_from_extract():
    """Cell 6 calls to_mono, which Cell 8 defines.

    That direction looks backwards but is correct: Cell 6 only defines
    functions, and nothing in it runs until Cell 8's loop calls it, by
    which point to_mono exists. Pulled in here so the test exercises the
    same arrangement -- if to_mono ever moves again, this fails loudly
    instead of the notebook failing on Colab.
    """
    for c in nb['cells']:
        s = ''.join(c['source'])
        if c['cell_type'] == 'code' and 'def to_mono(' in s:
            g = {'__name__': 'extract', 'print': lambda *a, **k: None}
            start = s.index('def to_mono(')
            end = s.index('def pitch_track(')
            exec(compile(s[start:end], 'cell8', 'exec'), g)
            return g['to_mono']
    raise AssertionError('no cell defines to_mono')


def load_cell(model, aligner, wav_seconds, **settings):
    install_stubs(model, aligner, wav_seconds)
    g = {
        '__name__': 'nbcell',
        'LYRICS_BY_SONG': LYRICS,
        'KEEP_PARENTHETICALS': False,
        'ALIGN_CHUNK_S': 20.0,
        'ALIGN_CONTEXT_S': 2.0,
        'ALIGN_MARGIN_S': 0.5,
        'USE_STAR': False,
        'LABEL_UNIT': 'syllable',
        'to_mono': to_mono_from_extract(),
    }
    g.update(settings)
    exec(compile(aligner_src, 'cell6', 'exec'), g)
    return g


print('the cell runs at all')
import io
import contextlib
buf = io.StringIO()
with contextlib.redirect_stdout(buf):
    G = load_cell(FakeModel(), FakeAligner(), 30.0)
check('cell 6 executes', 'align_words' in G)
check('  and prints a per-song word/syllable summary',
      'syllables' in buf.getvalue(), buf.getvalue().splitlines()[:1])

print('\nthe embedded text layer matches backend/lyric_text.py exactly')
for word in ["ako'y", "'yo", 'nag-iisa', 'hangin', 'minamahal', 'araw-araw',
             'pangarap', 'ng', "puso't", 'kumikinang-kinang', 'breakfast']:
    mine = [s[0] for s in G['LyricWord'](word).syllables]
    theirs = [s[0] for s in L.LyricWord(word).syllables]
    check(f'{word}: {"-".join(mine)}', mine == theirs, f'module says {theirs}')
for stem, text in LYRICS.items():
    a = [w.text for w in G['lyric_words'](text)]
    b = [w.text for w in L.lyric_words(text)]
    check(f'{stem[:38]:<38} {len(a):4d} words', a == b)

print('\nemission_for: chunk arithmetic')
for seconds, chunk in [(30.0, 20.0), (220.0, 20.0), (5.0, 20.0),
                       (61.3, 15.0), (1.0, 20.0)]:
    model = FakeModel()
    g = load_cell(model, FakeAligner(), seconds, ALIGN_CHUNK_S=chunk)
    with contextlib.redirect_stdout(io.StringIO()):
        m, _, _ = g['load_aligner']('cpu')
        em, times = g['emission_for'](torch.zeros(1, int(seconds * SR)),
                                      m, 'cpu')
    ok_len = em.shape[0] == len(times)
    monotonic = bool(np.all(np.diff(times) > 0)) if len(times) > 1 else True
    spans_track = -0.05 <= times[0] <= 0.05 and \
        abs(times[-1] - seconds) < 1.5
    check(f'{seconds:6.1f}s in {chunk:.0f}s chunks -> {em.shape[0]} frames',
          ok_len and monotonic and spans_track,
          f'len match {ok_len}, monotonic {monotonic}, '
          f'times {times[0]:.2f}..{times[-1]:.2f}')
    # Context must be fed to the model but not survive into the output.
    padded = sum(f for _, f in model.calls)
    check(f'  {len(model.calls)} pass(es), context trimmed',
          padded >= em.shape[0], f'{padded} frames in, {em.shape[0]} kept')

print('\nemission_for: a chunk boundary gets real context, not zeros')
model = FakeModel()
g = load_cell(model, FakeAligner(), 50.0, ALIGN_CHUNK_S=20.0,
              ALIGN_CONTEXT_S=2.0)
with contextlib.redirect_stdout(io.StringIO()):
    m, _, _ = g['load_aligner']('cpu')
    g['emission_for'](torch.zeros(1, 50 * SR), m, 'cpu')
sizes = [n for n, _ in model.calls]
check('3 chunks for 50s at 20s each', len(sizes) == 3, sizes)
check('  interior chunk is padded on both sides',
      sizes[1] == (20 + 4) * SR, f'{sizes[1] / SR:.1f}s')
check('  first chunk is padded on the right only',
      sizes[0] == (20 + 2) * SR, f'{sizes[0] / SR:.1f}s')
check('  last chunk is padded on the left only',
      sizes[2] == (10 + 2) * SR, f'{sizes[2] / SR:.1f}s')

print('\nalign_words: spans, order and the syllable split')
stem = 'Nasa Iyo Na Ang Lahat - Daniel Padilla'
g = load_cell(FakeModel(), FakeAligner(), 210.0)
with contextlib.redirect_stdout(io.StringIO()):
    words, sylls, rep = g['align_words']('fake.wav', LYRICS[stem], 'cpu')

check('every lyric word got a span',
      rep['words_aligned'] == rep['words_in_lyrics'],
      f'{rep["words_aligned"]}/{rep["words_in_lyrics"]}')
check('  word order is the lyrics order',
      [w['text'] for w in words[:6]]
      == ['Nasa', "'yo", 'na', 'ang', 'lahat', 'Minamahal'],
      [w['text'] for w in words[:6]])
check('  word spans are monotonic',
      all(a['start'] <= b['start'] for a, b in zip(words, words[1:])))
check('  every word has positive duration',
      all(w['end'] > w['start'] for w in words))
check('  spans stay inside the track',
      words[0]['start'] >= 0 and words[-1]['end'] <= 211.0,
      f'{words[0]["start"]:.2f}..{words[-1]["end"]:.2f}')

check('syllables outnumber words', rep['syllables'] > rep['words_aligned'],
      f'{rep["syllables"]} vs {rep["words_aligned"]}')
check('  no word failed to syllabify', rep['split_failed'] == 0,
      rep['split_failed'])
check('  first syllables are the lyrics, split',
      [s['text'] for s in sylls[:7]]
      == ['Na', 'sa', "'yo", 'na', 'ang', 'la', 'hat'],
      [s['text'] for s in sylls[:7]])
check('  syllable spans are monotonic',
      all(a['start'] <= b['start'] for a, b in zip(sylls, sylls[1:])))
check('  a word\'s syllables tile its span',
      abs(sylls[0]['start'] - words[0]['start']) < 1e-6
      and abs(sylls[1]['end'] - words[0]['end']) < 1e-6,
      f'word {words[0]["start"]:.3f}..{words[0]["end"]:.3f} vs '
      f'syllables {sylls[0]["start"]:.3f}..{sylls[1]["end"]:.3f}')
check('  no label is blank', all(s['text'].strip() for s in sylls))
check('  no music-note emoji can appear',
      not any(ch in s['text'] for s in sylls for ch in '\U0001f3b5\u266a'))

print('\nalign_words: a lost character falls back to the whole word')
g = load_cell(FakeModel(), FakeAligner(drop_a_token_in=(0, 5)), 210.0)
with contextlib.redirect_stdout(io.StringIO()):
    words, sylls, rep = g['align_words']('fake.wav', LYRICS[stem], 'cpu')
check('two words reported as not syllabified', rep['split_failed'] == 2,
      rep['split_failed'])
check('  the whole word is used as the label instead',
      sylls[0]['text'] == 'Nasa', sylls[0]['text'])
check('  the rest still split normally',
      sylls[1]['text'] == "'yo", sylls[1]['text'])

print('\nalign_words: label_notes consumes what it returns')
seg_src = settings_src = None
for c in nb['cells']:
    s = ''.join(c['source'])
    if c['cell_type'] != 'code':
        continue
    if s.startswith('HOP_MS'):
        settings_src = s
    if 'def label_notes(' in s:
        seg_src = s
assert seg_src and settings_src
# Settings first: note segmentation reports its own smoothing quorum, so
# it depends on SMOOTH_MS the same way it does in the notebook.
gseg = {'__name__': 'nbcell7'}
with contextlib.redirect_stdout(io.StringIO()):
    exec(compile(settings_src, 'settings', 'exec'), gseg)
    exec(compile(seg_src, 'cell7', 'exec'), gseg)
g = load_cell(FakeModel(), FakeAligner(), 210.0)
with contextlib.redirect_stdout(io.StringIO()):
    words, sylls, rep = g['align_words']('fake.wav', LYRICS[stem], 'cpu')
notes = [{'start': s['start'], 'end': s['end'],
          'midi': 60.0, 'note_frames': 20} for s in sylls[:40]]
rows = gseg['label_notes'](notes, sylls)
check('label_notes accepts the syllable spans', len(rows) == 40, len(rows))
check('  and emits the exact keys the app parses',
      all(set(r) == {'syllable', 'start', 'end', 'note'} for r in rows))
labelled = sum(1 for r in rows if r['syllable'])
check('  every note over a syllable gets that syllable', labelled == 40,
      f'{labelled}/40')
check('  and it is the right one',
      [r['syllable'] for r in rows[:5]]
      == [s['text'] for s in sylls[:5]],
      [r['syllable'] for r in rows[:5]])
rows_w = gseg['label_notes'](notes, words)
check('word spans work too (LABEL_UNIT = word)',
      rows_w[0]['syllable'] == 'Nasa', rows_w[0]['syllable'])

print('\nparentheticals change the transcript, as intended')
for stem2 in ['Mundo - IV Of Spades', 'Buwan - Juan Karlos']:
    g1 = load_cell(FakeModel(), FakeAligner(), 210.0,
                   KEEP_PARENTHETICALS=False)
    g2 = load_cell(FakeModel(), FakeAligner(), 210.0,
                   KEEP_PARENTHETICALS=True)
    with contextlib.redirect_stdout(io.StringIO()):
        _, _, r1 = g1['align_words']('f.wav', LYRICS[stem2], 'cpu')
        _, _, r2 = g2['align_words']('f.wav', LYRICS[stem2], 'cpu')
    check(f'{stem2[:28]:<28} {r1["words_in_lyrics"]} lead vs '
          f'{r2["words_in_lyrics"]} with backing',
          r2['words_in_lyrics'] > r1['words_in_lyrics'])

print('\nedge cases')
g = load_cell(FakeModel(), FakeAligner(), 210.0)
try:
    with contextlib.redirect_stdout(io.StringIO()):
        g['align_words']('f.wav', '[Chorus]\n\n', 'cpu')
    check('empty lyrics raise, not silently produce nothing', False)
except ValueError as e:
    check('empty lyrics raise ValueError', 'no alignable words' in str(e))
g = load_cell(FakeModel(), FakeAligner(), 210.0)
with contextlib.redirect_stdout(io.StringIO()):
    w, sy, rep = g['align_words']('f.wav', 'ng', 'cpu')
check('a single vowel-less word still aligns', len(w) == 1 and len(sy) == 1,
      f'{len(w)} words, {len(sy)} syllables')

g = load_cell(FakeModel(), FakeAligner(), 210.0)
with contextlib.redirect_stdout(io.StringIO()):
    _, _, rep = g['align_words']('f.wav', LYRICS[stem], 'cpu')
check('report carries every field the validate cell prints',
      set(rep) >= {'words_in_lyrics', 'words_aligned', 'syllables',
                   'mean_score', 'weak', 'split_failed', 'first', 'last',
                   'frames'},
      sorted(rep))

print()
print('FAILURES:', fails if fails else 'none')
sys.exit(1 if fails else 0)
