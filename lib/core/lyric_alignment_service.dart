/// On-device speech recognition using Whisper-Tiny (whisper_ggml /
/// whisper.cpp).
///
/// Transcribes the just-recorded mic audio into words with timestamps, and
/// nothing more. The recognized words are shown to the singer as what the
/// app heard; they are never matched or scored against the song's lyrics.
///
/// Scoring is pitch only — see [buildSingingSegments], which compares each
/// detected note against the ground-truth melody. The ground truth's
/// syllable TEXT is retained for developer inspection (the detail sheet
/// surfaces it in debug builds) and to bias the decoder toward the
/// vocabulary that is actually coming, but it is not a target the singer
/// is measured against.
library;

import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:whisper_ggml/whisper_ggml.dart';

const _bundledWhisperModelAsset = 'assets/models/huni_whisper.bin';

/// One word recognized by Whisper, with its start/end time in the recording —
/// used when there's no reference lyric to align against (see
/// [transcribeWords]).
class TranscribedWord {
  final String text;
  final Duration startTime;
  final Duration endTime;
  const TranscribedWord({
    required this.text,
    required this.startTime,
    required this.endTime,
  });
}

/// Byte offset of a WAV's PCM payload (its `data` chunk), or null if this
/// doesn't parse as a RIFF/WAVE file. Walks the chunk list rather than
/// assuming the canonical 44-byte header, so an extra `LIST`/`fact` chunk
/// can't silently shift every sample read by a few bytes.
int? _findWavDataOffset(Uint8List wav) {
  if (wav.length < 44) return null;
  const riff = [0x52, 0x49, 0x46, 0x46]; // 'RIFF'
  for (var i = 0; i < 4; i++) {
    if (wav[i] != riff[i]) return null;
  }

  final bd = ByteData.sublistView(wav);
  var pos = 12; // skip 'RIFF' + size + 'WAVE'
  while (pos + 8 <= wav.length) {
    final id = String.fromCharCodes(wav, pos, pos + 4);
    final size = bd.getUint32(pos + 4, Endian.little);
    if (id == 'data') return pos + 8;
    pos += 8 + size + (size.isOdd ? 1 : 0); // chunks are word-aligned
  }
  return null;
}

/// Scales a 16-bit PCM WAV up to a healthy peak level, returning a copy.
///
/// Whisper has no automatic gain control — it turns the samples straight
/// into a log-mel spectrogram — so a quiet take reads to it as silence and
/// comes back blank (an empty or "[]"-only transcription). CREPE never
/// surfaces this, because it z-score normalizes every frame internally,
/// which is how the very same recording can produce real pitch data and
/// zero recognized words.
///
/// Deliberately conservative: an already-loud recording is returned
/// untouched, something at the noise floor is left alone (there'd be
/// nothing but hiss to amplify, and a model handed loud hiss is more
/// likely to hallucinate words than to stay silent), and the gain is
/// capped for the same reason. Non-destructive — only the temporary copy
/// handed to Whisper is affected, never the audio that gets saved or
/// played back.
Uint8List normalizeWavForSpeech(Uint8List wav) {
  final dataOffset = _findWavDataOffset(wav);
  if (dataOffset == null) return wav;

  final bd = ByteData.sublistView(wav);
  var peak = 0;
  for (var i = dataOffset; i + 1 < wav.length; i += 2) {
    final sample = bd.getInt16(i, Endian.little).abs();
    if (sample > peak) peak = sample;
  }
  if (peak == 0) return wav;

  final peakDbfs = 20 * math.log(peak / 32768) / math.ln10;

  // Below roughly -58 dBFS there is no voice to recover, only noise floor.
  const silenceFloor = 40;
  if (peak < silenceFloor) {
    debugPrint('Whisper input left as-is: essentially silent '
        '(peak=$peak, ${peakDbfs.toStringAsFixed(1)} dBFS)');
    return wav;
  }

  const targetPeak = 31130; // ~0.95 full scale, leaves a little headroom
  const maxGain = 20.0; // ~26 dB ceiling
  final gain = (targetPeak / peak).clamp(1.0, maxGain);
  if (gain <= 1.05) {
    debugPrint('Whisper input already at a good level '
        '(peak=$peak, ${peakDbfs.toStringAsFixed(1)} dBFS)');
    return wav;
  }

  final out = Uint8List.fromList(wav);
  final outBd = ByteData.sublistView(out);
  for (var i = dataOffset; i + 1 < wav.length; i += 2) {
    final scaled = (bd.getInt16(i, Endian.little) * gain).round();
    outBd.setInt16(i, scaled.clamp(-32768, 32767), Endian.little);
  }

  debugPrint('Whisper input normalized: peak=$peak '
      '(${peakDbfs.toStringAsFixed(1)} dBFS) → gain ×${gain.toStringAsFixed(1)}');
  return out;
}

/// Seconds of audio in a 16 kHz mono PCM16 WAV of [wavByteCount] bytes.
///
/// The header is a rounding error at these sizes, so it is not subtracted
/// — this is a budget, not a measurement.
double _wavSeconds(int wavByteCount) => wavByteCount / (16000 * 2);

/// How long to allow one Whisper decode of [wavByteCount] bytes of audio.
///
/// This used to be a flat 90 seconds, which is roughly where a full
/// karaoke take lands: ggml-tiny runs at something like 2–4x realtime on a
/// mid-range Android phone, so a three-to-four minute song is right at the
/// edge. Over the line the decode was abandoned, [_transcribePass]
/// returned null, and the result screen showed no words at all — with
/// nothing on screen distinguishing "the model heard nothing" from "we
/// stopped listening". Short takes were unaffected, which is why it
/// looked intermittent.
///
/// Scaled with the audio and generously, because the cost of being wrong
/// in this direction is a longer wait, and the cost of being wrong in the
/// other direction is losing the transcript entirely.
///
/// Public because the screens that run Whisper alongside pitch analysis
/// bound the pair as well, and an outer cap shorter than this one would
/// cancel a decode that was still making progress — which is the bug this
/// replaced, moved one level out.
Duration whisperTimeoutFor(int wavByteCount) {
  final budget = 30 + (_wavSeconds(wavByteCount) * 8).round();
  return Duration(seconds: budget.clamp(90, 1200));
}

/// Whisper's prompt window is small (a few hundred tokens), and anything
/// past it is discarded — so a whole song's lyrics can't be handed over
/// wholesale. This trims to a budget that comfortably fits, which is
/// enough to name the vocabulary and spelling the decoder should prefer.
/// Returns null for empty input, matching whisper.cpp's "no prompt".
@visibleForTesting
String? promptFromForTest(String? expectedText) => _promptFrom(expectedText);

String? _promptFrom(String? expectedText) {
  if (expectedText == null) return null;
  final clean = expectedText.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (clean.isEmpty) return null;
  const maxChars = 600;
  if (clean.length <= maxChars) return clean;
  // Cut on a word boundary; a half-word would just be noise to bias on.
  final cut = clean.lastIndexOf(' ', maxChars);
  return clean.substring(0, cut > 0 ? cut : maxChars);
}

/// Everything one Whisper pass produced, before any of this app's
/// filtering.
///
/// [rawText] is the decoder's own full transcription string — the same
/// value the log line reports as `rawText=`. It is kept alongside
/// [segments] because measurement needs the unfiltered output: scoring
/// the word list instead would score this app's `_looksLikeRealWord`
/// filter as much as the model, and a change that only moved the filter
/// would look like a change in accuracy.
class WhisperPass {
  /// The decoder's full output, untrimmed and unfiltered.
  final String rawText;

  /// Word-level segments, as whisper.cpp emitted them.
  final List<WhisperTranscribeSegment> segments;

  /// Wall-clock time the native decode took, for reporting throughput.
  final int elapsedMs;

  const WhisperPass({
    required this.rawText,
    required this.segments,
    required this.elapsedMs,
  });
}

/// Runs Whisper over [recordedWavBytes] and returns raw word-level segments,
/// with no alignment against any expected/reference text. Shared by
/// [transcribeWords] and [transcribeForEvaluation].
///
/// [expectedText] becomes Whisper's `initialPrompt`, and only
/// [transcribeForEvaluation] passes it — the app's own callers cannot,
/// because [transcribeWords] does not take it. See the note at the call
/// site for why that matters.
///
/// Returns null if transcription fails or produces nothing usable.
Future<WhisperPass?> _transcribePass(
  Uint8List recordedWavBytes, {
  String lang = 'tl',
  String? expectedText,
}) async {
  File? tempWav;
  try {
    // Stages the bundled model (assets/models/huni_whisper.bin) at the
    // local path transcribe() reads from — throws if that fails, rather
    // than silently letting transcribe() try to read a missing file.
    // Deliberately NOT calling WhisperController().downloadModel() here:
    // that method falls back to an unguarded, no-timeout HttpClient
    // network fetch whenever it doesn't find a file already staged, which
    // can hang indefinitely on a device with no/flaky connectivity — this
    // app is meant to work fully offline, so that fallback should never
    // even be reachable. transcribe() itself calls initModel() internally
    // and resolves the same local path on its own, so nothing is lost by
    // skipping it.
    await _ensureBundledWhisperModel();

    final dir = await getTemporaryDirectory();
    tempWav = File('${dir.path}/huni_whisper_${DateTime.now().microsecondsSinceEpoch}.wav');
    await tempWav.writeAsBytes(
      normalizeWavForSpeech(recordedWavBytes),
      flush: true,
    );

    // Hard ceiling so a stuck native decode (bad/edge-case audio, or any
    // other unforeseen hang) can never leave the result screen waiting
    // forever — surfaces as a normal "transcription failed" instead.
    final sw = Stopwatch()..start();
    final result = await WhisperController().transcribe(
      model: WhisperModel.tiny,
      audioPath: tempWav.path,
      lang: lang,
      withSegments: true,
      splitOnWord: true,
      // Null on every production path: [transcribeWords] takes no
      // expected text, so only [transcribeForEvaluation] can set this,
      // where the prompt is a deliberate experimental variable. Biasing
      // the decode toward the lyrics would make a displayed transcript
      // partly an echo of them, and a clip's reference must never reach
      // this — it would flatter the measurement with the answer.
      initialPrompt: _promptFrom(expectedText),
      // Stops the decoder carrying one segment's output into the next.
      // Singing is slow and repetitive, which is exactly the condition
      // where that carry-over turns into invented repetition.
      noContext: true,
      // The take that returned " [] [] [] [] []" was non-speech
      // annotation tokens, not words. They never survive the word filter
      // anyway, so there is nothing to lose by not generating them.
      suppressNonSpeechTokens: true,
      // Without this the model is re-read from disk on every call, which
      // was a large part of why a 15-second take took 41 seconds.
      keepModelLoaded: true,
    ).timeout(whisperTimeoutFor(recordedWavBytes.length));
    final audioSeconds = _wavSeconds(recordedWavBytes.length);
    debugPrint('Whisper transcribe() returned after ${sw.elapsedMilliseconds}ms '
        'for ${audioSeconds.toStringAsFixed(1)}s of audio '
        '(${(sw.elapsedMilliseconds / 1000 / math.max(audioSeconds, 0.001)).toStringAsFixed(2)}x realtime), '
        'rawText="${result?.transcription.text}"');

    final segments = result?.transcription.segments;
    if (segments == null || segments.isEmpty) {
      debugPrint('Whisper produced no segments.');
      return null;
    }
    debugPrint('Whisper segments (${segments.length}): '
        '${segments.map((s) => '"${s.text}"').join(', ')}');
    return WhisperPass(
      rawText: result?.transcription.text ?? '',
      segments: segments,
      elapsedMs: sw.elapsedMilliseconds,
    );
  } catch (e, st) {
    debugPrint('Whisper transcription failed: $e\n$st');
    return null;
  } finally {
    // Two files to clean up, not one. whisper_ggml runs every input
    // through FFmpeg before decoding it — unconditionally, even though
    // what it is asked to produce here (16 kHz mono PCM16) is exactly
    // what it was handed — and writes the result beside the original as
    // `<path>.wav`. Nothing deletes that, so before this each
    // transcription left a second full copy of the recording in the
    // temp directory for the rest of the session.
    for (final file in [tempWav, if (tempWav != null) File('${tempWav.path}.wav')]) {
      if (file == null) continue;
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
  }
}

/// Puts the app's bundled ggml-tiny model (assets/models/huni_whisper.bin)
/// at the exact local path whisper_ggml's [WhisperController.transcribe]
/// reads from, if it isn't there yet — this app is meant to work fully
/// offline, so the model transcribe() ends up using should always be this
/// bundled one, never fetched over the network. Throws if staging fails
/// (missing/unreadable asset, no storage space, permission issue, etc.)
/// instead of silently swallowing it — a caller silently proceeding into
/// transcribe() with no model file actually present is exactly what leads
/// to it hanging or failing in some far less obvious way downstream.
Future<void> _ensureBundledWhisperModel() async {
  final controller = WhisperController();
  final destPath = await controller.getPath(WhisperModel.tiny);
  final destFile = File(destPath);
  final data = await rootBundle.load(_bundledWhisperModelAsset);

  // Existence alone can't tell a fully-staged model apart from a partial
  // one left behind by an earlier interrupted run (app killed mid-copy, or
  // a build from before this method used flush:true/atomic rename) — a
  // partial file here would otherwise be silently treated as "already
  // staged" on every future run and read as the model forever, which
  // reads exactly like "transcription stopped working" with no error.
  if (await destFile.exists() && await destFile.length() == data.lengthInBytes) {
    debugPrint('Whisper model already staged at $destPath (${data.lengthInBytes} bytes).');
    return;
  }

  debugPrint('Staging Whisper model to $destPath (${data.lengthInBytes} bytes)...');
  await destFile.parent.create(recursive: true);
  // Write to a temp file and rename into place — a reader can never race
  // in and see a partially-written file at the real destination path this
  // way, unlike writing destPath directly.
  final tempFile = File('$destPath.tmp');
  await tempFile.writeAsBytes(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    flush: true,
  );
  await tempFile.rename(destPath);
  debugPrint('Whisper model staged successfully.');
}

/// Ensures the Whisper-tiny model is staged ahead of time — copying the
/// bundled asset into place is a cheap no-op once done once, but calling
/// it eagerly (e.g. as soon as a recording screen opens) means that's
/// already done by the time [transcribeWords] actually needs
/// it after the user stops recording. Safe to call and ignore errors from;
/// the real transcribe call will surface any genuine failure.
Future<void> warmUpWhisperModel() async {
  try {
    await _ensureBundledWhisperModel();
  } catch (e) {
    debugPrint('Whisper model warm-up failed (will retry on demand): $e');
  }
}

/// Transcribes [recordedWavBytes] with word-level timestamps, for every
/// mode: the result is shown to the singer as the words we heard them
/// sing, and is never compared or scored against anything.
///
/// Deliberately takes no expected/reference text. It used to accept the
/// song's lyrics and hand them to Whisper as `initialPrompt` to bias
/// decoding, which made sense while the words were being aligned against
/// a reference. Now that they are only displayed, biasing toward the
/// lyrics defeats the one thing the display is for: it would show the
/// expected words to a singer who mumbled or sang the wrong line, and
/// there would be no way to tell that from a correct reading. A rough
/// transcript of what was actually sung is worth more than a polished one
/// that might be echoing the lyrics back.
///
/// Scoring is unaffected either way — it comes from pitch alone.
///
/// Returns an empty list if transcription fails or nothing was recognized.
Future<List<TranscribedWord>> transcribeWords(
  Uint8List recordedWavBytes, {
  String lang = 'tl',
}) async {
  final pass = await _transcribePass(recordedWavBytes, lang: lang);
  if (pass == null) return [];

  final words = <TranscribedWord>[];
  for (final segment in pass.segments) {
    final text = segment.text.trim();
    if (!_looksLikeRealWord(text)) continue;
    words.add(TranscribedWord(
      text: text,
      startTime: segment.fromTs,
      endTime: segment.toTs,
    ));
  }
  return words;
}

/// Transcribes [wavBytes] and hands back the decoder's unfiltered output,
/// for measuring transcription accuracy.
///
/// This exists so a WER figure describes the system that actually ships.
/// It goes through the very same [_transcribePass] as karaoke and
/// freestyle do — same bundled ggml model, same decode flags, same gain
/// normalization, same device — so the only difference between a measured
/// clip and a sung take is where the audio came from. Running a separate
/// Whisper build on a desktop would be easier and would measure something
/// else.
///
/// Returns null when the decode fails or produces nothing, which the
/// caller should record as an empty hypothesis rather than skip: a clip
/// the model returned nothing for is a total word loss, and dropping it
/// would quietly flatter the score.
Future<WhisperPass?> transcribeForEvaluation(
  Uint8List wavBytes, {
  String lang = 'tl',
  String? expectedText,
}) =>
    _transcribePass(wavBytes, lang: lang, expectedText: expectedText);

/// Whisper occasionally emits a token with no real letters or digits at
/// all — a stray symbol, or (on quiet/ambiguous audio, a known whisper.cpp
/// failure mode where it hallucinates a repeated garbage token instead of
/// staying silent) an unprintable glyph the device's font can't render
/// (shows as a "tofu" box). Filtering these out here, at the one place all
/// transcription flows through, keeps that from being displayed anywhere
/// as if it were a real recognized word. Legitimate non-speech annotations
/// like "[breath]" or "(laughs)" still have real letters and pass through
/// untouched — this isn't a blanket ban on bracketed text, just on text
/// that isn't actually text.
bool _looksLikeRealWord(String text) =>
    RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(text);
