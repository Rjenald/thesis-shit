"""Removes notes that sit outside the sung part of a ground truth.

A separated vocal stem is not silent during the intro: the instrumental
leaks into it, and a pitch tracker will happily report confident notes
for that leakage. Six of ten songs came back with some, up to 58 notes
(10%) on `Mundo - IV Of Spades` before a single word was sung. The app
creates one scored segment per row, so every one of those is a note the
singer is marked against for not hitting.

**The evidence is the word onsets**, not a guess. Forced alignment
(`<stem>.words.json`) says when each word was actually sung, from the
same audio but by a completely different model, so a note that ends
before the first word began cannot be a sung note. Without that file
this tool refuses — there is nothing to justify the cut.

What it will NOT do:

  - trim anything in the middle. A gap between words is a rest, a held
    note or a passage the lyrics sheet is missing, and all three are real.
  - trim without a margin. A word's opening consonant can start after the
    pitch of the note carrying it, so [MARGIN_S] of slack is kept.
  - run silently. Every note it would remove is printed with its pitch
    and duration, because a song that opens with humming has real notes
    before its first *word* and only a human can tell that apart.
  - write without being asked. `--apply` is required, and the original
    is copied to `backend/ground_truth_backups/` first — outside
    `assets/`, because pubspec bundles that folder wholesale and a
    backup left there would ship inside the APK.

    python backend/trim_bleed.py                 # report, change nothing
    python backend/trim_bleed.py --apply
    python backend/trim_bleed.py "Mundo - IV Of Spades" --apply
"""
from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
GT_DIR = REPO / "assets" / "ground_truth"

# Backups go OUTSIDE assets/. pubspec.yaml declares
# `assets/ground_truth/` wholesale, so a `.json.bak` left beside the
# ground truth is bundled into the APK — dead weight that also confuses
# anyone inspecting the build.
BACKUP_DIR = REPO / "backend" / "ground_truth_backups"

# Slack either side of the sung span. A note can legitimately start just
# before the word it carries, because the vocal onset of a consonant
# trails the pitch.
MARGIN_S = 0.35

# Below this, a leading region is not worth touching: a note or two at the
# very start is as likely to be a real pickup as bleed.
MIN_NOTES_TO_TRIM = 3


def load_rows(path: Path):
    data = json.loads(path.read_text(encoding="utf-8"))
    rows = data["data"] if isinstance(data, dict) else data
    rows = [r for r in rows if isinstance(r, dict)
            and "start" in r and "end" in r]
    rows.sort(key=lambda r: r["start"])
    return rows


def load_word_span(stem: str):
    """(first onset, last offset) from forced alignment, or None."""
    path = GT_DIR / f"{stem}.words.json"
    if not path.exists():
        return None
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        words = data["words"] if isinstance(data, dict) else data
        starts = [float(w["start"]) for w in words
                  if isinstance(w, dict) and "start" in w]
        ends = [float(w["end"]) for w in words
                if isinstance(w, dict) and "end" in w]
    except Exception:                                   # noqa: BLE001
        return None
    if not starts or not ends:
        return None
    return min(starts), max(ends)


def plan(rows, first_word, last_word):
    """What would be cut -> (kept, leading, trailing).

    Only the two ends. Anything between the first and last word stays,
    whatever the lyrics sheet does or does not cover.
    """
    lo = first_word - MARGIN_S
    hi = last_word + MARGIN_S
    leading = [r for r in rows if r["end"] <= lo]
    trailing = [r for r in rows if r["start"] >= hi]
    if len(leading) < MIN_NOTES_TO_TRIM:
        leading = []
    if len(trailing) < MIN_NOTES_TO_TRIM:
        trailing = []
    cut = {id(r) for r in leading + trailing}
    kept = [r for r in rows if id(r) not in cut]
    return kept, leading, trailing


def _note_to_midi(name):
    import re
    m = re.fullmatch(r"([A-G])([#b]?)(-?\d+)", (name or "").strip())
    if not m:
        return None
    base = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
    semi = base[m.group(1)]
    semi += 1 if m.group(2) == "#" else (-1 if m.group(2) == "b" else 0)
    return 12 * (int(m.group(3)) + 1) + semi


def looks_instrumental(region, sung):
    """Is this region the instrument leaking, or the same voice? -> (bool, why).

    Being outside the word span is not on its own proof of bleed. Three
    other things put real notes there, and all of them are singing:
    backing vocals the separation kept, humming before the first word, and
    — most likely of all — **a lyrics sheet missing the opening lines**,
    which pushes the "first word" later than the first word actually is.

    So the region is compared against the register the song is sung in:

      - **outside that register** is the strong signal. An instrument in
        the intro plays notes the singer never reaches, and an
        octave-doubled tracker error lands well above them.
      - **large leaps** point the same way. A voice moves mostly
        stepwise; an accompaniment jumps.

    When neither fires, the honest answer is that this looks like the same
    voice and should not be cut on this evidence.
    """
    rm = [m for m in (_note_to_midi(r.get("note")) for r in region)
          if m is not None]
    sm = [m for m in (_note_to_midi(r.get("note")) for r in sung)
          if m is not None]
    if len(rm) < 3 or len(sm) < 10:
        return False, "too few notes to judge"

    lo, hi = min(sm), max(sm)
    outside = sum(1 for m in rm if m < lo or m > hi)
    leaps = [abs(a - b) for a, b in zip(rm, rm[1:])]
    big = sum(1 for j in leaps if j >= 7)
    big_share = big / len(leaps) if leaps else 0.0

    reasons = []
    if outside:
        reasons.append(f"{outside}/{len(rm)} note(s) outside the sung "
                       "register")
    if big_share > 0.35:
        reasons.append(f"{100 * big_share:.0f}% of steps are a fifth or "
                       "more")
    if reasons:
        return True, "; ".join(reasons)
    return False, ("they sit inside the sung register and move stepwise, "
                   "so this looks like the same voice")


def describe(label, notes, sung, leading=True):
    """Prints the region and whether the evidence supports cutting it."""
    if not notes:
        return False
    span = f'{notes[0]["start"]:.2f}-{notes[-1]["end"]:.2f}s'
    total = sum(r["end"] - r["start"] for r in notes)
    pitches = sorted({r.get("note", "?") for r in notes})
    print(f"    {label}: {len(notes)} note(s), {span}, "
          f"{total:.1f}s of pitch")
    print(f"      pitches: {', '.join(pitches[:14])}"
          + (" ..." if len(pitches) > 14 else ""))

    instrumental, why = looks_instrumental(notes, sung)
    print(f"      {'INSTRUMENT' if instrumental else 'VOICE?'}: {why}")
    if not instrumental:
        where = "opening" if leading else "closing"
        print(f"      Most likely the lyrics sheet is missing the {where} "
              "lines, which")
        print(f"      moves the '{'first' if leading else 'last'} word' "
              f"{'later' if leading else 'earlier'} than it really is. "
              "Check the")
        print("      sheet before cutting; --force overrides.")
    held = [r for r in notes if r["end"] - r["start"] >= 0.6]
    if held and not instrumental:
        print(f"      {len(held)} note(s) held 0.6s or longer, which is "
              "what humming looks like.")
    return instrumental


def main() -> int:
    ap = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("stem", nargs="?",
                    help='"<Title> - <Artist>"; omit for every song')
    ap.add_argument("--apply", action="store_true",
                    help="write the trimmed files (keeps a .bak)")
    ap.add_argument("--force", action="store_true",
                    help="cut a region even when it looks like the same "
                         "voice")
    ap.add_argument("--margin", type=float, default=MARGIN_S,
                    help=f"slack either side, seconds (default {MARGIN_S})")
    args = ap.parse_args()

    globals()["MARGIN_S"] = args.margin

    if args.stem:
        paths = [GT_DIR / f"{args.stem}.json"]
        if not paths[0].exists():
            print(f"not found: {paths[0]}")
            return 1
    else:
        paths = sorted(p for p in GT_DIR.glob("*.json")
                       if not p.stem.endswith(".words"))
    if not paths:
        print("No ground truth in assets/ground_truth/.")
        return 0

    touched = skipped = 0
    for path in paths:
        stem = path.stem
        rows = load_rows(path)
        if not rows:
            continue
        span = load_word_span(stem)
        print(f"\n{stem}  ({len(rows)} notes)")
        if span is None:
            print("    no word onsets, so nothing justifies a cut — "
                  "skipped.")
            print("    Re-run the extractor with LABEL_MODE = 'align' to "
                  "produce them.")
            skipped += 1
            continue

        first_word, last_word = span
        kept, leading, trailing = plan(rows, first_word, last_word)
        if not leading and not trailing:
            print(f"    nothing outside {first_word:.2f}-{last_word:.2f}s "
                  "(the sung span) — already clean.")
            continue

        print(f"    sung span {first_word:.2f}-{last_word:.2f}s "
              f"(+/-{MARGIN_S}s margin)")
        lead_ok = describe("before the first word", leading, kept,
                           leading=True)
        trail_ok = describe("after the last word", trailing, kept,
                            leading=False)

        # Only cut what the evidence supports. A region that looks like
        # the same voice is kept unless --force says otherwise, because
        # deleting real singing is worse than leaving bleed in: the first
        # costs the singer notes they did sing, the second only adds notes
        # they did not.
        if not args.force:
            if leading and not lead_ok:
                leading = []
            if trailing and not trail_ok:
                trailing = []
            kept, leading, trailing = (
                [r for r in rows
                 if id(r) not in {id(x) for x in leading + trailing}],
                leading, trailing)

        removed = len(leading) + len(trailing)
        if not removed:
            print("    -> nothing cut: the evidence does not support it "
                  "(use --force to override).")
            continue
        print(f"    -> {len(rows)} notes becomes {len(kept)} "
              f"({removed} removed, {100 * removed / len(rows):.0f}%)")

        if not args.apply:
            continue
        if not kept:
            print("    refusing: that would leave no notes at all.")
            continue
        BACKUP_DIR.mkdir(parents=True, exist_ok=True)
        backup = BACKUP_DIR / f"{stem}.json"
        if not backup.exists():
            shutil.copy2(path, backup)
        path.write_text(
            json.dumps({"data": kept}, ensure_ascii=False, indent=1) + "\n",
            encoding="utf-8")
        # relative_to throws for a path outside the repo, and crashing
        # after a successful write would be the worst moment for it.
        try:
            shown = backup.relative_to(REPO)
        except ValueError:
            shown = backup
        print(f"    written; original kept as {shown}")
        touched += 1

    print()
    if args.apply:
        print(f"{touched} file(s) trimmed." if touched
              else "Nothing needed trimming.")
        if touched:
            print("Now re-run:  python backend/check_ground_truth.py")
    else:
        print("Nothing was written. Read the notes above, then re-run "
              "with --apply.")
    if skipped:
        print(f"{skipped} song(s) skipped for want of word onsets.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
