# Lyrics, as plain text

One file per catalogued song, named `<Title> - <Artist>.txt` — the same
stem as `assets/audio/` and `assets/ground_truth/`, so everything for a
song is found by one name.

These are the *input* to forced alignment, not an output of it. Free
Whisper decoding of singing was measured at 27% WER on
`Nasa Iyo Na Ang Lahat` (26 substitutions, 37 deletions over 255 words):
it turned `pinili` into `binili`, dropped `sarap` entirely, swallowed
`'yo na ang` into a single 1.06s span, and wrote 8 rows labelled `🎵`.
Forced alignment asks a different question — *where* is each of these
known words — so spelling and word order come from these files and
cannot be wrong. Only the timing is estimated.

Two conventions matter:

  - **Section markers** (`[Chorus]`, `[Verse 1]`) are stripped on load.
    They are kept in the files because they make the repetition structure
    readable when checking a file against the recording by ear.

  - **Parenthesised text** marks backing vocals, which in this catalog are
    sung *at the same time* as the lead (clearest in Mundo, Buwan and
    Randomantic). A forced aligner walks the transcript in order and has
    no way to express simultaneity, so including them would force the
    alignment to drift. They are stripped by default; see
    `KEEP_PARENTHETICALS` in the notebook. CTC blanks absorb the audio
    they would have claimed at no cost, which is the same thing that
    covers instrumental intros and outros.

Transcribed to match what is actually sung on the bundled recording, which
is not always what a lyrics site prints. `Dadalhin` is Regine Velasquez's
recording, not Ogie Alcasid's.

## When a sheet is missing a passage

Forced alignment walks the sheet in order and lets CTC blanks absorb
anything it does not account for, so a section the sheet is missing comes
back as a run of notes with no words. `backend/sync_lyrics.py` reports
those stretches by time; on `Araw-Araw` they were 24.1s and 13.3s.

Which fix applies depends on what is actually sung there:

  - **it has words** — add them to the sheet in sung order, then re-run
    the extractor with `LABEL_MODE = 'align'`. The word count changes, so
    the alignment has to be redone; `sync_lyrics.py` refuses rather than
    shifting every later line to absorb the difference.

  - **it is humming, "oh"s or a vocalise** — add a bare `♪` line to the
    sheet at that point. A line with no letters contributes no words, so
    the existing alignment stays valid and only `sync_lyrics.py` needs
    re-running. It takes its time from the gap it sits in.

Until one of those is done, `sync_lyrics.py` writes a `♪` into the app so
the screen does not freeze on the previous line for the whole stretch.
