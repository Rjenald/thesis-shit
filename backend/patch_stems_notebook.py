"""Re-applies the fixes that a Colab round trip strips from the extractor.

`ground_truth_from_stems.ipynb` is edited in place rather than generated,
so downloading a copy from Colab and saving it back over the repo quietly
reverts whatever was fixed since that copy was taken. That has already
happened once, and it cost a Colab run: the notebook rolled back far
enough to lose the smoothing quorum, the sung-region bounding and the
word-onset export, and Cell 4 failed with `NameError: LYRICS_BY_SONG`.

Each patch below is skipped when it is already present, so running this
on an up-to-date notebook is a no-op and running it on a stale one brings
it forward.

    python backend/patch_stems_notebook.py
    python backend/test_voiced_span.py    # then confirm

If a patch cannot find what it expects, it says so and changes nothing
rather than half-applying.
"""
from __future__ import annotations

import ast
import json
import sys
from pathlib import Path

NB = Path(__file__).resolve().parent / 'ground_truth_from_stems.ipynb'


def load():
    return json.loads(NB.read_text(encoding='utf-8'))


def cell_index(nb, needle, *, kind='code'):
    hits = [i for i, c in enumerate(nb['cells'])
            if c['cell_type'] == kind and needle in ''.join(c['source'])]
    if len(hits) != 1:
        raise LookupError(f'{needle!r} matched {len(hits)} cells')
    return hits[0]


def src(nb, i):
    return ''.join(nb['cells'][i]['source'])


def put(nb, i, s):
    nb['cells'][i]['source'] = s.splitlines(keepends=True)


# --------------------------------------------------------------- patches

def patch_lyrics_guard(nb):
    """Cell 4 must not read LYRICS_BY_SONG, which Cell 5 defines.

    Its own docstring promises it is self-contained and re-runnable on its
    own, and it was not: re-running settings alone raised NameError.
    """
    i = cell_index(nb, 'HOP_MS = 10')
    s = src(nb, i)
    if "globals().get('LYRICS_BY_SONG')" in s:
        return False
    pairs = [
        ("""print(f'  lyrics on file for {sum(1 for v in LYRICS_BY_SONG.values() if v.strip())} '
      f'song(s)')""",
         """# LYRICS_BY_SONG lives in Cell 5, which runs after this one, so this
# cell must not depend on it -- re-running settings alone has to work.
_sheets = globals().get('LYRICS_BY_SONG')
print(f'  lyrics on file for '
      f'{sum(1 for v in _sheets.values() if v.strip()) if _sheets else 0} '
      f'song(s)' + ('' if _sheets else ' (Cell 5 not run yet)'))"""),
        ("    has_lyrics = bool((LYRICS_BY_SONG.get(stem) or '').strip())",
         "    sheets = globals().get('LYRICS_BY_SONG') or {}\n"
         "    has_lyrics = bool((sheets.get(stem) or '').strip())"),
        ("    text = (LYRICS_BY_SONG.get(stem) or '').strip()",
         "    text = ((globals().get('LYRICS_BY_SONG') or {})"
         ".get(stem) or '').strip()"),
    ]
    for old, new in pairs:
        if old not in s:
            raise LookupError(f'settings cell: missing {old[:60]!r}')
        s = s.replace(old, new, 1)
    put(nb, i, s)
    return True


def patch_labels_off(nb):
    """Default LABEL_MODE to 'none'.

    Nothing scores the labels: the app groups segments by the singer's own
    recognised words and by time, and GroundTruthService reads a missing
    `syllable` as empty. A labelled run costs a 1.2GB model download and a
    longer extraction and changes no score, so it is opt-in.
    """
    i = cell_index(nb, 'HOP_MS = 10')
    s = src(nb, i)
    if "LABEL_MODE = 'none'" in s:
        return False
    old = "LABEL_MODE = 'auto'          # 'auto' | 'align' | 'whisper'"
    if old not in s:
        raise LookupError('settings cell: LABEL_MODE line not found')
    s = s.replace(old, """# DEFAULT IS 'none', because nothing scores them. Turn labels on when a
# file passes every check in Cell 9 and still sounds offset: a constant
# time shift that still fits inside the audio is invisible to all of
# them, and reading the word under a note is the only way to see it.
# 'align' is also what produces the word onsets that time the app's
# scrolling lyrics (backend/sync_lyrics.py).
LABEL_MODE = 'none'          # 'none' | 'align' | 'whisper' | 'auto'""", 1)

    old_fn = """def label_mode_for(stem):
    \"\"\"Which labeller this song gets, and why -> (mode, reason).\"\"\"
    sheets = globals().get('LYRICS_BY_SONG') or {}
    has_lyrics = bool((sheets.get(stem) or '').strip())
    if LABEL_MODE == 'whisper':
        return 'whisper', 'LABEL_MODE is whisper'
    if LABEL_MODE == 'align':
        if not has_lyrics:
            return 'skip', 'LABEL_MODE is align but no lyrics on file'
        return 'align', 'LABEL_MODE is align'
    return (('align', 'lyrics on file') if has_lyrics
            else ('whisper', 'no lyrics on file'))"""
    new_fn = """def label_mode_for(stem):
    \"\"\"Which labeller this song gets, and why -> (mode, reason).\"\"\"
    sheets = globals().get('LYRICS_BY_SONG') or {}
    has_lyrics = bool((sheets.get(stem) or '').strip())
    can_align = 'align_words' in globals()
    if LABEL_MODE == 'none':
        return 'none', 'labels off; nothing scores them'
    if LABEL_MODE == 'whisper':
        return 'whisper', 'LABEL_MODE is whisper'
    if LABEL_MODE == 'align':
        if not has_lyrics:
            return 'none', 'no lyrics on file -- run Cell 5'
        if not can_align:
            return 'none', 'aligner not defined -- run Cell 6'
        return 'align', 'LABEL_MODE is align'
    if has_lyrics and can_align:
        return 'align', 'lyrics on file'
    return 'whisper', ('no lyrics on file' if not has_lyrics
                       else 'Cell 6 not run')"""
    if old_fn not in s:
        raise LookupError('settings cell: label_mode_for not as expected')
    s = s.replace(old_fn, new_fn, 1)

    old_print = """print(f'  labels: mode={LABEL_MODE}, unit={LABEL_UNIT}, '
      f'parentheticals={"kept" if KEEP_PARENTHETICALS else "dropped"}, '
      f'star={"on" if USE_STAR else "off"}')"""
    new_print = """if LABEL_MODE == 'none':
    print('  labels: OFF -- notes only, so Cells 5 and 6 can be skipped')
else:
    print(f'  labels: mode={LABEL_MODE}, unit={LABEL_UNIT}, '
          f'parentheticals={"kept" if KEEP_PARENTHETICALS else "dropped"}, '
          f'star={"on" if USE_STAR else "off"}')"""
    if old_print not in s:
        raise LookupError('settings cell: label print not as expected')
    s = s.replace(old_print, new_print, 1)
    put(nb, i, s)
    return True


def patch_to_mono(nb):
    """Move to_mono from the optional Cell 6 into Cell 8, which always runs.

    pitch_track() needs it, so leaving it in the aligner cell meant that
    skipping Cell 6 -- the whole point of labels being optional -- broke
    extraction outright.
    """
    ai = cell_index(nb, 'def align_words(')
    s = src(nb, ai)
    if 'def to_mono' not in s:
        return False
    a = s.index('def to_mono(audio):')
    b = s.index('# ---- the forced aligner')
    body = s[a:b].rstrip() + '\n'
    head_marker = '# ---- audio ----'
    cut = s.index(head_marker) if head_marker in s else a
    s = (s[:cut]
         + '# to_mono lives in Cell 8, which always runs -- this one does not.\n\n'
         + s[b:])
    put(nb, ai, s)

    ei = cell_index(nb, 'def pitch_track(path):')
    es = src(nb, ei)
    es = es.replace('def pitch_track(path):', body + '\ndef pitch_track(path):', 1)
    put(nb, ei, es)
    return True


def patch_word_spans(nb):
    """Keep and export the aligned word onsets.

    They are the only measurement of when each word was actually sung,
    and backend/sync_lyrics.py needs them to time the app's scrolling
    lyrics. Estimating that from word count or tempo is what left the
    lyrics 3.74s out of step.
    """
    ei = cell_index(nb, 'LABEL_SOURCE[stem] = mode')
    s = src(nb, ei)
    if 'WORD_SPANS' in s:
        return False
    old = "            labels = syll_list if LABEL_UNIT == 'syllable' else word_list"
    if old not in s:
        raise LookupError('extract cell: label selection not found')
    s = s.replace(old, old + """
            # Kept whatever LABEL_UNIT is: word onsets are what time the
            # app's scrolling lyrics, and nothing else measures when a
            # word was actually sung.
            WORD_SPANS[stem] = word_list""", 1)
    s = s.replace('ALIGN_REPORT = {}', 'ALIGN_REPORT = {}\nWORD_SPANS = {}', 1)
    put(nb, ei, s)

    xi = cell_index(nb, 'ground_truth_service.dart parses')
    xs = src(nb, xi)
    anchor = "zip_base = "
    if anchor not in xs:
        raise LookupError('export cell: zip_base not found')
    xs = xs.replace(anchor, """    # Word onsets, when this song was forced-aligned. A separate file
    # because the app's own schema has no room for them, and because only
    # backend/sync_lyrics.py reads them.
    spans = WORD_SPANS.get(stem)
    if spans:
        words = {'stem': stem,
                 'source': 'MMS_FA forced alignment of the vocal stem',
                 'words': [{'text': w['text'],
                            'start': round(w['start'], 3),
                            'end': round(w['end'], 3),
                            'score': round(w.get('score', 0.0), 4)}
                           for w in spans]}
        with open(os.path.join(OUT_DIR, f'{stem}.words.json'), 'w',
                  encoding='utf-8') as fh:
            json.dump(words, fh, ensure_ascii=False, indent=1)
        print(f'    + {len(spans)} word onsets -> {stem}.words.json')

zip_base = """, 1)
    tail = ("print('which re-runs these same checks against what you "
            "actually shipped.')")
    if tail in xs:
        xs = xs.replace(tail, tail + """
if any(WORD_SPANS.values()):
    print('')
    print('Word onsets were exported too. To re-time the scrolling')
    print('lyrics from them:')
    print('  python backend/sync_lyrics.py --all --write')""", 1)
    put(nb, xi, xs)
    return True


def patch_optional_markdown(nb):
    """Say in the headings that Cells 5 and 6 are optional."""
    changed = False
    for i, c in enumerate(nb['cells']):
        if c['cell_type'] != 'markdown':
            continue
        s = ''.join(c['source'])
        if s.startswith('## Cell 5 —') and 'optional' not in s:
            nb['cells'][i]['source'] = (
                '## Cell 5 — the lyrics *(optional)*\n\n'
                'Skip unless `LABEL_MODE` is on. Word labels are never '
                'scored, so a default run goes from Cell 4 straight to '
                'Cell 7.\n\nRun it when you need word onsets to re-time '
                'the app\'s scrolling lyrics, which is the one thing that '
                'genuinely needs them.\n'
            ).splitlines(keepends=True)
            changed = True
        elif s.startswith('## Cell 6 —') and 'optional' not in s:
            nb['cells'][i]['source'] = (
                '## Cell 6 — forced alignment *(optional)*\n\n'
                'Skip unless `LABEL_MODE` is on; it fetches ~1.2GB of '
                'weights the first time Cell 8 aligns anything.\n\n'
                '`MMS_FA` is a character-level CTC model covering Tagalog. '
                'Given the lyrics it only decides *when* each character is '
                'sung, so spelling and word order come from Cell 5 and '
                'cannot come out wrong.\n\nIt also depends on `to_mono` '
                'from Cell 8, which is fine: nothing here is called until '
                'Cell 8 runs.\n'
            ).splitlines(keepends=True)
            changed = True
    return changed


def patch_pitch_floor(nb):
    """Make the F0 search range a setting, per song, and raise its floor.

    `fmin=50.0` was hard-coded in the extract cell. 50 Hz is far below any
    sung fundamental here and it lets the tracker lock onto a subharmonic
    — half the real frequency — which is an octave error that every other
    check in Cell 9 passes, because the note still sits inside a singable
    range. On Araw-Araw it produced 19 of them (4%), and not at random:
    `'Ma'`, the first syllable of "Mahiwaga", came out an octave low nine
    separate times, because a nasal onset is a soft attack and the
    tracker halves on it.

    Raising the floor to just under the lowest note a singer actually
    reaches makes the subharmonic unreachable. It is per-song because
    vocal ranges differ by more than an octave across this catalog, and a
    floor set for a baritone would clip a soprano's real notes.
    """
    i = cell_index(nb, 'HOP_MS = 10')
    s = src(nb, i)
    if 'FMIN_BY_SONG' in s:
        return False
    anchor = 'BATCH_SIZE = 512'
    if anchor not in s:
        raise LookupError('settings cell: BATCH_SIZE line not found')
    block = """# --- the F0 search range ---------------------------------------------
#
# The floor matters more than it looks. Below the lowest note actually
# sung, a pitch tracker can lock onto the subharmonic and report half the
# true frequency, which lands exactly 12 semitones low -- inside any
# singable range, so every other check in Cell 9 passes it. Araw-Araw came
# out with 19 such notes, 9 of them on the same syllable.
#
# Set this just under the lowest note the singer really reaches. Cell 9
# prints the measured register so the next run can be checked against it.
#  150 Hz = D3, a male pop baritone's floor (Araw-Araw, Nasa Iyo)
#   98 Hz = G2, only for a genuinely low voice
#  175 Hz = F3, a typical female pop range
DEFAULT_FMIN_HZ = 150.0
FMAX_HZ = 1100.0

# Per song, where the default clips something real or lets one through.
FMIN_BY_SONG = {
    # 'Mundo - IV Of Spades': 120.0,
}


def fmin_for(stem):
    return FMIN_BY_SONG.get(stem, DEFAULT_FMIN_HZ)


"""
    s = s.replace(anchor, anchor + '\n\n' + block.rstrip('\n'), 1)
    s = s.replace("print(f'  pitch: hop {HOP_MS}ms, confidence floor {CONF_MIN}')",
                  "print(f'  pitch: hop {HOP_MS}ms, confidence floor {CONF_MIN}, '\n"
                  "      f'{DEFAULT_FMIN_HZ:.0f}-{FMAX_HZ:.0f} Hz'\n"
                  "      + (f' (overrides: {FMIN_BY_SONG})' if FMIN_BY_SONG else ''))",
                  1)
    put(nb, i, s)

    ei = cell_index(nb, 'torchcrepe.predict(')
    es = src(nb, ei)
    old = """def pitch_track(path):
    \"\"\"torchcrepe over the vocal stem -> (times, hz, periodicity).\"\"\""""
    if old not in es:
        raise LookupError('extract cell: pitch_track signature not found')
    es = es.replace(old, """def pitch_track(path, fmin=None):
    \"\"\"torchcrepe over the vocal stem -> (times, hz, periodicity).\"\"\"""", 1)
    old_call = "        audio, sr, hop_length=hop, fmin=50.0, fmax=1100.0,"
    if old_call not in es:
        raise LookupError('extract cell: the fmin call is not as expected')
    es = es.replace(old_call,
                    "        audio, sr, hop_length=hop,\n"
                    "        fmin=fmin if fmin is not None else DEFAULT_FMIN_HZ,\n"
                    "        fmax=FMAX_HZ,", 1)
    old_use = "        times, hz, periodicity = pitch_track(vocals_path)"
    if old_use not in es:
        raise LookupError('extract cell: pitch_track call site not found')
    es = es.replace(old_use,
                    "        fmin = fmin_for(stem)\n"
                    "        print(f'  pitch tracking the vocals '\n"
                    "              f'({fmin:.0f}-{FMAX_HZ:.0f} Hz)...')\n"
                    "        times, hz, periodicity = pitch_track(vocals_path, fmin)",
                    1)
    es = es.replace("        print('  pitch tracking the vocals...')\n", '', 1)
    put(nb, ei, es)
    return True


def patch_octave_check(nb):
    """Catch octave errors in Cell 9, where they can still be acted on.

    This existed only in the local validator, which meant a Colab run
    could look clean and the problem surfaced after downloading. It is
    checked against each note's own NEIGHBOURS rather than the global
    range, because that is what makes it visible: an octave error sits
    comfortably inside a singable range and is wrong only relative to the
    notes around it.
    """
    i = cell_index(nb, 'OK_SONGS = []')
    s = src(nb, i)
    if 'octave_off' in s:
        return False
    anchor = """    if not problems:
        OK_SONGS.append(stem)"""
    if anchor not in s:
        raise LookupError('validate cell: OK_SONGS block not found')
    block = """    # Octave errors, against each note's own neighbours. A note half the
    # true frequency lands 12 semitones low and still sits inside a
    # singable range, so the spread/outlier checks above cannot see it.
    octave_off = []
    for k, r in enumerate(srt):
        m = note_to_midi(r['note'])
        if m is None:
            continue
        near = [note_to_midi(o['note']) for j, o in enumerate(srt)
                if j != k and abs(o['start'] - r['start']) <= 4.0]
        near = [x for x in near if x is not None]
        if len(near) < 2:
            continue
        local = sorted(near)[len(near) // 2]
        if 10.5 <= abs(m - local) <= 13.5:
            octave_off.append(r)
    if octave_off:
        share = 100 * len(octave_off) / len(rows)
        by_syl = {}
        for r in octave_off:
            key = (r.get('syllable') or '').strip()
            if key:
                by_syl[key] = by_syl.get(key, 0) + 1
        worst = sorted(by_syl.items(), key=lambda kv: -kv[1])[:3]
        detail = ('; worst: '
                  + ', '.join(f'{k!r}x{v}' for k, v in worst if v > 1)
                  if any(v > 1 for _, v in worst) else '')
        msg = (f'{len(octave_off)} note(s) ~12 semitones off their own '
               f'neighbours ({share:.0f}%) -- likely octave errors'
               + detail)
        if share > 3:
            problems.append(msg + f'; raise fmin above {fmin_for(stem):.0f} Hz')
        else:
            print(f'{"":>30}   -- {msg}')

    # The register actually used, so the next run's fmin can be chosen
    # from evidence instead of guessed.
    if midis:
        voiced_lo = min(midis)
        print(f'{"":>30}   register {note_name(voiced_lo)}'
              f'-{note_name(max(midis))}, lowest note '
              f'{440.0 * 2 ** ((voiced_lo - 69) / 12):.0f} Hz '
              f'(fmin was {fmin_for(stem):.0f} Hz)')

"""
    s = s.replace(anchor, block + anchor, 1)

    helper = """

def note_name(midi):
    \"\"\"MIDI -> 'C4', for reporting the register a song actually used.\"\"\"
    names = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']
    m = int(round(midi))
    return f'{names[m % 12]}{m // 12 - 1}'

"""
    s = s.replace("print(f\"{'song':<30}", helper.lstrip('\n')
                  + "\nprint(f\"{'song':<30}", 1)
    put(nb, i, s)
    return True


def patch_coverage_check(nb):
    """Catch under-extraction: notes covering too little of their own span.

    Every other check looks at the notes that ARE there and says nothing
    about the ones missing, so a badly under-extracted file passes
    everything. `Buwan - Juan Karlos` came back with 190 notes covering
    49s of a 272s span -- 18% -- against a sheet of 300 syllables, and
    looked clean on every column.
    """
    i = cell_index(nb, 'OK_SONGS = []')
    s = src(nb, i)
    if 'voiced coverage' in s:
        return False
    anchor = """    if not problems:
        OK_SONGS.append(stem)"""
    if anchor not in s:
        raise LookupError('validate cell: OK_SONGS block not found')
    block = """    # A song sings through most of the stretch it spans. Far less than
    # that means the tracker found almost nothing, which no other column
    # here would reveal.
    voiced_s = sum(r['end'] - r['start'] for r in rows)
    span_s = ends - first
    coverage = 100.0 * voiced_s / span_s if span_s > 0 else 0.0
    if span_s > 0 and coverage < 30:
        problems.append(
            f'only {coverage:.0f}% of the {span_s:.0f}s it spans is inside '
            f'a note ({voiced_s:.0f}s over {len(rows)} notes) -- '
            'under-extracted; lower conf_min, or fmin if the singer goes '
            'low')
    elif span_s > 0 and coverage < 45:
        print(f'{"":>30}   -- {coverage:.0f}% voiced coverage is low')

"""
    s = s.replace(anchor, block + anchor, 1)
    put(nb, i, s)
    return True


def patch_conf_min_per_song(nb):
    """Per-song confidence floor, with an automatic retry on low coverage.

    `CONF_MIN = 0.50` was global, and it is too strict for at least one
    stem in this catalog. `Buwan - Juan Karlos` came out with notes
    covering 49s of a 272s span while forced alignment placed 156 words
    across the whole song -- 83% of the aligned vocal had no note under
    it. The singing is plainly there; torchcrepe just would not call it
    voiced at 0.50.

    The retry is cheap because the expensive part does not repeat: the
    pitch track is already computed, and only the threshold applied to it
    changes. So a song that comes out under-covered is re-segmented at a
    lower floor in seconds rather than needing another Colab run.

    It reports both results and keeps the better-covered one. It is not
    silent: a lower floor admits weaker frames, which is a real trade, and
    Cell 9 shows the octave-error count that goes with it.
    """
    i = cell_index(nb, 'HOP_MS = 10')
    s = src(nb, i)
    if 'CONF_MIN_BY_SONG' in s:
        return False
    old = 'CONF_MIN = 0.50         # torchcrepe periodicity below this is not pitch'
    if old not in s:
        raise LookupError('settings cell: CONF_MIN line not found')
    s = s.replace(old, """CONF_MIN = 0.50         # torchcrepe periodicity below this is not pitch

# Per song, because 0.50 is too strict for some stems. Buwan's notes
# covered 49s of a 272s span at 0.50 while forced alignment placed words
# across the whole song, so the vocal was there and the threshold was
# rejecting it.
CONF_MIN_BY_SONG = {
    # 'Buwan - Juan Karlos': 0.35,
}

# When a song still comes out under-covered, re-segment it once at
# RELAXED_CONF_MIN and keep whichever covered more. Costs seconds, not
# another run: the pitch track is already computed and only the threshold
# applied to it changes.
AUTO_RELAX_CONF = True
RELAXED_CONF_MIN = 0.35
MIN_COVERAGE_PCT = 45


def conf_min_for(stem):
    return CONF_MIN_BY_SONG.get(stem, CONF_MIN)""", 1)
    s = s.replace("print(f'  pitch: hop {HOP_MS}ms, confidence floor {CONF_MIN}, '",
                  "print(f'  pitch: hop {HOP_MS}ms, confidence floor {CONF_MIN}'\n"
                  "      f'{\" (auto-relax to \" + str(RELAXED_CONF_MIN) + \" under \""
                  " + str(MIN_COVERAGE_PCT) + \"% coverage)\" if AUTO_RELAX_CONF else \"\"}, '",
                  1)
    put(nb, i, s)

    ei = cell_index(nb, 'LABEL_SOURCE[stem] = mode')
    es = src(nb, ei)
    old_seg = """        print('  segmenting notes...')
        note_events = segment_notes(times, hz, periodicity)"""
    if old_seg not in es:
        raise LookupError('extract cell: segmentation block not found')
    es = es.replace(old_seg, """        # segment_notes and voiced_span read CONF_MIN as a global, so the
        # per-song value is bound here rather than threaded through every
        # signature. Restored after the song so one override cannot leak
        # into the next.
        _conf_was = CONF_MIN
        CONF_MIN = conf_min_for(stem)
        print(f'  segmenting notes (confidence floor {CONF_MIN})...')
        note_events = segment_notes(times, hz, periodicity)

        def _coverage(evs):
            if not evs:
                return 0.0
            span = max(e['end'] for e in evs) - min(e['start'] for e in evs)
            voiced = sum(e['end'] - e['start'] for e in evs)
            return 100.0 * voiced / span if span > 0 else 0.0

        cov = _coverage(note_events)
        if AUTO_RELAX_CONF and cov < MIN_COVERAGE_PCT \\
                and CONF_MIN > RELAXED_CONF_MIN:
            print(f'    only {cov:.0f}% of the span is inside a note; '
                  f'retrying at {RELAXED_CONF_MIN}')
            CONF_MIN = RELAXED_CONF_MIN
            retry = segment_notes(times, hz, periodicity)
            cov2 = _coverage(retry)
            print(f'    {len(note_events)} notes / {cov:.0f}% -> '
                  f'{len(retry)} notes / {cov2:.0f}%')
            if cov2 > cov:
                note_events, cov = retry, cov2
                print(f'    keeping the relaxed pass (check Cell 9 for the '
                      'octave-error count that comes with it)')
            else:
                CONF_MIN = _conf_was
                print('    no better; keeping the original')
        print(f'    {cov:.0f}% of the span is inside a note')""", 1)
    es = es.replace("""        onset, offset = voiced_span(times, hz, periodicity)""",
                    """        onset, offset = voiced_span(times, hz, periodicity)""", 1)
    # CONF_MIN has to go back to its default once the song is done.
    old_fin = """    finally:
        gc.collect()"""
    if old_fin not in es:
        raise LookupError('extract cell: finally block not found')
    es = es.replace(old_fin, """    finally:
        try:
            CONF_MIN = _conf_was
        except NameError:
            pass
        gc.collect()""", 1)
    put(nb, ei, es)
    return True


def patch_resumable(nb):
    """Write each song as it finishes, and skip ones already done.

    Colab disconnects. Everything was held in RESULTS until Cell 10 wrote
    it, so a drop at song 7 of 10 lost all seven — half an hour of GPU
    time, and the next attempt started from nothing.

    Two changes make that cost one song instead of ten. Each song's JSON
    is written the moment it is extracted, and the loop skips any song
    whose output is already on disk. Re-running Cell 8 after a reconnect
    then picks up where it stopped.

    Whether that survives depends on what kind of disconnect it was. A
    reconnect to the same VM keeps /content, so resume works. A recycled
    VM loses everything including the uploads, which is what OUT_DIR on
    Google Drive is for — see Cell 4.
    """
    i = cell_index(nb, 'HOP_MS = 10')
    s = src(nb, i)
    if 'RESUME' not in s:
        old = "OUT_DIR = '/content/ground_truth'"
        if old not in s:
            raise LookupError('settings cell: OUT_DIR not found')
        s = s.replace(old, """# Each song is written as soon as it is extracted, and a song already
# written is skipped. Colab drops sessions, and holding ten songs in
# memory until the end meant a drop at song 7 lost all seven.
RESUME = True

# Put OUT_DIR on Drive to survive a RECYCLED runtime, not just a
# reconnect: /content is wiped when Colab hands you a new VM, uploads
# and all. Costs one consent prompt.
#   from google.colab import drive; drive.mount('/content/drive')
#   OUT_DIR = '/content/drive/MyDrive/huni_ground_truth'
OUT_DIR = '/content/ground_truth'""", 1)
        put(nb, i, s)

    ei = cell_index(nb, 'LABEL_SOURCE[stem] = mode')
    es = src(nb, ei)
    if 'already extracted' in es:
        return False

    old_head = """for stem, (vocals_path, instr_path) in PAIRS.items():
    print(f'\\n{"=" * 70}\\n{stem}\\n{"=" * 70}')
    try:"""
    if old_head not in es:
        raise LookupError('extract cell: loop header not found')
    es = es.replace(old_head, """def _written_path(stem):
    return os.path.join(OUT_DIR, f'{stem}.json')


def _load_written(stem):
    \"\"\"A song written by an earlier run, so it is not redone.\"\"\"
    try:
        with open(_written_path(stem), encoding='utf-8') as fh:
            return json.load(fh)['data']
    except Exception:            # noqa: BLE001
        return None


for stem, (vocals_path, instr_path) in PAIRS.items():
    print(f'\\n{"=" * 70}\\n{stem}\\n{"=" * 70}')
    if RESUME and stem not in RESULTS:
        _done = _load_written(stem)
        if _done:
            RESULTS[stem] = _done
            LABEL_SOURCE.setdefault(stem, 'none')
            print(f'  already extracted ({len(_done)} notes) -- skipping. '
                  'Set RESUME = False to redo it.')
            continue
    if stem in RESULTS:
        print('  already in RESULTS this session -- skipping.')
        continue
    try:""", 1)

    old_tail = """        RESULTS[stem] = rows

    except Exception:"""
    if old_tail not in es:
        raise LookupError('extract cell: RESULTS assignment not found')
    es = es.replace(old_tail, """        RESULTS[stem] = rows

        # Written now, not in Cell 10: a disconnect after this point costs
        # nothing, and Cell 8 can be re-run to carry on from here.
        os.makedirs(OUT_DIR, exist_ok=True)
        with open(_written_path(stem), 'w', encoding='utf-8') as fh:
            json.dump({'data': rows}, fh, ensure_ascii=False, indent=1)
        print(f'    saved {stem}.json')
        if WORD_SPANS.get(stem):
            with open(os.path.join(OUT_DIR, f'{stem}.words.json'), 'w',
                      encoding='utf-8') as fh:
                json.dump({'stem': stem,
                           'source': 'MMS_FA forced alignment of the '
                                     'vocal stem',
                           'words': [{'text': w['text'],
                                      'start': round(w['start'], 3),
                                      'end': round(w['end'], 3),
                                      'score': round(w.get('score', 0.0), 4)}
                                     for w in WORD_SPANS[stem]]},
                          fh, ensure_ascii=False, indent=1)
            print(f'    saved {stem}.words.json')

    except Exception:""", 1)

    es = es.replace("import gc\nimport os", "import gc\nimport json\nimport os", 1)
    if 'import json' not in es:
        es = 'import json\n' + es

    old_end = "print(f'\\n{len(RESULTS)} song(s) extracted.')"
    if old_end not in es:
        raise LookupError('extract cell: footer not found')
    es = es.replace(old_end, """_pending = [s for s in PAIRS if s not in RESULTS]
print(f'\\n{len(RESULTS)} of {len(PAIRS)} song(s) done, written to '
      f'{OUT_DIR}.')
if _pending:
    print(f'  {len(_pending)} still to do: {", ".join(_pending[:4])}'
          + (' ...' if len(_pending) > 4 else ''))
    print('  Re-run this cell to continue; finished songs are skipped.')""", 1)
    put(nb, ei, es)
    return True


def patch_gpu_sizing(nb):
    """Size the batch and chunk to the GPU actually allocated.

    `BATCH_SIZE = 512` and `ALIGN_CHUNK_S = 20.0` were chosen for a T4's
    16GB, and a Colab Pro account gets handed an L4 (24GB) or an A100
    (40GB) often enough that leaving them fixed wastes most of the card.

    The chunk length is not only a speed setting. Each chunk boundary is a
    seam the aligner has to be given context around, so fewer, longer
    chunks mean fewer seams as well as fewer passes.

    These are headroom figures, not benchmarks — nothing here has been
    timed on an L4 or an A100. They are deliberately short of what the
    VRAM would allow, because an OOM halfway through song 7 costs more
    than a slightly smaller batch. Set either explicitly to override.
    """
    i = cell_index(nb, 'HOP_MS = 10')
    s = src(nb, i)
    if 'tuned_for_gpu' in s:
        return False

    # The trailing comment on this line differs between notebook
    # generations, so match the assignment only.
    old = next((ln for ln in s.splitlines()
                if ln.startswith('BATCH_SIZE = ')), None)
    if old is None or 'None' in old:
        raise LookupError('settings cell: BATCH_SIZE line not found')
    s = s.replace(old, """# None sizes these from the GPU that was actually allocated (see
# tuned_for_gpu below); set a number to override. Lower them on OOM.
BATCH_SIZE = None       # torchcrepe frames per forward pass""", 1)

    old_chunk = """ALIGN_CHUNK_S = 20.0
ALIGN_CONTEXT_S = 2.0"""
    if old_chunk not in s:
        raise LookupError('settings cell: ALIGN_CHUNK_S not found')
    s = s.replace(old_chunk, """ALIGN_CHUNK_S = None    # seconds of audio per alignment pass
ALIGN_CONTEXT_S = 2.0""", 1)

    anchor = "OUT_DIR = '/content/ground_truth'"
    if anchor not in s:
        anchor = 'RESUME = True'
    if anchor not in s:
        raise LookupError('settings cell: no anchor for the sizing helper')
    helper = '''def _vram_gb():
    """VRAM on the allocated GPU, or 0.0 with no GPU."""
    try:
        import torch
        if torch.cuda.is_available():
            return (torch.cuda.get_device_properties(0).total_memory
                    / 1024 ** 3)
    except Exception:                                      # noqa: BLE001
        pass
    return 0.0


def tuned_for_gpu():
    """(torchcrepe batch, alignment chunk seconds) for this GPU.

    Headroom-based, not benchmarked, and deliberately under what the card
    would allow: an OOM in the middle of a ten-song run costs far more
    than a smaller batch. The alignment chunk matters twice over, since
    self-attention over a chunk grows with its square AND every boundary
    is a seam the aligner needs context around.
    """
    gb = _vram_gb()
    if gb >= 32:            # A100 40GB
        return 4096, 60.0
    if gb >= 20:            # L4 24GB
        return 2048, 40.0
    if gb >= 12:            # T4 16GB
        return 512, 20.0
    if gb > 0:              # something smaller
        return 256, 15.0
    return 128, 10.0        # CPU: small, because it is slow either way


_auto_batch, _auto_chunk = tuned_for_gpu()
if BATCH_SIZE is None:
    BATCH_SIZE = _auto_batch
if ALIGN_CHUNK_S is None:
    ALIGN_CHUNK_S = _auto_chunk

'''
    s = s.replace(anchor, helper + anchor, 1)

    s = s.replace("print('settings loaded')",
                  """print('settings loaded')
_gb = _vram_gb()
print(f'  gpu: {_gb:.0f} GB VRAM -> batch {BATCH_SIZE}, '
      f'{ALIGN_CHUNK_S:.0f}s alignment chunks'
      if _gb else f'  gpu: NONE -- batch {BATCH_SIZE}, '
                  f'{ALIGN_CHUNK_S:.0f}s chunks (CPU will be slow)')""", 1)
    put(nb, i, s)
    return True


def patch_notice_order(nb):
    """Print the per-song notes AFTER that song's row, not before it.

    The octave, coverage and register lines were printed where they were
    computed, which is before the row is printed. In a ten-song table that
    puts every diagnostic above the song it belongs to and below the
    previous one, so the whole table reads off by one -- Araw-Araw's
    octave errors appeared under the header, and Buwan's register appeared
    under Araw-Araw. Easy to misread as the wrong song's problem.
    """
    i = cell_index(nb, 'OK_SONGS = []')
    s = src(nb, i)
    if 'notices = []' in s:
        return False

    anchor = "    problems = []"
    if anchor not in s:
        raise LookupError('validate cell: problems list not found')
    s = s.replace(anchor, "    problems = []\n"
                          "    # Printed after this song's row, so the table "
                          "does not read off by one.\n"
                          "    notices = []", 1)

    # Every immediate print of a per-song note becomes an append.
    before = s
    s = s.replace("""        print(f'{"":>30}   -- {coverage:.0f}% voiced coverage is low')""",
                  """        notices.append(f'{coverage:.0f}% voiced coverage is low')""", 1)
    s = s.replace("""            print(f'{"":>30}   -- {msg}')""",
                  """            notices.append(msg)""", 1)
    s = s.replace("""        print(f'{"":>30}   register {note_name(voiced_lo)}'
              f'-{note_name(max(midis))}, lowest note '
              f'{440.0 * 2 ** ((voiced_lo - 69) / 12):.0f} Hz '
              f'(fmin was {fmin_for(stem):.0f} Hz)')""",
                  """        notices.append(
            f'register {note_name(voiced_lo)}-{note_name(max(midis))}, '
            f'{440.0 * 2 ** ((voiced_lo - 69) / 12):.0f}'
            f'-{440.0 * 2 ** ((max(midis) - 69) / 12):.0f} Hz '
            f'(fmin {fmin_for(stem):.0f}, fmax {FMAX_HZ:.0f})')""", 1)
    if s == before:
        raise LookupError('validate cell: no per-song prints to reorder')

    old_tail = """    if problems:
        for p in problems:
            print(f'{"":>30}   !! {p}')"""
    if old_tail not in s:
        raise LookupError('validate cell: problem printing not found')
    s = s.replace(old_tail, """    for p in problems:
        print(f'{"":>30}   !! {p}')
    for n in notices:
        print(f'{"":>30}   -- {n}')""", 1)
    put(nb, i, s)
    return True


def patch_fmax(nb):
    """Make the ceiling a setting too, and lower it to what is sung.

    A ten-song run put the top of several registers at A#5-C6 (932-1047
    Hz) -- Buwan reached C6 -- while the highest note any of these singers
    demonstrably reaches is around E5-G5. A note an octave too HIGH is the
    same subharmonic failure in reverse (the tracker doubling rather than
    halving), and `fmax=1100` leaves room for it.

    800 Hz still allows G5 (784) and blocks A#5 upward. Per song, because
    this is a claim about these ten singers and nothing else.
    """
    i = cell_index(nb, 'HOP_MS = 10')
    s = src(nb, i)
    if 'FMAX_BY_SONG' in s:
        return False
    old = 'FMAX_HZ = 1100.0'
    if old not in s:
        raise LookupError('settings cell: FMAX_HZ not found')
    s = s.replace(old, """# The ceiling matters for the same reason the floor does, mirrored: a
# tracker that doubles reports an octave too HIGH. A ten-song run topped
# out at A#5-C6 on several songs while the highest note these singers
# demonstrably reach is around G5, so 1100 Hz was leaving room for it.
# 800 Hz still allows G5 (784). Raise it per song for a real soprano.
DEFAULT_FMAX_HZ = 800.0
FMAX_BY_SONG = {
    # 'Dadalhin - Regine Velasquez': 1100.0,
}


def fmax_for(stem):
    return FMAX_BY_SONG.get(stem, DEFAULT_FMAX_HZ)


FMAX_HZ = DEFAULT_FMAX_HZ""", 1)
    s = s.replace("f'{DEFAULT_FMIN_HZ:.0f}-{FMAX_HZ:.0f} Hz'",
                  "f'{DEFAULT_FMIN_HZ:.0f}-{DEFAULT_FMAX_HZ:.0f} Hz'", 1)
    put(nb, i, s)

    ei = cell_index(nb, 'torchcrepe.predict(')
    es = src(nb, ei)
    es = es.replace('def pitch_track(path, fmin=None):',
                    'def pitch_track(path, fmin=None, fmax=None):', 1)
    old_call = """        fmin=fmin if fmin is not None else DEFAULT_FMIN_HZ,
        fmax=FMAX_HZ,"""
    if old_call not in es:
        raise LookupError('extract cell: the fmin/fmax call is not as expected')
    es = es.replace(old_call, """        fmin=fmin if fmin is not None else DEFAULT_FMIN_HZ,
        fmax=fmax if fmax is not None else DEFAULT_FMAX_HZ,""", 1)
    old_use = """        fmin = fmin_for(stem)
        print(f'  pitch tracking the vocals '
              f'({fmin:.0f}-{FMAX_HZ:.0f} Hz)...')
        times, hz, periodicity = pitch_track(vocals_path, fmin)"""
    if old_use not in es:
        raise LookupError('extract cell: pitch_track call site not found')
    es = es.replace(old_use, """        fmin, fmax = fmin_for(stem), fmax_for(stem)
        print(f'  pitch tracking the vocals '
              f'({fmin:.0f}-{fmax:.0f} Hz)...')
        times, hz, periodicity = pitch_track(vocals_path, fmin, fmax)""", 1)
    put(nb, ei, es)
    return True


def patch_case_insensitive_lyrics(nb):
    """Match a lyrics sheet to a stem regardless of capitalisation.

    A ten-song run uploaded `IKAW LANG - NOBITA` while the sheet is keyed
    `Ikaw Lang - NOBITA`, so the lookup missed, the song silently got
    `LABEL_MODE = 'none'`, and it was the one song absent from the word-
    label table. Nothing said why. Filenames come off a separation tool
    and their case is not something to design around.

    This fixes the lookup only. The exported filename still follows the
    upload, and `assets/ground_truth/` has to match the catalog exactly —
    `check_ground_truth.py` reports that separately.
    """
    i = cell_index(nb, 'HOP_MS = 10')
    s = src(nb, i)
    if 'def _sheet_for' in s:
        return False
    anchor = "def label_mode_for(stem):"
    if anchor not in s:
        raise LookupError('settings cell: label_mode_for not found')
    helper = '''def _sheet_for(stem):
    """The lyrics sheet for a stem, ignoring capitalisation.

    `IKAW LANG - NOBITA` and `Ikaw Lang - NOBITA` are the same song; a
    separation tool decides which one you get.
    """
    sheets = globals().get('LYRICS_BY_SONG') or {}
    if stem in sheets:
        return sheets[stem]
    low = stem.lower()
    for key, text in sheets.items():
        if key.lower() == low:
            print(f'  note: sheet "{key}" matched stem "{stem}" on case '
                  'alone')
            return text
    return None


'''
    s = s.replace(anchor, helper + anchor, 1)
    s = s.replace("""    sheets = globals().get('LYRICS_BY_SONG') or {}
    has_lyrics = bool((sheets.get(stem) or '').strip())""",
                  """    has_lyrics = bool((_sheet_for(stem) or '').strip())""", 1)
    s = s.replace("""    text = ((globals().get('LYRICS_BY_SONG') or {})"""
                  """.get(stem) or '').strip()""",
                  """    text = (_sheet_for(stem) or '').strip()""", 1)
    put(nb, i, s)

    ei = cell_index(nb, 'LABEL_SOURCE[stem] = mode')
    es = src(nb, ei)
    es = es.replace('vocals_path, LYRICS_BY_SONG[stem], DEVICE',
                    'vocals_path, _sheet_for(stem), DEVICE', 1)
    put(nb, ei, es)
    return True


PATCHES = [
    ('Cell 4 does not read Cell 5\'s lyrics', patch_lyrics_guard),
    ('a lyrics sheet matches a stem case-insensitively',
     patch_case_insensitive_lyrics),
    ('per-song notes print after their row', patch_notice_order),
    ('the F0 ceiling is a per-song setting', patch_fmax),
    ('batch and chunk size follow the GPU', patch_gpu_sizing),
    ('extraction is resumable after a disconnect', patch_resumable),
    ('conf_min is per song, with an auto-retry', patch_conf_min_per_song),
    ('the F0 floor is a per-song setting', patch_pitch_floor),
    ('Cell 9 catches octave errors', patch_octave_check),
    ('Cell 9 catches under-extraction', patch_coverage_check),
    ("LABEL_MODE defaults to 'none'", patch_labels_off),
    ('to_mono lives in Cell 8', patch_to_mono),
    ('word onsets are kept and exported', patch_word_spans),
    ('Cells 5 and 6 are marked optional', patch_optional_markdown),
]


def main() -> int:
    if not NB.exists():
        print(f'not found: {NB}')
        return 1
    nb = load()
    applied = []
    for label, fn in PATCHES:
        try:
            if fn(nb):
                applied.append(label)
                print(f'  applied : {label}')
            else:
                print(f'  already : {label}')
        except LookupError as e:
            print(f'  FAILED  : {label} -- {e}')
            print('\nNothing written. The notebook is not in a state this '
                  'script understands; fix it by hand or restore it.')
            return 1

    for i, c in enumerate(nb['cells']):
        if c['cell_type'] != 'code':
            continue
        body = '\n'.join('' if ln.lstrip().startswith('!') else ln
                         for ln in ''.join(c['source']).splitlines())
        try:
            ast.parse(body)
        except SyntaxError as e:
            print(f'\nSYNTAX ERROR in cell {i} line {e.lineno}: {e.msg}')
            print('Nothing written.')
            return 1

    if not applied:
        print('\nAlready up to date; nothing written.')
        return 0

    NB.write_text(json.dumps(nb, indent=1, ensure_ascii=False) + '\n',
                  encoding='utf-8')
    print(f'\nwrote {NB.name} ({len(applied)} patch(es) applied)')
    print('Now run: python backend/test_voiced_span.py')
    return 0


if __name__ == '__main__':
    sys.exit(main())
