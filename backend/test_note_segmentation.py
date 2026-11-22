"""Does the note pipeline find the notes that are actually there?

Every case is a synthetic contour whose answer is known by construction,
which is the only way to test a segmenter: on a real recording there is
nothing to check the output against except the output.

The cases are not arbitrary. Each one mirrors a defect that was measured
on this project's own data -- held notes chopped into same-pitch runs,
melisma divided arithmetically, isolated octave errors, and instrumental
bleed smoothed into phantom notes -- plus the musical realities that a
naive segmenter gets wrong: vibrato, portamento, and short dropouts.

This also covers the spec's required synthetic F0-to-MIDI check
independently of any uploaded song.

    python backend/test_note_segmentation.py
"""
from __future__ import annotations

import math
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import note_segmentation as N                               # noqa: E402

HOP_MS = 10.0
fails = []


def check(name, cond, detail=''):
    print(f"  {'OK  ' if cond else 'FAIL'} {name}"
          f"{'  ' + str(detail) if detail else ''}")
    if not cond:
        fails.append(name)


def contour(spans, conf=0.9):
    """spans = [(midi|None, ms)] -> (times, hz, confidence)."""
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
    hz = np.where(np.isnan(midi), 0.0, N.midi_to_hz(midi))
    return (np.arange(len(midi)) * HOP_MS / 1000.0, hz, np.array(per))


def seg(spans, **kw):
    t, hz, c = contour(spans)
    return N.segment_notes(t, hz, c, N.SegmentConfig(hop_ms=HOP_MS, **kw))


print('F0 <-> MIDI, the formula the whole pipeline rests on')
check('440 Hz -> MIDI 69', abs(N.hz_to_midi([440.0])[0] - 69) < 1e-9)
check('261.6256 Hz -> MIDI 60', abs(N.hz_to_midi([261.6256])[0] - 60) < 1e-4)
check('MIDI 69 -> 440 Hz', abs(N.midi_to_hz(69) - 440.0) < 1e-9)
check('round trip over 8 octaves',
      max(abs(N.hz_to_midi([float(N.midi_to_hz(m))])[0] - m)
          for m in range(24, 108)) < 1e-9)
check('an octave is 12 semitones',
      abs(N.hz_to_midi([880.0])[0] - N.hz_to_midi([440.0])[0] - 12) < 1e-9)
check('0 Hz is NaN, not a pitch', math.isnan(N.hz_to_midi([0.0])[0]))
check('negative Hz is NaN too', math.isnan(N.hz_to_midi([-5.0])[0]))

print('\nnote names, and the octave convention stated in the docs')
for midi, want in [(60, 'C4'), (69, 'A4'), (61, 'C#4'), (21, 'A0'),
                   (108, 'C8'), (12, 'C0'), (59, 'B3')]:
    check(f'MIDI {midi} -> {want}', N.midi_to_note(midi) == want,
          N.midi_to_note(midi))
check('middle C is C4, not C3 (DAW convention differs)',
      N.midi_to_note(60) == 'C4')
check('rounds to nearest', N.midi_to_note(60.4) == 'C4', N.midi_to_note(60.4))
check('  and upward too', N.midi_to_note(60.6) == 'C#4',
      N.midi_to_note(60.6))
check('names round-trip through note_to_midi',
      all(N.note_to_midi(N.midi_to_note(m)) == m for m in range(24, 108)))
check('a non-note returns None', N.note_to_midi('H4') is None)

print('\ncents, the unit the app scores in')
check('an octave is 1200 cents',
      abs(N.cents_between(880, 440) - 1200) < 1e-9)
check('a semitone is 100 cents',
      abs(N.cents_between(float(N.midi_to_hz(61)),
                          float(N.midi_to_hz(60))) - 100) < 1e-9)
check('  and it compounds: 3 semitones is 300',
      abs(N.cents_between(float(N.midi_to_hz(63)),
                          float(N.midi_to_hz(60))) - 300) < 1e-9)
check('flat is negative', N.cents_between(430, 440) < 0)
check('silence has no cents', N.cents_between(0, 440) is None)

print('\none note in, one note out')
r = seg([(60, 600)])
check('single steady note -> 1 event', len(r) == 1, f'got {len(r)}')
if r:
    check('  pitch is right', abs(r[0]['midi'] - 60) < 0.01,
          f"{r[0]['midi']:.2f}")
    check('  duration is right',
          abs((r[0]['end'] - r[0]['start']) - 0.6) < 0.03,
          f"{r[0]['end'] - r[0]['start']:.3f}s")
    check('  confidence is the model\'s own, not invented',
          abs(r[0]['confidence'] - 0.9) < 0.01, r[0]['confidence'])

print('\ntwo notes, boundary in the right place')
r = seg([(60, 500), (65, 500)])
check('-> 2 events', len(r) == 2, f'got {len(r)}')
if len(r) == 2:
    check('  pitches 60 and 65',
          abs(r[0]['midi'] - 60) < 0.2 and abs(r[1]['midi'] - 65) < 0.2,
          f"{r[0]['midi']:.1f}, {r[1]['midi']:.1f}")
    check('  boundary within 60ms of 0.5s',
          abs(r[1]['start'] - 0.5) < 0.06, f"{r[1]['start']:.3f}s")
    check('  the onset is NOT held_ms late',
          r[1]['start'] <= 0.52, f"{r[1]['start']:.3f}s")

print('\nvibrato is one note, not many')
n = 120
t = np.arange(n) * HOP_MS / 1000.0
midi = 60 + 0.5 * np.sin(2 * np.pi * 5 * t)      # +-0.5 st at 5 Hz
r = N.segment_notes(t, N.midi_to_hz(midi), np.full(n, 0.9),
                    N.SegmentConfig(hop_ms=HOP_MS))
check('5 Hz / +-0.5 semitone vibrato -> 1 event', len(r) == 1, f'got {len(r)}')
if r:
    check('  and it is reported as unstable, for a human to see',
          r[0]['midi_max'] - r[0]['midi_min'] > 0.5,
          f"{r[0]['midi_max'] - r[0]['midi_min']:.2f} st")
# Wider vibrato than the tolerance should still not shatter the note.
midi = 60 + 1.2 * np.sin(2 * np.pi * 6 * t)
r = N.segment_notes(t, N.midi_to_hz(midi), np.full(n, 0.9),
                    N.SegmentConfig(hop_ms=HOP_MS))
check('wide 6 Hz vibrato -> at most a couple of events', len(r) <= 3,
      f'got {len(r)}')

print('\nmelisma: one syllable, three real notes')
r = seg([(60, 250), (64, 250), (67, 250)])
check('-> 3 events', len(r) == 3, f'got {len(r)}')
if len(r) == 3:
    check('  pitches 60, 64, 67',
          [round(x['midi']) for x in r] == [60, 64, 67],
          [round(x['midi']) for x in r])

print('\nrests and dropouts are different things')
r = seg([(60, 400), (None, 300), (60, 400)])
check('300ms rest -> 2 events', len(r) == 2, f'got {len(r)}')
r = seg([(60, 400), (None, 30), (60, 400)])
check('30ms dropout -> still 1 event', len(r) == 1, f'got {len(r)}')

print('\nthe over-segmentation this exists to prevent')
# The old pipeline produced runs of up to 7 rows at one pitch.
r = seg([(60, 120)] * 7)
check('7 equal slices of one pitch -> 1 event', len(r) == 1, f'got {len(r)}')
check('  and its duration is the whole run',
      r and abs((r[0]['end'] - r[0]['start']) - 0.84) < 0.05,
      f"{(r[0]['end'] - r[0]['start']):.2f}s" if r else '-')

print('\nshort artifacts do not become notes')
r = seg([(60, 500), (72, 30), (60, 500)])
check('30ms octave blip -> 1 event', len(r) == 1, f'got {len(r)}')
r = seg([(60, 500), (61, 40), (60, 500)])
check('40ms semitone blip -> 1 event', len(r) == 1, f'got {len(r)}')

print('\nimplausible pitch is dropped, never corrected')
r = seg([(60, 400), (20, 400), (60, 400)])
midis = [round(x['midi']) for x in r]
check('sub-bass note dropped', 20 not in midis, midis)
check('  not folded up an octave', not any(abs(m - 32) < 2 for m in midis),
      midis)
check('  the real notes survive', midis.count(60) >= 1, midis)

print('\na slide does not spawn a note per frame')
n = 60
t = np.arange(n) * HOP_MS / 1000.0
midi = np.linspace(60, 67, n)                    # 7 semitones in 600ms
r = N.segment_notes(t, N.midi_to_hz(midi), np.full(n, 0.9),
                    N.SegmentConfig(hop_ms=HOP_MS))
check('600ms portamento -> a few events, not dozens', 1 <= len(r) <= 4,
      f'got {len(r)}')

print('\nconfidence gates pitch')
t, hz, c = contour([(60, 500)])
c[:] = 0.1
r = N.segment_notes(t, hz, c, N.SegmentConfig(hop_ms=HOP_MS))
check('all-unconfident input -> no notes', len(r) == 0, f'got {len(r)}')
t, hz, c = contour([(60, 500)])
c[200:300] = 0.1                                 # 100ms of doubt mid-note
r = N.segment_notes(t, hz, c, N.SegmentConfig(hop_ms=HOP_MS))
check('a confident note with a doubtful middle still yields notes',
      len(r) >= 1, f'got {len(r)}')

print('\nthe smoothing quorum: bleed must not become pitch')
rm = N.running_median
x = np.array([np.nan, np.nan, 60.0, np.nan, np.nan])
check('1 valid frame in 5 -> still unvoiced', np.isnan(rm(x, 5)[2]))
x = np.array([60.0, 60.0, 60.0, np.nan, np.nan])
check('3 valid in 5 -> voiced', not np.isnan(rm(x, 5)[2]))
solid = np.full(20, 60.0)
check('a solid note is untouched', np.allclose(rm(solid, 5), 60.0))
check('  including its clipped first frame', not np.isnan(rm(solid, 5)[0]))
onset = np.concatenate([np.full(10, np.nan), np.full(10, 60.0)])
check('a real onset survives', not np.isnan(rm(onset, 5)[11]))
check('  and the silence before it stays silent', np.isnan(rm(onset, 5)[8]))

# Sparse bleed: one confident frame in four, which is what an instrumental
# leaking into a vocal stem looked like.
n = 550
hz = np.full(n, float(N.midi_to_hz(73)))
c = np.zeros(n)
c[::4] = 0.9
bleed_t = np.arange(n) * HOP_MS / 1000.0
r = N.segment_notes(bleed_t, hz, c, N.SegmentConfig(hop_ms=HOP_MS))
check('sparse bleed -> no notes', len(r) == 0, f'got {len(r)}')
r_old = N.segment_notes(bleed_t, hz, c,
                        N.SegmentConfig(hop_ms=HOP_MS, smooth_quorum=1))
check('  and without the quorum it DID become notes (so this test bites)',
      len(r_old) > 0, f'{len(r_old)} notes without the quorum')

print('\nvoiced_span: where the performance is')
t, hz, c = contour([(None, 2000), (60, 3000), (None, 1500)])
lo, hi = N.voiced_span(t, hz, c)
check('3s note after 2s silence -> 2.0 .. 5.0',
      abs(lo - 2.0) < 0.05 and abs(hi - 5.0) < 0.05,
      f'{lo:.2f} .. {hi:.2f}')
check('sparse bleed alone -> no span',
      N.voiced_span(bleed_t, hz, c) == (None, None) or
      N.voiced_span(bleed_t, np.full(n, float(N.midi_to_hz(73))),
                    np.where(np.arange(n) % 4 == 0, 0.9, 0.0))
      == (None, None))
t, hz, c = contour([(60, 80), (None, 2000), (62, 2000)])
lo, _ = N.voiced_span(t, hz, c)
check('an 80ms blip does not start the span', lo > 2.0, f'{lo:.2f}')
check('silence only -> (None, None)',
      N.voiced_span(*contour([(None, 1000)])) == (None, None))

print('\nnotes_within')
notes = [{'start': 9.9, 'end': 10.1}, {'start': 12.2, 'end': 12.9},
         {'start': 15.9, 'end': 16.4}, {'start': 200.0, 'end': 200.8},
         {'start': 219.0, 'end': 220.5}]
kept, dropped = N.notes_within(notes, 15.1, 209.2)
check('two intro notes and one outro note dropped',
      len(dropped) == 3 and len(kept) == 2,
      f'{len(kept)} kept, {len(dropped)} dropped')
check('  and it says which', [n['start'] for n in dropped]
      == [9.9, 12.2, 219.0], [n['start'] for n in dropped])
check('no span known -> nothing dropped',
      len(N.notes_within(notes, None, None)[0]) == len(notes))

print('\nmulti-model comparison')
t, hz_a, c_a = contour([(60, 500), (64, 500)])
_, hz_b, c_b = contour([(60, 500), (64, 500)])
d = N.frame_disagreement(hz_a, hz_b, c_a, c_b)
check('identical models -> zero disagreement',
      np.nanmax(d) < 1e-9, float(np.nanmax(d)))
check('  and no regions', N.disagreement_regions(t, d) == [])
_, hz_c, c_c = contour([(60, 500), (76, 500)])   # second model an octave up
d = N.frame_disagreement(hz_a, hz_c, c_a, c_c)
regions = N.disagreement_regions(t, d)
check('an octave apart in the 2nd half -> 1 region', len(regions) == 1,
      regions)
if regions:
    check('  starting near 0.5s', abs(regions[0][0] - 0.5) < 0.1,
          f'{regions[0][0]:.2f}s')
    check('  and reported as ~12 semitones', abs(regions[0][2] - 12) < 0.5,
          f'{regions[0][2]:.1f}')
check('scattered single-frame noise is not a region',
      N.disagreement_regions(
          t, np.where(np.arange(len(t)) % 50 == 0, 9.0, 0.0)) == [],
      'isolated frames should be filtered')

_, hz_sil, c_sil = contour([(60, 500), (None, 500)])
dv = N.voicing_disagreement(hz_a, hz_sil, c_a, c_sil)
check('one model hearing nothing is a VOICING disagreement',
      dv[-10:].all() and not dv[:10].any())
check('  and is kept out of the pitch disagreement',
      np.isnan(N.frame_disagreement(hz_a, hz_sil, c_a, c_sil)[-1]))

print('\nnote_agreement says "unknown", never "fine"')
note = {'start': 0.0, 'end': 0.5}
d = N.frame_disagreement(hz_a, hz_c, c_a, c_c)
check('agreeing note -> 0.0', N.note_agreement(note, t, d) == 0.0,
      N.note_agreement(note, t, d))
check('disagreeing note -> ~1.0',
      N.note_agreement({'start': 0.5, 'end': 1.0}, t, d) > 0.9,
      N.note_agreement({'start': 0.5, 'end': 1.0}, t, d))
check('a note with nothing to compare -> None, not 0.0',
      N.note_agreement({'start': 50.0, 'end': 51.0}, t, d) is None)

print('\nQC flags are reasons to look, not verdicts')
notes = N.flag_notes([
    {'start': 0.0, 'end': 0.11, 'midi': 60.0, 'confidence': 0.9,
     'midi_min': 60, 'midi_max': 60},
    {'start': 1.0, 'end': 8.0, 'midi': 60.0, 'confidence': 0.9,
     'midi_min': 60, 'midi_max': 60},
    {'start': 9.0, 'end': 9.5, 'midi': 60.0, 'confidence': 0.2,
     'midi_min': 60, 'midi_max': 60},
])
check('a 110ms note is flagged very_short',
      'very_short' in notes[0]['flags'], notes[0]['flags'])
check('a 7s note is flagged very_long', 'very_long' in notes[1]['flags'],
      notes[1]['flags'])
check('confidence 0.2 is flagged low_confidence',
      'low_confidence' in notes[2]['flags'], notes[2]['flags'])
check('nothing is verified by flagging',
      all(n['verification_status'] == 'unverified' for n in notes))
check('no second model -> every note says single_model',
      all('single_model' in n['flags'] for n in notes))

# An octave outlier among neighbours in the same register.
base = [{'start': float(i), 'end': i + 0.5, 'midi': 60.0,
         'confidence': 0.9, 'midi_min': 60, 'midi_max': 60}
        for i in range(6)]
base[3]['midi'] = 72.0
flagged = N.flag_notes([dict(n) for n in base])
check('an octave outlier is flagged',
      'possible_octave_error' in flagged[3]['flags'], flagged[3]['flags'])
check('  and its neighbours are not',
      not any('possible_octave_error' in flagged[i]['flags']
              for i in (0, 1, 2, 4, 5)))
check('a whole song an octave up flags nothing (register, not error)',
      not any('possible_octave_error' in n['flags']
              for n in N.flag_notes([{**n, 'midi': 72.0} for n in base])))

agreed = N.flag_notes([dict(n) for n in base],
                      agreement=[0.0] * 3 + [0.9] + [0.0] * 2)
check('model_disagreement comes from the comparison, not a guess',
      'model_disagreement' in agreed[3]['flags']
      and 'model_disagreement' not in agreed[0]['flags'])
unknown = N.flag_notes([dict(n) for n in base],
                       agreement=[None] * 6)
check('unmeasurable agreement -> agreement_unknown',
      all('agreement_unknown' in n['flags'] for n in unknown))

print('\nwhole-file checks catch what per-note checks cannot')
# Durations must VARY: a list where every note is exactly 0.400s is
# itself the arithmetic-boundary signature, so it is not a clean list.
good = [{'start': i * 0.5, 'end': i * 0.5 + 0.20 + 0.013 * (i % 11),
         'midi': 60.0 + (i % 5), 'confidence': 0.9} for i in range(40)]
check('a clean list has no problems',
      N.boundary_checks(good, audio_duration=30.0) == [],
      N.boundary_checks(good, audio_duration=30.0))
check('overlaps are caught',
      any('overlapping' in p for p in N.boundary_checks(
          [{'start': 0, 'end': 1, 'midi': 60},
           {'start': 0.5, 'end': 1.5, 'midi': 62}])))
check('running past the audio is caught',
      any('does not exist' in p for p in N.boundary_checks(
          good, audio_duration=5.0)))
check('notes before any singing are caught',
      any('before any sustained pitch' in p for p in N.boundary_checks(
          good, audio_duration=30.0, voiced=(10.0, 25.0))))
check('notes after the singing stops are caught',
      any('after the singing' in p for p in N.boundary_checks(
          good, audio_duration=30.0, voiced=(0.0, 5.0))))
check('arithmetic durations are caught',
      any('share one duration' in p for p in N.boundary_checks(
          [{'start': i * 0.5, 'end': i * 0.5 + 0.5, 'midi': 60.0 + i % 7}
           for i in range(40)])))
check('same-pitch runs are caught',
      any('same-pitch' in p for p in N.boundary_checks(
          [{'start': i * 0.1, 'end': i * 0.1 + 0.1, 'midi': 60.0}
           for i in range(40)])))
check('an impossible range is caught',
      any('semitone range' in p for p in N.boundary_checks(
          [{'start': 0, 'end': 1, 'midi': 40.0},
           {'start': 1, 'end': 2, 'midi': 85.0}])))
check('an empty list is a problem, not silence',
      N.boundary_checks([]) == ['no notes at all'])

print('\nexport: both schemas describe the same notes')
notes = N.flag_notes(seg([(60, 500), (64, 400), (67, 600)]))
recs = N.to_records(notes)
rows = N.to_app_rows(notes)
check('one record per note', len(recs) == len(notes) == len(rows))
check('note_id starts at 1 and increments',
      [r['note_id'] for r in recs] == list(range(1, len(recs) + 1)))
check('every record carries the spec\'s required keys',
      all({'note_id', 'start_time', 'end_time', 'duration', 'midi_note',
           'note_name', 'frequency_hz', 'confidence',
           'verification_status'} <= set(r) for r in recs))
check('no lyric or syllable field in the rich schema',
      not any('syllable' in r or 'lyric' in r or 'word' in r
              for r in recs))
check('frequency_hz and midi_note agree (to the stored 2dp)',
      all(abs(N.hz_to_midi([r['frequency_hz']])[0] - r['midi_note']) < 1e-3
          for r in recs),
      max(abs(N.hz_to_midi([r['frequency_hz']])[0] - r['midi_note'])
          for r in recs))
check('duration == end - start',
      all(abs(r['duration'] - (r['end_time'] - r['start_time'])) < 1e-9
          for r in recs))
check('every note exports as unverified',
      all(r['verification_status'] == 'unverified' for r in recs))
check('app rows have exactly the 4 keys the parser reads',
      all(set(r) == {'syllable', 'start', 'end', 'note'} for r in rows))
check('  with syllable always empty',
      all(r['syllable'] == '' for r in rows))
check('  and the same times as the rich records',
      all(abs(a['start'] - b['start_time']) < 1e-9
          and a['note'] == b['note_name'] for a, b in zip(rows, recs)))
check('cents_off_grid is signed and small for an in-tune note',
      all(abs(r['cents_off_grid']) < 60 for r in recs),
      [r['cents_off_grid'] for r in recs])

csv = N.csv_rows(recs)
check('CSV has a header plus one row per note',
      len(csv) == len(recs) + 1 and csv[0][0] == 'note_id')
check('  every row is the same width',
      len({len(r) for r in csv}) == 1, {len(r) for r in csv})
check('  flags survive as a single field',
      all(isinstance(r[csv[0].index('flags')], str) for r in csv[1:]))
check('  and None becomes empty, not the string "None"',
      not any('None' in str(v) for r in csv[1:] for v in r))

print('\nedge cases that should not raise')
cfg = N.SegmentConfig(hop_ms=HOP_MS)
check('empty input', N.segment_notes(np.array([]), np.array([]),
                                     np.array([]), cfg) == [])
check('one frame', N.segment_notes(np.array([0.0]), np.array([440.0]),
                                   np.array([0.9]), cfg) == [])
check('a note shorter than the minimum is dropped', len(seg([(60, 50)])) == 0)
check('all-NaN pitch', N.segment_notes(
    np.arange(50) * 0.01, np.zeros(50), np.full(50, 0.9), cfg) == [])
check('config round-trips into the report',
      N.SegmentConfig().as_dict()['semitone_tol'] == 0.8
      and 'midi_convention' in N.SegmentConfig().as_dict())

print()
print('FAILURES:', fails if fails else 'none')
sys.exit(1 if fails else 0)
