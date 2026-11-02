"""Does the trim tool cut bleed and leave singing alone?

This one deletes ground truth, so the asymmetry matters more than the
accuracy: leaving bleed in adds notes the singer never sang, which costs
them a few marks; cutting real singing removes notes they DID sing, which
is worse and invisible afterwards. So every case here is about refusing.

The discrimination is the whole tool. Being outside the aligned word span
is NOT proof of bleed — three things put real notes there, and all of them
are singing:

  - backing vocals the separation kept
  - humming or a vocalise before the first word
  - **a lyrics sheet missing its opening lines**, which pushes the "first
    word" later than the first word actually is

That last one is the common case. On this catalog, five of six intro
regions turned out to sit inside the singer's own register, so a tool that
cut everything outside the word span would have deleted real singing from
five songs.

    python backend/test_trim_bleed.py
"""
from __future__ import annotations

import json
import sys
import tempfile
from pathlib import Path

BACKEND = Path(__file__).resolve().parent
sys.path.insert(0, str(BACKEND))

import trim_bleed as T                                       # noqa: E402

fails = []


def check(name, cond, detail=''):
    print(f"  {'OK  ' if cond else 'FAIL'} {name}"
          f"{'  ' + str(detail) if detail else ''}")
    if not cond:
        fails.append(name)


def notes(pitches, start=0.0, dur=0.4, gap=0.1):
    out, t = [], start
    for i, p in enumerate(pitches):
        d = dur + 0.03 * (i % 5)
        out.append({'syllable': '', 'start': round(t, 3),
                    'end': round(t + d, 3), 'note': p})
        t += d + gap
    return out


print('an accompaniment is recognised')
# Outside the singer's register, and leaping about: that is an instrument.
sung = notes(['A3', 'B3', 'C4', 'D4', 'B3', 'A3'] * 6, start=30.0)
intro = notes(['A5', 'C4', 'F5', 'A#3', 'D5', 'G4', 'A#5', 'C5'])
is_inst, why = T.looks_instrumental(intro, sung)
check('flagged as instrumental', is_inst, why)
check('  and it says why', 'outside' in why or 'fifth' in why, why)

print('\nthe same voice is NOT cut')
# Inside the register, stepwise: this is singing the sheet did not cover.
hum = notes(['A3', 'B3', 'C4', 'B3', 'A3', 'B3', 'C4', 'D4'])
is_inst, why = T.looks_instrumental(hum, sung)
check('not flagged', not is_inst, why)
check('  and it explains the likely cause',
      'same voice' in why, why)

print('\ntoo little to judge is not a licence to cut')
check('two notes cannot be judged',
      not T.looks_instrumental(notes(['A3', 'B3']), sung)[0])
check('  nor can a song with almost no sung notes',
      not T.looks_instrumental(intro, notes(['A3', 'B3']))[0])

print('\nthe plan only ever touches the two ends')
rows = (notes(['A5', 'F5', 'C5'], start=0.0)
        + notes(['A3', 'B3', 'C4'] * 8, start=20.0)
        + notes(['A5', 'F5', 'C5'], start=80.0))
kept, lead, trail = T.plan(rows, 20.0, 60.0)
check('leading region found', len(lead) == 3, len(lead))
check('trailing region found', len(trail) == 3, len(trail))
check('  everything between is kept', len(kept) == len(rows) - 6, len(kept))
check('  a gap in the MIDDLE is never cut',
      all(20.0 <= r['start'] <= 80.0 for r in kept),
      'a rest, a held note or a missing lyric line all live there')

print('\nsmall regions are left alone')
rows = notes(['A3'], start=0.0) + notes(['A3', 'B3'] * 10, start=20.0)
kept, lead, trail = T.plan(rows, 20.0, 60.0)
check('one stray note is not worth cutting', not lead and len(kept) == len(rows))

print('\nthe margin protects a note that starts just before its word')
rows = notes(['A3', 'B3', 'C4'] * 8, start=19.9)
kept, lead, _ = T.plan(rows, 20.0, 60.0)
check('a note 0.1s early survives', not lead, f'{len(lead)} cut')

print('\nend to end, on disk')
tmp = Path(tempfile.mkdtemp(prefix='huni_trim_'))
real_gt, real_backup = T.GT_DIR, T.BACKUP_DIR
T.GT_DIR = tmp
T.BACKUP_DIR = tmp / 'backups'
try:
    stem = 'Test Song - Someone'
    body = (notes(['A5', 'F5', 'C5', 'A#5', 'D5'], start=0.0)
            + notes(['A3', 'B3', 'C4', 'D4'] * 10, start=30.0))
    (tmp / f'{stem}.json').write_text(
        json.dumps({'data': body}), encoding='utf-8')
    words = [{'text': 'one', 'start': 30.0, 'end': 30.4},
             {'text': 'two', 'start': 48.0, 'end': 48.4}]
    (tmp / f'{stem}.words.json').write_text(
        json.dumps({'words': words}), encoding='utf-8')

    import contextlib
    import io

    def run(*argv):
        sys.argv = ['trim_bleed.py', *argv]
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            T.main()
        return out.getvalue()

    before = json.loads((tmp / f'{stem}.json').read_text(encoding='utf-8'))
    out = run(stem)
    check('a dry run reports the cut', '5 note(s)' in out, out.strip()[:70])
    after = json.loads((tmp / f'{stem}.json').read_text(encoding='utf-8'))
    check('  and changes nothing on disk', after == before)
    check('  and says so', 'Nothing was written' in out)

    out = run(stem, '--apply')
    after = json.loads((tmp / f'{stem}.json').read_text(encoding='utf-8'))
    check('--apply removes the instrumental intro',
          len(after['data']) == len(body) - 5,
          f"{len(after['data'])} of {len(body)}")
    check('  the sung notes are untouched',
          after['data'][0]['start'] >= 30.0, after['data'][0])
    # Backups land outside assets/, because pubspec bundles that folder
    # wholesale and a .bak beside the ground truth would ship in the APK.
    backup = T.BACKUP_DIR / f'{stem}.json'
    check('  a backup is kept', backup.exists(), str(backup))
    # Checked against the real default, not the temp override this test
    # installs — the point is where the shipped tool puts backups.
    check('  the default backup dir is outside the bundled assets',
          'assets' not in str(real_backup.relative_to(T.REPO)).lower(),
          str(real_backup.relative_to(T.REPO)))
    check('  the backup still has everything',
          len(json.loads(backup.read_text(encoding='utf-8'))['data'])
          == len(body))
    # Running it twice must not keep eating into the file.
    run(stem, '--apply')
    twice = json.loads(
        (tmp / f'{stem}.json').read_text(encoding='utf-8'))['data']
    check('  running it again changes nothing',
          len(twice) == len(after['data']),
          f"{len(after['data'])} then {len(twice)}")

    print('\nwithout word onsets it refuses outright')
    (tmp / f'{stem}.words.json').unlink()
    (tmp / f'{stem}.json').write_text(json.dumps({'data': body}),
                                      encoding='utf-8')
    out = run(stem, '--apply')
    check('nothing justifies a cut, so nothing is cut',
          'no word onsets' in out, out.strip()[:80])
    check('  the file is intact',
          len(json.loads((tmp / f'{stem}.json').read_text(
              encoding='utf-8'))['data']) == len(body))

    print('\nit never empties a file')
    (tmp / f'{stem}.words.json').write_text(
        json.dumps({'words': [{'text': 'x', 'start': 999.0, 'end': 999.4}]}),
        encoding='utf-8')
    out = run(stem, '--apply', '--force')
    left = json.loads((tmp / f'{stem}.json').read_text(
        encoding='utf-8'))['data']
    check('refuses to leave no notes at all', len(left) > 0,
          f'{len(left)} left')
finally:
    T.GT_DIR, T.BACKUP_DIR = real_gt, real_backup
    for f in sorted(tmp.rglob('*'), reverse=True):
        f.unlink() if f.is_file() else f.rmdir()
    tmp.rmdir()

check('the real ground truth was not touched',
      not list(real_gt.glob('Test Song*')),
      [p.name for p in real_gt.glob('Test Song*')])

print()
print('FAILURES:', fails if fails else 'none')
sys.exit(1 if fails else 0)
