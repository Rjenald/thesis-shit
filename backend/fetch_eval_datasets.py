"""Builds a folder of labelled Filipino speech clips for measuring Huni's
transcription accuracy on the phone.

WHAT THIS DOES
--------------
Downloads public, appropriately licensed Filipino speech, converts it to
exactly the format the app records in (16 kHz mono PCM16 WAV), and writes a
clips.json of reference transcripts next to it. Push the folder to the
device, run Admin -> Transcription accuracy, pull hypotheses.json back, and
score it with evaluate_transcription.py --merge.

SOURCES
-------
sapinsapin/filipinospeechcorpus (MIT) -- the default.
    The Filipino Speech Corpus (Sagum): 65.1 h, 125 speakers, studio
    recorded, already 16 kHz mono PCM16, which is the app's exact input
    format. Fetched row by row over HTTP, so a 150-clip set costs a few MB
    rather than a whole-corpus download.

    Two traps this handles, both documented on the dataset card:
      - 56% of its segments are single machine-pre-segmented word tokens
        (median 0.62 s). Those measure nothing about transcribing speech,
        so speech_type/duration/num_words are filtered.
      - its own split is random over segments, so the same speakers appear
        in train and test. This collects from a bounded set of speakers and
        prints their ids, which must then be excluded from any fine-tuning
        set or the score stops describing generalisation.

YIELD, AND WHY THIS IS SLOW
---------------------------
Measured on the test split: 8,036 rows scanned produced 12 clips with a
3-speaker cap, 57% of rows being single-word tokens (the card says 56%).
That works out to roughly 15 sentence-level clips per speaker in the
30,516-row test split, so about 1,900 in total across its 125 speakers.

Two consequences:
  - The clip count is bounded by the speaker cap. 60 clips needs ~5
    speakers' worth and roughly a third of the split scanned; asking for
    many more than ~180 from `test` means raising --fsc-speakers, which
    costs you those speakers for fine-tuning, or moving to --fsc-split
    train.
  - The Hub's row API rate-limits hard. The run above took 13 backoff
    waits. Expect minutes, not seconds, and leave it running. The script
    reports what it actually got rather than silently returning short.

google/fleurs, config fil_ph (CC-BY-4.0) -- opt-in with --fleurs N.
    964 test utterances of read speech. Worth having because it is a
    published benchmark, so the resulting WER can be compared with numbers
    in the literature instead of standing alone.

    Off by default because it cannot be fetched row by row: its parquet row
    groups exceed the Hub row API's scan limit, so the only way in is
    `datasets` streaming, which pulls the whole ~1.1 GB test split. Budget
    for that before passing --fleurs.

WHAT THIS DOES NOT PROVIDE
--------------------------
Sung Tagalog. No public dataset has it: 494 datasets tagged `tl` and 211
tagged `fil` on the Hub contain none, and OpenSLR lists no Filipino
resource at all. Sung clips have to be recorded, and this project's own
bundled lyrics (lib/data/song_lyrics.dart, 320 lines across 9 songs) are
already the reference transcripts for them -- so --sung-slots leaves blank
rows to paste them into.

These clips are for MEASUREMENT. Keep them out of any fine-tuning set.

USAGE
-----
    pip install soundfile numpy            # FSC only; no `datasets` needed
    python fetch_eval_datasets.py --out clips
    python fetch_eval_datasets.py --out clips --fsc 300 --fsc-speakers 12

    pip install "datasets>=2.19"           # only if you want FLEURS
    python fetch_eval_datasets.py --out clips --fleurs 150
"""
from __future__ import annotations

import argparse
import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

TARGET_SR = 16000          # what the app records at; no resampling at inference
ROWS_API = "https://datasets-server.huggingface.co/rows"
FSC_REPO = "sapinsapin/filipinospeechcorpus"
PAGE = 50                  # kept modest; the rows API rate-limits
PAGE_PAUSE = 1.5           # seconds between pages, to stay under it
UA = {"User-Agent": "huni-eval-fetcher/1.0"}


def _require_audio_libs():
    try:
        import numpy  # noqa: F401
        import soundfile  # noqa: F401
    except ImportError as e:
        print(f"missing dependency: {e.name}")
        print("install with:  pip install soundfile numpy")
        raise SystemExit(1)


def write_wav(path: Path, audio, sr: int) -> float:
    """Writes 16 kHz mono PCM16, resampling only if the source differs.

    Returns the clip's duration in seconds. The app hands whisper.cpp
    native 16 kHz mono PCM16 with no resampling step, so writing anything
    else would measure a resampler the app does not have. (An earlier
    evaluation in this project was invalidated by exactly that: feeding
    44.1 kHz audio to a 16 kHz model shifts every pitch by 1755 cents.)
    """
    import numpy as np
    import soundfile as sf

    a = np.asarray(audio, dtype=np.float64)
    if a.ndim > 1:                      # average channels down to mono
        a = a.mean(axis=1)

    if sr != TARGET_SR:
        # Linear interpolation. Adequate because every source here is
        # already 16 kHz or a clean downsample from 48 kHz; this is not a
        # general-purpose resampler.
        n = int(round(len(a) * TARGET_SR / sr))
        a = np.interp(
            np.linspace(0, len(a) - 1, n, endpoint=True),
            np.arange(len(a)),
            a,
        )

    peak = np.abs(a).max() if len(a) else 0.0
    if peak > 1.0:                      # guard against int16 wraparound
        a = a / peak
    pcm = np.clip(a * 32767.0, -32768, 32767).astype("<i2")
    sf.write(str(path), pcm, TARGET_SR, subtype="PCM_16")
    return len(pcm) / TARGET_SR


def _sleep_for(err, attempt: int) -> float:
    """Backoff that respects the Hub's own Retry-After when it sends one.

    The rows API rate-limits well below what a tight loop will do, and a
    429 is a request to wait rather than a failure, so this waits properly
    instead of hammering and giving up.
    """
    retry_after = None
    if isinstance(err, urllib.error.HTTPError):
        header = err.headers.get("Retry-After") if err.headers else None
        if header:
            try:
                retry_after = float(header)
            except ValueError:
                retry_after = None
    if retry_after is not None:
        return min(retry_after, 120.0)
    return min(5.0 * (2 ** attempt), 60.0)          # 5, 10, 20, 40, 60…


def _get_json(url: str, tries: int = 6) -> dict:
    """GETs JSON, waiting out rate limits and the Hub's intermittent 5xx."""
    last = None
    for attempt in range(tries):
        try:
            req = urllib.request.Request(url, headers=UA)
            with urllib.request.urlopen(req, timeout=90) as r:
                payload = json.loads(r.read().decode("utf-8"))
            if "error" in payload:
                last = payload["error"]
                raise RuntimeError(last)
            return payload
        except Exception as e:                      # noqa: BLE001
            last = e
            if attempt < tries - 1:
                wait = _sleep_for(e, attempt)
                code = getattr(e, "code", None)
                print(f"    rows API {code or type(e).__name__}; "
                      f"waiting {wait:.0f}s")
                time.sleep(wait)
    raise RuntimeError(f"rows API failed after {tries} tries: {last}")


def _download(url: str, dest: Path, tries: int = 3) -> None:
    last = None
    for attempt in range(tries):
        try:
            req = urllib.request.Request(url, headers=UA)
            with urllib.request.urlopen(req, timeout=120) as r:
                dest.write_bytes(r.read())
            return
        except Exception as e:                      # noqa: BLE001
            last = e
            if attempt < tries - 1:
                time.sleep(2 * (attempt + 1))
    raise RuntimeError(f"could not download {dest.name}: {last}")


def fetch_fsc(out: Path, limit: int, clips: list[dict], max_speakers: int,
              start_offset: int, split: str = "test") -> None:
    """Filipino Speech Corpus, sentence-level, bounded speaker set."""
    import soundfile as sf

    print(f"\n--- Filipino Speech Corpus (MIT), up to {limit} clips ---")

    base = (f"{ROWS_API}?dataset={urllib.parse.quote(FSC_REPO, safe='')}"
            f"&config=default&split={split}")
    total = _get_json(f"{base}&offset=0&length=1").get("num_rows_total", 0)
    print(f"  {split} split has {total} rows; scanning from {start_offset}")

    speakers: set[str] = set()
    kept = 0
    scanned = 0
    skipped_tokens = 0
    offset = start_offset
    tmp = out / "_tmp_fsc.wav"

    while kept < limit and offset < total:
        page = _get_json(f"{base}&offset={offset}&length={PAGE}")
        rows = page.get("rows", [])
        if not rows:
            break
        offset += len(rows)
        time.sleep(PAGE_PAUSE)          # stay under the rows API rate limit

        for entry in rows:
            if kept >= limit:
                break
            row = entry.get("row", {})
            scanned += 1

            # Drop the single-word machine-segmented tokens: 56% of the
            # corpus, median 0.62 s, and not a test of transcription.
            if row.get("speech_type") not in ("read", "spontaneous"):
                skipped_tokens += 1
                continue
            dur = row.get("duration") or 0
            if not (1.5 <= dur <= 30.0):
                continue
            if (row.get("num_words") or 0) < 3:
                continue
            ref = (row.get("sentence") or "").strip()
            if not ref:
                continue

            spk = str(row.get("speaker_id", "unknown"))
            if spk not in speakers:
                if len(speakers) >= max_speakers:
                    continue
                speakers.add(spk)

            audio = row.get("audio") or []
            src = audio[0].get("src") if audio and isinstance(audio[0], dict) \
                else None
            if not src:
                continue

            cid = f"fsc_{kept:04d}"
            try:
                _download(src, tmp)
                data, sr = sf.read(str(tmp))
            except Exception as e:                  # noqa: BLE001
                print(f"  skipped {cid}: {e}")
                continue
            seconds = write_wav(out / f"{cid}.wav", data, sr)

            clips.append({
                "id": cid,
                "category": "spoken_tagalog",
                "audio": f"{cid}.wav",
                "reference": ref,
                "hypothesis": "",
                "lang": "tl",
                "source": f"{FSC_REPO} (MIT)",
                "speaker_id": spk,
                "speech_type": row.get("speech_type"),
                "duration": round(seconds, 2),
                "notes": "studio recorded; speaker held out for eval",
            })
            kept += 1
            if kept % 10 == 0:
                print(f"  {kept}/{limit} clips, {scanned} rows scanned, "
                      f"{len(speakers)}/{max_speakers} speakers")

    if tmp.exists():
        tmp.unlink()

    print(f"  kept {kept} clips from {len(speakers)} speaker(s), "
          f"scanned {scanned} rows")
    if skipped_tokens:
        print(f"  skipped {skipped_tokens} single-word token segments")
    if kept < limit:
        print(f"  !! wanted {limit}, got {kept}. The {max_speakers}-speaker "
              f"cap or the end of the split stopped it, not an error.")
        print(f"     Raise --fsc-speakers (costs those speakers for "
              f"fine-tuning) or use --fsc-split train.")
    if speakers:
        print("  EXCLUDE these speaker_ids from any fine-tuning set:")
        print(f"    {', '.join(sorted(speakers))}")


def fetch_fleurs(out: Path, limit: int, clips: list[dict]) -> None:
    """FLEURS fil_ph test: read speech, CC-BY-4.0, via `datasets` streaming."""
    try:
        from datasets import load_dataset
    except ImportError:
        print("\n--- FLEURS skipped: `datasets` is not installed ---")
        print('    pip install "datasets>=2.19"')
        return

    print(f"\n--- FLEURS fil_ph (test), up to {limit} clips ---")
    print("    NOTE: this streams the whole ~1.1 GB test split, because "
          "its\n          parquet row groups are too large for the Hub's "
          "row API.")

    ds = load_dataset("google/fleurs", "fil_ph", split="test", streaming=True)

    kept = 0
    for row in ds:
        if kept >= limit:
            break
        ref = (row.get("raw_transcription") or row.get("transcription") or "")
        ref = ref.strip()
        if not ref:
            continue
        audio = row["audio"]
        cid = f"fleurs_{kept:04d}"
        seconds = write_wav(out / f"{cid}.wav", audio["array"],
                            audio["sampling_rate"])
        clips.append({
            "id": cid,
            "category": "spoken_tagalog",
            "audio": f"{cid}.wav",
            "reference": ref,
            "hypothesis": "",
            "lang": "tl",
            "source": "google/fleurs fil_ph test (CC-BY-4.0)",
            "duration": round(seconds, 2),
            "notes": "read speech; published benchmark",
        })
        kept += 1
        if kept % 25 == 0:
            print(f"  {kept} clips…")
    print(f"  kept {kept}")


def sung_placeholders(clips: list[dict], n: int) -> None:
    """Blank rows for the sung clips only you can record.

    No reference is filled in, so the scorer skips them until you do. The
    reference for a sung line is the lyric line itself, which
    lib/data/song_lyrics.dart already holds for 9 of the 10 songs.
    """
    for i in range(n):
        for cat in ("sung_tagalog", "sung_acappella"):
            clips.append({
                "id": f"{cat}_{i + 1}",
                "category": cat,
                "audio": f"{cat}_{i + 1}.wav",
                "reference": "",
                "hypothesis": "",
                "lang": "tl",
                "source": "record yourself",
                "notes": "paste the lyric line you sang as the reference, "
                         "and sing it deliberately: the reference is what "
                         "the lyrics say, not what you improvised",
            })


def main() -> int:
    ap = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", type=Path, default=Path("clips"),
                    help="output folder (default: clips)")
    ap.add_argument("--fsc", type=int, default=60,
                    help="Filipino Speech Corpus clips (default 60; see "
                         "YIELD in the header before raising it)")
    ap.add_argument("--fsc-speakers", type=int, default=12,
                    help="cap on distinct speakers to draw from (default "
                         "12). Raising it finds clips faster but means "
                         "excluding more speakers from fine-tuning")
    ap.add_argument("--fsc-split", default="test",
                    choices=("test", "train"),
                    help="which split to scan (default test, 30.5k rows). "
                         "`train` has 274k rows if you need a larger set; "
                         "the two are a random split over segments, not "
                         "over speakers, so neither is 'the training data' "
                         "until you make it so")
    ap.add_argument("--fsc-offset", type=int, default=0,
                    help="row offset to start scanning from (default 0); "
                         "change it for a different, still-disjoint slice")
    ap.add_argument("--fleurs", type=int, default=0,
                    help="FLEURS fil_ph test clips (default 0: enabling this "
                         "streams ~1.1 GB)")
    ap.add_argument("--sung-slots", type=int, default=4,
                    help="blank sung rows per category (default 4)")
    args = ap.parse_args()

    _require_audio_libs()
    args.out.mkdir(parents=True, exist_ok=True)
    clips: list[dict] = []

    if args.fsc > 0:
        fetch_fsc(args.out, args.fsc, clips, args.fsc_speakers,
                  args.fsc_offset, args.fsc_split)
    if args.fleurs > 0:
        fetch_fleurs(args.out, args.fleurs, clips)
    if args.sung_slots > 0:
        sung_placeholders(clips, args.sung_slots)

    manifest = args.out / "clips.json"
    manifest.write_text(
        json.dumps(clips, indent=2, ensure_ascii=False), encoding="utf-8")

    wavs = sorted(args.out.glob("*.wav"))
    total_s = sum(c.get("duration", 0) for c in clips)
    with_ref = sum(1 for c in clips if c["reference"])
    print(f"\nWrote {len(wavs)} WAVs and {manifest}")
    print(f"  {len(clips)} rows, {with_ref} with a reference, "
          f"{total_s / 60:.1f} min of audio")
    if with_ref == 0:
        print("  !! nothing has a reference yet, so there is nothing to "
              "score.")
    print("\nNext:")
    print(f"  adb push {args.out}/. /storage/emulated/0/Android/data/"
          "com.example.final_thesis_ui/files/eval_clips/")
    print("  app: Admin -> Transcription accuracy -> Transcribe all clips")
    print("  adb pull /storage/emulated/0/Android/data/"
          "com.example.final_thesis_ui/files/eval_clips/hypotheses.json")
    print(f"  python evaluate_transcription.py {manifest} "
          "--merge hypotheses.json")
    print("\nThese clips are for measurement. Keep them out of any "
          "fine-tuning set.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
