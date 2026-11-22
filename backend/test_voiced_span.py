"""Does the sung-region logic actually remove the bleed and keep the song?

The defect this exists for was measured, not imagined: the first aligned
extraction of `Nasa Iyo Na Ang Lahat` put 7 notes between 9.9s and 15.4s
on a track whose first sung word is at 15.8s. The cause was
`running_median` being NaN-aware without a quorum -- one confident frame
in five made all five voiced -- so sparse instrumental bleed in the vocal
stem was smoothed into something shaped like a held note.

So the cases below are built the way that bleed looks: short, sparse,
weakly-periodic pitch, next to real sustained singing. A fix that only
removed the bleed by also clipping the song would pass a looser test and
fail here.

    python backend/test_voiced_span.py
"""
from __future__ import annotations

import contextlib
import io
import json
import sys
from pathlib import Path

import numpy as np

BACKEND = Path(__file__).resolve().parent
HOP_MS = 10

fails = []
SETTINGS_SRC = ''


def check(name, cond, detail=''):
    print(f"  {'OK  ' if cond else 'FAIL'} {name}"
          f"{'  ' + str(detail) if detail else ''}")
    if not cond:
        fails.append(name)


def load_cells():
    """Exec the notebook's settings and note-segmentation cells."""
    nb = json.loads((BACKEND / 'ground_truth_from_stems.ipynb')
                    .read_text(encoding='utf-8'))
    settings = seg = None
    for c in nb['cells']:
        s = ''.join(c['source'])
        if c['cell_type'] != 'code':
            continue
        if s.startswith('HOP_MS'):
            settings = s
        if 'def segment_notes(' in s:
            seg = s
    assert settings and seg
    global SETTINGS_SRC
    SETTINGS_SRC = settings
    g = {'__name__': 'nb'}
    try:
        with contextlib.redirect_stdout(io.StringIO()):
            exec(compile(settings, 'settings', 'exec'), g)
            exec(compile(seg, 'noteseg', 'exec'), g)
    except Exception as e:                                  # noqa: BLE001
        # The notebook is edited in place, so saving a Colab download over
        # it silently reverts everything fixed since that copy was taken.
        # That has happened, and the bare traceback it produced here was
        # no help at all -- the failure is not in these cells, it is that
        # the file went backwards.
        raise SystemExit(
            f'\nThe extractor notebook does not run: {type(e).__name__}: '
            f'{e}\n\n'
            'This is what a stale copy looks like. If you downloaded\n'
            'ground_truth_from_stems.ipynb from Colab and saved it back\n'
            'over the repo, it lost every fix made after that copy was\n'
            'taken. Bring it forward with:\n\n'
            '    python backend/patch_stems_notebook.py\n'
            '    python backend/test_voiced_span.py\n') from e
    return g


G = load_cells()


def contour(spans, conf=0.9):
    """spans = [(midi|None, ms)] -> (times, hz, periodicity)."""
    midi, per = [], []
    for value, ms in spans:
        n = int(round(ms / HOP_MS))
        if value is None:
            midi += [np.nan] * n
            per += [0.0] * n
        else:
            midi += [float(value)] * n
            per += [conf] * n
    midi = np.array(midi, dtype=float)
    hz = np.where(np.isnan(midi), 0.0, 440.0 * 2 ** ((midi - 69) / 12))
    return (np.arange(len(midi)) * HOP_MS / 1000.0, hz, np.array(per))


def sparse_bleed(ms, midi=73, duty=4, conf=0.9):
    """One confident frame in `duty`, which is what the stem bleed was.

    Every frame is nominally the same pitch; only a fraction are
    periodic enough to count. This is the input that the old filter
    turned into a solid note.
    """
    n = int(round(ms / HOP_MS))
    hz = np.full(n, 440.0 * 2 ** ((midi - 69) / 12))
    per = np.zeros(n)
    per[::duty] = conf
    return np.arange(n) * HOP_MS / 1000.0, hz, per


def join(*parts):
    hzs, pers = [], []
    for _, hz, per in parts:
        hzs.append(hz)
        pers.append(per)
    hz = np.concatenate(hzs)
    per = np.concatenate(pers)
    return np.arange(len(hz)) * HOP_MS / 1000.0, hz, per


print('running_median needs a quorum before it believes a window')
rm = G['running_median']
x = np.array([np.nan, np.nan, 60.0, np.nan, np.nan])
check('1 valid frame in 5 -> still unvoiced',
      np.isnan(rm(x, 5)[2]), rm(x, 5)[2])
x = np.array([60.0, 60.0, 60.0, np.nan, np.nan])
check('3 valid in 5 -> voiced', not np.isnan(rm(x, 5)[2]), rm(x, 5)[2])
solid = np.full(20, 60.0)
check('a solid note is untouched',
      np.allclose(rm(solid, 5), 60.0))
check('  including its first frame, where the window is clipped',
      not np.isnan(rm(solid, 5)[0]), rm(solid, 5)[0])
check('  and its last', not np.isnan(rm(solid, 5)[-1]), rm(solid, 5)[-1])
# A real onset must not be eaten: the first frames of a note have a
# half-window of silence behind them and still have to survive.
onset = np.concatenate([np.full(10, np.nan), np.full(10, 60.0)])
sm = rm(onset, 5)
check('a note onset survives the quorum',
      not np.isnan(sm[11]), f'frame 11 = {sm[11]}')
check('  and the silence before it stays silent', np.isnan(sm[8]), sm[8])

print('\nvoiced_span: where the performance really is')
vs = G['voiced_span']
t, hz, per = contour([(None, 2000), (60, 3000), (None, 1500)])
lo, hi = vs(t, hz, per)
check('3s note after 2s of silence -> 2.0 .. 5.0',
      abs(lo - 2.0) < 0.05 and abs(hi - 5.0) < 0.05,
      f'{lo:.2f} .. {hi:.2f}')
t, hz, per = sparse_bleed(4000)
lo, hi = vs(t, hz, per)
check('sparse bleed alone -> no span at all', lo is None and hi is None,
      f'{lo} .. {hi}')
t, hz, per = contour([(60, 80), (None, 2000), (62, 2000)])
lo, hi = vs(t, hz, per)
check('an 80ms blip does not start the span', lo is not None and lo > 2.0,
      f'{lo:.2f}')
t, hz, per = contour([(None, 1000)])
check('silence only -> (None, None)', vs(t, hz, per) == (None, None))
t, hz, per = contour([(60, 3000)])
lo, hi = vs(t, hz, per)
check('singing from frame 0 is not confused with "nothing"',
      lo is not None and abs(lo) < 0.05, f'{lo}')

print('\nthe measured defect: bleed before the first sung word')
# 5.9s of bleed at 9.9s, then real singing from 15.8s -- the shape of the
# actual file, where 7 notes came out of the intro.
parts = join(contour([(None, 9900)]),
             sparse_bleed(5500, midi=73),
             contour([(None, 400), (59, 4000), (61, 3000), (59, 2000)]))
t, hz, per = parts
lo, hi = vs(t, hz, per)
check('span starts at the singing, not the bleed',
      lo is not None and lo > 15.0, f'{lo:.2f}s')
notes = G['segment_notes'](t, hz, per)
intro = [n for n in notes if n['end'] <= 15.5]
check('the quorum alone keeps bleed from becoming notes',
      not intro, f'{len(intro)} intro note(s): '
      f'{[round(n["start"], 2) for n in intro]}')
check('  and the real notes are still found', len(notes) >= 2, len(notes))
if notes:
    check('  starting where the singing does',
          abs(notes[0]['start'] - 15.8) < 0.3, f'{notes[0]["start"]:.2f}s')

print('\nnotes_within: the second line of defence')
nw = G['notes_within']
notes = [{'start': 9.9, 'end': 10.1}, {'start': 12.2, 'end': 12.9},
         {'start': 15.9, 'end': 16.4}, {'start': 200.0, 'end': 200.8},
         {'start': 219.0, 'end': 220.5}]
kept, dropped = nw(notes, 15.1, 209.2)
check('drops the two intro notes and the outro one',
      len(dropped) == 3 and len(kept) == 2,
      f'{len(kept)} kept, {len(dropped)} dropped')
check('  keeps exactly what is inside the span',
      [n['start'] for n in kept] == [15.9, 200.0],
      [n['start'] for n in kept])
check('  and names what it dropped, rather than dropping it quietly',
      [n['start'] for n in dropped] == [9.9, 12.2, 219.0],
      [n['start'] for n in dropped])
kept, dropped = nw(notes, None, None)
check('no span known -> nothing is dropped',
      len(kept) == len(notes) and not dropped)
kept, _ = nw([{'start': 14.95, 'end': 15.4}], 15.1, 209.2)
check('a note overlapping the boundary is kept, not clipped', len(kept) == 1)
kept, _ = nw([{'start': 209.3, 'end': 209.5}], 15.1, 209.2)
check('  and the margin forgives a near miss', len(kept) == 1)

print('\nthe previous behaviour is what changed, not the real notes')
# Same contour, quorum disabled: the bleed DOES become notes. If this
# ever stops being true, the test above has stopped proving anything.
t, hz, per = parts
midi = G['hz_to_midi'](hz)
midi[per < G['CONF_MIN']] = np.nan
win = max(1, int(round(G['SMOOTH_MS'] / HOP_MS)))
old = rm(midi, win, min_valid=1)
voiced_in_bleed = np.sum(~np.isnan(old[990:1540]))
check('without a quorum the bleed smooths into pitch',
      voiced_in_bleed > 300, f'{voiced_in_bleed} frames')
new = rm(midi, win)
check('  with one, it does not',
      np.sum(~np.isnan(new[990:1540])) < voiced_in_bleed / 2,
      f'{np.sum(~np.isnan(new[990:1540]))} frames')

print('\nbatch and chunk size follow the GPU that was allocated')
# A Colab Pro account gets an L4 or an A100 often enough that fixed
# T4-sized values waste most of the card. These are headroom figures, not
# benchmarks, so what is pinned here is the shape: bigger card, bigger
# batch, never smaller, and always a usable value even with no GPU.
sizes = {}
for gb in (0, 8, 16, 24, 40, 80):
    G['_vram_gb'] = lambda gb=gb: float(gb)
    sizes[gb] = G['tuned_for_gpu']()
check('every tier returns a usable pair',
      all(b > 0 and c > 0 for b, c in sizes.values()), sizes)
check('  no GPU still works', sizes[0][0] > 0, sizes[0])
check('  bigger VRAM never gets a smaller batch',
      all(sizes[a][0] <= sizes[b][0]
          for a, b in zip(sorted(sizes), sorted(sizes)[1:])),
      {k: v[0] for k, v in sizes.items()})
check('  nor a shorter chunk',
      all(sizes[a][1] <= sizes[b][1]
          for a, b in zip(sorted(sizes), sorted(sizes)[1:])),
      {k: v[1] for k, v in sizes.items()})
check('  a T4 keeps the values it was tuned with',
      sizes[16] == (512, 20.0), sizes[16])
check('  an L4 gets more', sizes[24][0] > sizes[16][0], sizes[24])
check('  and an A100 more again', sizes[40][0] > sizes[24][0], sizes[40])
# Alignment memory grows with the square of the chunk, so a chunk that
# scaled linearly with VRAM would OOM on the bigger cards.
check('  the chunk grows more slowly than VRAM does',
      sizes[40][1] / sizes[16][1] < 40 / 16 * 1.5,
      f'{sizes[16][1]:.0f}s -> {sizes[40][1]:.0f}s')
del G['_vram_gb']
check('an explicit setting is not overridden',
      'if BATCH_SIZE is None:' in SETTINGS_SRC
      and 'if ALIGN_CHUNK_S is None:' in SETTINGS_SRC)

print('\nthe confidence floor is per song, and relaxes when coverage is low')
# Buwan's notes covered 49s of a 272s span at conf_min 0.50 while forced
# alignment placed 156 words across the whole song: 83% of the aligned
# vocal had no note under it. The singing was there and the threshold was
# rejecting it, so a single global floor cannot serve this catalog.
for k, want in [('CONF_MIN', 0.50), ('RELAXED_CONF_MIN', 0.35),
                ('MIN_COVERAGE_PCT', 45), ('AUTO_RELAX_CONF', True)]:
    check(f'{k} = {want!r}', G.get(k) == want, G.get(k))
check('conf_min_for falls back to the default',
      G['conf_min_for']('a song with no override') == G['CONF_MIN'])
G['CONF_MIN_BY_SONG']['Buwan - Juan Karlos'] = 0.35
check('  and honours a per-song override',
      G['conf_min_for']('Buwan - Juan Karlos') == 0.35)
G['CONF_MIN_BY_SONG'].clear()


def coverage(evs):
    if not evs:
        return 0.0
    span = max(e['end'] for e in evs) - min(e['start'] for e in evs)
    return 100.0 * sum(e['end'] - e['start'] for e in evs) / span if span \
        else 0.0


# A breathy stem: real sung notes whose periodicity sits between the two
# thresholds. This is the shape the retry exists for.
breathy = []
bconf = []
for m, ms, c in [(59, 800, 0.42), (None, 200, 0.0), (61, 700, 0.40),
                 (None, 200, 0.0), (62, 900, 0.44), (None, 300, 0.0),
                 (59, 1000, 0.41)]:
    n = int(ms / HOP_MS)
    breathy += [np.nan] * n if m is None else [float(m)] * n
    bconf += [0.0] * n if m is None else [c] * n
breathy = np.array(breathy, dtype=float)
bconf = np.array(bconf, dtype=float)
bhz = np.where(np.isnan(breathy), 0.0,
               440.0 * 2 ** ((breathy - 69) / 12))
bt = np.arange(len(breathy)) * HOP_MS / 1000.0

strict = G['segment_notes'](bt, bhz, bconf)
G['CONF_MIN'] = G['RELAXED_CONF_MIN']
relaxed = G['segment_notes'](bt, bhz, bconf)
G['CONF_MIN'] = 0.50
check(f'a breathy stem yields {len(strict)} notes at 0.50',
      coverage(strict) < G['MIN_COVERAGE_PCT'],
      f'{coverage(strict):.0f}% coverage')
check(f'  and {len(relaxed)} notes at 0.35',
      coverage(relaxed) > G['MIN_COVERAGE_PCT'],
      f'{coverage(relaxed):.0f}% coverage')
check('  so the retry has something to find', len(relaxed) > len(strict))
check('  and CONF_MIN was put back', G['CONF_MIN'] == 0.50, G['CONF_MIN'])

nb_src = json.loads((BACKEND / 'ground_truth_from_stems.ipynb')
                    .read_text(encoding='utf-8'))
extract = next(''.join(c['source']) for c in nb_src['cells']
               if c['cell_type'] == 'code'
               and 'LABEL_SOURCE[stem] = mode' in ''.join(c['source']))
check('the extract cell retries on low coverage',
      'AUTO_RELAX_CONF' in extract and 'retrying at' in extract)
check('  it reports both passes rather than switching quietly',
      'notes /' in extract and 'keeping the relaxed pass' in extract)
check('  it only keeps the retry when coverage actually improved',
      'if cov2 > cov:' in extract)
check('  and it restores CONF_MIN per song',
      extract.count('CONF_MIN = _conf_was') >= 2)

print('\nlabels off is the default, and nothing needs Cells 5 or 6')
# The whole point of LABEL_MODE='none': Cell 4 -> 7 -> 8 -> 9 has to work
# with the lyrics and the aligner never loaded. These globals are absent
# in exactly the way they would be on a fresh Colab that skipped them.
check("LABEL_MODE defaults to 'none'", G['LABEL_MODE'] == 'none',
      repr(G['LABEL_MODE']))
check('  so settings alone never mentions LYRICS_BY_SONG',
      'LYRICS_BY_SONG' not in G)
check('  nor defines an aligner', 'align_words' not in G)
mode, why = G['label_mode_for']('Nasa Iyo Na Ang Lahat - Daniel Padilla')
check(f'label_mode_for -> {mode!r} ({why})', mode == 'none', mode)
for probe in ['Kumpas - Moira Dela Torre', 'a song nobody has heard of']:
    m, _ = G['label_mode_for'](probe)
    check(f'  {probe[:34]:<34} -> {m!r}', m == 'none', m)

# Asking for alignment without the cells that make it possible must
# degrade to 'none', not raise: the run still has notes to produce.
#
# G is mutated in place rather than copied, because label_mode_for reads
# the globals it was DEFINED in -- a copied dict would leave it looking at
# the originals and every case below would silently pass as 'none'.
SONG = 'Kumpas - Moira Dela Torre'


def mode_with(**overrides):
    saved = {k: G[k] for k in overrides if k in G}
    added = [k for k in overrides if k not in G]
    G.update(overrides)
    try:
        return G['label_mode_for'](SONG)
    finally:
        G.update(saved)
        for k in added:
            del G[k]


m, why = mode_with(LABEL_MODE='align')
check(f'align without Cell 5 -> {m!r} ({why})',
      m == 'none' and 'Cell 5' in why, f'{m} / {why}')
m, why = mode_with(LABEL_MODE='align',
                   LYRICS_BY_SONG={SONG: 'Ako ay para sa iyo'})
check(f'align with lyrics but no Cell 6 -> {m!r} ({why})',
      m == 'none' and 'Cell 6' in why, f'{m} / {why}')
m, why = mode_with(LABEL_MODE='align',
                   LYRICS_BY_SONG={SONG: 'Ako ay para sa iyo'},
                   align_words=lambda *a, **k: None)
check(f'align with both cells run -> {m!r}', m == 'align', f'{m} / {why}')
m, why = mode_with(LABEL_MODE='auto',
                   align_words=lambda *a, **k: None)
check(f'auto with no lyrics falls back to whisper -> {m!r}',
      m == 'whisper', f'{m} / {why}')
check("and the override really was undone", G['LABEL_MODE'] == 'none',
      G['LABEL_MODE'])
check('  with no leftover globals', 'align_words' not in G
      and 'LYRICS_BY_SONG' not in G)

print('\nthe validate cell survives a run with no labels at all')
nb = json.loads((BACKEND / 'ground_truth_from_stems.ipynb')
                .read_text(encoding='utf-8'))
section = None
for c in nb['cells']:
    s = ''.join(c['source'])
    if c['cell_type'] == 'code' and 'LABELLED = sorted' in s:
        section = s[s.index('# ---- word-label health ---'):]
assert section, 'no label-health section found'
gv = {'__name__': 'validate', 'LABEL_SOURCE': {'A': 'none', 'B': 'none'},
      'LABEL_MODE': 'none', 'LABEL_UNIT': 'syllable', 'RESULTS': {}}
out = io.StringIO()
with contextlib.redirect_stdout(out):
    exec(compile(section, 'labels', 'exec'), gv)
text = out.getvalue()
check('it explains itself instead of printing an empty table',
      'Labels were off' in text and 'WORD LABELS' not in text,
      text.splitlines()[:1])
check('  and says why that is fine', 'Nothing scores them' in text)

gv = {'__name__': 'validate', 'LABEL_SOURCE': {'A': 'align'},
      'LABEL_MODE': 'align', 'LABEL_UNIT': 'syllable',
      'RESULTS': {'A': [{'syllable': 'la'}, {'syllable': 'hat'},
                        {'syllable': ''}]}}
out = io.StringIO()
with contextlib.redirect_stdout(out):
    exec(compile(section, 'labels', 'exec'), gv)
text = out.getvalue()
check('with labels, the table is printed', 'WORD LABELS' in text)
check('  and the Whisper looping threshold is not',
      'looping' not in text or 'was about Whisper' in text)
check('  blank labels are counted, not dropped', ' 1 ' in text or '1' in text)

print()
print('FAILURES:', fails if fails else 'none')
sys.exit(1 if fails else 0)
