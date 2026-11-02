"""Turning an F0 contour into note events, and judging the result.

Shared by `ground_truth_notes.ipynb` (which embeds a copy, because Colab
gets the notebook and nothing else) and by this directory's tests. Pure
numpy: no torch, no audio I/O, so all of it is testable off-GPU.

Every threshold here has a reason, and most of them are a defect that was
measured on this project's own data rather than a guess:

  - **the smoothing quorum** (`running_median`): a NaN-aware median that
    accepted one valid frame in five was manufacturing voicing out of
    sparse instrumental bleed in a vocal stem, which put 7 notes 5.2s
    before the first sung word of `Nasa Iyo Na Ang Lahat`.
  - **persistence before a new note** (`HOLD_MS`): without it a pitch
    slide spawns a note per frame.
  - **the same-pitch merge**: an earlier pipeline left ~50% of rows
    inside same-pitch runs of up to 7, i.e. held notes chopped up, each
    counting separately toward the score.
  - **dropping, never correcting, implausible pitch**: inventing a value
    for an unusable frame is worse than admitting the frame was unusable.

MIDI convention is the one the formula gives: MIDI 69 = A4 = 440 Hz, so
MIDI 60 = C4 and middle C is C4. Stated because the alternative (C3 for
60) is common enough in DAWs to cause silent off-by-an-octave bugs.
"""
from __future__ import annotations

import math

import numpy as np

NOTE_NAMES = ('C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#',
              'B')

# A singing voice lives well inside this. Octave errors land outside it,
# which is the point: they are dropped rather than folded back, because
# folding assumes the error was exactly an octave.
MIDI_LO, MIDI_HI = 36, 88


class SegmentConfig:
    """Every knob the segmenter has, with the defaults that were measured.

    Kept as a class rather than loose globals so a notebook can hold two
    configurations side by side (one per model, say) without one of them
    silently reading the other's thresholds.
    """

    __slots__ = ('hop_ms', 'conf_min', 'semitone_tol', 'hold_ms', 'gap_ms',
                 'min_note_ms', 'max_note_ms', 'smooth_ms', 'midi_lo',
                 'midi_hi', 'smooth_quorum')

    def __init__(self, hop_ms=10.0, conf_min=0.50, semitone_tol=0.8,
                 hold_ms=60.0, gap_ms=100.0, min_note_ms=100.0,
                 max_note_ms=6000.0, smooth_ms=50.0, midi_lo=MIDI_LO,
                 midi_hi=MIDI_HI, smooth_quorum=None):
        self.hop_ms = hop_ms
        # Below this the model is not reporting pitch, it is reporting a
        # guess. Every model here exposes some confidence; the notebook
        # maps each one's own scale onto this.
        self.conf_min = conf_min
        # How far pitch may wander and still be one note. Vibrato in
        # pop singing is roughly +-0.5 semitone, so 0.8 keeps a vibrato
        # note whole while still splitting a real semitone step.
        self.semitone_tol = semitone_tol
        # How long a deviation must persist before it counts as a new
        # note. This is what stops a slide becoming a note per frame.
        self.hold_ms = hold_ms
        # A voicing gap this long ends a note: a breath or a rest is a
        # real boundary, a 30ms tracker dropout is not.
        self.gap_ms = gap_ms
        self.min_note_ms = min_note_ms
        # Not a musical limit -- a tracking-failure limit. A "note" this
        # long is usually a drone or a stuck tracker, so it is flagged,
        # never silently cut.
        self.max_note_ms = max_note_ms
        self.smooth_ms = smooth_ms
        self.midi_lo, self.midi_hi = midi_lo, midi_hi
        # Frames in the smoothing window that must be real pitch before
        # any of it is believed. None -> a majority.
        self.smooth_quorum = smooth_quorum

    @property
    def smooth_frames(self):
        return max(1, int(round(self.smooth_ms / self.hop_ms)))

    def as_dict(self):
        """For the processing report, so a file records how it was made."""
        d = {k: getattr(self, k) for k in self.__slots__}
        d['smooth_frames'] = self.smooth_frames
        d['midi_convention'] = 'MIDI 69 = A4 = 440 Hz, so middle C = C4'
        return d


# --------------------------------------------------------------- pitch

def hz_to_midi(hz):
    """Hz -> float MIDI. Non-positive input becomes NaN, not an error.

    NaN rather than a sentinel because every downstream step already has
    to handle unvoiced frames, and a magic number eventually gets treated
    as a pitch.
    """
    hz = np.asarray(hz, dtype=float)
    out = np.full(hz.shape, np.nan)
    good = hz > 0
    out[good] = 69.0 + 12.0 * np.log2(hz[good] / 440.0)
    return out


def midi_to_hz(midi):
    return 440.0 * 2.0 ** ((np.asarray(midi, dtype=float) - 69.0) / 12.0)


def midi_to_note(midi):
    """Float MIDI -> 'C4'. Rounds to the nearest semitone."""
    if midi is None or (isinstance(midi, float) and math.isnan(midi)):
        return ''
    m = int(round(float(midi)))
    return f'{NOTE_NAMES[m % 12]}{m // 12 - 1}'


def note_to_midi(name):
    """'C#4' -> 61, or None if it is not a note name."""
    import re
    m = re.fullmatch(r'([A-G])([#b]?)(-?\d+)', (name or '').strip())
    if not m:
        return None
    base = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}
    semi = base[m.group(1)]
    semi += 1 if m.group(2) == '#' else (-1 if m.group(2) == 'b' else 0)
    return 12 * (int(m.group(3)) + 1) + semi


def cents_between(hz_a, hz_b):
    """Signed cents from b to a. The unit the app scores in."""
    if not hz_a or not hz_b or hz_a <= 0 or hz_b <= 0:
        return None
    return 1200.0 * math.log2(hz_a / hz_b)


# ------------------------------------------------------------ smoothing

def running_median(x, window, min_valid=None):
    """NaN-aware median filter, same length out as in.

    Median rather than mean: it removes tracker jitter and isolated octave
    jumps without smearing a real onset across the boundary.

    `min_valid` is the fix for a measured defect. Taking the median of
    whatever happens to be valid in the window means ONE confident frame
    in five makes all five voiced, so the filter was inventing voicing out
    of sparse, weakly-periodic instrumental bleed in a vocal stem.
    Requiring most of the window to be real pitch leaves genuine singing
    untouched -- a sung note fills its own window -- and leaves bleed as
    the silence it is.

    The requirement is scaled at the edges, where the window is clipped
    and could never be full; without that, every note's first and last
    frames would be discarded.
    """
    if window <= 1:
        return np.asarray(x, dtype=float)
    half = window // 2
    need = (window + 1) // 2 if min_valid is None else min_valid
    x = np.asarray(x, dtype=float)
    out = np.empty_like(x)
    for i in range(len(x)):
        lo, hi = max(0, i - half), min(len(x), i + half + 1)
        chunk = x[lo:hi]
        chunk = chunk[~np.isnan(chunk)]
        edge_need = max(1, int(round(need * (hi - lo) / window)))
        out[i] = np.median(chunk) if len(chunk) >= edge_need else np.nan
    return out


def voiced_span(times, hz, confidence, conf_min=0.5, sustain_ms=150.0):
    """(first, last) time a sustained run of confident pitch covers.

    Stricter than "any confident frame" on purpose: one frame is noise,
    and this decides what counts as part of the performance at all. A run
    must last `sustain_ms`, which is still shorter than any note worth
    scoring.

    Returns (None, None) when nothing qualifies, so a caller can tell
    "no singing found" from "singing starts at 0.0".
    """
    times = np.asarray(times, dtype=float)
    ok = ((np.asarray(confidence, dtype=float) >= conf_min)
          & (np.asarray(hz, dtype=float) > 0))
    if not ok.any():
        return None, None
    hop_ms = (times[1] - times[0]) * 1000 if len(times) > 1 else 10.0
    need = max(1, int(round(sustain_ms / hop_ms)))
    first = last = None
    run = 0
    for i, v in enumerate(ok):
        if v:
            run += 1
            if run >= need:
                if first is None:
                    first = i - run + 1
                last = i
        else:
            run = 0
    if first is None:
        return None, None
    return float(times[first]), float(times[last] + hop_ms / 1000.0)


def notes_within(notes, t_lo, t_hi, pad=0.30):
    """Drops notes outside the sung span -> (kept, dropped).

    Returned rather than silently removed so the count can be reported: a
    large number means the stem has bleed worth looking at, not that this
    filter is working.
    """
    if t_lo is None or t_hi is None:
        return list(notes), []
    kept, dropped = [], []
    for n in notes:
        (kept if n['end'] > t_lo - pad and n['start'] < t_hi + pad
         else dropped).append(n)
    return kept, dropped


# ---------------------------------------------------------- segmentation

def segment_notes(times, hz, confidence, config=None):
    """An F0 contour -> note events.

    A new note begins when the smoothed pitch leaves the current note's
    running median by more than `semitone_tol` AND stays there for
    `hold_ms`. Requiring persistence is what keeps a slide or a moment of
    tracker noise from becoming a note, and the boundary is placed where
    the deviation STARTED rather than where it was confirmed -- otherwise
    every onset would sit `hold_ms` late.

    Deliberately not "round each frame to a MIDI number and group equal
    values": that produces a note per vibrato cycle on a held note and a
    note per frame on a slide, which is exactly the defect this replaced.

    Each event carries the mean confidence of its own frames, so a note
    assembled from weak frames can be flagged later instead of being
    presented with the same authority as a clean one.
    """
    cfg = config or SegmentConfig()
    times = np.asarray(times, dtype=float)
    if len(times) == 0:
        return []
    hop_ms = ((times[1] - times[0]) * 1000 if len(times) > 1
              else cfg.hop_ms)
    hold_frames = max(1, int(round(cfg.hold_ms / hop_ms)))
    gap_frames = max(1, int(round(cfg.gap_ms / hop_ms)))

    conf = np.asarray(confidence, dtype=float)
    midi = hz_to_midi(hz)
    midi[conf < cfg.conf_min] = np.nan
    smooth = running_median(midi, max(1, int(round(cfg.smooth_ms / hop_ms))),
                            cfg.smooth_quorum)

    notes = []
    cur, pending = [], []
    unvoiced_run = 0

    def close(frames):
        if not frames:
            return
        vals = smooth[frames]
        vals = vals[~np.isnan(vals)]
        if len(vals) == 0:
            return
        idx = np.asarray(frames)
        note_conf = conf[idx]
        note_conf = note_conf[note_conf >= cfg.conf_min]
        notes.append({
            'start': float(times[frames[0]]),
            'end': float(times[frames[-1]] + hop_ms / 1000.0),
            'midi': float(np.median(vals)),
            'frames': len(frames),
            # The model's own number, not a quality judgement of ours.
            'confidence': float(np.mean(note_conf)) if len(note_conf)
            else 0.0,
            # Kept so a later step can measure how much the pitch moved
            # inside the note -- vibrato depth, or a slide that survived.
            'midi_std': float(np.std(vals)),
            'midi_min': float(np.min(vals)),
            'midi_max': float(np.max(vals)),
        })

    for i in range(len(smooth)):
        if np.isnan(smooth[i]):
            unvoiced_run += 1
            if unvoiced_run >= gap_frames:
                close(cur + pending)
                cur, pending = [], []
            continue
        unvoiced_run = 0

        if not cur:
            cur, pending = [i], []
            continue

        ref = np.nanmedian(smooth[cur])
        if abs(smooth[i] - ref) <= cfg.semitone_tol:
            cur.extend(pending)          # the deviation was a wobble
            pending = []
            cur.append(i)
            continue

        pending.append(i)
        if len(pending) < hold_frames:
            continue

        close(cur)
        cur, pending = pending, []

    close(cur + pending)

    kept = [n for n in notes
            if (n['end'] - n['start']) * 1000 >= cfg.min_note_ms
            and cfg.midi_lo <= n['midi'] <= cfg.midi_hi]

    # Join neighbours left at the same pitch with no gap between them:
    # one held note that a brief wobble split in two. Without this, a note
    # held across several rows counts several times in the app's score.
    merged = []
    for n in kept:
        prev = merged[-1] if merged else None
        if (prev and abs(n['midi'] - prev['midi']) <= cfg.semitone_tol
                and n['start'] - prev['end'] <= cfg.gap_ms / 1000.0):
            total = prev['frames'] + n['frames']
            prev['midi'] = (prev['midi'] * prev['frames']
                            + n['midi'] * n['frames']) / total
            prev['confidence'] = (
                (prev['confidence'] * prev['frames']
                 + n['confidence'] * n['frames']) / total)
            prev['midi_min'] = min(prev['midi_min'], n['midi_min'])
            prev['midi_max'] = max(prev['midi_max'], n['midi_max'])
            prev['end'] = n['end']
            prev['frames'] = total
        else:
            merged.append(dict(n))
    return merged


# ------------------------------------------------- multi-model agreement

def frame_disagreement(hz_a, hz_b, conf_a=None, conf_b=None, conf_min=0.5):
    """Per-frame |semitone| difference between two models -> array.

    NaN where either model calls the frame unvoiced, so "they disagree
    about the pitch" never gets confused with "one of them heard nothing".
    Both of those matter, and they are different problems.
    """
    a, b = hz_to_midi(hz_a), hz_to_midi(hz_b)
    n = min(len(a), len(b))
    a, b = a[:n].copy(), b[:n].copy()
    if conf_a is not None:
        a[np.asarray(conf_a, dtype=float)[:n] < conf_min] = np.nan
    if conf_b is not None:
        b[np.asarray(conf_b, dtype=float)[:n] < conf_min] = np.nan
    return np.abs(a - b)


def voicing_disagreement(hz_a, hz_b, conf_a, conf_b, conf_min=0.5):
    """Frames where exactly one model reports pitch -> bool array."""
    n = min(len(hz_a), len(hz_b))
    va = (np.asarray(conf_a, dtype=float)[:n] >= conf_min) & \
         (np.asarray(hz_a, dtype=float)[:n] > 0)
    vb = (np.asarray(conf_b, dtype=float)[:n] >= conf_min) & \
         (np.asarray(hz_b, dtype=float)[:n] > 0)
    return va ^ vb


def disagreement_regions(times, disagree, min_ms=150.0, merge_ms=200.0):
    """Contiguous stretches of disagreement, as [(start, end, mean)].

    Short, scattered disagreement is normal -- two models will differ by
    a few cents on a held vowel. A sustained run is the thing worth a
    human's attention, so isolated frames are filtered out and near
    neighbours are merged into one region rather than reported as dozens.
    """
    times = np.asarray(times, dtype=float)
    d = np.asarray(disagree, dtype=float)
    flag = ~np.isnan(d) & (d > 0)
    if not flag.any():
        return []
    hop = (times[1] - times[0]) if len(times) > 1 else 0.01
    runs, start = [], None
    for i, f in enumerate(flag):
        if f and start is None:
            start = i
        elif not f and start is not None:
            runs.append((start, i))
            start = None
    if start is not None:
        runs.append((start, len(flag)))

    merged = []
    for lo, hi in runs:
        if merged and (lo - merged[-1][1]) * hop * 1000 <= merge_ms:
            merged[-1] = (merged[-1][0], hi)
        else:
            merged.append((lo, hi))

    out = []
    for lo, hi in merged:
        if (hi - lo) * hop * 1000 < min_ms:
            continue
        vals = d[lo:hi]
        vals = vals[~np.isnan(vals)]
        out.append((float(times[lo]), float(times[min(hi, len(times) - 1)]),
                    float(np.mean(vals)) if len(vals) else 0.0))
    return out


def note_agreement(note, times, disagree, tol_semitones=0.5):
    """Share of a note's frames where two models differ beyond `tol`.

    None when the comparison says nothing about this note -- no second
    model, or every frame unvoiced in one of them. None is not 0.0, and
    reporting it as 0.0 would claim agreement that was never measured.
    """
    times = np.asarray(times, dtype=float)
    d = np.asarray(disagree, dtype=float)
    lo = int(np.searchsorted(times, note['start']))
    hi = int(np.searchsorted(times, note['end']))
    seg = d[lo:hi]
    seg = seg[~np.isnan(seg)]
    if len(seg) == 0:
        return None
    return float(np.mean(seg > tol_semitones))


# ------------------------------------------------------- quality control

def flag_notes(notes, config=None, agreement=None, conf_warn=0.60,
               octave_window_s=4.0):
    """Attaches a list of QC flags to each note. Nothing is removed.

    These are reasons for a human to look, not verdicts. Every one of
    them can fire on a note that is perfectly correct -- a real held note
    is long, a real falsetto leap is an octave -- which is exactly why
    this flags rather than filters, and why no note is ever marked
    verified by anything in here.

    `agreement` is the per-note output of note_agreement(), when a second
    model was run. A note it says nothing about is flagged as unchecked
    rather than as agreeing.
    """
    cfg = config or SegmentConfig()
    midis = np.array([n['midi'] for n in notes], dtype=float)
    starts = np.array([n['start'] for n in notes], dtype=float)

    for i, n in enumerate(notes):
        flags = []
        dur_ms = (n['end'] - n['start']) * 1000

        if dur_ms < cfg.min_note_ms * 1.25:
            flags.append('very_short')
        if dur_ms > cfg.max_note_ms:
            flags.append('very_long')
        if n.get('confidence', 1.0) < conf_warn:
            flags.append('low_confidence')
        # Pitch that moved a lot inside one note: either vibrato wider
        # than semitone_tol let through, or a slide that was held long
        # enough to survive. Worth seeing, not necessarily wrong.
        if n.get('midi_max', 0) - n.get('midi_min', 0) > 2.0:
            flags.append('unstable_pitch')

        # An octave error shows as a note sitting ~12 semitones off the
        # local register while its neighbours do not. Compared against
        # nearby notes rather than the whole song, because a real song
        # changes register.
        near = np.abs(starts - n['start']) <= octave_window_s
        near[i] = False
        if near.sum() >= 2:
            local = float(np.median(midis[near]))
            delta = abs(n['midi'] - local)
            if 10.5 <= delta <= 13.5:
                flags.append('possible_octave_error')
            elif delta > 13.5:
                flags.append('far_from_local_register')

        if agreement is None:
            flags.append('single_model')
        else:
            a = agreement[i] if i < len(agreement) else None
            if a is None:
                flags.append('agreement_unknown')
            elif a > 0.40:
                flags.append('model_disagreement')

        n['flags'] = flags
        # Nothing here promotes a note. Verification is a human action.
        n.setdefault('verification_status', 'unverified')
    return notes


def boundary_checks(notes, audio_duration=None, voiced=(None, None)):
    """Problems with the note LIST as a whole -> list of strings.

    Separate from flag_notes because these are not properties of any one
    note: they are the file disagreeing with its own audio, which is the
    class of defect that shipped undetected before.
    """
    problems = []
    if not notes:
        return ['no notes at all']

    srt = sorted(notes, key=lambda n: n['start'])
    overlaps = sum(1 for a, b in zip(srt, srt[1:])
                   if b['start'] < a['end'] - 1e-9)
    if overlaps:
        problems.append(f'{overlaps} overlapping note(s)')
    backwards = sum(1 for n in notes if n['end'] <= n['start'])
    if backwards:
        problems.append(f'{backwards} note(s) end at or before their start')

    ends = max(n['end'] for n in notes)
    first = min(n['start'] for n in notes)
    if audio_duration is not None and ends > audio_duration + 0.5:
        problems.append(f'describes audio that does not exist: ends '
                        f'{ends:.1f}s, audio is {audio_duration:.1f}s')

    lo, hi = voiced
    if lo is not None and first < lo - 2.0:
        problems.append(f'first note {lo - first:.1f}s before any sustained '
                        'pitch -- bleed in the stem, not singing')
    if hi is not None and ends > hi + 2.0:
        problems.append(f'last note {ends - hi:.1f}s after the singing '
                        'stops')

    # Held notes chopped into pieces. An earlier pipeline had ~50% of
    # rows inside such runs, and each piece scored separately.
    runs = sum(1 for a, b in zip(srt, srt[1:])
               if abs(a['midi'] - b['midi']) < 0.5
               and b['start'] - a['end'] < 0.12)
    if runs > len(notes) * 0.10:
        problems.append(f'{runs} adjacent same-pitch notes -- held notes '
                        'may still be split')

    # Identical durations repeating is the signature of boundaries that
    # were computed rather than detected.
    durs = [round(n['end'] - n['start'], 3) for n in notes]
    if durs:
        top = max(set(durs), key=durs.count)
        share = 100.0 * durs.count(top) / len(durs)
        if share > 20:
            problems.append(f'{share:.0f}% of notes share one duration '
                            f'({top:.3f}s) -- arithmetic boundaries?')

    spread = max(n['midi'] for n in notes) - min(n['midi'] for n in notes)
    if spread > 40:
        problems.append(f'{spread:.0f}-semitone range is wide for one voice')
    return problems


# ------------------------------------------------------------- export

def to_records(notes, start_id=1):
    """Note events -> the rich per-note records the spec's JSON carries."""
    out = []
    for k, n in enumerate(notes, start=start_id):
        midi_round = int(round(n['midi']))
        out.append({
            'note_id': k,
            'start_time': round(n['start'], 3),
            'end_time': round(n['end'], 3),
            'duration': round(n['end'] - n['start'], 3),
            'midi_note': midi_round,
            'note_name': midi_to_note(n['midi']),
            # The rounded note's own frequency, so frequency_hz and
            # midi_note always describe the same pitch. The measured
            # median is kept beside it rather than conflated with it.
            'frequency_hz': round(float(midi_to_hz(midi_round)), 2),
            'measured_midi': round(n['midi'], 3),
            'measured_hz': round(float(midi_to_hz(n['midi'])), 2),
            'cents_off_grid': round(1200.0 * (n['midi'] - midi_round)
                                    / 12.0, 1),
            'confidence': (round(n['confidence'], 4)
                           if n.get('confidence') is not None else None),
            'frames': n.get('frames'),
            'flags': list(n.get('flags', [])),
            'verification_status': n.get('verification_status',
                                         'unverified'),
        })
    return out


def to_app_rows(notes):
    """Note events -> exactly what ground_truth_service.dart parses.

    `syllable` is always empty. The app's schema keeps the key, and
    nothing scores it: segments are grouped by the singer's own
    recognised words and by time, so the field is carried and displayed
    only. This pipeline does not do lyrics at all.
    """
    return [{'syllable': '',
             'start': round(n['start'], 3),
             'end': round(n['end'], 3),
             'note': midi_to_note(n['midi'])}
            for n in notes]


def csv_rows(records):
    """Flat rows for ground_truth_notes.csv, header first."""
    cols = ['note_id', 'start_time', 'end_time', 'duration', 'midi_note',
            'note_name', 'frequency_hz', 'measured_midi', 'measured_hz',
            'cents_off_grid', 'confidence', 'frames', 'flags',
            'verification_status']
    rows = [cols]
    for r in records:
        rows.append([('|'.join(r[c]) if c == 'flags' else
                      ('' if r.get(c) is None else r[c])) for c in cols])
    return rows
