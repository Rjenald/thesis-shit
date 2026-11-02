"""Does lyric timing come from the recording, and refuse when it cannot?

Two things are worth pinning here, and only one of them is "the happy
path works".

The first is that `sync_lyrics.py` **refuses** when all it has is note
onsets. That is the whole point of the tool. Ground truth records when
notes happened, not which words they are, so splitting 499 notes across
62 lines is underdetermined — and the note-only attempt produced a line
sung 17 times with durations spanning 8.41s, and gave a 9-syllable line a
single 0.12s note. A tool that quietly emitted that would be worse than
one that emits nothing.

The second is that when word onsets DO exist, every timestamp is one of
them. No interpolation, no per-line averaging, no tempo.

Word onsets here are synthetic and live in a temp directory. Nothing is
written into assets/, because a plausible-looking fabricated ground truth
is exactly the thing this project must never produce.

    python backend/test_sync_lyrics.py
"""
from __future__ import annotations

import io
import contextlib
import json
import sys
import tempfile
from pathlib import Path

BACKEND = Path(__file__).resolve().parent
sys.path.insert(0, str(BACKEND))

import sync_lyrics as S                                      # noqa: E402
from lyric_text import clean_lyrics, lyric_words             # noqa: E402

fails = []

# Everything in assets/ground_truth/ before this test touches
# anything. Synthetic word onsets go in a temp directory, and this
# proves none of them leaked into the real one -- and equally that
# nothing real was deleted.
ASSETS_BEFORE = {p.name for p in
                 (BACKEND.parent / 'assets' / 'ground_truth')
                 .glob('*')}
# Whichever song currently has ground truth on disk. Hard-coding one
# meant the suite broke the moment a different song was uploaded, which
# is a normal thing to do while authoring ground truth one song at a
# time -- the test is about the tool, not about any one song.
_GT = sorted(p.stem for p in (BACKEND.parent / 'assets' / 'ground_truth')
             .glob('*.json') if not p.stem.endswith('.words'))
if not _GT:
    print('No ground truth in assets/ground_truth/, so there is nothing '
          'to time lyrics against. Upload one and re-run.')
    raise SystemExit(0)
STEM = next((s for s in _GT
             if (BACKEND / 'lyrics' / f'{s}.txt').exists()), None)
if STEM is None:
    print(f'Ground truth exists ({", ".join(_GT)}) but none of it has a '
          'sheet in backend/lyrics/.')
    raise SystemExit(0)


def check(name, cond, detail=''):
    print(f"  {'OK  ' if cond else 'FAIL'} {name}"
          f"{'  ' + str(detail) if detail else ''}")
    if not cond:
        fails.append(name)


def fake_words(text, start=15.85, per_word=0.35, line_gap=0.4):
    """Word spans in sung order, at a steady pace.

    Steady on purpose: the test is about whether the timestamps that come
    out are the ones that went in, not about realism. Real spacing is
    uneven, which is precisely why it has to be measured rather than
    assumed.
    """
    out, t = [], start
    for line in clean_lyrics(text):
        for w in lyric_words(line):
            out.append({'text': w.text, 'start': round(t, 3),
                        'end': round(t + per_word * 0.8, 3), 'score': 0.9})
            t += per_word
        t += line_gap
    return out


print('the real sheets are what gets timed')
text = S.load_lyrics(STEM)
check('the lyrics sheet loads', bool(text))
lines = [ln for ln in clean_lyrics(text)]
check(f'{STEM}: {len(lines)} lines in the sheet', len(lines) > 0,
      len(lines))

print('\nwith word onsets, every timestamp is one of them')
words = fake_words(text)
timed = S.time_lines_from_words(text, words)
check(f'{len(timed)} lines timed', len(timed) == len(lines), len(timed))
starts = [a for a, _, _, _ in timed]
onsets = {w['start'] for w in words}
check('every line start is a measured word onset',
      all(s in onsets for s in starts),
      [s for s in starts if s not in onsets][:3])
check('  the first line starts at the first word',
      starts[0] == words[0]['start'], f'{starts[0]} vs {words[0]["start"]}')
check('  line starts are strictly increasing',
      all(b > a for a, b in zip(starts, starts[1:])))
check('  a line ends at its own last word',
      abs(timed[0][1] - words[len(lyric_words(lines[0])) - 1]['end']) < 1e-9,
      timed[0][1])
check('  word counts per line match the sheet',
      [n for _, _, _, n in timed]
      == [len(lyric_words(ln)) for ln in lines],
      [n for _, _, _, n in timed][:6])

print('\na wordless line can be added without redoing the alignment')
# The point of this: a ♪ line has no letters, so it contributes no words
# and the existing word onsets stay valid. A passage that is sung but has
# no lyrics can therefore be marked without another Colab run.
with_marks = clean_lyrics(text)
cut = min(4, len(with_marks))
marked = '\n'.join(with_marks[:cut] + ['♪'] + with_marks[cut:])
timed_m = S.time_lines_from_words(marked, words)
check('it does not change the word count (so nothing has to be realigned)',
      len(timed_m) == len(timed) + 1, f'{len(timed_m)} vs {len(timed) + 1}')
check('  the marker gets a time of its own',
      timed_m[cut][3] == 0 and timed_m[cut][0] > 0,
      f'{timed_m[cut][0]:.2f}s, {timed_m[cut][3]} words')
check('  it sits between its neighbours',
      timed_m[cut - 1][0] < timed_m[cut][0] < timed_m[cut + 1][0],
      [round(timed_m[i][0], 2) for i in (cut - 1, cut, cut + 1)])
check('  every other line keeps the time it had',
      [r[0] for r in timed_m if r[3]] == [r[0] for r in timed],
      'word-bearing lines moved')
check('  the whole list is still in time order',
      all(b[0] >= a[0] for a, b in zip(timed_m, timed_m[1:])))
marked_first = '\n'.join(['♪'] + with_marks)
first = S.time_lines_from_words(marked_first, words)
check('  a marker before the first line still works',
      first[0][3] == 0 and first[0][0] >= 0,
      f'{first[0][0]:.2f}s')
marked_last = '\n'.join(with_marks + ['♪'])
last = S.time_lines_from_words(marked_last, words)
check('  and one after the last line too',
      last[-1][3] == 0 and last[-1][0] >= last[-2][0],
      f'{last[-1][0]:.2f}s after {last[-2][0]:.2f}s')

print('\nno timestamp is invented')
# Every emitted start must appear in the input. The converse check --
# that nothing was averaged or interpolated -- is that no start falls
# strictly between two consecutive onsets.
sorted_onsets = sorted(onsets)
between = [s for s in starts
           if s not in onsets
           and sorted_onsets[0] < s < sorted_onsets[-1]]
check('nothing lands between two onsets', not between, between[:3])

print('\na sheet edited after alignment is reported, not absorbed')
try:
    S.time_lines_from_words(text, words[:-5])
    check('a word-count mismatch raises', False)
except ValueError as e:
    check('a word-count mismatch raises ValueError',
          'changed after alignment' in str(e), str(e)[:70])
try:
    S.time_lines_from_words(text, words + [dict(words[-1])])
    check('  in the other direction too', False)
except ValueError:
    check('  in the other direction too', True)

print('\nwith only note onsets, it refuses')
tmp = Path(tempfile.mkdtemp(prefix='huni_sync_'))
real_gt = S.GT_DIR
S.GT_DIR = tmp
try:
    notes = json.loads(
        (real_gt / f'{STEM}.json').read_text(encoding='utf-8'))
    (tmp / f'{STEM}.json').write_text(json.dumps(notes), encoding='utf-8')

    check('note onsets alone load', len(S.load_notes(STEM) or []) > 0,
          len(S.load_notes(STEM) or []))
    check('  and no word onsets are found',
          S.load_word_onsets(STEM) is None)

    sys.argv = ['sync_lyrics.py', STEM, '--write']
    out = io.StringIO()
    with contextlib.redirect_stdout(out):
        S.main()
    text_out = out.getvalue()
    check('--write refuses and explains why',
          'need word onsets' in text_out and 'LABEL_MODE' in text_out,
          text_out.strip().splitlines()[-1:])
    check('  it names the notebook to re-run',
          'ground_truth_from_stems' in text_out)
    check('  and it does NOT claim to have written anything',
          'wrote ' not in text_out)

    print('\n--from-notes runs, but says it is a diagnostic')
    sys.argv = ['sync_lyrics.py', STEM, '--from-notes']
    out = io.StringIO()
    with contextlib.redirect_stdout(out):
        S.main()
    diag = out.getvalue()
    check('it labels itself a DIAGNOSTIC', 'DIAGNOSTIC' in diag)
    check('  it prints the repeat-spread check', 'spread' in diag)
    check('  it refuses to be written', 'will not write' in diag)
    # The check has to actually fire on this song, or it is decoration.
    worst = [l for l in diag.splitlines()
             if 'worst spread across repeats' in l]
    check('  it reports a worst-case spread', bool(worst), worst)
    spread = float(worst[0].rsplit(':', 1)[1].strip().rstrip('s'))
    check(f'  the spread check exposes the problem ({spread:.2f}s)',
          spread > 2.0,
          f'{spread:.2f}s between the longest and shortest rendering of '
          'one repeated line')

    print('\nwith word onsets present, --write writes')
    (tmp / f'{STEM}.words.json').write_text(
        json.dumps({'stem': STEM, 'words': words}), encoding='utf-8')
    check('word onsets now load', len(S.load_word_onsets(STEM) or [])
          == len(words))

    dart = S.DART.read_text(encoding='utf-8')
    backup = dart
    try:
        sys.argv = ['sync_lyrics.py', STEM, '--write']
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            S.main()
        wrote = out.getvalue()
        check('it reports writing', 'wrote ' in wrote, wrote.strip()[-60:])
        after = S.DART.read_text(encoding='utf-8')
        check('  song_lyrics.dart changed', after != backup)
        check('  the first timestamp is the first word onset',
              f'milliseconds: {int(round(words[0]["start"] * 1000))}' in after,
              int(round(words[0]['start'] * 1000)))
        check('  it records where the numbers came from',
              'sync_lyrics.py' in after and 'forced alignment' in after)
        check('  other songs are untouched',
              after.count('static final List<LrcLine>')
              == backup.count('static final List<LrcLine>'))
        var = S.var_name_for(STEM.rsplit(' - ', 1)[0])
        check(f'  {var} is still exactly one list',
              after.count(f'{var} = [') == 1, after.count(f'{var} = ['))
    finally:
        S.DART.write_text(backup, encoding='utf-8')
        restored = S.DART.read_text(encoding='utf-8') == backup
        check('song_lyrics.dart restored after the test', restored)
finally:
    S.GT_DIR = real_gt
    for f in tmp.glob('*'):
        f.unlink()
    tmp.rmdir()

check('no file was added to or removed from assets/ground_truth/',
      {p.name for p in real_gt.glob('*')} == ASSETS_BEFORE,
      sorted({p.name for p in real_gt.glob('*')} ^ ASSETS_BEFORE))

print()
print('FAILURES:', fails if fails else 'none')
sys.exit(1 if fails else 0)
