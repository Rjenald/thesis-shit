"""Generates backend/ground_truth_notes.ipynb.

A generator rather than a hand-edited .ipynb for two reasons. The
segmentation cell is inlined from backend/note_segmentation.py, so the
notebook always carries the exact code that backend/test_note_segmentation.py
covers -- test_notes_notebook.py fails if the two ever drift. And every
code cell is parsed here before it is written, so a syntax error surfaces
now rather than halfway through a Colab run.

    python backend/build_notes_notebook.py
    python backend/test_notes_notebook.py   # then check it still runs
"""
import ast
import json
from pathlib import Path

BACKEND = Path(__file__).resolve().parent
OUT = BACKEND / 'ground_truth_notes.ipynb'
MODULE = (BACKEND / 'note_segmentation.py').read_text(encoding='utf-8')

cells = []


def md(text):
    cells.append({'cell_type': 'markdown', 'metadata': {},
                  'source': text.strip('\n').splitlines(keepends=True)})


# Cheap stdlib modules that a cell may use without the author having
# remembered to import them. A name that happens to be in scope because
# an earlier cell imported it works right up until someone re-runs one
# cell on its own -- which is the normal way a notebook gets used, and is
# exactly what §14 -> §15 asks for.
AUTO_IMPORT = ('os', 'csv', 'json', 'shutil', 'time', 'gc', 'datetime',
               'math')


def code(text):
    body = text.strip('\n')
    check = '\n'.join('' if ln.lstrip().startswith(('!', '%')) else ln
                      for ln in body.splitlines())
    tree = ast.parse(check)

    imported = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            imported |= {a.asname or a.name.split('.')[0] for a in node.names}
        elif isinstance(node, ast.ImportFrom):
            imported |= {a.asname or a.name for a in node.names}
    used = {n.id for n in ast.walk(tree) if isinstance(n, ast.Name)}
    missing = sorted(set(AUTO_IMPORT) & used - imported)
    if missing:
        body = ''.join(f'import {m}\n' for m in missing) + body
        ast.parse('\n'.join('' if ln.lstrip().startswith(('!', '%')) else ln
                            for ln in body.splitlines()))

    cells.append({'cell_type': 'code', 'execution_count': None,
                  'metadata': {}, 'outputs': [],
                  'source': body.splitlines(keepends=True)})


# ======================================================== 1. Overview
md(r'''
# Huni — note-level vocal ground truth

Takes an **already separated vocal stem** and produces a note-level
reference: one event per note the singer actually sang, with its MIDI
pitch, frequency, start and end.

No vocal separation, no lyrics, no words, no syllables. The instrumental
stem is never processed — it is already Huni's backing track, and it is
only read here (optionally) to cross-check durations.

## Why note-level

The app creates one scored segment per ground-truth row, so **row
granularity is scoring granularity**. That makes the unit the *note
event* — what a transcriber writes on a staff — and the mapping to lyrics
deliberately not one-to-one:

- usually one syllable is one note
- one syllable can carry several notes (melisma)
- several syllables can sit on one pitch, as separate events

An earlier version of this pipeline got this wrong in both directions at
once, and the numbers are worth keeping in view because every threshold
here is a response to one of them:

| defect | measured |
|---|---|
| within-word boundaries that were arithmetic | 100% of multi-row words (59/59, 104/104, 51/51, 95/95) |
| held notes chopped into same-pitch runs | ~50% of rows, runs up to 7 |
| ground truth describing audio that did not exist | up to 46.5s past the end |
| phantom notes from instrumental bleed in the stem | 7 notes, 5.2s before the first sung word |

## What this notebook will not do

- It will **not** mark anything verified. Automatic output is
  `unverified` until you approve it in §14.
- It will **not** report an accuracy percentage. Nothing here knows the
  true pitch; there is no reference to score against. What it reports is
  the model's own confidence, where two models disagree, and which notes
  look odd — all of which are reasons to look, not verdicts.
- It will **not** silently swap models. If the preferred model cannot be
  loaded you get a loud banner naming what was used instead.

## Two output schemas, on purpose

`ground_truth_notes.json` carries the full record (ids, durations,
confidence, flags, verification status) for the PHP/MySQL backend and for
this notebook's own verification pass.

`<Title> - <Artist>.json` carries the four fields
`ground_truth_service.dart` actually parses — `{syllable, start, end,
note}`, with `syllable` always empty. Same notes, two serialisations. The
app cannot read the first one, so both are produced rather than one being
chosen.

**Set Runtime → Change runtime type → GPU (T4) before running.**
''')

# =================================================== 2. Configuration
md(r'''
## 2. Configuration

Everything you would want to change, in one place. Re-run this cell alone
after editing; nothing below depends on a cell above it except through
these names.
''')
code(r'''
# ---- the song -------------------------------------------------------
SONG_ID = 'nasa_iyo_na_ang_lahat'
SONG_TITLE = 'Nasa Iyo Na Ang Lahat'
ARTIST = 'Daniel Padilla'

# The stem that assets/audio/ and assets/ground_truth/ pair on. The app
# finds every file for a song by this one name, so it has to match
# SongCatalogService.bundled exactly.
ASSET_STEM = f'{SONG_TITLE} - {ARTIST}'

# ---- pitch extraction ------------------------------------------------
# Preference order, best-for-singing first. Each is tried in turn; the
# first that loads becomes PRIMARY and the rest become validators.
# Nothing is substituted silently -- §5 prints what actually loaded.
MODEL_PREFERENCE = ['rmvpe', 'fcpe', 'torchcrepe']

# Run every model that loads, not just the primary one. The second model
# is what makes §9 possible, and a region where two models disagree is
# the single most useful thing to hand a human reviewer.
RUN_ALL_MODELS = True

# 10 ms is CREPE's own default and RMVPE's native hop. Keep them equal
# across models or the frame-by-frame comparison in §9 has to resample,
# which would blur exactly the disagreements it is looking for.
HOP_MS = 10.0

# Vocal fundamentals. Deliberately wide enough for a low male voice and a
# high female one; narrowing it is the easiest way to create octave
# errors at the edges.
FMIN_HZ, FMAX_HZ = 50.0, 1100.0

# ---- note segmentation ----------------------------------------------
# See §10 for what each one does and which measured defect it answers.
SEG = dict(
    conf_min=0.50,        # below this the model is guessing, not hearing
    semitone_tol=0.80,    # wander allowed inside one note (vibrato ~0.5)
    hold_ms=60.0,         # a deviation must persist this long to count
    gap_ms=100.0,         # a voicing gap this long ends a note
    min_note_ms=100.0,    # shorter than this is an artifact
    max_note_ms=6000.0,   # longer is flagged as a probable stuck tracker
    smooth_ms=50.0,       # median filter width
    midi_lo=36, midi_hi=88,
)

# Notes lying entirely outside the sung region are dropped. Smoothing can
# bridge sparse instrumental bleed in a vocal stem into something shaped
# like a held note; that is where the 7 phantom notes came from.
DROP_NOTES_OUTSIDE_VOICED = True
VOICED_SUSTAIN_MS = 150.0     # a run must last this long to be singing

# ---- quality control -------------------------------------------------
CONF_WARN = 0.60              # flag notes assembled from weak frames
DISAGREE_TOL_SEMITONES = 0.5  # below this two models count as agreeing
DISAGREE_MIN_MS = 150.0       # shorter disagreements are not regions

OUT_DIR = '/content/huni_ground_truth'

print('configuration')
print(f'  song     : {SONG_TITLE} — {ARTIST}  (id {SONG_ID})')
print(f'  stem     : {ASSET_STEM}')
print(f'  models   : {" > ".join(MODEL_PREFERENCE)}'
      f'{"  (all run)" if RUN_ALL_MODELS else "  (primary only)"}')
print(f'  frames   : {HOP_MS:.0f} ms hop, {FMIN_HZ:.0f}-{FMAX_HZ:.0f} Hz')
print(f'  notes    : tol {SEG["semitone_tol"]} st, hold {SEG["hold_ms"]:.0f} ms, '
      f'gap {SEG["gap_ms"]:.0f} ms, min {SEG["min_note_ms"]:.0f} ms')
print(f'  out      : {OUT_DIR}')
''')

# ============================================ 3. GPU and environment
md(r'''
## 3. GPU and environment

Reports what you actually got. The free tier hands out different GPUs and
sometimes none at all, and every model below runs on CPU — slowly — so
this reports rather than refuses.
''')
code(r'''
import platform
import shutil
import subprocess
import sys

ENV = {'python': sys.version.split()[0], 'platform': platform.platform()}

try:
    import torch
    ENV['torch'] = torch.__version__
    ENV['cuda_available'] = torch.cuda.is_available()
    if torch.cuda.is_available():
        p = torch.cuda.get_device_properties(0)
        ENV['gpu'] = p.name
        ENV['gpu_vram_gb'] = round(p.total_memory / 1024 ** 3, 1)
        ENV['cuda'] = torch.version.cuda
        DEVICE = 'cuda'
    else:
        DEVICE = 'cpu'
except ImportError:
    ENV['torch'] = None
    DEVICE = 'cpu'

# Total RAM, which is what decides whether a 4-minute track at 16 kHz can
# be held alongside three models' outputs.
try:
    with open('/proc/meminfo') as fh:
        for line in fh:
            if line.startswith('MemTotal'):
                ENV['ram_gb'] = round(int(line.split()[1]) / 1024 ** 2, 1)
                break
except OSError:
    pass

for _root in ('/content', '/'):
    try:
        ENV['disk_free_gb'] = round(
            shutil.disk_usage(_root).free / 1024 ** 3, 1)
        break
    except OSError:
        continue

# .m4a decoding goes through ffmpeg; WAV and FLAC do not.
ENV['ffmpeg'] = bool(shutil.which('ffmpeg'))

print('environment')
for k in ('python', 'platform', 'torch', 'cuda', 'cuda_available', 'gpu',
          'gpu_vram_gb', 'ram_gb', 'disk_free_gb', 'ffmpeg'):
    if k in ENV:
        print(f'  {k:<14} {ENV[k]}')

print()
if DEVICE == 'cuda':
    print(f'Running on {ENV.get("gpu", "GPU")}.')
else:
    print('NO GPU. Everything below still works on CPU, but pitch')
    print('extraction on a 4-minute track takes minutes per model rather')
    print('than seconds. Runtime > Change runtime type > T4 GPU.')
if not ENV['ffmpeg']:
    print('ffmpeg missing: .m4a upload may fail. WAV and FLAC are safe.')
''')

# ============================================== 4. Dependencies
md(r'''
## 4. Dependency installation

One install per line so a failure names the package that broke instead of
taking the others down with it.

Nothing is pinned to an exact version here except where a conflict is
known. Colab's preinstalled torch is left alone deliberately: reinstalling
it is the most common way to break every CUDA wheel in the image, and
every model below works against whatever torch Colab ships.
''')
code(r'''
# Known-good against Colab's own torch build.
!pip install -q torchcrepe
!pip install -q torchfcpe
!pip install -q librosa soundfile mutagen

# RMVPE has no canonical PyPI package. These are the two routes that
# exist; both are attempted and §5 reports which (if either) worked.
# Deliberately NOT failing the cell on error -- a missing RMVPE must
# degrade to a named fallback, not stop the notebook.
!pip install -q rmvpe 2>/dev/null || echo "no 'rmvpe' package on PyPI"
![ -d /content/RMVPE ] || git clone -q https://github.com/Dream-High/RMVPE /content/RMVPE 2>/dev/null || echo "RMVPE repo clone failed"

import importlib
import sys

sys.path.insert(0, '/content/RMVPE')

VERSIONS = {}
for mod in ('torch', 'torchaudio', 'numpy', 'librosa', 'soundfile',
            'torchcrepe', 'torchfcpe', 'matplotlib', 'pandas',
            'ipywidgets'):
    try:
        m = importlib.import_module(mod)
        VERSIONS[mod] = getattr(m, '__version__', 'unknown')
    except Exception as e:                                  # noqa: BLE001
        VERSIONS[mod] = f'NOT AVAILABLE ({type(e).__name__})'

print('package versions')
for k, v in VERSIONS.items():
    print(f'  {k:<12} {v}')

# numpy 2.x against a package built for 1.x is the single most common
# Colab breakage, and it surfaces as a confusing ABI error deep inside a
# model. Checking here turns that into one readable line.
import numpy as np
if np.__version__.startswith('2.') and 'NOT' in str(VERSIONS['torchcrepe']):
    print()
    print('torchcrepe failed to import under numpy 2.x. Fix with:')
    print('    !pip install -q "numpy<2"')
    print('then Runtime > Restart session, and re-run from §3.')
''')

# ====================================== 5. Model download and init
md(r'''
## 5. Model download and initialisation

Three candidate F0 models, each behind the same small adapter so §8 does
not care which one it is holding:

| model | why it is here | confidence |
|---|---|---|
| **RMVPE** | trained specifically for *vocal* pitch and for robustness to accompaniment; the strongest choice for singing when its weights are reachable | yes |
| **FCPE** | singing-oriented, fast, pip-installable with bundled weights | voicing only |
| **torchcrepe** | the PyTorch port of CREPE. Known-good here: measured **97.52% RPA** on this project's own evaluation set, which is why it is the fallback rather than an afterthought | yes (periodicity) |

Two things worth being explicit about.

**RMVPE may not load.** It has no canonical PyPI package and its weights
are distributed through mirrors that come and go. The cell above tries
both routes it has; if neither works you will see it named in the banner
and the run continues on the next model. That is a stated fallback, not a
silent substitution.

**"Confidence" is not comparable between models.** torchcrepe's
periodicity and RMVPE's own score are real per-frame confidences. FCPE as
bundled reports voicing but not a graded confidence, so its adapter
returns 1.0 for voiced and 0.0 for unvoiced and says so in the report. A
flag derived from FCPE confidence would be meaningless, and the report
records which kind each model gave.
''')
code(r'''
import time
import traceback

import numpy as np


class PitchModel:
    """One F0 model behind a uniform interface.

    `predict(audio, sr)` returns (times, hz, confidence) on a HOP_MS grid
    starting at t=0, so every model's output indexes the same way and the
    comparison in §9 needs no resampling.

    `confidence_kind` is either 'graded' (a real per-frame confidence) or
    'voicing' (1/0 only). It is carried rather than hidden because a
    threshold on a voicing flag means something different from a
    threshold on a confidence, and the report has to say which it was.
    """

    def __init__(self, key, label, checkpoint, confidence_kind, fn):
        self.key = key
        self.label = label
        self.checkpoint = checkpoint
        self.confidence_kind = confidence_kind
        self._fn = fn

    def predict(self, audio, sr):
        return self._fn(audio, sr)


def _frames_for(n_hz, hop_ms=None):
    hop = (hop_ms or HOP_MS) / 1000.0
    return np.arange(n_hz) * hop


# ---- torchcrepe -----------------------------------------------------
def _load_torchcrepe():
    import torch
    import torchcrepe

    def predict(audio, sr):
        x = torch.from_numpy(audio.astype(np.float32)).unsqueeze(0)
        hop = int(round(sr * HOP_MS / 1000))
        hz, periodicity = torchcrepe.predict(
            x, sr, hop_length=hop, fmin=FMIN_HZ, fmax=FMAX_HZ,
            model='full', batch_size=512, device=DEVICE,
            return_periodicity=True)
        hz = hz.squeeze().cpu().numpy().astype(float)
        conf = periodicity.squeeze().cpu().numpy().astype(float)
        return _frames_for(len(hz)), hz, conf

    # 'full' is the 22M-parameter capacity, not the 'tiny' one; the RPA
    # figure above was measured with it.
    return PitchModel('torchcrepe', 'CREPE (torchcrepe, full)',
                      'torchcrepe bundled weights (full)', 'graded',
                      predict)


# ---- FCPE -----------------------------------------------------------
def _load_fcpe():
    import torch
    from torchfcpe import spawn_bundled_infer_model

    model = spawn_bundled_infer_model(device=DEVICE)

    def predict(audio, sr):
        x = torch.from_numpy(audio.astype(np.float32)).unsqueeze(-1
                                                                 ).unsqueeze(0)
        target = int(round(len(audio) / sr * 1000.0 / HOP_MS))
        f0 = model.infer(x.to(DEVICE), sr=sr, decoder_mode='local_argmax',
                         threshold=0.006,
                         f0_min=FMIN_HZ, f0_max=FMAX_HZ,
                         interp_uv=False,
                         output_interp_target_length=target)
        hz = f0.squeeze().detach().cpu().numpy().astype(float)
        # Bundled FCPE gives f0 with unvoiced frames at 0 and no graded
        # score, so voicing is all that can honestly be reported.
        conf = (hz > 0).astype(float)
        return _frames_for(len(hz)), hz, conf

    return PitchModel('fcpe', 'FCPE (torchfcpe, bundled)',
                      'torchfcpe bundled checkpoint', 'voicing', predict)


# ---- RMVPE ----------------------------------------------------------
def _load_rmvpe():
    """Best-effort: two import routes, then a weights hunt.

    Raises with a readable message if any step fails. The caller turns
    that into a named fallback rather than a crash.
    """
    import glob
    import torch

    RMVPE = None
    errors = []
    for route in ('rmvpe', 'src.rmvpe', 'rmvpe.rmvpe'):
        try:
            mod = __import__(route, fromlist=['RMVPE'])
            RMVPE = getattr(mod, 'RMVPE', None) or getattr(mod, 'RMVPE0', None)
            if RMVPE is not None:
                break
        except Exception as e:                              # noqa: BLE001
            errors.append(f'{route}: {type(e).__name__}')
    if RMVPE is None:
        raise RuntimeError('no RMVPE class importable (' +
                           '; '.join(errors) + ')')

    found = (glob.glob('/content/**/rmvpe.pt', recursive=True) +
             glob.glob('/root/**/rmvpe.pt', recursive=True) +
             glob.glob('/usr/**/rmvpe.pt', recursive=True))
    if not found:
        raise RuntimeError(
            'RMVPE code imported but no rmvpe.pt checkpoint found. Upload '
            'one to /content/rmvpe.pt and re-run this cell. Not downloading '
            'from an unverified mirror automatically.')
    ckpt = found[0]
    model = RMVPE(ckpt, is_half=(DEVICE == 'cuda'), device=DEVICE)

    def predict(audio, sr):
        # RMVPE is trained at 16 kHz; its own hop is 10 ms.
        hz = model.infer_from_audio(audio.astype(np.float32), thred=0.03)
        hz = np.asarray(hz, dtype=float)
        conf = (hz > 0).astype(float)
        return _frames_for(len(hz)), hz, conf

    return PitchModel('rmvpe', 'RMVPE', ckpt, 'voicing', predict)


LOADERS = {'rmvpe': _load_rmvpe, 'fcpe': _load_fcpe,
           'torchcrepe': _load_torchcrepe}

MODELS, MODEL_ERRORS = {}, {}
for key in MODEL_PREFERENCE:
    t0 = time.time()
    try:
        MODELS[key] = LOADERS[key]()
        print(f'  loaded {key:<11} in {time.time() - t0:.1f}s  '
              f'({MODELS[key].label})')
    except Exception as e:                                  # noqa: BLE001
        MODEL_ERRORS[key] = f'{type(e).__name__}: {e}'
        print(f'  FAILED {key:<11} {type(e).__name__}: {str(e)[:90]}')

print()
if not MODELS:
    raise RuntimeError(
        'No pitch model loaded. Fix the errors above before continuing — '
        'there is no point running the rest of the notebook.')

PRIMARY_KEY = next(k for k in MODEL_PREFERENCE if k in MODELS)
PRIMARY = MODELS[PRIMARY_KEY]
VALIDATORS = [k for k in MODELS if k != PRIMARY_KEY]

print('=' * 72)
print(f'PRIMARY MODEL : {PRIMARY.label}')
print(f'  checkpoint  : {PRIMARY.checkpoint}')
print(f'  confidence  : {PRIMARY.confidence_kind}')
if PRIMARY_KEY != MODEL_PREFERENCE[0]:
    print()
    print(f'  NOT the preferred model. {MODEL_PREFERENCE[0]!r} was asked')
    print('  for first and did not load:')
    for k in MODEL_PREFERENCE:
        if k == PRIMARY_KEY:
            break
        print(f'    {k}: {MODEL_ERRORS.get(k, "unknown")[:100]}')
print(f'VALIDATORS    : {", ".join(VALIDATORS) if VALIDATORS else "NONE"}')
if not VALIDATORS:
    print('  Only one model loaded, so §9 cannot cross-check anything and')
    print('  every note will carry a `single_model` flag. That is a real')
    print('  reduction in what this notebook can tell you.')
print('=' * 72)
''')

# ============================================ 6. Vocal audio upload
md(r'''
### Shared analysis code

Loaded here, before anything uses it, because **§8, §9 and §10 all need
it** — pitch conversion for the contour plot, the comparison helpers for
the cross-check, and the segmenter itself. An earlier draft put it in §10
and §9 failed with `NameError: frame_disagreement`, which is the ordinary
cost of defining things after their first use in a notebook.

It is a verbatim copy of `backend/note_segmentation.py`, which
`backend/test_note_segmentation.py` covers with 114 assertions against
synthetic contours whose answers are known by construction. Inlined
because Colab receives this notebook and nothing else; the test suite
fails if the copy ever drifts from the file.

The algorithm it implements is explained where it is used, in §10.
''')
code(MODULE + '''

print('shared analysis code loaded')
print(f'  MIDI 60 = {midi_to_note(60)} = {midi_to_hz(60):.2f} Hz '
      '(middle C is C4)')
print('  segmentation, QC and both export schemas are now available')
''')

md(r'''
## 6. Vocal audio upload

Upload the **isolated vocal stem**. WAV, FLAC, MP3 and M4A all work.

The instrumental is optional and is never processed — if you upload it
too, it is read only for its duration, which cross-checks that the notes
cannot run past the track the app will play.

On format: MP3 is fine. Its encoder discards content above roughly 16 kHz
and in masked low-energy regions, and every model here resamples to
16 kHz and looks for fundamentals between 50 and 1100 Hz, so none of them
can see what was removed. Do not re-export a stem to "improve" it —
re-encoding risks shifting it relative to the instrumental, which is the
one property this whole approach depends on.
''')
code(r'''
import os

os.makedirs(OUT_DIR, exist_ok=True)

try:
    from google.colab import files as colab_files
    IN_COLAB = True
except ImportError:
    IN_COLAB = False

VOCAL_PATH = None
INSTRUMENTAL_PATH = None

AUDIO_EXT = ('.wav', '.flac', '.mp3', '.m4a', '.ogg', '.aiff', '.aif')


def looks_instrumental(name):
    low = name.lower()
    return any(w in low for w in ('instrumental', 'minus', 'backing',
                                  'karaoke', 'accomp'))


if IN_COLAB:
    print('Select the vocal stem (and optionally the instrumental):')
    uploaded = colab_files.upload()
    for name in uploaded:
        if not name.lower().endswith(AUDIO_EXT):
            print(f'  ignoring {name} (not an audio file)')
            continue
        if looks_instrumental(name):
            INSTRUMENTAL_PATH = f'/content/{name}'
        else:
            VOCAL_PATH = f'/content/{name}'
else:
    # Running outside Colab: point these at local files instead.
    cand = [f for f in sorted(os.listdir('.'))
            if f.lower().endswith(AUDIO_EXT)]
    for name in cand:
        if looks_instrumental(name):
            INSTRUMENTAL_PATH = os.path.abspath(name)
        elif VOCAL_PATH is None:
            VOCAL_PATH = os.path.abspath(name)

if VOCAL_PATH is None:
    raise RuntimeError(
        'No vocal stem. Re-run this cell and choose the vocals file. If '
        'its filename contains "instrumental", "minus", "backing" or '
        '"karaoke" it was classified as the backing track — rename it.')

print()
print(f'vocals       : {VOCAL_PATH}')
_instr = INSTRUMENTAL_PATH or '(none; duration will not be cross-checked)'
print(f'instrumental : {_instr}')
''')

# ============================= 7. Audio inspection and preprocessing
md(r'''
## 7. Audio inspection and preprocessing

What matters here is that **timestamps stay on the original recording's
clock**. Everything downstream is a time in seconds into the stem you
uploaded, so the file is loaded from sample zero and never trimmed,
padded or offset. Resampling happens, because the models require 16 kHz,
but resampling the whole file from sample zero preserves the mapping.

Channels are averaged, with one guard: averaging cancels anything
phase-inverted between the two, which would hand the model silence. So
the mix is compared against the individual channels and the loudest
channel is used instead if averaging destroyed the signal. Separated
stems are usually stereo, so this is the normal path rather than an edge
case.
''')
code(r'''
import librosa
import matplotlib.pyplot as plt
import numpy as np
import soundfile as sf

MODEL_SR = 16000       # every model here is trained at 16 kHz


def describe(path):
    info = {'path': path, 'bytes': os.path.getsize(path)}
    try:
        with sf.SoundFile(path) as fh:
            info.update(sample_rate=fh.samplerate, channels=fh.channels,
                        frames=len(fh), duration=len(fh) / fh.samplerate,
                        subtype=fh.subtype, format=fh.format)
    except Exception:                                       # noqa: BLE001
        # soundfile cannot open every MP3/M4A build; librosa falls back.
        y, sr = librosa.load(path, sr=None, mono=False)
        info.update(sample_rate=sr, channels=1 if y.ndim == 1 else y.shape[0],
                    frames=y.shape[-1], duration=y.shape[-1] / sr,
                    subtype='(via librosa)', format=path.rsplit('.', 1)[-1])
    return info


def to_mono(y):
    """(channels, n) or (n,) -> (n,), without letting phase cancel it."""
    if y.ndim == 1:
        return y
    mixed = y.mean(axis=0)
    rms_mixed = float(np.sqrt(np.mean(mixed ** 2)))
    per = [float(np.sqrt(np.mean(y[c] ** 2))) for c in range(y.shape[0])]
    loudest = int(np.argmax(per))
    if rms_mixed < 0.5 * per[loudest]:
        print(f'  channels cancel when averaged (mix RMS {rms_mixed:.5f} '
              f'vs channel {loudest} {per[loudest]:.5f}); '
              f'using channel {loudest} alone')
        return y[loudest]
    return mixed


VOCAL_INFO = describe(VOCAL_PATH)
print('vocal stem')
for k in ('format', 'subtype', 'sample_rate', 'channels', 'duration',
          'frames', 'bytes'):
    v = VOCAL_INFO.get(k)
    print(f'  {k:<12} {v:.3f}' if isinstance(v, float) else
          f'  {k:<12} {v}')

INSTRUMENTAL_INFO = (describe(INSTRUMENTAL_PATH) if INSTRUMENTAL_PATH
                     else None)
if INSTRUMENTAL_INFO:
    print('instrumental (read for its duration only, never processed)')
    print(f'  duration     {INSTRUMENTAL_INFO["duration"]:.3f}')
    drift = abs(INSTRUMENTAL_INFO['duration'] - VOCAL_INFO['duration'])
    print(f'  vs vocals    {drift:.3f}s apart')
    if drift > 0.5:
        print('  !! more than 0.5s apart. Stems from one separation run')
        print('     should match almost exactly — if one was trimmed or')
        print('     faded on its own afterwards, ground truth taken from')
        print('     the vocals will not line up with what the app plays.')

y_raw, sr_native = librosa.load(VOCAL_PATH, sr=None, mono=False)
print(f'\nloaded {np.shape(y_raw)} at {sr_native} Hz')
y_mono = to_mono(np.asarray(y_raw, dtype=float))

# Resampled from sample zero, so time in AUDIO maps to time in the
# original stem by t = i / MODEL_SR with no offset to track.
AUDIO = (y_mono if sr_native == MODEL_SR else
         librosa.resample(y_mono, orig_sr=sr_native, target_sr=MODEL_SR))
AUDIO = np.asarray(AUDIO, dtype=np.float32)
DURATION = len(AUDIO) / MODEL_SR

peak = float(np.max(np.abs(AUDIO))) if len(AUDIO) else 0.0
rms = float(np.sqrt(np.mean(AUDIO ** 2))) if len(AUDIO) else 0.0
print(f'analysis signal: {len(AUDIO)} samples at {MODEL_SR} Hz '
      f'= {DURATION:.3f}s')
print(f'  peak {peak:.4f}   rms {rms:.5f}'
      f'   {20 * np.log10(peak) if peak else -np.inf:.1f} dBFS peak')

AUDIO_WARNINGS = []
if peak >= 0.999:
    AUDIO_WARNINGS.append('clipped (peak at full scale) — separation '
                          'artifacts can confuse pitch tracking')
if peak < 0.05:
    AUDIO_WARNINGS.append(f'very quiet (peak {peak:.4f}) — check the right '
                          'file was uploaded')
if rms < 1e-4:
    AUDIO_WARNINGS.append('near-silent overall')
# Deliberately NOT normalising: every model here is scale-invariant in
# practice, and a gain change is one more way for a file to stop matching
# the instrumental it was separated with.
for w in AUDIO_WARNINGS:
    print(f'  !! {w}')

fig, ax = plt.subplots(2, 1, figsize=(14, 5), sharex=True)
t_wave = np.arange(len(AUDIO)) / MODEL_SR
ax[0].plot(t_wave, AUDIO, lw=0.4)
ax[0].set_ylabel('amplitude')
ax[0].set_title(f'{ASSET_STEM} — vocal stem ({DURATION:.1f}s)')
win = int(MODEL_SR * 0.05)
env = np.sqrt(np.convolve(AUDIO.astype(float) ** 2,
                          np.ones(win) / win, mode='same'))
ax[1].plot(t_wave, 20 * np.log10(np.maximum(env, 1e-6)), lw=0.6,
           color='tab:orange')
ax[1].set_ylabel('dBFS (50ms RMS)')
ax[1].set_xlabel('time (s)')
ax[1].set_ylim(-80, 0)
for a in ax:
    a.grid(alpha=0.3)
plt.tight_layout()
plt.show()
''')

# ====================================================== 8. F0 extraction
md(r'''
## 8. F0 extraction

Every loaded model runs over the same 16 kHz mono signal on the same
10 ms grid, so frame *i* means the same instant in all of them.

Frames are **not** interpolated across unvoiced gaps. An interpolated
contour looks smoother and segments more cleanly, which is precisely the
problem: it invents pitch where the singer was silent, and the segmenter
cannot then tell a held note from a rest.
''')
code(r'''
import gc
import time

import numpy as np

TRACKS = {}
TIMING = {}

for key, model in MODELS.items():
    if key != PRIMARY_KEY and not RUN_ALL_MODELS:
        continue
    print(f'{key} ({model.label})...')
    t0 = time.time()
    try:
        times, hz, conf = model.predict(AUDIO, MODEL_SR)
        times = np.asarray(times, dtype=float)
        hz = np.nan_to_num(np.asarray(hz, dtype=float), nan=0.0)
        conf = np.nan_to_num(np.asarray(conf, dtype=float), nan=0.0)
        n = min(len(times), len(hz), len(conf))
        TRACKS[key] = {'times': times[:n], 'hz': hz[:n],
                       'conf': conf[:n],
                       'confidence_kind': model.confidence_kind}
        TIMING[key] = time.time() - t0
        voiced = int(np.sum((hz[:n] > 0) & (conf[:n] >= SEG['conf_min'])))
        print(f'  {n} frames in {TIMING[key]:.1f}s '
              f'({n * HOP_MS / 1000:.1f}s of audio), '
              f'{voiced} voiced ({100 * voiced / max(n, 1):.0f}%)')
        # A frame count that disagrees with the audio length means the
        # hop assumption is wrong, and every timestamp after it is wrong
        # too -- worth catching here rather than in the export.
        expect = len(AUDIO) / MODEL_SR
        got = n * HOP_MS / 1000
        if abs(got - expect) > max(0.5, 0.02 * expect):
            print(f'  !! covers {got:.1f}s but the audio is {expect:.1f}s. '
                  f'This model may not use a {HOP_MS:.0f}ms hop; its '
                  'timestamps cannot be trusted.')
    except Exception as e:                                  # noqa: BLE001
        print(f'  FAILED {type(e).__name__}: {e}')
        MODEL_ERRORS[key] = f'inference: {type(e).__name__}: {e}'
    finally:
        gc.collect()
        try:
            import torch
            if torch.cuda.is_available():
                torch.cuda.empty_cache()
        except ImportError:
            pass

if PRIMARY_KEY not in TRACKS:
    raise RuntimeError(f'the primary model ({PRIMARY_KEY}) produced no '
                       'pitch track; see the error above')

T = TRACKS[PRIMARY_KEY]['times']
HZ = TRACKS[PRIMARY_KEY]['hz']
CONF = TRACKS[PRIMARY_KEY]['conf']
print(f'\nprimary track: {PRIMARY_KEY}, {len(T)} frames')
''')

code(r'''
# The contour, as it actually is -- gaps shown as gaps.
import matplotlib.pyplot as plt

fig, ax = plt.subplots(2, 1, figsize=(14, 7), sharex=True,
                       gridspec_kw={'height_ratios': [3, 1]})
colors = {'rmvpe': 'tab:red', 'fcpe': 'tab:green',
          'torchcrepe': 'tab:blue'}
for key, tr in TRACKS.items():
    midi = np.where(
        (tr['hz'] > 0) & (tr['conf'] >= SEG['conf_min']),
        69 + 12 * np.log2(np.maximum(tr['hz'], 1e-9) / 440.0), np.nan)
    ax[0].plot(tr['times'], midi, '.', ms=1.2,
               color=colors.get(key, 'tab:gray'),
               label=f'{key} ({"primary" if key == PRIMARY_KEY else "validator"})')
ax[0].set_ylabel('MIDI pitch')
ax[0].legend(loc='upper right', markerscale=8)
ax[0].grid(alpha=0.3)
ax[0].set_title(f'{ASSET_STEM} — F0, confidence floor {SEG["conf_min"]}')

pt = TRACKS[PRIMARY_KEY]
ax[1].plot(pt['times'], pt['conf'], lw=0.5, color='tab:purple')
ax[1].axhline(SEG['conf_min'], color='k', ls='--', lw=0.8,
              label=f'conf_min {SEG["conf_min"]}')
ax[1].set_ylabel(f'{PRIMARY_KEY}\n{pt["confidence_kind"]}')
ax[1].set_xlabel('time (s)')
ax[1].legend(loc='lower right')
ax[1].grid(alpha=0.3)
plt.tight_layout()
plt.show()

if pt['confidence_kind'] == 'voicing':
    print(f'NOTE: {PRIMARY_KEY} reports voicing only (1/0), not a graded')
    print('confidence, so the lower panel is a gate and not a quality')
    print('curve, and per-note confidence will be 1.0 for every note it')
    print('accepted. Flags derived from confidence mean nothing here.')
''')

# ======================================== 9. Multi-model comparison
md(r'''
## 9. Multi-model pitch comparison

Two models that agree are not necessarily right — they can share a bias,
and both were trained on broadly similar data. But where they *disagree*,
at least one is wrong, and that is a region worth a human's eyes.

Two kinds of disagreement, kept apart because they mean different things:

- **pitch** — both heard a note, by different amounts. A sustained run
  near 12 semitones is an octave error in one of them.
- **voicing** — one heard a note and the other heard nothing. Usually
  breath, consonants, or bleed that one model rejected.
''')
code(r'''
import numpy as np

AGREEMENT = None
DISAGREE_FRAMES = None
DISAGREE_REGIONS = []
VOICING_REGIONS = []

if not VALIDATORS or not any(k in TRACKS for k in VALIDATORS):
    print('Only one pitch track, so nothing can be cross-checked.')
    print('Every note will be flagged `single_model`. If you want this')
    print('section to do its job, fix whichever model failed in §5.')
else:
    ref = TRACKS[PRIMARY_KEY]
    for key in VALIDATORS:
        if key not in TRACKS:
            continue
        other = TRACKS[key]
        d = frame_disagreement(ref['hz'], other['hz'], ref['conf'],
                              other['conf'], SEG['conf_min'])
        v = voicing_disagreement(ref['hz'], other['hz'], ref['conf'],
                                 other['conf'], SEG['conf_min'])
        both = ~np.isnan(d)
        print(f'{PRIMARY_KEY} vs {key}')
        print(f'  frames both call voiced : {int(both.sum())} '
              f'({100 * both.mean():.0f}%)')
        if both.any():
            print(f'  median |difference|     : '
                  f'{np.nanmedian(d):.3f} semitones')
            print(f'  beyond {DISAGREE_TOL_SEMITONES} semitones      : '
                  f'{100 * np.nanmean(d > DISAGREE_TOL_SEMITONES):.1f}% '
                  'of those frames')
            near_octave = np.nansum((d > 10.5) & (d < 13.5))
            print(f'  within 1.5st of an octave: {int(near_octave)} frames '
                  f'({100 * near_octave / max(int(both.sum()), 1):.1f}%)')
        print(f'  voicing disagreement    : {100 * v.mean():.1f}% of frames')

        regions = disagreement_regions(
            ref['times'], np.where(d > DISAGREE_TOL_SEMITONES, d, 0.0),
            min_ms=DISAGREE_MIN_MS)
        print(f'  sustained regions       : {len(regions)}')
        for a, b, mean in regions[:15]:
            tag = ('  <- octave?' if 10.5 <= mean <= 13.5 else '')
            print(f'      {a:7.2f} - {b:7.2f}s   mean '
                  f'{mean:5.2f} st{tag}')
        if len(regions) > 15:
            print(f'      ... and {len(regions) - 15} more')

        # The first validator is the one notes are scored against, so the
        # choice is recorded rather than left to dict ordering.
        if DISAGREE_FRAMES is None:
            DISAGREE_FRAMES = d
            DISAGREE_REGIONS = regions
            COMPARED_WITH = key
            VOICING_REGIONS = disagreement_regions(
                ref['times'], v.astype(float), min_ms=DISAGREE_MIN_MS)
        print()

    if DISAGREE_FRAMES is not None:
        print(f'Notes will be cross-checked against {COMPARED_WITH}.')
''')

# ======================================== 10. Note segmentation
md(r'''
## 10. Note segmentation

The part everything else rests on.

A new note begins when the smoothed pitch leaves the current note's
running median by more than `semitone_tol` **and stays there** for
`hold_ms`. The persistence requirement is what separates this from
rounding frames to semitones: without it, a vibrato cycle becomes several
notes and a slide becomes one note per frame. The boundary is then placed
where the deviation *started*, not where it was confirmed, or every onset
would land `hold_ms` late.

Afterwards, neighbours left at the same pitch with no gap between them are
merged — one held note that a brief wobble split in two. That matters for
the score and not just for tidiness: the app creates one scored segment
per row, so a note held across five rows would otherwise count five
times.

Two things are dropped rather than repaired:

- pitch outside `midi_lo..midi_hi`, because folding an octave error back
  assumes it was exactly an octave
- notes shorter than `min_note_ms`, which are tracker artifacts

`segment_notes` itself was loaded in the shared-code cell after §5,
because §8 and §9 needed it too. This section is where it gets explained,
checked and used.
''')
code(r'''
# The thresholds from §2, resolved against this run's hop.
CFG_PREVIEW = SegmentConfig(hop_ms=HOP_MS, **SEG)

print('segmentation settings')
for k, v in CFG_PREVIEW.as_dict().items():
    print(f'  {k:<18} {v}')
print()
print(f'  smoothing window {CFG_PREVIEW.smooth_frames} frames, needing '
      f'{(CFG_PREVIEW.smooth_frames + 1) // 2} of them to be real pitch')
print('  (that quorum is what stops sparse instrumental bleed in a vocal')
print('   stem from being smoothed into something shaped like a note)')
''')

md(r'''
### Synthetic self-test

Runs the segmenter and the MIDI conversion against contours whose answers
are known, independently of any uploaded song. If this fails, nothing
below it means anything — and it will fail *here*, where the cause is
obvious, rather than as a strange note list later.
''')
code(r'''
import numpy as np

def _contour(spans, conf=0.9, hop_ms=None):
    hop = hop_ms or HOP_MS
    midi, per = [], []
    for value, ms in spans:
        n = int(round(ms / hop))
        midi += [np.nan] * n if value is None else [float(value)] * n
        per += [0.0] * n if value is None else [conf] * n
    midi = np.array(midi, dtype=float)
    hz = np.where(np.isnan(midi), 0.0, midi_to_hz(midi))
    return np.arange(len(midi)) * hop / 1000.0, hz, np.array(per)


_cfg = SegmentConfig(hop_ms=HOP_MS, **SEG)
_fails = []


def _expect(name, cond, detail=''):
    print(f'  {"OK  " if cond else "FAIL"} {name}'
          f'{"  " + str(detail) if detail else ""}')
    if not cond:
        _fails.append(name)


# F0 -> MIDI, the formula everything downstream uses.
_expect('440 Hz is MIDI 69', abs(hz_to_midi([440.0])[0] - 69) < 1e-9)
_expect('MIDI 60 is named C4', midi_to_note(60) == 'C4', midi_to_note(60))
_expect('an octave is 12 semitones',
        abs(hz_to_midi([880.0])[0] - hz_to_midi([440.0])[0] - 12) < 1e-9)
_expect('0 Hz is not a pitch', np.isnan(hz_to_midi([0.0])[0]))

# Segmentation behaviours, each a defect this pipeline was built against.
r = segment_notes(*_contour([(60, 600)]), _cfg)
_expect('one steady note -> 1 event', len(r) == 1, f'got {len(r)}')
r = segment_notes(*_contour([(60, 500), (65, 500)]), _cfg)
_expect('two notes -> 2 events, boundary near 0.5s',
        len(r) == 2 and abs(r[1]['start'] - 0.5) < 0.06,
        f'{len(r)} events' + (f", {r[1]['start']:.3f}s" if len(r) > 1 else ''))
r = segment_notes(*_contour([(60, 120)] * 7), _cfg)
_expect('7 equal slices of one pitch -> 1 event (the old over-segmentation)',
        len(r) == 1, f'got {len(r)}')
r = segment_notes(*_contour([(60, 250), (64, 250), (67, 250)]), _cfg)
_expect('melisma: 3 real notes -> 3 events', len(r) == 3, f'got {len(r)}')
r = segment_notes(*_contour([(60, 400), (None, 300), (60, 400)]), _cfg)
_expect('a 300ms rest splits the note', len(r) == 2, f'got {len(r)}')
r = segment_notes(*_contour([(60, 400), (None, 30), (60, 400)]), _cfg)
_expect('a 30ms dropout does not', len(r) == 1, f'got {len(r)}')
r = segment_notes(*_contour([(60, 500), (72, 30), (60, 500)]), _cfg)
_expect('a 30ms octave blip is not a note', len(r) == 1, f'got {len(r)}')

_n = 120
_t = np.arange(_n) * HOP_MS / 1000.0
_vib = 60 + 0.5 * np.sin(2 * np.pi * 5 * _t)
r = segment_notes(_t, midi_to_hz(_vib), np.full(_n, 0.9), _cfg)
_expect('vibrato stays one note', len(r) == 1, f'got {len(r)}')

_slide = np.linspace(60, 67, 60)
r = segment_notes(np.arange(60) * HOP_MS / 1000.0, midi_to_hz(_slide),
                  np.full(60, 0.9), _cfg)
_expect('a 600ms slide does not become a note per frame', len(r) <= 4,
        f'got {len(r)}')

# Sparse bleed: one confident frame in four, which is what an
# instrumental leaking into a vocal stem looked like.
_bn = 550
_bhz = np.full(_bn, float(midi_to_hz(73)))
_bc = np.zeros(_bn)
_bc[::4] = 0.9
_bt = np.arange(_bn) * HOP_MS / 1000.0
_expect('sparse instrumental bleed -> no notes',
        len(segment_notes(_bt, _bhz, _bc, _cfg)) == 0)
_expect('  and the smoothing quorum is why',
        len(segment_notes(_bt, _bhz, _bc,
                          SegmentConfig(hop_ms=HOP_MS, smooth_quorum=1,
                                        **SEG))) > 0)

# Export shape must match what the app parses.
_rows = to_app_rows(segment_notes(*_contour([(60, 500), (64, 500)]), _cfg))
_expect('app rows have exactly {syllable,start,end,note}',
        all(set(x) == {'syllable', 'start', 'end', 'note'} for x in _rows))
_expect('  with syllable empty (no lyrics in this pipeline)',
        all(x['syllable'] == '' for x in _rows))

print()
if _fails:
    raise AssertionError(f'{len(_fails)} self-test failure(s): {_fails}. '
                         'Do not trust anything below this cell.')
print('self-test passed; the segmenter behaves as documented')
''')

md(r'''
### Segment the real contour
''')
code(r'''
import numpy as np

CFG = SegmentConfig(hop_ms=HOP_MS, **SEG)

VOICED_LO, VOICED_HI = voiced_span(T, HZ, CONF, SEG['conf_min'],
                                   VOICED_SUSTAIN_MS)
if VOICED_LO is None:
    raise RuntimeError('no sustained pitch anywhere in this stem — check '
                       'the right file was uploaded and that conf_min is '
                       'not above what this model ever reports')
print(f'sustained singing runs {VOICED_LO:.2f}s .. {VOICED_HI:.2f}s '
      f'of {DURATION:.2f}s')

NOTES = segment_notes(T, HZ, CONF, CFG)
print(f'{len(NOTES)} note events from {len(T)} frames')

DROPPED_OUTSIDE = []
if DROP_NOTES_OUTSIDE_VOICED:
    NOTES, DROPPED_OUTSIDE = notes_within(NOTES, VOICED_LO, VOICED_HI)
    if DROPPED_OUTSIDE:
        print(f'  dropped {len(DROPPED_OUTSIDE)} note(s) outside that span '
              f'({DROPPED_OUTSIDE[0]["start"]:.1f}s .. '
              f'{DROPPED_OUTSIDE[-1]["end"]:.1f}s) — bleed in the stem, '
              'not singing')

if not NOTES:
    raise RuntimeError('no notes survived segmentation; loosen conf_min or '
                       'min_note_ms in §2 and re-run')

durs = np.array([n['end'] - n['start'] for n in NOTES])
midis = np.array([n['midi'] for n in NOTES])
print(f'  span      {NOTES[0]["start"]:.2f}s .. {NOTES[-1]["end"]:.2f}s')
print(f'  duration  median {np.median(durs):.3f}s, '
      f'min {durs.min():.3f}s, max {durs.max():.3f}s')
print(f'  pitch     {midi_to_note(midis.min())} .. '
      f'{midi_to_note(midis.max())} '
      f'({midis.max() - midis.min():.0f} semitones)')
print(f'  coverage  {100 * durs.sum() / (VOICED_HI - VOICED_LO):.0f}% of '
      'the sung span is inside a note')
''')

# =========================================== 11. MIDI conversion
md(r'''
## 11. MIDI conversion

`MIDI = 69 + 12·log₂(f / 440)`, with **MIDI 69 = A4 = 440 Hz**, so
MIDI 60 is C4 and middle C is C4. Stated explicitly because the other
common convention names MIDI 60 "C3", and a mismatch there is an
off-by-an-octave bug that looks like a tuning problem.

Each note carries both numbers, which are not the same thing:

- `midi_note` / `frequency_hz` — the nearest semitone, and *that note's*
  frequency. These always agree with each other.
- `measured_midi` / `measured_hz` / `cents_off_grid` — what was actually
  measured, and how far off the equal-tempered grid it sat.

Keeping them apart matters because a singer who is consistently 40 cents
flat is still singing that note, and collapsing the two would either
hide that or invent a pitch nobody sang.
''')
code(r'''
RECORDS = to_records(NOTES)

print(f'{len(RECORDS)} notes converted')
print(f"\n{'id':>4} {'start':>8} {'end':>8} {'dur':>6} {'midi':>5} "
      f"{'name':>5} {'Hz':>8} {'cents':>6} {'conf':>5}")
for r in RECORDS[:15]:
    print(f"{r['note_id']:4d} {r['start_time']:8.3f} {r['end_time']:8.3f} "
          f"{r['duration']:6.3f} {r['midi_note']:5d} {r['note_name']:>5} "
          f"{r['frequency_hz']:8.2f} {r['cents_off_grid']:6.1f} "
          f"{r['confidence'] if r['confidence'] is not None else 0:5.2f}")
if len(RECORDS) > 15:
    print(f'... and {len(RECORDS) - 15} more')

import numpy as np
cents = np.array([r['cents_off_grid'] for r in RECORDS])
print(f'\noff-grid: median {np.median(cents):+.1f} cents, '
      f'{np.percentile(np.abs(cents), 90):.0f} cents at the 90th pct')
if abs(np.median(cents)) > 25:
    print(f'  !! the whole track sits {np.median(cents):+.0f} cents off')
    print('     equal temperament. That is a tuning reference difference,')
    print('     not a pitch error — but the app compares against A440, so')
    print('     expect a constant offset in every score.')
''')

# ================================= 12. Ground-truth generation / QC
md(r'''
## 12. Ground-truth generation and quality control

Flags are attached here. Every one of them can fire on a note that is
perfectly correct — a real held note *is* long, a real falsetto leap *is*
an octave — which is why this flags rather than filters, and why nothing
in this section ever marks a note verified.

| flag | what it means |
|---|---|
| `very_short` / `very_long` | near the duration limits; the long one is usually a stuck tracker |
| `low_confidence` | assembled from frames the model was unsure of |
| `unstable_pitch` | moved more than 2 semitones inside one note: wide vibrato, or a slide that survived |
| `possible_octave_error` | ~12 semitones off the *local* register while its neighbours are not |
| `far_from_local_register` | a bigger jump than an octave |
| `model_disagreement` | two models differ beyond tolerance across most of the note |
| `agreement_unknown` | a second model ran but says nothing here |
| `single_model` | nothing cross-checked this note at all |

No accuracy percentage is reported anywhere, because nothing here knows
the true pitch. `confidence` is the model's own number, passed through.
''')
code(r'''
import numpy as np

if DISAGREE_FRAMES is not None:
    AGREEMENT = [note_agreement(n, T, DISAGREE_FRAMES,
                                DISAGREE_TOL_SEMITONES) for n in NOTES]
else:
    AGREEMENT = None

NOTES = flag_notes(NOTES, CFG, agreement=AGREEMENT, conf_warn=CONF_WARN)
RECORDS = to_records(NOTES)

FILE_PROBLEMS = boundary_checks(
    NOTES,
    audio_duration=(INSTRUMENTAL_INFO['duration'] if INSTRUMENTAL_INFO
                    else DURATION),
    voiced=(VOICED_LO, VOICED_HI))

from collections import Counter
counts = Counter(f for n in NOTES for f in n['flags'])
flagged = [n for n in NOTES if n['flags']]

print(f'{len(NOTES)} notes, {len(flagged)} carrying at least one flag '
      f'({100 * len(flagged) / len(NOTES):.0f}%)')
print()
for flag, k in counts.most_common():
    print(f'  {flag:<26} {k:4d}  ({100 * k / len(NOTES):.0f}%)')

print()
if FILE_PROBLEMS:
    print('whole-file problems — these are the serious ones, because they')
    print('mean the file disagrees with its own audio:')
    for p in FILE_PROBLEMS:
        print(f'  !! {p}')
else:
    print('no whole-file problems: no overlaps, nothing past the end of')
    print('the audio, nothing outside the sung span, no arithmetic')
    print('durations, no implausible range.')

print()
print(f'verification: 0 of {len(NOTES)} verified. Everything is')
print('`unverified` until you approve it in §14 — nothing in this')
print('notebook promotes a note on its own.')
''')

# ====================================================== 13. Visualisation
md(r'''
## 13. Visualisation

Three views, because each one makes a different mistake obvious: the
contour with note boundaries drawn on it shows boundaries in the wrong
place; the piano roll shows octave errors and register jumps; the
duration and pitch histograms show arithmetic boundaries as a spike.
''')
code(r'''
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.patches import Rectangle

fig = plt.figure(figsize=(15, 11))
gs = fig.add_gridspec(4, 2, height_ratios=[3, 2, 2, 2], hspace=0.45,
                      wspace=0.2)

# 1. contour with the segmented notes laid over it
ax = fig.add_subplot(gs[0, :])
midi_track = np.where((HZ > 0) & (CONF >= SEG['conf_min']),
                      69 + 12 * np.log2(np.maximum(HZ, 1e-9) / 440.0),
                      np.nan)
ax.plot(T, midi_track, '.', ms=1.0, color='0.55', label='F0 frames')
for n in NOTES:
    bad = bool(n['flags']) and not set(n['flags']) <= {'single_model'}
    ax.plot([n['start'], n['end']], [n['midi']] * 2, '-',
            lw=2.4, color='tab:red' if bad else 'tab:blue')
for a, b, _m in DISAGREE_REGIONS:
    ax.axvspan(a, b, color='tab:orange', alpha=0.18, zorder=0)
ax.axvspan(0, VOICED_LO, color='0.9', zorder=0)
ax.axvspan(VOICED_HI, max(DURATION, VOICED_HI), color='0.9', zorder=0)
ax.set_ylabel('MIDI')
ax.set_xlabel('time (s)')
ax.set_title(f'{ASSET_STEM} — {len(NOTES)} notes over the '
             f'{PRIMARY_KEY} contour  (red = flagged, orange = models '
             'disagree, grey = outside the sung span)')
ax.legend(loc='upper right', markerscale=8)
ax.grid(alpha=0.3)

# 2. piano roll
ax = fig.add_subplot(gs[1, :])
lo, hi = int(min(n['midi'] for n in NOTES)), int(max(n['midi'] for n in NOTES))
for n in NOTES:
    bad = bool(n['flags']) and not set(n['flags']) <= {'single_model'}
    ax.add_patch(Rectangle((n['start'], round(n['midi']) - 0.4),
                           n['end'] - n['start'], 0.8,
                           color='tab:red' if bad else 'tab:blue',
                           alpha=0.85))
for m in range(lo, hi + 2):
    if m % 12 == 0:
        ax.axhline(m, color='k', lw=0.6, alpha=0.4)
        ax.text(0, m, f' {midi_to_note(m)}', va='center', fontsize=7)
ax.set_xlim(max(0, VOICED_LO - 2), min(DURATION, VOICED_HI + 2))
ax.set_ylim(lo - 1.5, hi + 1.5)
ax.set_ylabel('MIDI')
ax.set_xlabel('time (s)')
ax.set_title('piano roll')
ax.grid(alpha=0.2, axis='x')

# 3. waveform with boundaries
ax = fig.add_subplot(gs[2, :])
t_wave = np.arange(len(AUDIO)) / MODEL_SR
ax.plot(t_wave, AUDIO, lw=0.3, color='0.6')
for n in NOTES:
    ax.axvline(n['start'], color='tab:green', lw=0.5, alpha=0.7)
ax.set_xlim(max(0, VOICED_LO - 2), min(DURATION, VOICED_HI + 2))
ax.set_ylabel('amplitude')
ax.set_xlabel('time (s)')
ax.set_title('vocal waveform with note onsets')

# 4. duration histogram -- a spike here is arithmetic boundaries
ax = fig.add_subplot(gs[3, 0])
durs = np.array([n['end'] - n['start'] for n in NOTES])
ax.hist(durs, bins=40, color='tab:blue')
ax.axvline(SEG['min_note_ms'] / 1000, color='k', ls='--', lw=0.8,
           label=f'min {SEG["min_note_ms"]:.0f}ms')
ax.set_xlabel('note duration (s)')
ax.set_ylabel('count')
ax.set_title('durations (one tall spike = computed, not detected)')
ax.legend()

# 5. pitch histogram -- the register, and any octave outliers
ax = fig.add_subplot(gs[3, 1])
ax.hist([n['midi'] for n in NOTES],
        bins=range(lo - 1, hi + 3), color='tab:green')
ax.set_xlabel('MIDI pitch')
ax.set_ylabel('count')
ax.set_title('register (outliers far from the mass are octave errors)')

VIS_PATH = os.path.join(OUT_DIR, 'note_visualization.png')
plt.savefig(VIS_PATH, dpi=110, bbox_inches='tight')
print(f'wrote {VIS_PATH}')
plt.show()
''')

# ================================= 14. Manual note verification
md(r'''
## 14. Manual note verification

Nothing above this point produced ground truth. It produced *candidates*.

The interface below walks the notes, plays each one's audio, and lets you
correct its pitch and boundaries and then approve it. Flagged notes come
first, because they are where the time is best spent.

Approval is explicit and per note (or per visible page). There is no
"approve everything" button, because a button that marks 500 notes
verified in one click records a claim nobody checked.

If the widgets do not render — Colab occasionally needs a page reload —
use the CSV round-trip in the next cell instead. It is less pleasant and
exactly as valid.
''')
code(r'''
import numpy as np

try:
    import ipywidgets as W
    from IPython.display import Audio, display
    HAVE_WIDGETS = True
except ImportError:
    HAVE_WIDGETS = False
    print('ipywidgets unavailable; use the CSV round-trip cell below.')

# Review order: flagged notes first, then the rest, each in time order.
REVIEW_ORDER = (
    [i for i, n in enumerate(NOTES)
     if set(n['flags']) - {'single_model'}]
    + [i for i, n in enumerate(NOTES)
       if not (set(n['flags']) - {'single_model'})])


def verified_count():
    return sum(1 for n in NOTES if n['verification_status'] == 'verified')


def note_audio(i, pad=0.25):
    """The note, plus a little either side so its onset is audible."""
    n = NOTES[i]
    a = max(0, int((n['start'] - pad) * MODEL_SR))
    b = min(len(AUDIO), int((n['end'] + pad) * MODEL_SR))
    return AUDIO[a:b]


if HAVE_WIDGETS and NOTES:
    pos = {'k': 0}

    header = W.HTML()
    info = W.HTML()
    audio_box = W.Output()
    plot_box = W.Output()

    midi_in = W.FloatText(description='MIDI', step=1.0,
                          layout=W.Layout(width='180px'))
    start_in = W.FloatText(description='start', step=0.01,
                           layout=W.Layout(width='180px'))
    end_in = W.FloatText(description='end', step=0.01,
                         layout=W.Layout(width='180px'))

    btn_prev = W.Button(description='< prev')
    btn_next = W.Button(description='next >')
    btn_apply = W.Button(description='apply edits', button_style='warning')
    btn_ok = W.Button(description='approve this note',
                      button_style='success')
    btn_unver = W.Button(description='un-approve')
    btn_del = W.Button(description='delete note', button_style='danger')
    btn_split = W.Button(description='split at midpoint')

    def render():
        k = pos['k'] % len(REVIEW_ORDER)
        pos['k'] = k
        i = REVIEW_ORDER[k]
        n = NOTES[i]
        flags = ', '.join(n['flags']) or 'none'
        header.value = (
            f"<b>note {i + 1} of {len(NOTES)}</b> "
            f"&nbsp; (review position {k + 1}/{len(REVIEW_ORDER)}) "
            f"&nbsp;&nbsp; <span style='color:#888'>verified "
            f"{verified_count()}/{len(NOTES)}</span>")
        status = n['verification_status']
        colour = {'verified': 'green', 'unverified': '#b26b00',
                  'deleted': 'red'}.get(status, '#444')
        info.value = (
            f"<div style='font-family:monospace'>"
            f"{n['start']:.3f} – {n['end']:.3f}s "
            f"({n['end'] - n['start']:.3f}s)<br>"
            f"{midi_to_note(n['midi'])} "
            f"(MIDI {n['midi']:.2f}, {midi_to_hz(n['midi']):.1f} Hz)<br>"
            f"confidence {n.get('confidence', 0):.3f}"
            f" &nbsp; frames {n.get('frames', 0)}<br>"
            f"flags: <b>{flags}</b><br>"
            f"status: <b style='color:{colour}'>{status}</b></div>")
        midi_in.value = round(n['midi'], 2)
        start_in.value = round(n['start'], 3)
        end_in.value = round(n['end'], 3)

        audio_box.clear_output(wait=True)
        with audio_box:
            display(Audio(note_audio(i), rate=MODEL_SR, autoplay=False))

        plot_box.clear_output(wait=True)
        with plot_box:
            import matplotlib.pyplot as plt
            lo = max(0, n['start'] - 1.0)
            hi = min(DURATION, n['end'] + 1.0)
            m = (T >= lo) & (T <= hi)
            fig, ax = plt.subplots(figsize=(9, 2.4))
            mt = np.where((HZ[m] > 0) & (CONF[m] >= SEG['conf_min']),
                          69 + 12 * np.log2(np.maximum(HZ[m], 1e-9) / 440),
                          np.nan)
            ax.plot(T[m], mt, '.', ms=2.5, color='0.5')
            ax.plot([n['start'], n['end']], [n['midi']] * 2, lw=3,
                    color='tab:red')
            for other in NOTES:
                if other is n or other['end'] < lo or other['start'] > hi:
                    continue
                ax.plot([other['start'], other['end']],
                        [other['midi']] * 2, lw=2, color='tab:blue',
                        alpha=0.6)
            ax.axhline(round(n['midi']), color='k', ls=':', lw=0.8)
            ax.set_xlim(lo, hi)
            ax.set_xlabel('time (s)')
            ax.set_ylabel('MIDI')
            ax.grid(alpha=0.3)
            plt.tight_layout()
            plt.show()

    def step(d):
        def handler(_):
            pos['k'] += d
            render()
        return handler

    def apply_edits(_):
        i = REVIEW_ORDER[pos['k']]
        n = NOTES[i]
        if end_in.value <= start_in.value:
            info.value += ("<br><b style='color:red'>end must be after "
                           'start; not applied</b>')
            return
        n['midi'] = float(midi_in.value)
        n['start'] = float(start_in.value)
        n['end'] = float(end_in.value)
        # An edited note is NOT automatically verified -- editing and
        # approving are separate acts, and conflating them would record
        # an approval the reviewer never gave.
        n['verification_status'] = 'edited'
        n['flags'] = [f for f in n['flags'] if f != 'single_model'] or []
        n['flags'].append('manually_edited')
        render()

    def approve(_):
        NOTES[REVIEW_ORDER[pos['k']]]['verification_status'] = 'verified'
        pos['k'] += 1
        render()

    def unapprove(_):
        NOTES[REVIEW_ORDER[pos['k']]]['verification_status'] = 'unverified'
        render()

    def delete(_):
        NOTES[REVIEW_ORDER[pos['k']]]['verification_status'] = 'deleted'
        pos['k'] += 1
        render()

    def split(_):
        i = REVIEW_ORDER[pos['k']]
        n = NOTES[i]
        mid = 0.5 * (n['start'] + n['end'])
        if mid - n['start'] < 0.02 or n['end'] - mid < 0.02:
            return
        right = dict(n)
        right['start'] = mid
        right['flags'] = list(n['flags']) + ['manually_split']
        right['verification_status'] = 'unverified'
        n['end'] = mid
        n['flags'] = list(n['flags']) + ['manually_split']
        NOTES.insert(i + 1, right)
        REVIEW_ORDER[:] = list(range(len(NOTES)))
        render()

    btn_prev.on_click(step(-1))
    btn_next.on_click(step(1))
    btn_apply.on_click(apply_edits)
    btn_ok.on_click(approve)
    btn_unver.on_click(unapprove)
    btn_del.on_click(delete)
    btn_split.on_click(split)

    display(W.VBox([
        header,
        W.HBox([info, audio_box]),
        plot_box,
        W.HBox([midi_in, start_in, end_in, btn_apply]),
        W.HBox([btn_prev, btn_next, btn_ok, btn_unver, btn_split, btn_del]),
    ]))
    render()
''')

md(r'''
### CSV round-trip (fallback, and for bulk edits)

Writes the notes out, waits for you to edit the file, and reads them back.
Works when widgets do not, and is the better tool for a sweep of similar
corrections.

Edit `midi_note`, `start_time`, `end_time`, and set
`verification_status` to `verified` on the rows you have actually
checked. Rows left `unverified` stay unverified; a row set to `deleted`
is dropped on import.
''')
code(r'''
import csv

REVIEW_CSV = os.path.join(OUT_DIR, 'notes_for_review.csv')


def write_review_csv(path=REVIEW_CSV):
    with open(path, 'w', newline='', encoding='utf-8') as fh:
        csv.writer(fh).writerows(csv_rows(to_records(NOTES)))
    print(f'wrote {path} ({len(NOTES)} notes)')
    print('Edit it (Colab: left sidebar > Files), then run '
          'read_review_csv().')


def read_review_csv(path=REVIEW_CSV):
    """Reads edits back. Only ever as trusting as the file deserves."""
    global NOTES, RECORDS
    with open(path, newline='', encoding='utf-8') as fh:
        rows = list(csv.DictReader(fh))
    out, skipped = [], 0
    for r in rows:
        try:
            start, end = float(r['start_time']), float(r['end_time'])
            midi = float(r.get('measured_midi') or r['midi_note'])
        except (TypeError, ValueError):
            skipped += 1
            continue
        status = (r.get('verification_status') or 'unverified').strip()
        if status == 'deleted' or end <= start:
            skipped += 1
            continue
        out.append({
            'start': start, 'end': end, 'midi': midi,
            'confidence': float(r['confidence'] or 0) if r.get('confidence')
            else None,
            'frames': int(r['frames']) if (r.get('frames') or '').isdigit()
            else None,
            'flags': [f for f in (r.get('flags') or '').split('|') if f],
            'midi_min': midi, 'midi_max': midi,
            'verification_status': status,
        })
    out.sort(key=lambda n: n['start'])
    NOTES = out
    RECORDS = to_records(NOTES)
    v = sum(1 for n in NOTES if n['verification_status'] == 'verified')
    print(f'read {len(NOTES)} notes ({skipped} skipped or deleted)')
    print(f'  {v} verified, {len(NOTES) - v} still unverified')
    for p in boundary_checks(NOTES, audio_duration=DURATION,
                            voiced=(VOICED_LO, VOICED_HI)):
        print(f'  !! {p}')


write_review_csv()
''')

# ================================================ 15. JSON and CSV export
md(r'''
## 15. JSON and CSV export

`reference_status` is derived, never asserted: `verified` only when every
note is verified, `partially_verified` when some are, and
`pending_verification` otherwise. It cannot say "verified" about a file
you did not finish reviewing.
''')
code(r'''
import csv
import json

RECORDS = to_records(NOTES)
n_ver = sum(1 for r in RECORDS if r['verification_status'] == 'verified')
n_edit = sum(1 for r in RECORDS
             if r['verification_status'] in ('edited', 'manually_edited'))

if n_ver == len(RECORDS) and RECORDS:
    REFERENCE_STATUS = 'verified'
elif n_ver:
    REFERENCE_STATUS = 'partially_verified'
else:
    REFERENCE_STATUS = 'pending_verification'

PAYLOAD = {
    'song_id': SONG_ID,
    'song_title': SONG_TITLE,
    'artist': ARTIST,
    'asset_stem': ASSET_STEM,
    'reference_status': REFERENCE_STATUS,
    'pitch_extraction_model': PRIMARY.label,
    'pitch_extraction_checkpoint': PRIMARY.checkpoint,
    'confidence_kind': PRIMARY.confidence_kind,
    'validated_against': (COMPARED_WITH if DISAGREE_FRAMES is not None
                          else None),
    'midi_convention': 'MIDI 69 = A4 = 440 Hz; middle C = C4',
    'hop_ms': HOP_MS,
    'analysis_sample_rate': MODEL_SR,
    'source_sample_rate': VOCAL_INFO['sample_rate'],
    'audio_duration': round(DURATION, 3),
    'sung_span': [round(VOICED_LO, 3), round(VOICED_HI, 3)],
    'segmentation': CFG.as_dict(),
    'note_count': len(RECORDS),
    'verified_count': n_ver,
    'edited_count': n_edit,
    'file_problems': FILE_PROBLEMS,
    'notes': RECORDS,
}

JSON_PATH = os.path.join(OUT_DIR, 'ground_truth_notes.json')
with open(JSON_PATH, 'w', encoding='utf-8') as fh:
    json.dump(PAYLOAD, fh, ensure_ascii=False, indent=2)

CSV_PATH = os.path.join(OUT_DIR, 'ground_truth_notes.csv')
with open(CSV_PATH, 'w', newline='', encoding='utf-8') as fh:
    csv.writer(fh).writerows(csv_rows(RECORDS))

# The frame-level contour, for re-segmenting later without re-running a
# model, and for auditing a boundary against the pitch it came from.
CONTOUR_PATH = os.path.join(OUT_DIR, 'pitch_contour.csv')
with open(CONTOUR_PATH, 'w', newline='', encoding='utf-8') as fh:
    w = csv.writer(fh)
    keys = [k for k in MODEL_PREFERENCE if k in TRACKS]
    head = ['time']
    for k in keys:
        head += [f'{k}_hz', f'{k}_conf', f'{k}_midi']
    w.writerow(head)
    n = min(len(TRACKS[k]['times']) for k in keys)
    for i in range(n):
        row = [round(float(TRACKS[keys[0]]['times'][i]), 4)]
        for k in keys:
            hz = float(TRACKS[k]['hz'][i])
            cf = float(TRACKS[k]['conf'][i])
            voiced = hz > 0 and cf >= SEG['conf_min']
            row += [round(hz, 3), round(cf, 4),
                    round(69 + 12 * np.log2(hz / 440.0), 4) if voiced
                    else '']
        w.writerow(row)

# The app's own schema. Written separately because
# ground_truth_service.dart parses {"data":[{syllable,start,end,note}]}
# and cannot read the rich file above. `syllable` is always empty: this
# pipeline does no lyrics, and nothing scores that field.
APP_ROWS = to_app_rows([n for n in NOTES
                        if n['verification_status'] != 'deleted'])
APP_PATH = os.path.join(OUT_DIR, f'{ASSET_STEM}.json')
with open(APP_PATH, 'w', encoding='utf-8') as fh:
    json.dump({'data': APP_ROWS}, fh, ensure_ascii=False, indent=1)

print(f'reference_status : {REFERENCE_STATUS}')
print(f'  {n_ver} of {len(RECORDS)} notes verified'
      + (f', {n_edit} edited' if n_edit else ''))
print()
# VIS_PATH only exists if §13 ran. This section is meant to be re-run on
# its own after approving notes in §14, so a missing figure must not take
# the export down with it.
_outputs = [JSON_PATH, CSV_PATH, CONTOUR_PATH, APP_PATH]
_outputs += [p for p in [globals().get('VIS_PATH')] if p]
for p in _outputs:
    if os.path.exists(p):
        print(f'  {os.path.getsize(p):>9,} bytes  {os.path.basename(p)}')
    else:
        print(f'  {"missing":>15}  {os.path.basename(p)}')
if 'VIS_PATH' not in globals():
    print('  (no note_visualization.png yet — run §13 if you want one)')

print()
print('Drop the app file into assets/ground_truth/ keeping its exact')
print(f'name — "{ASSET_STEM}.json" — so it pairs with assets/audio/.')
print('Then, locally:')
print('    python backend/check_ground_truth.py')
''')

# ====================================================== 16. Report
md(r'''
## 16. Processing report

Written to a file because six months from now the only way to know how a
ground truth was made is a record made at the time. It includes the
things that went *wrong* as well as the settings.
''')
code(r'''
import datetime
import json

lines = []
A = lines.append

A('Huni — note-level vocal ground truth')
A('=' * 68)
A(f'generated        : {datetime.datetime.now().isoformat(timespec="seconds")}')
A(f'song             : {SONG_TITLE} — {ARTIST}')
A(f'song_id          : {SONG_ID}')
A(f'asset stem       : {ASSET_STEM}')
A(f'reference_status : {REFERENCE_STATUS}')
A('')
A('INPUT AUDIO')
A('-' * 68)
for k in ('path', 'format', 'subtype', 'sample_rate', 'channels',
          'duration', 'frames', 'bytes'):
    if k in VOCAL_INFO:
        A(f'  {k:<18} {VOCAL_INFO[k]}')
A(f'  analysis rate      {MODEL_SR} Hz mono, resampled from sample 0')
A(f'  analysis duration  {DURATION:.3f}s')
A(f'  peak / rms         {float(np.max(np.abs(AUDIO))):.4f} / '
  f'{float(np.sqrt(np.mean(AUDIO ** 2))):.5f}')
if INSTRUMENTAL_INFO:
    A(f'  instrumental       {INSTRUMENTAL_INFO["duration"]:.3f}s '
      '(read for duration only; never processed)')
else:
    A('  instrumental       not supplied; duration not cross-checked')
for w in AUDIO_WARNINGS:
    A(f'  WARNING            {w}')
A('')
A('MODELS')
A('-' * 68)
A(f'  preference order   {" > ".join(MODEL_PREFERENCE)}')
A(f'  PRIMARY            {PRIMARY.label}')
A(f'    checkpoint       {PRIMARY.checkpoint}')
A(f'    confidence       {PRIMARY.confidence_kind}')
A(f'    inference time   {TIMING.get(PRIMARY_KEY, float("nan")):.1f}s')
for k in MODEL_PREFERENCE:
    if k in TRACKS and k != PRIMARY_KEY:
        A(f'  validator          {MODELS[k].label} '
          f'({TIMING.get(k, float("nan")):.1f}s, '
          f'{MODELS[k].confidence_kind})')
for k, err in MODEL_ERRORS.items():
    A(f'  NOT LOADED         {k}: {err}')
if PRIMARY_KEY != MODEL_PREFERENCE[0]:
    A(f'  NOTE               the preferred model '
      f'({MODEL_PREFERENCE[0]}) did not load; this is a stated')
    A('                     fallback, not a silent substitution')
A('')
A('ENVIRONMENT')
A('-' * 68)
for k, v in ENV.items():
    A(f'  {k:<18} {v}')
A('  packages')
for k, v in VERSIONS.items():
    A(f'    {k:<16} {v}')
A('')
A('CONFIGURATION')
A('-' * 68)
A(f'  hop                {HOP_MS} ms')
A(f'  f0 range           {FMIN_HZ}–{FMAX_HZ} Hz')
for k, v in CFG.as_dict().items():
    A(f'  {k:<18} {v}')
A(f'  drop notes outside sung span   {DROP_NOTES_OUTSIDE_VOICED}')
A(f'  voiced sustain     {VOICED_SUSTAIN_MS} ms')
A(f'  conf_warn          {CONF_WARN}')
A(f'  disagreement tol   {DISAGREE_TOL_SEMITONES} semitones, '
  f'min {DISAGREE_MIN_MS} ms')
A('')
A('RESULTS')
A('-' * 68)
A(f'  frames analysed    {len(T)}')
A(f'  sung span          {VOICED_LO:.3f}–{VOICED_HI:.3f}s')
A(f'  notes detected     {len(NOTES)}')
A(f'  notes dropped      {len(DROPPED_OUTSIDE)} (outside the sung span)')
A(f'  notes verified     {n_ver}')
A(f'  notes edited       {n_edit}')
_d = np.array([n['end'] - n['start'] for n in NOTES])
_m = np.array([n['midi'] for n in NOTES])
A(f'  duration           median {np.median(_d):.3f}s, '
  f'range {_d.min():.3f}–{_d.max():.3f}s')
A(f'  pitch range        {midi_to_note(_m.min())}–{midi_to_note(_m.max())} '
  f'({_m.max() - _m.min():.0f} semitones)')
A('  flags')
for flag, k in Counter(f for n in NOTES for f in n['flags']).most_common():
    A(f'    {flag:<26} {k}')
A('')
A('MODEL DISAGREEMENT')
A('-' * 68)
if DISAGREE_FRAMES is None:
    A('  not measured: only one pitch model produced a track, so every')
    A('  note carries a `single_model` flag. This is a real gap — a')
    A('  second model is what makes octave errors visible.')
else:
    A(f'  compared with      {COMPARED_WITH}')
    A(f'  sustained regions  {len(DISAGREE_REGIONS)}')
    for a, b, mean in DISAGREE_REGIONS[:40]:
        A(f'    {a:8.2f}–{b:8.2f}s  mean {mean:5.2f} semitones'
          + ('   (near an octave)' if 10.5 <= mean <= 13.5 else ''))
    if len(DISAGREE_REGIONS) > 40:
        A(f'    ... and {len(DISAGREE_REGIONS) - 40} more')
A('')
A('FILE-LEVEL PROBLEMS')
A('-' * 68)
if FILE_PROBLEMS:
    for p in FILE_PROBLEMS:
        A(f'  !! {p}')
else:
    A('  none')
A('')
A('KNOWN LIMITATIONS')
A('-' * 68)
A('  - No accuracy percentage is reported anywhere in this pipeline.')
A('    Nothing here knows the true pitch, so there is nothing to score')
A('    against. `confidence` is the model\'s own number, passed through.')
A('  - Agreement between two models is not correctness. They can share')
A('    a bias. Disagreement is the useful signal, not agreement.')
A('  - Note boundaries come from pitch, so a change of word on the same')
A('    pitch is one note, by design. That is what the app scores.')
A('  - A constant time offset that still fits inside the audio passes')
A('    every check here. Guarding against it is why the stems must come')
A('    from one separation run and must not be edited afterwards.')
if PRIMARY.confidence_kind == 'voicing':
    A(f'  - {PRIMARY_KEY} reports voicing only, so every note\'s')
    A('    confidence is 1.0 and confidence-derived flags say nothing.')
if REFERENCE_STATUS != 'verified':
    A(f'  - {len(RECORDS) - n_ver} of {len(RECORDS)} notes are still')
    A('    unverified. This file is a candidate, not ground truth.')

REPORT = '\n'.join(lines)
REPORT_PATH = os.path.join(OUT_DIR, 'processing_report.txt')
with open(REPORT_PATH, 'w', encoding='utf-8') as fh:
    fh.write(REPORT + '\n')
print(REPORT)
''')

# ======================================================= 17. ZIP
md(r'''
## 17. ZIP download

One archive with everything: both JSON schemas, both CSVs, the contour,
the visualisation and the report.
''')
code(r'''
import shutil

ZIP_BASE = f'/content/huni_ground_truth_{SONG_ID}'
ZIP_PATH = shutil.make_archive(ZIP_BASE, 'zip', OUT_DIR)

print(f'{ZIP_PATH}  ({os.path.getsize(ZIP_PATH):,} bytes)')
for name in sorted(os.listdir(OUT_DIR)):
    print(f'  {os.path.getsize(os.path.join(OUT_DIR, name)):>9,}  {name}')

print()
print(f'reference_status: {REFERENCE_STATUS}')
if REFERENCE_STATUS != 'verified':
    print(f'{len(RECORDS) - n_ver} note(s) are still unverified, so this is')
    print('a candidate reference. Go back to §14 to approve notes, then')
    print('re-run §15–17.')

if IN_COLAB:
    colab_files.download(ZIP_PATH)
''')

nb = {'cells': cells,
      'metadata': {'kernelspec': {'display_name': 'Python 3',
                                  'language': 'python', 'name': 'python3'},
                   'language_info': {'name': 'python'},
                   'colab': {'provenance': [], 'toc_visible': True},
                   'accelerator': 'GPU'},
      'nbformat': 4, 'nbformat_minor': 0}

OUT.write_text(json.dumps(nb, indent=1, ensure_ascii=False) + '\n',
               encoding='utf-8')
print(f'wrote {OUT}')
print(f'  {len(cells)} cells '
      f'({sum(1 for c in cells if c["cell_type"] == "code")} code)')
for i, c in enumerate(cells):
    s = ''.join(c['source'])
    head = next((l for l in s.splitlines() if l.strip()), '')
    print(f'  {i:2d} {c["cell_type"][:4]:<4} {len(s):6d}  {head[:64]}')
