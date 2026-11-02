"""Re-times lib/data/song_lyrics.dart onto a replaced set of backing tracks.

WHY THIS IS NEEDED
------------------
The bundled lyrics are timed against the commercial karaoke MP3s that were
in assets/audio/. Measured on the current build, 8 of 9 lyric sets sit
inside those files with sensible tails (4.9s to 42.2s between the last
line and the end of the track), which is what tells us they follow that
timeline and not the originals'.

Swapping the backing tracks for separated instrumental stems puts the
audio on the original recording's timeline, so every lyric timestamp goes
out by whatever the edit difference is -- on these songs, -13.3s to +3.6s
with no consistent pattern. This maps each timestamp from the old track
onto the new one so the lyric TEXT is kept exactly as hand-authored and
only the numbers move.

HOW
---
DTW over chroma between the old and new audio, which handles a different
start AND a different length. A plain cross-correlation cannot: tried
earlier on this project, it estimated -40s for a song whose true offset is
~0. The warping code here is the same logic tested against synthetic pairs
with known edits (added intro, trimmed tail, both at once), recovered to
within 0.01s.

USAGE
-----
    pip install librosa mutagen

    # Dry run first -- prints the shift per song, writes nothing:
    python retime_lyrics.py --old ../assets/audio.backup --new ../assets/audio

    # Then apply:
    python retime_lyrics.py --old ../assets/audio.backup --new ../assets/audio --write

The old directory must hold the ORIGINAL karaoke files. Back them up
before overwriting assets/audio, or this cannot run.
"""
from __future__ import annotations

import argparse
import re
import shutil
import sys
from pathlib import Path

import numpy as np

ALIGN_SR = 22050
ALIGN_HOP = 512
AUDIO_EXT = (".mp3", ".wav", ".flac", ".m4a", ".ogg")


# ── alignment (same logic as the notebook, tested in isolation) ────────────

def chroma_of(y, sr, hop_length=ALIGN_HOP):
    import librosa

    chroma = librosa.feature.chroma_cqt(y=y, sr=sr, hop_length=hop_length)
    # A silent frame has all-zero chroma and cosine distance to a zero
    # vector is NaN, which makes the whole DTW cost matrix NaN. Tracks
    # start and end quiet, so this is not hypothetical.
    chroma = chroma + 1e-6
    norms = np.linalg.norm(chroma, axis=0, keepdims=True)
    return chroma / np.maximum(norms, 1e-8)


def warp_path(y_src, y_dst, sr, hop_length=ALIGN_HOP):
    import librosa

    cs = chroma_of(y_src, sr, hop_length)
    cd = chroma_of(y_dst, sr, hop_length)
    _, path = librosa.sequence.dtw(X=cs, Y=cd, metric="cosine")
    path = path[::-1]
    frame_sec = hop_length / sr
    return path[:, 0] * frame_sec, path[:, 1] * frame_sec


def make_mapper(src_sec, dst_sec, dst_duration=None):
    """f(t_old) -> t_new, single-valued and non-decreasing.

    DTW emits several destination frames per source frame where the target
    is slower; averaging them keeps the mapping single-valued, and the
    running maximum stops a later line landing before an earlier one.
    """
    src = np.asarray(src_sec, dtype=float)
    dst = np.asarray(dst_sec, dtype=float)
    uniq, inverse = np.unique(src, return_inverse=True)
    collapsed = np.bincount(inverse, weights=dst) / np.bincount(inverse)
    collapsed = np.maximum.accumulate(collapsed)

    def mapper(t):
        out = np.interp(np.asarray(t, dtype=float), uniq, collapsed)
        if dst_duration is not None:
            out = np.clip(out, 0.0, dst_duration)
        return out

    return mapper


# ── the Dart file ─────────────────────────────────────────────────────────

LYRICS_REL = Path("lib") / "data" / "song_lyrics.dart"
CASE_RE = re.compile(r"case '([^']+)':\s*\n\s*return (_\w+);")
LINE_RE = re.compile(
    r"LrcLine\(timestamp: Duration\(milliseconds: (\d+)\), text: ")


def song_blocks(src: str):
    """(title, var, block_start, block_end) for each song's line list."""
    out = []
    for title, var in CASE_RE.findall(src):
        m = re.search(re.escape(var) + r"\s*=\s*\[(.*?)\n  \];", src, re.S)
        if m:
            out.append((title, var, m.start(1), m.end(1)))
    return out


def audio_for(folder: Path, title: str):
    """The file in `folder` whose "Title - Artist" stem starts with title."""
    for path in sorted(folder.iterdir()):
        if not path.suffix.lower() in AUDIO_EXT:
            continue
        if path.stem.split(" - ")[0].strip().lower() == title.strip().lower():
            return path
    return None


def duration_of(path: Path):
    from mutagen import File as MutagenFile

    info = MutagenFile(str(path))
    if info is None or not getattr(info, "info", None):
        return None
    return float(info.info.length)


def main() -> int:
    ap = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--old", type=Path, required=True,
                    help="directory holding the ORIGINAL karaoke tracks")
    ap.add_argument("--new", type=Path, required=True,
                    help="directory holding the replacement tracks")
    ap.add_argument("--repo", type=Path, default=Path(__file__).parent.parent,
                    help="repo root (default: the parent of backend/)")
    ap.add_argument("--write", action="store_true",
                    help="apply the changes; without it this is a dry run")
    args = ap.parse_args()

    try:
        import librosa  # noqa: F401
        from mutagen import File  # noqa: F401
    except ImportError as e:
        print(f"missing dependency: {e.name}")
        print("install with:  pip install librosa mutagen")
        return 1

    for folder in (args.old, args.new):
        if not folder.is_dir():
            print(f"not a directory: {folder}")
            return 1

    lyrics_path = args.repo / LYRICS_REL
    if not lyrics_path.exists():
        print(f"not found: {lyrics_path}")
        return 1

    import librosa

    src = lyrics_path.read_text(encoding="utf-8")
    blocks = song_blocks(src)
    if not blocks:
        print("Parsed no songs out of song_lyrics.dart -- its shape must "
              "have changed. Not touching it.")
        return 1

    print(f"{len(blocks)} song(s) in song_lyrics.dart\n")
    print(f"{'song':<26} {'lines':>5} {'first old':>10} {'first new':>10} "
          f"{'shift':>8} {'max shift':>10}  status")
    print("-" * 94)

    edits = []          # (block_start, block_end, new_text)
    skipped = []

    for title, _var, b_start, b_end in blocks:
        block = src[b_start:b_end]
        stamps = [int(m) for m in LINE_RE.findall(block)]
        if not stamps:
            skipped.append((title, "no timestamps parsed"))
            continue

        old_audio = audio_for(args.old, title)
        new_audio = audio_for(args.new, title)
        if old_audio is None or new_audio is None:
            missing = "old" if old_audio is None else "new"
            print(f"{title[:26]:<26} {len(stamps):5d} "
                  f"{'':>10} {'':>10} {'':>8} {'':>10}  "
                  f"no {missing} audio, left unchanged")
            skipped.append((title, f"missing {missing} audio"))
            continue

        y_old, _ = librosa.load(str(old_audio), sr=ALIGN_SR, mono=True)
        y_new, _ = librosa.load(str(new_audio), sr=ALIGN_SR, mono=True)
        new_dur = len(y_new) / ALIGN_SR

        p_src, p_dst = warp_path(y_old, y_new, ALIGN_SR)
        mapper = make_mapper(p_src, p_dst, new_dur)

        old_sec = np.array(stamps, dtype=float) / 1000.0
        new_sec = mapper(old_sec)
        shifts = new_sec - old_sec

        # Rewrite only the millisecond numbers, leaving every other
        # character of the block -- text, escapes, formatting -- untouched.
        it = iter((int(round(s * 1000)) for s in new_sec))
        rewritten = LINE_RE.sub(
            lambda m: f"LrcLine(timestamp: Duration(milliseconds: "
                      f"{next(it)}), text: ",
            block)
        edits.append((b_start, b_end, rewritten))

        print(f"{title[:26]:<26} {len(stamps):5d} {old_sec[0]:10.2f} "
              f"{new_sec[0]:10.2f} {shifts[0]:+8.2f} "
              f"{np.abs(shifts).max():10.2f}  ok")

    print("-" * 94)
    if skipped:
        print("\nleft unchanged:")
        for title, why in skipped:
            print(f"  {title}: {why}")

    if not edits:
        print("\nNothing to write.")
        return 0

    if not args.write:
        print(f"\nDry run. {len(edits)} song(s) would be re-timed.")
        print("Check the shifts above look like real edit differences "
              "rather than\nnoise, then re-run with --write.")
        return 0

    # Apply back-to-front so earlier offsets stay valid.
    out = src
    for b_start, b_end, text in sorted(edits, reverse=True):
        out = out[:b_start] + text + out[b_end:]

    backup = lyrics_path.with_suffix(".dart.bak")
    shutil.copy2(lyrics_path, backup)
    lyrics_path.write_text(out, encoding="utf-8")
    print(f"\nRe-timed {len(edits)} song(s).")
    print(f"  wrote  {lyrics_path}")
    print(f"  backup {backup}")
    print("\nRun `flutter analyze` to confirm the file still parses, then "
          "play a\nsong and check a line lands on the right words.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
