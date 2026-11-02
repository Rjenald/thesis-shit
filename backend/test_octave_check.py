"""Does Cell 9 catch an octave error, and not cry wolf on a key change?

The defect this is for was measured, not imagined. `Araw-Araw - Ben&Ben`
came back with 19 notes sitting ~12 semitones below their own
neighbours — 9 of them on `'Ma'`, the first syllable of "Mahiwaga" — and
every other check in the notebook passed it, because half the true
frequency is still a perfectly singable note. Only its neighbours say it
is wrong.

So the check compares each note against the notes around it rather than
against a global range, and these cases pin both halves of that: it has
to fire on a real subharmonic, and it has to stay quiet when a song
genuinely changes register, which looks similar from a distance.

The real uploaded file is used when it is on disk, because a check that
passes on synthetic data and misses the file that prompted it is worth
nothing.

    python backend/test_octave_check.py
"""
from __future__ import annotations

import contextlib
import io
import json
import sys
from pathlib import Path

BACKEND = Path(__file__).resolve().parent
GT_DIR = BACKEND.parent / 'assets' / 'ground_truth'
sys.path.insert(0, str(BACKEND))

from note_segmentation import midi_to_note, note_to_midi      # noqa: E402

fails = []


def check(name, cond, detail=''):
    print(f"  {'OK  ' if cond else 'FAIL'} {name}"
          f"{'  ' + str(detail) if detail else ''}")
    if not cond:
        fails.append(name)


def validate_cell():
    nb = json.loads((BACKEND / 'ground_truth_from_stems.ipynb')
                    .read_text(encoding='utf-8'))
    for c in nb['cells']:
        s = ''.join(c['source'])
        if c['cell_type'] == 'code' and 'OK_SONGS = []' in s:
            return s
    raise AssertionError('validate cell not found')


SRC = validate_cell()
check('the validate cell contains the octave check', 'octave_off' in SRC)
check('  it compares against neighbours, not a fixed range',
      "abs(o['start'] - r['start']) <= 4.0" in SRC)
check('  and it names the fmin to raise', 'raise fmin above' in SRC)


def run(rows, stem='Test Song - Someone', audio=400.0):
    """Exec the real cell over one song's rows and return what it printed."""
    g = {
        '__name__': 'nb',
        'RESULTS': {stem: rows},
        'PAIRS': {stem: ('vocals.wav', 'instr.wav')},
        'VOCAL_ONSET': {stem: rows[0]['start']},
        'VOCAL_OFFSET': {stem: max(r['end'] for r in rows)},
        'LABEL_SOURCE': {stem: 'align'},
        'ALIGN_REPORT': {},
        'LABEL_MODE': 'align',
        'LABEL_UNIT': 'syllable',
        'fmin_for': lambda s: 150.0,
        'fmax_for': lambda s: 800.0,
        'FMAX_HZ': 800.0,
        'MutagenFile': lambda p: type(
            'I', (), {'info': type('J', (), {'length': audio})()})(),
    }
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        # The cell imports mutagen itself; pre-seeding the name it binds
        # keeps this off the filesystem.
        src = SRC.replace('from mutagen import File as MutagenFile', '')
        exec(compile(src, 'validate', 'exec'), g)
    return buf.getvalue(), g


def note_rows(midis, start=10.0, syllables=None):
    """Synthetic rows with VARYING durations.

    Uneven on purpose: a list where every note is exactly 0.4s is itself
    the arithmetic-boundary signature Cell 9 exists to catch, so a "clean"
    fixture built that way fails for a reason that has nothing to do with
    octaves. Two earlier versions of this test tripped on exactly that.
    """
    rows, t = [], start
    for i, m in enumerate(midis):
        dur = 0.22 + 0.031 * (i % 13)
        rows.append({'start': round(t, 3), 'end': round(t + dur, 3),
                     'note': midi_to_note(m),
                     'syllable': (syllables[i] if syllables else '')})
        t += dur + 0.05 + 0.017 * (i % 7)
    return rows


print('\na clean file passes')
clean = note_rows([59, 61, 62, 59, 61, 64, 62, 59] * 8)
out, g = run(clean)
check('no octave complaint', 'octave error' not in out,
      [l.strip() for l in out.splitlines() if 'octave' in l])
check('  and the song passes every check', len(g['OK_SONGS']) == 1,
      out.strip().splitlines()[-3:])
check('  the register is reported, with both bounds, for choosing them',
      'register' in out and 'fmin' in out and 'fmax' in out,
      [l.strip() for l in out.splitlines() if 'register' in l])
# The notes used to print where they were computed, which is before the
# row, so a ten-song table read off by one: each song's diagnostics sat
# under the PREVIOUS song.
lines = [l for l in out.splitlines() if l.strip()]
row_at = next(i for i, l in enumerate(lines) if 'Test Song' in l)
note_at = [i for i, l in enumerate(lines) if '--' in l and 'register' in l]
check('  and it prints BELOW its own row, not above it',
      all(i > row_at for i in note_at), f'row {row_at}, notes {note_at}')

print('\na subharmonic is caught')
bad = note_rows([59, 61, 62, 59, 61, 64, 62, 59] * 8)
# One note in ten dropped an octave, which is what halving looks like.
for i in range(0, len(bad), 10):
    bad[i]['note'] = midi_to_note(note_to_midi(bad[i]['note']) - 12)
    bad[i]['syllable'] = 'Ma'
out, _ = run(bad)
check('flagged as an octave error', 'octave error' in out,
      [l.strip() for l in out.splitlines() if 'octave' in l][:1])
check('  it names the repeated syllable', "'Ma'" in out)
check('  and tells you to raise fmin', 'raise fmin above 150' in out)

print('\na genuine key change is NOT flagged')
# The whole song moves up a tone part-way through: every note changes, so
# no note is wrong relative to its own neighbours.
keychange = note_rows([59, 61, 62, 59] * 10) + note_rows(
    [61, 63, 64, 61] * 10, start=100.0)
out, _ = run(keychange)
check('no octave complaint', 'octave error' not in out,
      [l.strip() for l in out.splitlines() if 'octave' in l])

print('\na whole song an octave higher is NOT flagged')
high = note_rows([71, 73, 74, 71, 73, 76] * 10)
out, _ = run(high)
check('no octave complaint', 'octave error' not in out)

print('\na real falsetto leap is tolerated, not condemned')
# A handful of deliberate octave jumps, below the 3% threshold, should be
# reported as a note rather than failing the song.
leap = note_rows([59, 61, 62, 59, 61, 64] * 20)
# An octave above the LOCAL MEDIAN (61), not above its own pitch — the
# check measures against neighbours, so +12 from one note is only +10
# from the median and correctly does not fire. A first version of this
# case made that mistake and looked like a miss.
leap[30]['note'] = midi_to_note(73)
out, g = run(leap)
check('mentioned but not fatal',
      'octave error' in out and len(g['OK_SONGS']) == 1,
      f"{len(g['OK_SONGS'])} song(s) passed")

print('\nthe file that prompted all of this')
real = GT_DIR / 'Araw-Araw - Ben&Ben.json'
if not real.exists():
    print('  (Araw-Araw - Ben&Ben.json is not on disk; skipped. '
          'Upload it to check the real case.)')
else:
    rows = json.loads(real.read_text(encoding='utf-8'))['data']
    rows.sort(key=lambda r: r['start'])
    out, g = run(rows, stem='Araw-Araw - Ben&Ben', audio=316.1)
    line = [l.strip() for l in out.splitlines() if 'octave' in l]
    check('the real octave errors are caught', bool(line), line[:1])
    check('  "Ma" is named as the worst offender', "'Ma'" in out)
    # Deliberately NOT asserting pass/fail here. Whether it fails depends
    # on the share crossing 3%, and that share legitimately moves when the
    # extraction improves -- raising fmin took this file from 4% to 3%, so
    # an assertion on the verdict would now be failing on a real
    # improvement. What must hold is that the errors are still reported.
    reg = [l.strip() for l in out.splitlines() if 'register' in l]
    check('  the register is reported', bool(reg), reg[:1])

print('\nunder-extraction is caught')
# Synthetic, not the real Buwan file. It WAS the real case -- 190 notes
# covering 49s of a 272s span, 18% -- but re-extracting with a relaxed
# conf_min fixed it to 527 notes, and a regression test pinned to live
# data starts failing on its own success. The shape is what matters.
sparse = note_rows([59, 61, 62] * 20, start=10.0)
# Spread the same notes across six times the span: plenty of notes, almost
# no coverage, which is exactly what a too-strict confidence floor does.
for k, r in enumerate(sparse):
    shift = k * 4.0
    r['start'] = round(r['start'] + shift, 3)
    r['end'] = round(r['end'] + shift, 3)
out, g = run(sparse, audio=400.0)
under = [l.strip() for l in out.splitlines() if 'under-extracted' in l]
check('a sparse file is flagged', bool(under), under[:1])
check('  and it fails the song', len(g['OK_SONGS']) == 0,
      f"{len(g['OK_SONGS'])} passed")
check('  the message says what to change',
      'conf_min' in out, [l for l in out.splitlines() if 'conf_min' in l])

# And a well-covered file must NOT be flagged, or the check is useless.
out, g = run(note_rows([59, 61, 62, 64] * 25), audio=400.0)
check('a well-covered file is not flagged',
      'under-extracted' not in out)

print()
print('FAILURES:', fails if fails else 'none')
sys.exit(1 if fails else 0)
