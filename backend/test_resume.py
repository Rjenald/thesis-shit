"""Does a disconnected run pick up where it stopped?

Colab drops sessions. Everything used to be held in `RESULTS` until the
export cell ran, so a drop at song 7 of 10 lost all seven — half an hour
of GPU time, and the next attempt restarted from nothing. Each song is now
written the moment it is extracted and a song already on disk is skipped.

This checks the two halves separately, because either one alone is
useless: a song has to be *written* as soon as it is done, and a later run
has to *recognise* it. The second half is the one worth testing hardest —
a resume that silently re-does work costs nothing but time, while a resume
that silently skips an unfinished song ships a truncated ground truth.

Only the loop's own helpers are exercised; the cell imports torchcrepe,
which is not installed here, so it cannot be exec'd whole.

    python backend/test_resume.py
"""
from __future__ import annotations

import ast
import json
import sys
import tempfile
from pathlib import Path

BACKEND = Path(__file__).resolve().parent
NB = BACKEND / 'ground_truth_from_stems.ipynb'

fails = []


def check(name, cond, detail=''):
    print(f"  {'OK  ' if cond else 'FAIL'} {name}"
          f"{'  ' + str(detail) if detail else ''}")
    if not cond:
        fails.append(name)


nb = json.loads(NB.read_text(encoding='utf-8'))
EXTRACT = next(''.join(c['source']) for c in nb['cells']
               if c['cell_type'] == 'code'
               and 'LABEL_SOURCE[stem] = mode' in ''.join(c['source']))
SETTINGS = next(''.join(c['source']) for c in nb['cells']
                if c['cell_type'] == 'code'
                and ''.join(c['source']).startswith('HOP_MS'))

print('the settings expose the switch')
g = {'__name__': 'nb'}
import contextlib
import io
with contextlib.redirect_stdout(io.StringIO()):
    exec(compile(SETTINGS, 'settings', 'exec'), g)
check('RESUME defaults to True', g.get('RESUME') is True, g.get('RESUME'))
check('OUT_DIR is set', bool(g.get('OUT_DIR')), g.get('OUT_DIR'))
check('  and Drive is documented as the fix for a recycled VM',
      'drive.mount' in SETTINGS)

print('\nthe loop writes each song as it finishes')
check('it writes inside the loop, not in the export cell',
      "print(f'    saved {stem}.json')" in EXTRACT)
check('  word onsets are written next to it',
      "f'{stem}.words.json'" in EXTRACT)
# Scoped to the loop body: `_load_written` has an `except Exception:` of
# its own, which an unscoped search finds first and compares against.
_loop = EXTRACT[EXTRACT.index('for stem, (vocals_path'):]
check('  the write sits inside the try, so a later step failing '
      'cannot lose it',
      _loop.index('saved {stem}.json') < _loop.index('    except Exception:'))

print('\nthe loop skips what is already on disk')
check('it looks for an earlier run', 'already extracted' in EXTRACT)
check('  and says how to force a redo', 'RESUME = False' in EXTRACT)
check('  it reports what is still outstanding',
      'still to do' in EXTRACT and 'Re-run this cell to continue' in EXTRACT)

# Pull just the helpers out: the cell as a whole imports torchcrepe.
start = EXTRACT.index('def _written_path(stem):')
end = EXTRACT.index('for stem, (vocals_path')
helpers = EXTRACT[start:end]
ast.parse(helpers)

tmp = Path(tempfile.mkdtemp(prefix='huni_resume_'))
hg = {'__name__': 'nb', 'os': __import__('os'), 'json': json,
      'OUT_DIR': str(tmp)}
exec(compile(helpers, 'helpers', 'exec'), hg)

STEM = 'Araw-Araw - Ben&Ben'
check('a song with nothing written is not skipped',
      hg['_load_written'](STEM) is None)

rows = [{'syllable': '', 'start': 1.0, 'end': 1.4, 'note': 'C4'},
        {'syllable': '', 'start': 1.5, 'end': 2.0, 'note': 'D4'}]
(tmp / f'{STEM}.json').write_text(json.dumps({'data': rows}),
                                 encoding='utf-8')
loaded = hg['_load_written'](STEM)
check('a written song is found again', loaded == rows, loaded)
check('  and its path is the one the exporter uses',
      hg['_written_path'](STEM).endswith(f'{STEM}.json'))

print('\na half-written file is NOT mistaken for a finished song')
# The case that matters: a disconnect mid-write. Treating truncated JSON
# as done would ship a ground truth missing most of its notes.
(tmp / 'Truncated - Someone.json').write_text('{"data": [{"start": 1.0,',
                                              encoding='utf-8')
check('truncated JSON reads as not-done',
      hg['_load_written']('Truncated - Someone') is None)
(tmp / 'Empty - Someone.json').write_text('{"data": []}', encoding='utf-8')
check('an empty note list reads as not-done',
      not hg['_load_written']('Empty - Someone'))
(tmp / 'NoData - Someone.json').write_text('{"notes": []}',
                                           encoding='utf-8')
check('the wrong shape reads as not-done',
      hg['_load_written']('NoData - Someone') is None)
check('a missing file reads as not-done',
      hg['_load_written']('Nothing - Here') is None)

print('\nthe skip decision itself')
# Mirrors the loop's own branch, which cannot be exec'd without torchcrepe.
def would_skip(stem, results, resume=True):
    if resume and stem not in results:
        if hg['_load_written'](stem):
            return 'resumed from disk'
    if stem in results:
        return 'already this session'
    return None


check('a finished song is skipped', would_skip(STEM, {}) == 'resumed from disk')
check('  an unfinished one is not', would_skip('Buwan - Juan Karlos', {})
      is None)
check('  a truncated one is not',
      would_skip('Truncated - Someone', {}) is None)
check('RESUME = False redoes everything',
      would_skip(STEM, {}, resume=False) is None)
check('a song done earlier this session is not redone',
      would_skip('Buwan - Juan Karlos', {'Buwan - Juan Karlos': rows})
      == 'already this session')

for f in tmp.glob('*'):
    f.unlink()
tmp.rmdir()

print()
print('FAILURES:', fails if fails else 'none')
sys.exit(1 if fails else 0)
