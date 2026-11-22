"""Times each lyric line from the vocal itself, not from the text.

The app's bundled lyric timings were authored against other recordings.
Against the backing tracks it now ships they are simply wrong, and the
failure is quiet: the words still scroll, so a singer follows the screen,
sings at the wrong moment and scores badly for reasons that have nothing
to do with their pitch.

The fix has to come from the recording. The obvious shortcuts do not
work and are rejected on purpose:

  - **characters or words per line** says nothing about how long a line
    is held. "Ohhh" is one word and four seconds.
  - **a constant seconds-per-line** assumes an even delivery no singer
    has.
  - **tempo** gives bar positions, not vocal entries, and a singer enters
    late or early against the beat constantly — that is most of what
    phrasing is.

What this uses instead is **word onsets measured from the vocal stem** by
forced alignment — `<stem>.words.json`, produced by
`ground_truth_from_stems.ipynb` with `LABEL_MODE = 'align'`. A line's
start is then its first word's onset. There is nothing to infer: the
recording says when each word was sung, and these are those numbers.

Note onsets alone are NOT enough, and `--from-notes` exists only to
demonstrate why rather than to be used. Ground truth records *when* notes
happened but not *which words* they are, so splitting 499 notes across 62
lines is underdetermined. On `Nasa Iyo Na Ang Lahat` the best alignment
available from notes plus syllable counts gave a line sung 17 times
durations spanning **8.41s**, and handed a 9-syllable line a single
0.12s note. The checks in `report()` are there to catch exactly that; a
plausible-looking output with no way to tell whether it is right is worse
than no output.

    # the real thing, once the notebook has produced word onsets
    python backend/sync_lyrics.py "Nasa Iyo Na Ang Lahat - Daniel Padilla" --write

    # the diagnostic, which prints why notes alone cannot do it
    python backend/sync_lyrics.py "<stem>" --from-notes
"""
from __future__ import annotations

import argparse
import json
import math
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lyric_text import clean_lyrics, load_lyrics, lyric_words  # noqa: E402

REPO = Path(__file__).resolve().parent.parent
GT_DIR = REPO / 'assets' / 'ground_truth'
DART = REPO / 'lib' / 'data' / 'song_lyrics.dart'

# A gap at or beyond this counts as a full breath: a boundary landing here
# costs nothing. Shorter gaps earn partial credit, scaled linearly.
FULL_BREATH_S = 0.30

# How much a boundary in the wrong place costs relative to a line being
# the wrong length. Breath evidence comes from the recording and syllable
# counts come from the text, so the recording is trusted considerably
# more.
BREATH_WEIGHT = 6.0


def load_notes(stem: str):
    path = GT_DIR / f'{stem}.json'
    if not path.exists():
        return None
    data = json.loads(path.read_text(encoding='utf-8'))
    rows = data['data'] if isinstance(data, dict) else data
    rows = [r for r in rows if 'start' in r and 'end' in r]
    rows.sort(key=lambda r: r['start'])
    return rows


def load_word_onsets(stem: str):
    """Word spans measured from the vocal, or None if none were exported.

    Written by the extractor's alignment pass as
    `assets/ground_truth/<stem>.words.json`: a list of
    {text, start, end, score}, in sung order.
    """
    path = GT_DIR / f'{stem}.words.json'
    if not path.exists():
        return None
    data = json.loads(path.read_text(encoding='utf-8'))
    words = data['words'] if isinstance(data, dict) else data
    out = [w for w in words
           if isinstance(w, dict) and 'start' in w and 'end' in w
           and str(w.get('text', '')).strip()]
    out.sort(key=lambda w: w['start'])
    return out or None


def time_lines_from_words(text: str, words):
    """Line start times straight from word onsets -> [(start, line, n)].

    The lyrics sheet and the aligned word list describe the same words in
    the same order — the aligner was given this sheet — so walking both
    in step needs no matching at all. It is checked rather than assumed:
    a mismatch in count means the sheet was edited after alignment, and
    that is reported instead of being silently absorbed.
    """
    lines = clean_lyrics(text)
    per_line = [[w.text for w in lyric_words(ln)] for ln in lines]
    expected = sum(len(w) for w in per_line)
    if expected != len(words):
        raise ValueError(
            f'the sheet has {expected} words but {len(words)} were aligned. '
            'The sheet changed after alignment — re-run the extractor, or '
            'put the sheet back the way it was.')

    out, k = [], 0
    wordless = []
    for line, line_words in zip(lines, per_line):
        if not line_words:
            # A line with no letters at all -- a bare ♪, or (oh) once the
            # parentheses are stripped. It contributes nothing to the
            # alignment, which is what makes it useful: it can be added to
            # a sheet AFTER aligning without changing the word count, so
            # a wordless passage can be marked without re-running Colab.
            # Its time comes from the gap it sits in, resolved below.
            wordless.append((len(out), line))
            continue
        start = words[k]['start']
        end = words[k + len(line_words) - 1]['end']
        out.append((start, end, line, len(line_words)))
        k += len(line_words)

    # Place each wordless line in the gap between the lines it sits
    # between, a quarter of the way in so it does not land on the
    # previous line's last syllable.
    for offset, (pos, line) in enumerate(wordless):
        i = pos + offset
        prev_end = out[i - 1][1] if i > 0 else 0.0
        next_start = out[i][0] if i < len(out) else prev_end + 2.0
        if next_start <= prev_end:
            next_start = prev_end + 2.0
        t = prev_end + 0.25 * (next_start - prev_end)
        out.insert(i, (t, next_start, line, 0))
    return out


def syllables_per_line(text: str):
    """[(line text, syllable count)], skipping markers and blank lines."""
    out = []
    for line in clean_lyrics(text):
        n = sum(len(w.syllables) for w in lyric_words(line))
        if n:
            out.append((line, n))
    return out


def breath_credit(rows, i):
    """How much of a full breath precedes note `i`, from 0 to 1.

    Note 0 is a free boundary: the song starting is the clearest phrase
    boundary there is.
    """
    if i <= 0 or i >= len(rows):
        # Index len(rows) is the boundary past the final note, i.e. the
        # end of the song — as free a boundary as the start.
        return 1.0
    gap = rows[i]['start'] - rows[i - 1]['end']
    return max(0.0, min(1.0, gap / FULL_BREATH_S))


def align(rows, lines):
    """Assign a contiguous run of notes to each line -> [(start, end) idx].

    A dynamic program, because a greedy pass cannot undo an early
    mistake: one line taking two notes too many pushes every later line
    off, and in a song whose chorus repeats six times that error is
    invisible until the end.
    """
    n_notes, n_lines = len(rows), len(lines)
    if n_notes < n_lines:
        raise ValueError(f'{n_notes} notes cannot cover {n_lines} lines')

    total_syll = sum(s for _, s in lines)
    # Expected notes per syllable for this song, measured from this song:
    # a melisma-heavy performance has more, a syllabic one fewer.
    ratio = n_notes / total_syll
    expected = [s * ratio for _, s in lines]

    credit = [breath_credit(rows, i) for i in range(n_notes + 1)]
    credit.append(1.0)                     # the end of the song

    INF = float('inf')
    # cost[i][j] = best cost for the first i lines using the first j notes
    cost = [[INF] * (n_notes + 1) for _ in range(n_lines + 1)]
    back = [[-1] * (n_notes + 1) for _ in range(n_lines + 1)]
    cost[0][0] = 0.0

    for i in range(1, n_lines + 1):
        want = expected[i - 1]
        # A line gets at least one note and at most enough to leave one
        # for every line after it.
        max_take = n_notes - (n_lines - i)
        lo_j = i
        for j in range(lo_j, max_take + 1):
            best, best_k = INF, -1
            # Searching every split point is O(notes^2) per line and fine
            # at this size, but the window keeps it quick and also stops
            # one line swallowing a whole verse.
            k_lo = max(i - 1, j - int(math.ceil(want * 3)) - 4)
            for k in range(k_lo, j):
                prev = cost[i - 1][k]
                if prev == INF:
                    continue
                take = j - k
                length_cost = abs(take - want) / max(want, 1.0)
                boundary_cost = (1.0 - credit[k]) + (1.0 - credit[j])
                c = prev + length_cost + BREATH_WEIGHT * boundary_cost
                if c < best:
                    best, best_k = c, k
            cost[i][j] = best
            back[i][j] = best_k

    if cost[n_lines][n_notes] == INF:
        raise ValueError('no alignment found')

    spans, j = [], n_notes
    for i in range(n_lines, 0, -1):
        k = back[i][j]
        spans.append((k, j))
        j = k
    spans.reverse()
    return spans


def report(stem, rows, lines, spans):
    """Prints the alignment and the checks that say whether to trust it."""
    print(f'\n{stem}')
    print(f'  {len(rows)} notes, {len(lines)} lines, '
          f'{sum(s for _, s in lines)} syllables')

    starts = [rows[a]['start'] for a, _ in spans]
    print(f"\n  {'#':>3} {'start':>8} {'end':>8} {'notes':>6} {'syl':>4}  line")
    print('  ' + '-' * 74)
    for i, ((a, b), (text, syl)) in enumerate(zip(spans, lines)):
        print(f'  {i + 1:3d} {rows[a]["start"]:8.2f} '
              f'{rows[b - 1]["end"]:8.2f} {b - a:6d} {syl:4d}  {text[:40]}')

    # The check that matters: this chorus repeats, so the same line sung
    # again should take about the same time. Erratic durations for
    # identical text mean the split is wrong, and no amount of plausible
    # output would reveal that on its own.
    by_text = {}
    for (a, b), (text, _) in zip(spans, lines):
        key = re.sub(r'[^a-z ]', '', text.lower()).strip()
        by_text.setdefault(key, []).append(rows[b - 1]['end'] - rows[a]['start'])

    repeats = {k: v for k, v in by_text.items() if len(v) >= 3}
    print(f'\n  repeated lines ({len(repeats)} with 3+ occurrences):')
    worst = 0.0
    for key, durs in sorted(repeats.items(), key=lambda kv: -len(kv[1]))[:8]:
        spread = max(durs) - min(durs)
        worst = max(worst, spread)
        print(f'    {len(durs)}x  {sum(durs) / len(durs):5.2f}s avg, '
              f'spread {spread:4.2f}s   {key[:38]}')
    if repeats:
        print(f'  worst spread across repeats: {worst:.2f}s')
        print('    (a line sung six times should take about the same time '
              'each\n     time; a large spread means the split is wrong)')

    gaps = [rows[a]['start'] - rows[a - 1]['end'] for a, _ in spans if a > 0]
    on_breath = sum(1 for g in gaps if g >= 0.15)
    print(f'\n  {on_breath} of {len(gaps)} line boundaries fall on a gap of '
          f'0.15s or more')
    print(f'  every timestamp is a note onset from the recording; '
          f'none is interpolated')
    return starts


def gap_markers(timed, rows, min_gap_s=6.0):
    """Marker lines for stretches that are sung but have no lyrics.

    Forced alignment walks the sheet in order and lets CTC blanks absorb
    anything the sheet does not account for, so a section the sheet is
    missing comes back as a long run of notes with no words. On Araw-Araw
    that is 23.5s and 13.2s — real singing the sheet simply does not
    contain.

    Without a marker the app keeps the previous line highlighted for the
    whole stretch, which looks like the lyrics have frozen. A marker says
    what is true: something is being sung that nobody transcribed.

    Returns [(time, text)] to merge into the line list.
    """
    out = []
    for (a_start, a_end, _t, _n), (b_start, *_rest) in zip(timed, timed[1:]):
        if b_start - a_end < min_gap_s:
            continue
        inside = [r for r in rows if a_end < r['start'] < b_start]
        if len(inside) < 4:
            continue            # an instrumental break, not missing words
        out.append((inside[0]['start'], '♪'))
    return out


def to_dart(stem, starts, lines, markers=(), intro=True):
    rows_out = [(t, text) for t, (text, _) in zip(starts, lines)]
    rows_out += list(markers)
    rows_out.sort(key=lambda r: r[0])
    body = []
    if intro and (not rows_out or rows_out[0][0] > 0.5):
        body.append("    LrcLine(timestamp: Duration(milliseconds: 0), "
                    "text: '\\u266a Intro \\u266a'),")
    for t, text in rows_out:
        esc = text.replace('\\', '\\\\').replace("'", "\\'")
        body.append(f'    LrcLine(timestamp: Duration(milliseconds: '
                    f'{int(round(t * 1000))}), text: \'{esc}\'),')
    return '\n'.join(body)


def write_dart(var_name: str, dart_body: str, stem: str):
    """Replaces one list in song_lyrics.dart, leaving the rest alone."""
    src = DART.read_text(encoding='utf-8')
    needle = f'static final List<LrcLine> {var_name} = ['
    if needle not in src:
        raise SystemExit(f'{var_name} not found in {DART}')
    start = src.index(needle) + len(needle)
    # The list may be an empty stub (`= [];`) or already populated across
    # many lines (`= [\n ... \n  ];`). Scanning for the matching bracket
    # handles both; looking for '  ];' only handled the second, and threw
    # ValueError on every song that had not been written yet.
    depth, end = 1, None
    for k in range(start, len(src)):
        if src[k] == '[':
            depth += 1
        elif src[k] == ']':
            depth -= 1
            if depth == 0:
                end = k
                break
    if end is None:
        raise SystemExit(f'{var_name} in {DART} has no closing bracket')
    note = (f'\n    // Timed from the vocal stem via\n'
            f'    // `python backend/sync_lyrics.py "{stem}"`. Every\n'
            f'    // timestamp below is the measured onset of that line\'s\n'
            f'    // first word, from forced alignment against the isolated\n'
            f'    // vocal in assets/ground_truth/{stem}.words.json — not a\n'
            f'    // guess from word count, line length or tempo.\n'
            f'    //\n'
            f'    // A ♪ line marks a stretch that is sung but missing\n'
            f'    // from backend/lyrics/{stem}.txt; add the real words\n'
            f'    // there and re-run to replace it.\n'
            f'    //\n'
            f'    // Regenerate if that ground truth or the backing track\n'
            f'    // ever changes; hand edits here will be overwritten.\n')
    # `end` indexes the closing bracket itself, so the two-space indent
    # that belonged to "  ];" has to be re-emitted here.
    DART.write_text(src[:start] + note + dart_body + '\n  ' + src[end:],
                    encoding='utf-8')
    print(f'\nwrote {var_name} into {DART.relative_to(REPO)}')


def var_name_for(title: str):
    """The Dart field name song_lyrics.dart uses for a song, or None."""
    src = DART.read_text(encoding='utf-8')
    m = re.search(rf"case '{re.escape(title.lower())}':\s*\n\s*return (\w+);",
                  src)
    return m.group(1) if m else None


def main() -> int:
    ap = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('stem', nargs='?',
                    help='"<Title> - <Artist>", matching the asset names')
    ap.add_argument('--all', action='store_true',
                    help='every song that has both lyrics and ground truth')
    ap.add_argument('--write', action='store_true',
                    help='write the result into lib/data/song_lyrics.dart')
    ap.add_argument('--from-notes', action='store_true',
                    help='diagnostic only: try it from note onsets alone '
                         'and print why that is not good enough')
    args = ap.parse_args()

    if args.all:
        stems = sorted(p.stem for p in GT_DIR.glob('*.json'))
    elif args.stem:
        stems = [args.stem]
    else:
        ap.error('give a stem or --all')

    done = blocked = 0
    for stem in stems:
        if stem.endswith('.words'):
            continue
        text = load_lyrics(stem)
        if not text:
            print(f'{stem}: no sheet in backend/lyrics/')
            continue

        words = load_word_onsets(stem)
        if words and not args.from_notes:
            timed = time_lines_from_words(text, words)
            print(f'\n{stem}')
            print(f'  {len(words)} word onsets measured from the vocal, '
                  f'{len(timed)} lines')
            print(f"\n  {'#':>3} {'start':>8} {'end':>8} {'words':>6}  line")
            print('  ' + '-' * 70)
            for i, (a, b, line, n) in enumerate(timed):
                print(f'  {i + 1:3d} {a:8.2f} {b:8.2f} {n:6d}  {line[:40]}')
            starts = [a for a, _, _, _ in timed]
            lines = [(line, n) for _, _, line, n in timed]
            print('\n  every timestamp is a word onset from the recording')

            notes = load_notes(stem) or []
            markers = gap_markers(timed, notes)
            if markers:
                print(f'\n  {len(markers)} stretch(es) are sung but have no '
                      'lyrics in the sheet:')
                ends = {a: b for a, b, _, _ in timed}
                for mt in markers:
                    nxt = min((a for a, _, _, _ in timed if a > mt[0]),
                              default=mt[0])
                    print(f'    {mt[0]:7.2f}s .. {nxt:7.2f}s  '
                          f'({nxt - mt[0]:.1f}s)')
                print('    The alignment is fine — CTC blanks absorbed them.')
                print(f'    backend/lyrics/{stem}.txt is missing those lines.')
                print('    A ♪ marker goes in meanwhile, so the screen '
                      'does not freeze on\n    the previous line for the '
                      'whole stretch. Two ways to fix it:')
                print('      - the passage HAS words: add them to the sheet '
                      'in sung order,\n        then re-run the extractor '
                      "with LABEL_MODE = 'align' (the word\n        count "
                      'changes, so the alignment has to be redone)')
                print('      - the passage is humming or "oh"s: add a bare '
                      '♪ line to the\n        sheet at that point. It '
                      'has no letters, so it adds no words and\n        the '
                      'existing alignment stays valid — just re-run this.')
            if args.write:
                title = stem.rsplit(' - ', 1)[0]
                var = var_name_for(title)
                if var is None:
                    print(f'  no case for "{title.lower()}" in '
                          'song_lyrics.dart; not written')
                    continue
                write_dart(var, to_dart(stem, starts, lines, markers), stem)
            done += 1
            continue

        # No word onsets. Say so plainly rather than falling back to
        # something that cannot be checked.
        rows = load_notes(stem)
        if not rows:
            print(f'{stem}: no ground truth in assets/ground_truth/')
            continue
        if not args.from_notes:
            blocked += 1
            print(f'\n{stem}')
            print(f'  {len(rows)} note onsets, but no {stem}.words.json.')
            print('  Note onsets record WHEN notes happened, not WHICH words')
            print('  they are, so splitting them across lines is')
            print('  underdetermined — see --from-notes for the evidence.')
            print('  Produce word onsets by re-running')
            print('  backend/ground_truth_from_stems.ipynb with')
            print("  LABEL_MODE = 'align' (Cells 5 and 6 included).")
            continue

        lines = syllables_per_line(text)
        if not lines:
            print(f'{stem}: the sheet has no usable lines')
            continue
        print('\n--from-notes: a DIAGNOSTIC. Read the checks at the end '
              'before believing any of it.')
        report(stem, rows, lines, align(rows, lines))
        print('\n  Not written, and --write will not write this.')

    if blocked:
        print(f'\n{blocked} song(s) need word onsets before their lyrics '
              'can be timed.')
    if args.write and done == 0 and not blocked:
        print('\nNothing to write.')
    elif not args.write and done:
        print('\nNothing was written. Re-run with --write to apply.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
