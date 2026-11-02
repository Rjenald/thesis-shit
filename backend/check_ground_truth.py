"""Checks the ground truth actually shipped in assets/ against its audio.

Run this after dropping new files into assets/ground_truth/. Every check
here corresponds to a defect that was measured in a real run, not a
hypothetical one:

  - ground truth describing audio past the end of the file
      the first generated set overshot by up to 46.5s, because it was
      extracted from the original recordings while the app played
      differently-edited karaoke tracks
  - arithmetic note boundaries
      100% of multi-row words in the next set had exactly equal sub-
      durations: a Whisper word span divided by its vowel count, so every
      within-word boundary was invented
  - over-segmentation
      ~50% of rows sat in same-pitch runs of up to 7, i.e. held notes
      chopped into pieces, each counting separately toward the score
  - octave errors
      a 36-semitone range and notes outside any singable register

It also reports catalog drift, since a song listed in
SongCatalogService.bundled with no files on disk dead-ends in the app,
and scores the word labels against backend/lyrics/ when a sheet is there.

    python backend/check_ground_truth.py
    python backend/check_ground_truth.py --strict   # exit 1 on any problem
    python backend/check_ground_truth.py --errors 20   # show what differs
"""
from __future__ import annotations

import argparse
import collections
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lyric_text import load_lyrics, lyric_words        # noqa: E402
from trim_bleed import looks_instrumental              # noqa: E402

NOTE_BASE = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
NOTE_RE = re.compile(r"([A-G])([#b]?)(-?\d+)")

# A voice sits well inside this; octave errors land outside it.
SINGABLE_LO, SINGABLE_HI = 40, 84


def note_to_midi(name: str):
    m = NOTE_RE.fullmatch((name or "").strip())
    if not m:
        return None
    semi = NOTE_BASE[m.group(1)]
    semi += 1 if m.group(2) == "#" else (-1 if m.group(2) == "b" else 0)
    return 12 * (int(m.group(3)) + 1) + semi


def duration_of(path: Path):
    try:
        from mutagen import File as MutagenFile
    except ImportError:
        return None
    info = MutagenFile(str(path))
    if info is None or not getattr(info, "info", None):
        return None
    return float(info.info.length)


def load_rows(path: Path):
    d = json.loads(path.read_text(encoding="utf-8"))
    rows = d["data"] if isinstance(d, dict) and "data" in d else d
    if not isinstance(rows, list):
        raise ValueError('expected a top-level "data" list')
    out = []
    for r in rows:
        if not isinstance(r, dict):
            continue
        if "start" not in r or "end" not in r:
            continue
        out.append(r)
    return sorted(out, key=lambda r: r["start"])


def _norm_label(text: str) -> str:
    """A label or lyric word, reduced to the letters both have in common."""
    return re.sub(r"[^a-z]", "", (text or "").lower())


def _levenshtein_ops(ref: list[str], hyp: list[str]):
    """[(op, ref_word, hyp_word)] turning `ref` into `hyp`."""
    n, m = len(ref), len(hyp)
    d = [[0] * (m + 1) for _ in range(n + 1)]
    for i in range(n + 1):
        d[i][0] = i
    for j in range(m + 1):
        d[0][j] = j
    for i in range(1, n + 1):
        for j in range(1, m + 1):
            d[i][j] = min(d[i - 1][j] + 1, d[i][j - 1] + 1,
                          d[i - 1][j - 1] + (ref[i - 1] != hyp[j - 1]))
    i, j, ops = n, m, []
    while i > 0 or j > 0:
        if i > 0 and j > 0 and \
                d[i][j] == d[i - 1][j - 1] + (ref[i - 1] != hyp[j - 1]):
            ops.append(('ok' if ref[i - 1] == hyp[j - 1] else 'sub',
                        ref[i - 1], hyp[j - 1]))
            i, j = i - 1, j - 1
        elif i > 0 and d[i][j] == d[i - 1][j] + 1:
            ops.append(('del', ref[i - 1], ''))
            i -= 1
        else:
            ops.append(('ins', '', hyp[j - 1]))
            j -= 1
    ops.reverse()
    return ops


def score_labels(rows: list[dict], lyrics: str):
    """How close a file's word labels are to the lyrics it should sing.

    Two numbers, because they fail differently:

      **stray** is the share of labelled rows whose text appears nowhere in
      the song. It needs no alignment, so it has no alignment artifacts,
      and it is the one that caught free Whisper decoding writing `binili`
      for `pinili`, `nilireto` for `nirereto`, and eight rows labelled with
      a music-note emoji. Forced alignment should drive it to zero by
      construction: the words come from the sheet.

      **wer** compares the label *sequence* to the lyrics. Labels are
      per-note, so consecutive repeats are collapsed first to recover the
      sequence -- which is lossy in one direction worth knowing about: a
      word the lyrics genuinely repeat back to back ("Oh Oh Oh") collapses
      to one, and the rest count as deletions. So this reads as an upper
      bound on the error, not a measurement of it. On the first
      `Nasa Iyo Na Ang Lahat` extraction it was 27.1%.
    """
    expected = lyric_words(lyrics)
    vocab = {_norm_label(w.text) for w in expected}
    vocab |= {_norm_label(s[0]) for w in expected for s in w.syllables}
    vocab.discard("")
    if not vocab:
        return None

    labels = [(r.get("syllable") or "").strip() for r in rows]
    named = [s for s in labels if s]

    # Labels off is the normal case: the extractor's LABEL_MODE defaults
    # to 'none' because nothing scores them. Reporting that as 281
    # deletions and 100% WER would be arithmetically true and completely
    # misleading, so it is reported as what it is instead.
    if not named:
        return {"unit": "none", "rows": len(rows), "blank": len(labels),
                "labels_off": True}

    stray = [s for s in named if _norm_label(s) not in vocab]

    # The reference is syllables when the file is labelled by syllable and
    # words when it is labelled by word, decided by which the labels
    # actually match -- not by a flag, since the file does not carry one.
    words_only = {_norm_label(w.text) for w in expected} - {""}
    as_words = sum(1 for s in named if _norm_label(s) in words_only)
    unit = "word" if as_words >= 0.8 * len(named) else "syllable"
    if unit == "word":
        ref = [_norm_label(w.text) for w in expected]
    else:
        ref = [_norm_label(s[0]) for w in expected for s in w.syllables]
    ref = [w for w in ref if w]

    hyp: list[str] = []
    for s in named:
        n = _norm_label(s)
        if n and (not hyp or hyp[-1] != n):
            hyp.append(n)

    ops = _levenshtein_ops(ref, hyp)
    c = collections.Counter(o[0] for o in ops)
    return {
        "unit": unit,
        "rows": len(rows),
        "blank": len(labels) - len(named),
        "stray": len(stray),
        "stray_share": 100.0 * len(stray) / max(len(named), 1),
        "stray_words": collections.Counter(stray),
        "ref": len(ref),
        "hyp": len(hyp),
        "sub": c["sub"], "del": c["del"], "ins": c["ins"], "ok": c["ok"],
        "wer": 100.0 * (c["sub"] + c["del"] + c["ins"]) / max(len(ref), 1),
        "subs": collections.Counter((o[1], o[2]) for o in ops
                                    if o[0] == "sub"),
        "dels": collections.Counter(o[1] for o in ops if o[0] == "del"),
    }


def catalog_songs(repo: Path):
    """"Title - Artist" for each entry in SongCatalogService.bundled."""
    src = (repo / "lib" / "services" / "song_catalog_service.dart")
    if not src.exists():
        return None
    text = src.read_text(encoding="utf-8")
    pairs = re.findall(
        r"CatalogSong\(\s*\n?\s*title:\s*'([^']+)',\s*\n?\s*artist:\s*'([^']+)'",
        text)
    return [f"{t} - {a}" for t, a in pairs]


def check_song(stem: str, gt_path: Path, audio_path: Path | None):
    problems, notes = [], []

    try:
        rows = load_rows(gt_path)
    except Exception as e:                              # noqa: BLE001
        return [f"unreadable: {e}"], {}

    if not rows:
        return ["no usable rows"], {}

    starts_bad = sum(1 for r in rows if r["end"] <= r["start"])
    if starts_bad:
        problems.append(f"{starts_bad} row(s) end at or before their start")

    ends = max(r["end"] for r in rows)
    first = min(r["start"] for r in rows)

    audio_dur = duration_of(audio_path) if audio_path else None
    if audio_path is None:
        problems.append("no matching MP3 in assets/audio/")
    elif audio_dur is None:
        notes.append("could not read the audio duration (install mutagen)")
    elif ends > audio_dur + 0.5:
        problems.append(
            f"describes audio that does not exist: ends {ends:.1f}s, "
            f"track is {audio_dur:.1f}s")

    midis = [m for m in (note_to_midi(r.get("note")) for r in rows)
             if m is not None]
    unparsed = len(rows) - len(midis)
    if unparsed:
        problems.append(f"{unparsed} row(s) have an unparseable note name")
    spread = (max(midis) - min(midis)) if midis else 0
    outliers = sum(1 for m in midis if not SINGABLE_LO <= m <= SINGABLE_HI)
    if outliers:
        problems.append(f"{outliers} note(s) outside a singable range "
                        f"(MIDI {SINGABLE_LO}-{SINGABLE_HI}) — octave errors")
    if spread > 40:
        problems.append(f"{spread}-semitone range is too wide for one voice")

    overlap = sum(1 for a, b in zip(rows, rows[1:])
                  if b["start"] < a["end"] - 1e-9)
    if overlap:
        problems.append(f"{overlap} overlapping row(s)")

    # Octave errors against the LOCAL register, not the global range.
    # SINGABLE_LO..HI only catches a note outside any voice at all, and
    # these sit comfortably inside it: on Araw-Araw, 20 notes were ~12
    # semitones off their own neighbours while the whole file stayed
    # within B2-G#5. A pitch tracker that locks onto a subharmonic
    # produces exactly that, and it is invisible to every other check
    # here — the app then scores a correct singer as wrong on those notes.
    octave_off = []
    for i, r in enumerate(rows):
        m = note_to_midi(r.get("note"))
        if m is None:
            continue
        near = [note_to_midi(o.get("note")) for j, o in enumerate(rows)
                if j != i and abs(o["start"] - r["start"]) <= 4.0]
        near = [x for x in near if x is not None]
        if len(near) < 2:
            continue
        local = sorted(near)[len(near) // 2]
        if 10.5 <= abs(m - local) <= 13.5:
            octave_off.append((r, m, local))
    if octave_off:
        share = 100 * len(octave_off) / len(rows)
        worst = {}
        for r, _m, _l in octave_off:
            key = (r.get("syllable") or "").strip()
            if key:
                worst[key] = worst.get(key, 0) + 1
        repeated = sorted(worst.items(), key=lambda kv: -kv[1])[:3]
        detail = (
            "; worst: "
            + ", ".join(f"{k!r}x{v}" for k, v in repeated if v > 1)
            if any(v > 1 for _, v in repeated) else "")
        msg = (f"{len(octave_off)} note(s) sit ~12 semitones off their own "
               f"neighbours ({share:.0f}%) — likely octave errors{detail}")
        (problems if share > 3 else notes).append(msg)

    # Arithmetic splits. The sharp test is per WORD, not across the file:
    # dividing one word's span by its vowel count leaves that word's rows
    # with identical durations to the millisecond. Measured this way the
    # previous generation scored 100% (59/59, 104/104, 51/51, 95/95), while
    # counting the most common duration file-wide only showed 4-12% — so
    # the global version would have let it through.
    durs = [round(r["end"] - r["start"], 3) for r in rows]
    groups, cur = [], [rows[0]]
    for r in rows[1:]:
        if r.get("syllable") == cur[-1].get("syllable"):
            cur.append(r)
        else:
            groups.append(cur)
            cur = [r]
    groups.append(cur)

    multi = [g for g in groups if len(g) > 1]
    equal_words = 0
    for g in multi:
        gd = [round(r["end"] - r["start"], 3) for r in g]
        if max(gd) - min(gd) <= 0.002:
            equal_words += 1
    equal_share = 100 * equal_words / len(multi) if multi else 0.0
    if equal_share > 25 and len(multi) >= 5:
        problems.append(
            f"{equal_share:.0f}% of multi-row words are split into equal "
            f"slices ({equal_words}/{len(multi)}) — boundaries are "
            "arithmetic, not detected from the audio")

    # Over-segmentation: adjacent rows at the same pitch, butted together.
    same_runs = sum(1 for a, b in zip(rows, rows[1:])
                    if a.get("note") == b.get("note")
                    and b["start"] - a["end"] < 0.12)
    if same_runs > len(rows) * 0.10:
        problems.append(
            f"{same_runs} adjacent same-pitch rows — held notes split up")

    # Under-extraction: notes covering far too little of the stretch they
    # span. Every other check here looks at the notes that ARE there and
    # says nothing about the ones that are missing, so a badly
    # under-extracted file passes everything — `Buwan` came back with 190
    # notes covering 49s of a 272s span (18%) against a sheet of 300
    # syllables, and looked clean. A song sings through most of its own
    # span; 18% means the tracker found almost nothing.
    voiced = sum(r["end"] - r["start"] for r in rows)
    span = ends - first
    coverage = 100.0 * voiced / span if span > 0 else 0.0
    if span > 0 and coverage < 30:
        problems.append(
            f"only {coverage:.0f}% of the {span:.0f}s it spans is inside a "
            f"note ({voiced:.0f}s over {len(rows)} notes) — under-extracted; "
            "try lowering conf_min or fmin")
    elif span > 0 and coverage < 45:
        notes.append(f"{coverage:.0f}% voiced coverage is on the low side")

    # Notes before the first word was sung. Where forced alignment ran,
    # the word onsets are an independent witness to when the vocal starts,
    # and anything the pitch tracker found before that cannot be a sung
    # note — it is the instrumental leaking into the vocal stem. Six of
    # ten songs had some, up to 58 notes (10%) on Mundo, and the app
    # scores a singer against every one of them.
    words_path = gt_path.with_suffix("") .with_suffix(".words.json")
    if not words_path.exists():
        words_path = gt_path.parent / f"{gt_path.stem}.words.json"
    if words_path.exists():
        try:
            wdata = json.loads(words_path.read_text(encoding="utf-8"))
            wlist = wdata["words"] if isinstance(wdata, dict) else wdata
            onsets = sorted(float(w["start"]) for w in wlist
                            if isinstance(w, dict) and "start" in w)
        except Exception:                               # noqa: BLE001
            onsets = []
        if onsets:
            first_word = onsets[0]
            early = [r for r in rows if r["end"] <= first_word]
            if len(early) >= 3:
                share = 100 * len(early) / len(rows)
                rest = [r for r in rows if r["end"] > first_word]
                # Same discrimination backend/trim_bleed.py uses, so the
                # two tools cannot disagree about the same notes. Being
                # outside the word span is not proof of bleed: a lyrics
                # sheet missing its opening lines pushes the "first word"
                # later than it really is, and those notes are real.
                instrumental, why = looks_instrumental(early, rest)
                if instrumental:
                    msg = (f"{len(early)} note(s) ({share:.0f}%) before the "
                           f"first sung word at {first_word:.1f}s look "
                           f"instrumental ({why}) — scored as if sung; "
                           "backend/trim_bleed.py --apply")
                    (problems if share >= 3 else notes).append(msg)
                else:
                    notes.append(
                        f"{len(early)} note(s) ({share:.0f}%) sit before the "
                        f"first sung word at {first_word:.1f}s but {why}. "
                        f"Most likely backend/lyrics/{gt_path.stem}.txt is "
                        "missing the opening lines")

    sdur = sorted(durs)
    stats = {
        "rows": len(rows),
        "first": first,
        "ends": ends,
        "audio": audio_dur,
        "median": sdur[len(sdur) // 2],
        "spread": spread,
        "same_runs": same_runs,
        "equal_share": equal_share,
    }
    return problems, stats, notes


def main() -> int:
    ap = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--repo", type=Path, default=Path(__file__).parent.parent)
    ap.add_argument("--strict", action="store_true",
                    help="exit 1 if any song has a problem")
    ap.add_argument("--errors", type=int, default=0, metavar="N",
                    help="list the N most common label errors per song")
    args = ap.parse_args()

    gt_dir = args.repo / "assets" / "ground_truth"
    audio_dir = args.repo / "assets" / "audio"
    if not gt_dir.is_dir():
        print(f"not found: {gt_dir}")
        return 1

    # `<stem>.words.json` sits beside `<stem>.json` and holds word onsets
    # for backend/sync_lyrics.py, not notes. Globbing *.json swept it up
    # and reported it as a broken ground truth.
    gts = sorted(p for p in gt_dir.glob("*.json")
                 if not p.stem.endswith(".words"))
    if not gts:
        print("No ground truth files in assets/ground_truth/ yet.")
        return 0

    print(f"{'song':<32} {'rows':>5} {'ends':>7} {'audio':>7} {'med':>6} "
          f"{'rng':>4} {'runs':>5} {'equal':>6}")
    print("-" * 82)

    failing = []
    for gt in gts:
        stem = gt.stem
        audio = audio_dir / f"{stem}.mp3"
        result = check_song(stem, gt, audio if audio.exists() else None)
        problems, stats = result[0], result[1]
        extra = result[2] if len(result) > 2 else []

        if stats:
            a = stats["audio"]
            print(f"{stem[:32]:<32} {stats['rows']:5d} {stats['ends']:7.1f} "
                  f"{a if a is not None else -1:7.1f} {stats['median']:6.2f} "
                  f"{stats['spread']:4d} {stats['same_runs']:5d} "
                  f"{stats['equal_share']:5.0f}%")
        else:
            print(f"{stem[:32]:<32} {'--':>5}")

        for p in problems:
            print(f"{'':>32}   !! {p}")
        for n in extra:
            print(f"{'':>32}   -- {n}")
        if problems:
            failing.append(stem)

    print("-" * 82)
    ok = len(gts) - len(failing)
    print(f"{ok} of {len(gts)} ground-truth file(s) passed every check.")

    # ---- labels against the lyrics -------------------------------------
    #
    # Reported apart from the checks above because the labels are
    # debug-only in the app: nothing is scored against them, so a song
    # with poor labels and good notes is still usable. They are measured
    # because they are how a human tells whether a file lines up with its
    # recording, and because "the words are wrong" needs a number before
    # it can be fixed.
    scored = []
    for gt in gts:
        lyrics = load_lyrics(gt.stem)
        if lyrics is None:
            continue
        try:
            rows = load_rows(gt)
        except Exception:                               # noqa: BLE001
            continue
        s = score_labels(rows, lyrics)
        if s:
            scored.append((gt.stem, s))

    labels_off = [st for st, s in scored if s.get("labels_off")]
    scored = [(st, s) for st, s in scored if not s.get("labels_off")]

    if labels_off:
        print(f"\n{len(labels_off)} file(s) carry no word labels, which is "
              "the default:")
        for stem in labels_off:
            print(f"  -- {stem}")
        print("     Nothing scores them — the app groups segments by the")
        print("     singer's own recognised words and by time — so there is")
        print("     nothing to compare against backend/lyrics/ here.")

    if scored:
        print(f"\n{'song':<32} {'unit':>8} {'blank':>6} {'stray':>6} "
              f"{'ref':>5} {'heard':>6} {'wer':>6}")
        print("-" * 82)
        for stem, s in scored:
            print(f"{stem[:32]:<32} {s['unit']:>8} {s['blank']:6d} "
                  f"{s['stray']:6d} {s['ref']:5d} {s['hyp']:6d} "
                  f"{s['wer']:5.0f}%")
            if s["stray_share"] > 2:
                print(f"{'':>32}   !! {s['stray_share']:.0f}% of labels are "
                      "words this song never sings")
            if s["wer"] > 15:
                print(f"{'':>32}   -- {s['sub']} sub, {s['del']} del, "
                      f"{s['ins']} ins against {s['ref']} "
                      f"{s['unit']}s")
            if args.errors:
                for (a, b), k in s["subs"].most_common(args.errors):
                    print(f"{'':>32}      {k:3d}x {a} -> {b}")
                for w, k in s["dels"].most_common(args.errors):
                    print(f"{'':>32}      {k:3d}x {w} -> (missing)")
        print("-" * 82)
        print("stray = labels that are not in the lyrics at all. Forced")
        print("        alignment should make this 0: the words come from")
        print("        backend/lyrics/, so they cannot be misspelled.")
        print("wer   = label sequence vs the lyrics. An UPPER bound: a word")
        print("        repeated back to back in the lyrics collapses to one")
        print("        and the rest count against it. 27% was the first")
        print("        Whisper-labelled extraction; use it as the baseline.")
    elif not labels_off and (Path(__file__).parent / "lyrics").is_dir():
        print("\nNo ground truth has a matching sheet in backend/lyrics/, "
              "so labels were not scored.")

    # Catalog drift: a listed song with no files dead-ends in the app.
    catalog = catalog_songs(args.repo)
    if catalog is not None:
        have_audio = {p.stem for p in audio_dir.glob("*.mp3")}
        have_gt = {p.stem for p in gts}
        missing_audio = [s for s in catalog if s not in have_audio]
        missing_gt = [s for s in catalog if s not in have_gt]
        extra_audio = sorted(have_audio - set(catalog))

        print(f"\ncatalog: {len(catalog)} song(s) listed")
        if missing_audio:
            print(f"  !! {len(missing_audio)} listed with NO backing track "
                  "(they dead-end in the app):")
            for s in missing_audio:
                print(f"       {s}")
        if missing_gt:
            print(f"  -- {len(missing_gt)} listed with no ground truth "
                  "(playable, but no Pitch Timeline):")
            for s in missing_gt:
                print(f"       {s}")
        if extra_audio:
            print(f"  -- {len(extra_audio)} track(s) on disk but not in the "
                  "catalog (invisible in the app):")
            for s in extra_audio:
                print(f"       {s}")
        # A name that differs from the catalog only in capitalisation.
        # Reported on its own because it looks like a missing file and is
        # not one: `IKAW LANG - NOBITA.json` came off a separation tool
        # that upper-cased the title, and the app looks for
        # `Ikaw Lang - NOBITA.json`. Renaming fixes it; re-extracting
        # does not.
        lower_cat = {s.lower(): s for s in catalog}
        for stem in sorted(have_gt - set(catalog)):
            match = lower_cat.get(stem.lower())
            if match:
                print(f"\n  !! \"{stem}.json\" differs from the catalog "
                      "only in case.")
                print(f"     The app looks for \"{match}.json\" and will "
                      "not find this one.")
                print(f"     Rename it to \"{match}.json\" — and rename the "
                      "stems too, so the")
                print("     next extraction writes the right name.")
                failing.append(stem)

        if missing_audio and args.strict:
            failing.append("catalog")

    return 1 if (failing and args.strict) else 0


if __name__ == "__main__":
    sys.exit(main())
