"""Scores Huni's transcription against reference transcripts.

Computes Word Error Rate and Character Error Rate overall and per category,
so a change can be shown to help rather than asserted to.

WHY IT WORKS THIS WAY
---------------------
The app transcribes with whisper.cpp on the phone, through whisper_ggml.
Running a different Whisper build here would measure a different system, so
this scores the app's OWN output: run a clip in the app, copy the line it
logs, and paste it in as the hypothesis. What is measured is then exactly
what ships.

The app already logs each take as:

    Whisper transcribe() returned after 1234ms, wavBytes=..., rawText=" ... "

USAGE
-----
    python evaluate_transcription.py --init clips.json     # make a template
    # record clips, fill in reference + hypothesis
    python evaluate_transcription.py clips.json            # score
    python evaluate_transcription.py before.json after.json  # compare runs

NORMALIZATION POLICY (fixed before any measurement, per Phase 6)
----------------------------------------------------------------
Applied identically to reference and hypothesis:
  - lowercase
  - strip punctuation except the apostrophe, which is part of Tagalog
    contractions ("'yo", "'di") and English ones ("I've")
  - collapse whitespace
  - keep filler and repeated words: dropping them would hide exactly the
    duplication and word-loss failures worth catching
NOT applied: stemming, affix stripping, spelling normalization, or
Tagalog/English equivalence - all of which would flatter the score by
forgiving real errors.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import unicodedata
from pathlib import Path

CATEGORIES = [
    "spoken_tagalog",      # clear conversational Tagalog
    "spoken_taglish",      # Taglish / code-switching
    "spoken_english",      # English, to check language config didn't break it
    "spoken_noisy",        # quiet speech or background noise
    "spoken_short",        # short phrases, a few words
    "spoken_repeats",      # deliberately repeated words and syllables
    "sung_tagalog",        # sung, with backing track
    "sung_acappella",      # sung, no backing track
]


def normalize(text: str) -> list[str]:
    """The fixed policy documented above. Same treatment both sides."""
    text = unicodedata.normalize("NFKC", text or "").lower()
    text = text.replace("’", "'")          # curly to straight apostrophe
    text = re.sub(r"[^\w\s']", " ", text)       # punctuation out, apostrophe in
    text = re.sub(r"\s+", " ", text)
    return text.strip().split()


def edit_distance(a: list, b: list) -> tuple[int, int, int, int]:
    """Levenshtein with an operation breakdown: (distance, sub, del, ins).

    The breakdown matters here: deletions are dropped words and insertions
    are invented or duplicated ones, which are different failures with
    different causes.
    """
    n, m = len(a), len(b)
    d = [[0] * (m + 1) for _ in range(n + 1)]
    op = [[None] * (m + 1) for _ in range(n + 1)]
    for i in range(1, n + 1):
        d[i][0], op[i][0] = i, "del"
    for j in range(1, m + 1):
        d[0][j], op[0][j] = j, "ins"
    for i in range(1, n + 1):
        for j in range(1, m + 1):
            if a[i - 1] == b[j - 1]:
                d[i][j], op[i][j] = d[i - 1][j - 1], "ok"
                continue
            sub, dele, ins = d[i - 1][j - 1] + 1, d[i - 1][j] + 1, d[i][j - 1] + 1
            best = min(sub, dele, ins)
            d[i][j] = best
            op[i][j] = "sub" if best == sub else ("del" if best == dele else "ins")

    i, j = n, m
    counts = {"sub": 0, "del": 0, "ins": 0}
    while i > 0 or j > 0:
        o = op[i][j]
        if o == "ok":
            i, j = i - 1, j - 1
        elif o == "sub":
            counts["sub"] += 1; i, j = i - 1, j - 1
        elif o == "del":
            counts["del"] += 1; i -= 1
        else:
            counts["ins"] += 1; j -= 1
    return d[n][m], counts["sub"], counts["del"], counts["ins"]


def score(clips: list[dict]) -> dict:
    per_cat: dict[str, dict] = {}
    rows = []

    for c in clips:
        ref_raw, hyp_raw = c.get("reference", ""), c.get("hypothesis", "")
        if not ref_raw.strip():
            continue                      # not yet transcribed by hand
        if hyp_raw is None:
            hyp_raw = ""

        ref, hyp = normalize(ref_raw), normalize(hyp_raw)
        dist, sub, dele, ins = edit_distance(ref, hyp)
        ref_chars = list(" ".join(ref))
        hyp_chars = list(" ".join(hyp))
        cdist, *_ = edit_distance(ref_chars, hyp_chars)

        cat = c.get("category", "uncategorized")
        b = per_cat.setdefault(cat, dict(words=0, err=0, sub=0, dele=0,
                                         ins=0, chars=0, cerr=0, n=0))
        b["words"] += len(ref); b["err"] += dist
        b["sub"] += sub; b["dele"] += dele; b["ins"] += ins
        b["chars"] += len(ref_chars); b["cerr"] += cdist; b["n"] += 1

        rows.append(dict(id=c.get("id", "?"), category=cat,
                         wer=dist / max(len(ref), 1), sub=sub, dele=dele,
                         ins=ins, ref=" ".join(ref), hyp=" ".join(hyp)))

    return {"per_category": per_cat, "rows": rows}


def report(result: dict, label: str) -> None:
    per_cat, rows = result["per_category"], result["rows"]
    if not rows:
        print("No scored clips: fill in 'reference' (and 'hypothesis') first.")
        return

    print(f"\n=== {label} ===")
    print(f"{'category':<18} {'n':>3} {'WER%':>7} {'CER%':>7} "
          f"{'sub':>5} {'del':>5} {'ins':>5}")
    print("-" * 60)
    tw = te = tc = tce = 0
    for cat in sorted(per_cat):
        b = per_cat[cat]
        tw += b["words"]; te += b["err"]; tc += b["chars"]; tce += b["cerr"]
        print(f"{cat:<18} {b['n']:3d} {100*b['err']/max(b['words'],1):7.1f} "
              f"{100*b['cerr']/max(b['chars'],1):7.1f} "
              f"{b['sub']:5d} {b['dele']:5d} {b['ins']:5d}")
    print("-" * 60)
    print(f"{'OVERALL':<18} {len(rows):3d} {100*te/max(tw,1):7.1f} "
          f"{100*tce/max(tc,1):7.1f}")
    print("\ndel = words the model missed, ins = words it invented or doubled")

    worst = sorted(rows, key=lambda r: -r["wer"])[:5]
    if worst and worst[0]["wer"] > 0:
        print("\nworst clips:")
        for r in worst:
            if r["wer"] == 0:
                continue
            print(f"  [{r['category']}] {r['id']}  WER {100*r['wer']:.0f}%")
            print(f"     ref: {r['ref'][:88]}")
            print(f"     hyp: {r['hyp'][:88]}")


def make_template(path: Path) -> None:
    clips = []
    for cat in CATEGORIES:
        for i in (1, 2):
            clips.append({
                "id": f"{cat}_{i}",
                "category": cat,
                "audio": f"clips/{cat}_{i}.wav",
                "reference": "",
                "hypothesis": "",
                "notes": "",
            })
    path.write_text(json.dumps(clips, indent=2, ensure_ascii=False),
                    encoding="utf-8")
    print(f"Wrote template with {len(clips)} slots -> {path}\n")
    print("For each clip:")
    print("  1. Record it (sing or speak), keeping the audio for re-runs.")
    print("  2. Type exactly what was said/sung into 'reference'.")
    print("  3. Run it through the app and copy what it logged as rawText")
    print("     into 'hypothesis'.")
    print("\nKeep these clips OUT of anything used for tuning or training,")
    print("or the score stops measuring generalisation.")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("files", nargs="*", type=Path)
    ap.add_argument("--init", type=Path, help="write a blank template and exit")
    args = ap.parse_args()

    if args.init:
        make_template(args.init)
        return 0
    if not args.files:
        ap.print_help()
        return 1

    results = []
    for f in args.files:
        if not f.exists():
            print(f"missing: {f}")
            return 1
        clips = json.loads(f.read_text(encoding="utf-8"))
        r = score(clips)
        report(r, f.stem)
        results.append((f.stem, r))

    if len(results) == 2:
        (n1, r1), (n2, r2) = results
        print(f"\n=== {n1} -> {n2} ===")
        print(f"{'category':<18} {'before':>8} {'after':>8} {'change':>9}")
        print("-" * 46)
        for cat in sorted(set(r1['per_category']) | set(r2['per_category'])):
            a = r1['per_category'].get(cat)
            b = r2['per_category'].get(cat)
            if not a or not b:
                continue
            wa = 100 * a['err'] / max(a['words'], 1)
            wb = 100 * b['err'] / max(b['words'], 1)
            arrow = "better" if wb < wa else ("worse" if wb > wa else "same")
            print(f"{cat:<18} {wa:7.1f}% {wb:7.1f}% {wb-wa:+8.1f} {arrow}")
        print("\nA change is only an improvement if it holds per category -")
        print("an overall gain can hide a regression on sung or English clips.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
