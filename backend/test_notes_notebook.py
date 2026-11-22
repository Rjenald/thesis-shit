"""Executes ground_truth_notes.ipynb's data-flow cells on a fake singer.

What this can and cannot cover, stated plainly:

  **covered** -- configuration, the inlined segmentation module, the
  notebook's own synthetic self-test, segmentation of a real-shaped
  contour, MIDI conversion, QC flagging, both export schemas, the
  processing report, and the CSV round-trip. That is every cell where a
  typo, an undefined name or a wrong dict key would waste a Colab run.

  **not covered** -- model downloads, librosa decoding, the file upload,
  ipywidgets, and matplotlib. Those need Colab, a GPU or a browser. They
  are exercised by running the notebook, and the first run is where they
  get verified.

The stand-in "performance" is a contour built from known notes, so the
segmenter's output can be checked against what was put in rather than
merely inspected.

    python backend/test_notes_notebook.py
"""
from __future__ import annotations

import ast
import contextlib
import io
import json
import sys
import tempfile
from pathlib import Path

import numpy as np

BACKEND = Path(__file__).resolve().parent
NB = BACKEND / 'ground_truth_notes.ipynb'

fails = []


def check(name, cond, detail=''):
    print(f"  {'OK  ' if cond else 'FAIL'} {name}"
          f"{'  ' + str(detail) if detail else ''}")
    if not cond:
        fails.append(name)


# ------------------------------------------------------------- cells
nb = json.loads(NB.read_text(encoding='utf-8'))
CODE = [''.join(c['source']) for c in nb['cells']
        if c['cell_type'] == 'code']


# Which notebook cell each EXECUTED cell came from, in the order the
# harness executed them — recorded in run(), not here, because several
# cells are fetched only to be inspected as text and never run.
PICKED = []


def cell_with(*needles, exclude=()):
    hits = [s for s in CODE
            if all(n in s for n in needles)
            and not any(x in s for x in exclude)]
    assert len(hits) == 1, (f'{needles} matched {len(hits)} cells '
                            '(expected exactly 1)')
    return hits[0]


print('every code cell is syntactically valid Python')
bad = []
for i, s in enumerate(CODE):
    stripped = '\n'.join('' if ln.lstrip().startswith(('!', '%')) else ln
                         for ln in s.splitlines())
    try:
        ast.parse(stripped)
    except SyntaxError as e:
        bad.append(f'cell {i} line {e.lineno}: {e.msg}')
check(f'{len(CODE)} code cells parse', not bad, bad)

print('\nno cell uses a name a LATER cell defines')
# The check that was missing. §9 called frame_disagreement, which §10
# defined, and it only passed review because this harness happened to
# exec the module cell first -- an order I chose, not the notebook's.
# Running top to bottom is the only order that matters.
#
# Module-level loads only: a name used inside a function body resolves
# when the function is CALLED, so a forward reference there is legitimate
# and common.
BOUND = (ast.Assign, ast.AnnAssign, ast.AugAssign, ast.For, ast.With,
         ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef,
         ast.Import, ast.ImportFrom, ast.comprehension, ast.ExceptHandler,
         ast.Global, ast.NamedExpr)
SKIP_BODY = (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef,
             ast.Lambda)


def top_level_names(tree):
    """(names loaded at module level, names bound at module level).

    Function and class BODIES are skipped, because a name used inside one
    resolves when it is called rather than when it is defined — a forward
    reference there is legitimate. Their decorators and default arguments
    are not skipped: those evaluate at definition time.
    """
    loads, binds = set(), set()

    def descend(node):
        for child in ast.iter_child_nodes(node):
            if isinstance(child, SKIP_BODY):
                name = getattr(child, 'name', None)
                if name:
                    binds.add(name)
                for sub in getattr(child, 'decorator_list', []):
                    for n in ast.walk(sub):
                        if isinstance(n, ast.Name) and \
                                isinstance(n.ctx, ast.Load):
                            loads.add(n.id)
                continue

            if isinstance(child, ast.Name):
                (loads if isinstance(child.ctx, ast.Load)
                 else binds).add(child.id)
            elif isinstance(child, (ast.Import, ast.ImportFrom)):
                for a in child.names:
                    binds.add(a.asname or a.name.split('.')[0])
            elif isinstance(child, ast.Global):
                binds.update(child.names)
            elif isinstance(child, ast.ExceptHandler) and child.name:
                binds.add(child.name)

            descend(child)

    descend(tree)
    return loads, binds


import builtins
defined = set(dir(builtins))
forward = []
for i, s in enumerate(CODE):
    stripped = '\n'.join('' if ln.lstrip().startswith(('!', '%')) else ln
                         for ln in s.splitlines())
    loads, binds = top_level_names(ast.parse(stripped))
    unknown = sorted(loads - binds - defined)
    if unknown:
        forward.append(f'cell {i} uses {unknown}')
    defined |= binds
check('every module-level name is defined by an earlier cell', not forward,
      forward)


def detects(cells_src):
    """Would the check above flag this sequence of cells?"""
    seen = set(dir(builtins))
    hits = []
    for src in cells_src:
        ld, bd = top_level_names(ast.parse(src))
        hits += sorted(ld - bd - seen)
        seen |= bd
    return hits


# The exact shape of the bug that shipped: §9 called a helper that §10
# defined. If this stops being detected, the check above is decoration.
check('  the check catches a use-before-define across cells',
      detects(['d = frame_disagreement(a, b)',
               'def frame_disagreement(x, y):\n    return x']) ==
      ['a', 'b', 'frame_disagreement'],
      detects(['d = frame_disagreement(a, b)',
               'def frame_disagreement(x, y):\n    return x']))
check('  and allows the correct order',
      detects(['def f(x):\n    return x', 'y = f(1)']) == [])
check('  a forward reference INSIDE a function is allowed',
      detects(['def g():\n    return later_name', 'later_name = 1']) == [])
check('  imports count as definitions',
      detects(['import os', 'print(os.getcwd())']) == [])
check('  loop and comprehension variables are not reported',
      detects(['for i in range(3):\n    pass\nxs = [j for j in range(3)]'])
      == [])
check('  with-as and except-as bind too',
      detects(['import io\nwith io.StringIO() as fh:\n    pass\n'
               'try:\n    pass\nexcept ValueError as e:\n    print(e, fh)'])
      == [])

print('\nthe inlined module matches backend/note_segmentation.py')
module_src = (BACKEND / 'note_segmentation.py').read_text(encoding='utf-8')
inlined = cell_with('def segment_notes(', 'def to_app_rows(')
drifted = module_src.strip() not in inlined
check('the notebook carries the module verbatim', not drifted,
      'the inlined copy has DRIFTED from the file the tests cover; '
      're-run the generator' if drifted else '')

print('\nthe shipped notebook does no lyric recognition')
whole = '\n'.join(''.join(c['source']) for c in nb['cells'])
# API names, not prose: an earlier version of this check banned the
# substring "transcribe" and tripped on the word "transcriber" in the
# overview, which is a description of note-level notation and exactly
# what this pipeline does.
for banned in ('whisper', 'initial_prompt', 'WhisperModel',
               'word_timestamps', 'forced_align', 'MMS_FA'):
    check(f'no {banned!r} anywhere in the notebook',
          banned.lower() not in whole.lower())
check('no syllable or word text is ever assigned a value',
      "'syllable': ''" in whole
      and not any(f"'syllable': {q}" in whole for q in ('"a', "'a")),
      "only the app schema's empty field")

print('\nevery cell imports what it uses')
STDLIB = {'os', 'csv', 'json', 'shutil', 'time', 'gc', 'datetime', 'math'}
leaks = []
for i, s in enumerate(CODE):
    stripped = '\n'.join('' if ln.lstrip().startswith(('!', '%')) else ln
                         for ln in s.splitlines())
    tree = ast.parse(stripped)
    imported = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            imported |= {a.asname or a.name.split('.')[0]
                         for a in node.names}
        elif isinstance(node, ast.ImportFrom):
            imported |= {a.asname or a.name for a in node.names}
    used = {n.id for n in ast.walk(tree) if isinstance(n, ast.Name)}
    if (used & STDLIB) - imported:
        leaks.append(f'cell {i}: {sorted((used & STDLIB) - imported)}')
# A name that happens to be in scope because an earlier cell imported it
# works until someone re-runs a cell on its own, which is the normal way
# a notebook gets used.
check('no cell relies on a stdlib name leaking from another', not leaks,
      leaks)

# ---------------------------------------------------------- the stub
SR = 16000
HOP = 10.0

# A short "performance": known notes, a rest, a melisma, a held note,
# then 6s of instrumental bleed before any of it -- the exact shape that
# produced 7 phantom notes on the real track.
SCORE = [(None, 6000), (0, 0)]       # placeholder, replaced below
#   Durations must not repeat exactly. A first version of this phrase had
#   a melisma of three notes at exactly 250ms each, which is 38% of the
#   notes sharing one duration -- precisely the arithmetic-boundary
#   signature boundary_checks() exists to catch. It flagged it, correctly.
#   A real melisma is not metronomic, so neither is this one.
PHRASE = [(57, 430), (59, 380), (61, 710), (None, 300),
          (61, 240), (64, 190), (66, 310),
          (59, 1200), (None, 400), (57, 620)]
EXPECTED_MIDI = [m for m, _ in PHRASE if m is not None]


def build_contour():
    midi, conf = [], []

    # leading bleed: one confident frame in four, 5.5s of it
    n_bleed = int(5500 / HOP)
    midi += [73.0] * n_bleed
    conf += [0.9 if i % 4 == 0 else 0.0 for i in range(n_bleed)]

    midi += [np.nan] * int(500 / HOP)
    conf += [0.0] * int(500 / HOP)

    for m, ms in PHRASE:
        n = int(ms / HOP)
        if m is None:
            midi += [np.nan] * n
            conf += [0.0] * n
        else:
            # a little vibrato, so this is not an unrealistically flat line
            midi += [m + 0.25 * np.sin(2 * np.pi * 5 * k * HOP / 1000)
                     for k in range(n)]
            conf += [0.93] * n

    midi += [np.nan] * int(800 / HOP)
    conf += [0.0] * int(800 / HOP)

    midi = np.array(midi, dtype=float)
    conf = np.array(conf, dtype=float)
    hz = np.where(np.isnan(midi), 0.0, 440.0 * 2 ** ((midi - 69) / 12))
    times = np.arange(len(midi)) * HOP / 1000.0
    return times, hz, conf


T, HZ, CONF = build_contour()
DURATION = len(T) * HOP / 1000.0
AUDIO = (0.3 * np.sin(2 * np.pi * 220
                      * np.arange(int(DURATION * SR)) / SR)
         ).astype(np.float32)


class FakeModel:
    label = 'FakeModel (test stub)'
    checkpoint = 'none'
    confidence_kind = 'graded'


def fresh_globals():
    """A namespace holding everything cells 3-9 would have defined."""
    out_dir = tempfile.mkdtemp(prefix='huni_nb_test_')
    g = {
        '__name__': 'nbtest',
        'np': np,
        'DEVICE': 'cpu',
        'HOP_MS': HOP,
        'MODEL_SR': SR,
        'AUDIO': AUDIO,
        'DURATION': DURATION,
        'T': T, 'HZ': HZ, 'CONF': CONF,
        'TRACKS': {'torchcrepe': {'times': T, 'hz': HZ, 'conf': CONF,
                                  'confidence_kind': 'graded'},
                   'fcpe': {'times': T, 'hz': HZ, 'conf': CONF,
                            'confidence_kind': 'voicing'}},
        'TIMING': {'torchcrepe': 1.0, 'fcpe': 0.5},
        'MODELS': {'torchcrepe': FakeModel(), 'fcpe': FakeModel()},
        'MODEL_ERRORS': {},
        'MODEL_PREFERENCE': ['rmvpe', 'fcpe', 'torchcrepe'],
        'PRIMARY_KEY': 'torchcrepe',
        'PRIMARY': FakeModel(),
        'VALIDATORS': ['fcpe'],
        'ENV': {'python': '3.11.0', 'gpu': 'none'},
        'VERSIONS': {'torch': '2.5.0', 'numpy': np.__version__},
        'VOCAL_INFO': {'path': '/content/vocals.wav', 'format': 'WAV',
                       'subtype': 'PCM_16', 'sample_rate': 44100,
                       'channels': 2, 'duration': DURATION,
                       'frames': int(DURATION * 44100), 'bytes': 1234567},
        'INSTRUMENTAL_INFO': {'duration': DURATION},
        'AUDIO_WARNINGS': [],
        'IN_COLAB': False,
        'OUT_DIR': out_dir,
    }
    return g, out_dir


def run(g, src, label):
    try:
        PICKED.append((CODE.index(src), label))
    except ValueError:
        pass            # a snippet of the harness's own, not a cell
    buf = io.StringIO()
    try:
        with contextlib.redirect_stdout(buf):
            exec(compile(src, label, 'exec'), g)
    except Exception as e:                                  # noqa: BLE001
        print(f'  FAIL {label} raised {type(e).__name__}: {e}')
        import traceback
        traceback.print_exc()
        fails.append(f'{label} raised')
    return buf.getvalue()


# --------------------------------------------------------------- run
print('\nconfiguration cell')
G, OUT = fresh_globals()
cfg_src = cell_with('SONG_ID =', 'MODEL_PREFERENCE =')
out = run(G, cfg_src, 'config')
# The config cell owns these names; restore the test's own after it runs.
G['HOP_MS'] = HOP
G['OUT_DIR'] = OUT
check('defines the song and the model order',
      G.get('SONG_ID') and G.get('MODEL_PREFERENCE'), G.get('SONG_ID'))
check('SEG carries every segmentation knob',
      {'conf_min', 'semitone_tol', 'hold_ms', 'gap_ms', 'min_note_ms',
       'max_note_ms', 'smooth_ms', 'midi_lo', 'midi_hi'} == set(G['SEG']),
      sorted(G['SEG']))
check('ASSET_STEM is "<Title> - <Artist>"',
      G['ASSET_STEM'] == f"{G['SONG_TITLE']} - {G['ARTIST']}",
      G['ASSET_STEM'])

print('\nsegmentation module cell')
run(G, inlined, 'module')
for fn in ('segment_notes', 'voiced_span', 'notes_within', 'flag_notes',
           'boundary_checks', 'to_records', 'to_app_rows', 'csv_rows',
           'midi_to_note', 'hz_to_midi', 'SegmentConfig',
           'frame_disagreement', 'note_agreement',
           'disagreement_regions'):
    check(f'defines {fn}', callable(G.get(fn)) or fn in G, fn)

print('\nmulti-model comparison cell (§9 — runs before any segmentation)')
cmp_src = cell_with('DISAGREE_REGIONS', 'voicing_disagreement')
out = run(G, cmp_src, 'compare')
check('identical tracks produce no disagreement regions',
      G.get('DISAGREE_REGIONS') == [], G.get('DISAGREE_REGIONS'))
check('  and it records which model was compared',
      G.get('COMPARED_WITH') == 'fcpe', G.get('COMPARED_WITH'))

print('\nsegmentation settings cell (§10)')
prev_src = cell_with('CFG_PREVIEW = SegmentConfig(')
out = run(G, prev_src, 'cfg-preview')
check('it prints the resolved thresholds', 'semitone_tol' in out)
check('  and explains why the smoothing quorum is there',
      'quorum' in out and 'bleed' in out)

print("\nthe notebook's own synthetic self-test")
self_test = cell_with('self-test passed', '_expect(')
out = run(G, self_test, 'self-test')
check('it runs and passes', 'self-test passed' in out,
      out.strip().splitlines()[-1] if out.strip() else 'no output')
check('  and it really asserts things', out.count('OK  ') >= 12,
      f"{out.count('OK  ')} assertions")

print('\nsegmentation of the stand-in performance')
seg_src = cell_with('NOTES = segment_notes(', 'DROPPED_OUTSIDE')
out = run(G, seg_src, 'segment')
NOTES = G.get('NOTES') or []
check('notes were produced', len(NOTES) > 0, len(NOTES))
check(f'the {len(EXPECTED_MIDI)} notes put in come back out',
      len(NOTES) == len(EXPECTED_MIDI),
      f'got {len(NOTES)}: {[round(n["midi"]) for n in NOTES]}')
check('  at the right pitches',
      [round(n['midi']) for n in NOTES] == EXPECTED_MIDI,
      f'{[round(n["midi"]) for n in NOTES]} vs {EXPECTED_MIDI}')
check('the 5.5s of bleed produced no notes',
      all(n['start'] > 5.5 for n in NOTES),
      f'earliest note at {NOTES[0]["start"]:.2f}s' if NOTES else '-')
check('  and the sung span starts after it',
      G['VOICED_LO'] > 5.5, f"{G['VOICED_LO']:.2f}s")
check('vibrato did not shatter the held 1.2s note',
      any(abs((n['end'] - n['start']) - 1.2) < 0.15 for n in NOTES),
      [round(n['end'] - n['start'], 2) for n in NOTES])

print('\nMIDI conversion cell')
rec_src = cell_with('RECORDS = to_records(NOTES)', 'off-grid')
out = run(G, rec_src, 'midi')
RECORDS = G.get('RECORDS') or []
check('one record per note', len(RECORDS) == len(NOTES), len(RECORDS))
check('note_name matches midi_note',
      all(G['midi_to_note'](r['midi_note']) == r['note_name']
          for r in RECORDS))

print('\nQC cell')
qc_src = cell_with('FILE_PROBLEMS = boundary_checks(', 'flag_notes(')
out = run(G, qc_src, 'qc')
check('every note carries a flags list',
      all(isinstance(n.get('flags'), list) for n in G['NOTES']))
check('nothing was verified by the QC pass',
      all(n['verification_status'] == 'unverified' for n in G['NOTES']))
check('it says so out loud',
      f"0 of {len(G['NOTES'])} verified" in out,
      [l for l in out.splitlines() if 'verified' in l][:1])
check('a clean stand-in has no file-level problems',
      G['FILE_PROBLEMS'] == [], G['FILE_PROBLEMS'])
check('  and no note is flagged as an octave error',
      not any('possible_octave_error' in n['flags'] for n in G['NOTES']))

print('\nCSV round-trip cell (§14 — defined before §15 uses it)')
rt_src = cell_with('def read_review_csv(', 'write_review_csv(')
out = run(G, rt_src, 'roundtrip')
check('a review CSV was written on load',
      (Path(G['OUT_DIR']) / 'notes_for_review.csv').exists())

print('\nexport cell: both schemas')
exp_src = cell_with('ground_truth_notes.json', 'to_app_rows(')
out = run(G, exp_src, 'export')
check('reference_status is pending, not verified',
      G.get('REFERENCE_STATUS') == 'pending_verification',
      G.get('REFERENCE_STATUS'))

rich = json.loads((Path(OUT) / 'ground_truth_notes.json')
                  .read_text(encoding='utf-8'))
check('rich JSON has the spec\'s top-level keys',
      {'song_id', 'song_title', 'artist', 'reference_status',
       'pitch_extraction_model', 'notes'} <= set(rich), sorted(rich))
check('  notes carry the spec\'s per-note keys',
      {'note_id', 'start_time', 'end_time', 'duration', 'midi_note',
       'note_name', 'frequency_hz', 'confidence',
       'verification_status'} <= set(rich['notes'][0]),
      sorted(rich['notes'][0]))
check('  and no lyric, syllable or word field',
      not any(k in rich['notes'][0] for k in ('syllable', 'lyric', 'word',
                                              'text')))
check('  the segmentation config is recorded',
      'segmentation' in rich and rich['segmentation']['semitone_tol'] == 0.8,
      rich.get('segmentation', {}).get('semitone_tol'))
check('  the MIDI convention is stated',
      'C4' in rich.get('midi_convention', ''), rich.get('midi_convention'))

app_path = Path(OUT) / f"{G['ASSET_STEM']}.json"
check(f'the app file is named "<Title> - <Artist>.json"',
      app_path.exists(), app_path.name)
app = json.loads(app_path.read_text(encoding='utf-8'))
check('  it is {"data": [...]}, as the parser expects',
      set(app) == {'data'} and isinstance(app['data'], list), sorted(app))
check('  each row has exactly syllable/start/end/note',
      all(set(r) == {'syllable', 'start', 'end', 'note'}
          for r in app['data']))
check('  syllable is always empty', all(r['syllable'] == ''
                                        for r in app['data']))
check('  times agree with the rich file',
      [r['start'] for r in app['data']]
      == [r['start_time'] for r in rich['notes']])
check('  note names agree too',
      [r['note'] for r in app['data']]
      == [r['note_name'] for r in rich['notes']])

import csv as _csv
with open(Path(OUT) / 'ground_truth_notes.csv', encoding='utf-8') as fh:
    rows = list(_csv.reader(fh))
check('notes CSV: header plus one row per note',
      len(rows) == len(NOTES) + 1, len(rows))
check('  rows are rectangular', len({len(r) for r in rows}) == 1,
      {len(r) for r in rows})
with open(Path(OUT) / 'pitch_contour.csv', encoding='utf-8') as fh:
    contour_rows = list(_csv.reader(fh))
check('contour CSV: header plus one row per frame',
      len(contour_rows) == len(T) + 1,
      f'{len(contour_rows)} vs {len(T) + 1}')
check('  it names each model\'s columns',
      'torchcrepe_hz' in contour_rows[0] and 'fcpe_hz' in contour_rows[0],
      contour_rows[0])
check('  unvoiced frames leave midi blank rather than 0',
      any(r[contour_rows[0].index('torchcrepe_midi')] == ''
          for r in contour_rows[1:]))

print('\nverification keeps approval an explicit act')
ver_src = cell_with('btn_ok', 'approve this note')
check('there is no approve-everything button',
      'approve all' not in ver_src.lower()
      and 'verify all' not in ver_src.lower())
check('editing a note does not verify it',
      "'edited'" in ver_src and 'manually_edited' in ver_src)
check('flagged notes are reviewed first', 'REVIEW_ORDER' in ver_src)

print('\nreviewing through the CSV, the way a reviewer would')
review = Path(OUT) / 'notes_for_review.csv'
text = review.read_text(encoding='utf-8').splitlines()
hdr = text[0].split(',')
body = [r.split(',') for r in text[1:] if r.strip()]
# Approve two notes and delete one, the way a reviewer would.
si, vi = hdr.index('start_time'), hdr.index('verification_status')
body[0][vi] = 'verified'
body[1][vi] = 'verified'
body[2][vi] = 'deleted'
review.write_text('\n'.join([','.join(hdr)]
                            + [','.join(r) for r in body]) + '\n',
                  encoding='utf-8')
out = run(G, 'read_review_csv()', 'reimport')
check('the deleted note is dropped on import',
      len(G['NOTES']) == len(NOTES) - 1,
      f"{len(G['NOTES'])} vs {len(NOTES) - 1}")
check('  the two approvals survive',
      sum(1 for n in G['NOTES']
          if n['verification_status'] == 'verified') == 2,
      sum(1 for n in G['NOTES']
          if n['verification_status'] == 'verified'))
check('  and the rest stay unverified',
      sum(1 for n in G['NOTES']
          if n['verification_status'] == 'unverified')
      == len(NOTES) - 3)

out = run(G, exp_src, 'export-again')
check('partial approval exports as partially_verified',
      G['REFERENCE_STATUS'] == 'partially_verified', G['REFERENCE_STATUS'])

# And a fully approved file must say so -- otherwise the status is
# unreachable and the whole workflow has no end state.
for n in G['NOTES']:
    n['verification_status'] = 'verified'
out = run(G, exp_src, 'export-verified')
check('full approval exports as verified',
      G['REFERENCE_STATUS'] == 'verified', G['REFERENCE_STATUS'])

print('\nprocessing report')
rep_src = cell_with('processing_report.txt', 'KNOWN LIMITATIONS')
out = run(G, rep_src, 'report')
report = (Path(OUT) / 'processing_report.txt').read_text(encoding='utf-8')
for needed in ('INPUT AUDIO', 'MODELS', 'ENVIRONMENT', 'CONFIGURATION',
               'RESULTS', 'MODEL DISAGREEMENT', 'FILE-LEVEL PROBLEMS',
               'KNOWN LIMITATIONS'):
    check(f'report has a {needed} section', needed in report)
check('it records the checkpoint', 'checkpoint' in report)
check('it records the segmentation thresholds', 'semitone_tol' in report)
check('it records the MIDI convention', 'middle C = C4' in report)
check('it records processing time', 'inference time' in report)
check('it states that no accuracy figure is reported',
      'No accuracy percentage' in report)
check('it names the models that did not load',
      'rmvpe' in report.lower())
check('no fabricated accuracy figure anywhere',
      not any(tok in report for tok in ('% accurate', 'accuracy: 9',
                                        'accuracy of 9')))

print('\nZIP cell')
zip_src = cell_with('make_archive', 'reference_status')
out = run(G, zip_src, 'zip')
import os as _os
check('an archive was produced',
      any(f.endswith('.zip') for f in _os.listdir('/content')
          if _os.path.isdir('/content')) or 'zip' in out.lower(),
      out.strip().splitlines()[:1])

print('\nall five spec-required outputs exist')
for name in ('ground_truth_notes.json', 'ground_truth_notes.csv',
             'pitch_contour.csv', 'processing_report.txt'):
    p = Path(OUT) / name
    check(f'{name} ({p.stat().st_size if p.exists() else 0:,} bytes)',
          p.exists() and p.stat().st_size > 0)
check('note_visualization.png is produced by the plotting cell',
      'note_visualization.png' in whole,
      'not asserted here: matplotlib is not exercised in this harness')

print('\nthe harness itself walked the notebook forwards')
# The frame_disagreement bug survived review because this harness ran the
# module cell before the cell that needed it — an order I picked, not the
# notebook's. Re-running an earlier cell on purpose is fine (§15 is meant
# to be re-run after §14), so only the FIRST use of each cell is checked.
first_seen = {}
for idx, label in PICKED:
    first_seen.setdefault(label, idx)
order = list(first_seen.values())
regressions = [f'cell {b} ran after cell {a}'
               for a, b in zip(order, order[1:]) if b < a]
check('each cell it ran came from at or after the previous one',
      not regressions, regressions)
check(f'  covering {len(first_seen)} of {len(CODE)} code cells',
      len(first_seen) >= 10, sorted(order))

print()
print('FAILURES:', fails if fails else 'none')
sys.exit(1 if fails else 0)
