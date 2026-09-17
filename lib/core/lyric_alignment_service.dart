/// On-device lyric alignment using Whisper-Tiny (whisper_ggml / whisper.cpp).
///
/// Transcribes the just-recorded mic audio with word-level timestamps, then
/// aligns each recognized word against the reference lyric text using a
/// greedy, time-anchored fuzzy match (recognized words are naturally
/// time-ordered like the reference lyrics, so this avoids full sequence
/// alignment while still handling repeated words/choruses correctly, since
/// a match is only accepted within a few seconds of where that lyric word
/// was expected).
library;

import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:whisper_ggml/whisper_ggml.dart';
import '../services/lyrics_service.dart' show LrcLine;

const _bundledWhisperModelAsset = 'assets/models/huni_whisper.bin';

class AlignedWord {
  final String expectedWord;
  final Duration expectedTime;
  final String? recognizedWord;
  final Duration? recognizedTime;

  const AlignedWord({
    required this.expectedWord,
    required this.expectedTime,
    this.recognizedWord,
    this.recognizedTime,
  });

  bool get matched => recognizedWord != null;

  /// Positive = sung late, negative = sung early.
  int? get timingOffsetMs =>
      matched ? recognizedTime!.inMilliseconds - expectedTime.inMilliseconds : null;

  Map<String, dynamic> toJson() => {
        'expectedWord': expectedWord,
        'expectedTimeMs': expectedTime.inMilliseconds,
        'recognizedWord': recognizedWord,
        'recognizedTimeMs': recognizedTime?.inMilliseconds,
      };

  factory AlignedWord.fromJson(Map<String, dynamic> j) {
    final recognizedMs = j['recognizedTimeMs'] as int?;
    return AlignedWord(
      expectedWord: j['expectedWord'] as String? ?? '',
      expectedTime: Duration(milliseconds: j['expectedTimeMs'] as int? ?? 0),
      recognizedWord: j['recognizedWord'] as String?,
      recognizedTime:
          recognizedMs == null ? null : Duration(milliseconds: recognizedMs),
    );
  }
}

class LyricAlignmentResult {
  final List<AlignedWord> words;
  const LyricAlignmentResult(this.words);

  int get matchedCount => words.where((w) => w.matched).length;
  int get totalCount => words.length;
  double get matchRatePercent => totalCount == 0 ? 0 : matchedCount / totalCount * 100;

  double get avgAbsTimingOffsetMs {
    final offsets = words.where((w) => w.matched).map((w) => w.timingOffsetMs!.abs());
    if (offsets.isEmpty) return 0;
    return offsets.reduce((a, b) => a + b) / offsets.length;
  }

  Map<String, dynamic> toJson() => {
        'words': words.map((w) => w.toJson()).toList(),
      };

  factory LyricAlignmentResult.fromJson(Map<String, dynamic> j) =>
      LyricAlignmentResult(
        (j['words'] as List<dynamic>?)
                ?.map((e) => AlignedWord.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

class _ExpectedWord {
  final String norm;
  final String raw;
  final Duration time;
  const _ExpectedWord(this.norm, this.raw, this.time);
}

class _RecognizedWord {
  final String norm;
  final String raw;
  final Duration time;
  const _RecognizedWord(this.norm, this.raw, this.time);
}

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

/// Runs Whisper over [recordedWavBytes] and returns raw word-level segments,
/// with no alignment against any expected/reference text. Shared by
/// [alignLyrics] (karaoke mode) and [transcribeWords] (reference-free mode).
/// Returns null if transcription fails or produces nothing usable.
Future<List<WhisperTranscribeSegment>?> _transcribeSegments(
  Uint8List recordedWavBytes, {
  String lang = 'tl',
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
    ).timeout(const Duration(seconds: 90));
    debugPrint('Whisper transcribe() returned after ${sw.elapsedMilliseconds}ms, '
        'wavBytes=${recordedWavBytes.length}, '
        'rawText="${result?.transcription.text}"');

    final segments = result?.transcription.segments;
    if (segments == null || segments.isEmpty) {
      debugPrint('Whisper produced no segments.');
      return null;
    }
    debugPrint('Whisper segments (${segments.length}): '
        '${segments.map((s) => '"${s.text}"').join(', ')}');
    return segments;
  } catch (e, st) {
    debugPrint('Whisper transcription failed: $e\n$st');
    return null;
  } finally {
    if (tempWav != null && await tempWav.exists()) {
      try {
        await tempWav.delete();
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
/// already done by the time [transcribeWords]/[alignLyrics] actually need
/// it after the user stops recording. Safe to call and ignore errors from;
/// the real transcribe call will surface any genuine failure.
Future<void> warmUpWhisperModel() async {
  try {
    await _ensureBundledWhisperModel();
  } catch (e) {
    debugPrint('Whisper model warm-up failed (will retry on demand): $e');
  }
}

/// Returns null if transcription fails or produces no usable segments —
/// caller should treat this as "alignment unavailable" and not block on it.
/// Runs its own Whisper transcription pass; if the caller already has
/// [TranscribedWord]s from a separate [transcribeWords] call (e.g. karaoke
/// mode also needs them for pitch-segment word matching), call
/// [alignTranscribedWords] directly instead to avoid transcribing the same
/// audio twice.
Future<LyricAlignmentResult?> alignLyrics({
  required List<LrcLine> lyrics,
  required Uint8List recordedWavBytes,
  required Duration recordStartOffset,
  String lang = 'tl',
}) async {
  final recognized = await transcribeWords(recordedWavBytes, lang: lang);
  if (recognized.isEmpty) return null;
  return alignTranscribedWords(
    lyrics: lyrics,
    recognizedWords: recognized,
    recordStartOffset: recordStartOffset,
  );
}

/// Aligns already-transcribed [recognizedWords] (see [transcribeWords])
/// against the reference [lyrics] — the pure alignment half of
/// [alignLyrics], split out so a caller that already transcribed the
/// recording for another purpose doesn't have to do it again.
LyricAlignmentResult? alignTranscribedWords({
  required List<LrcLine> lyrics,
  required List<TranscribedWord> recognizedWords,
  required Duration recordStartOffset,
}) {
  if (lyrics.isEmpty || recognizedWords.isEmpty) return null;

  final expected = _buildExpectedWords(lyrics);
  final recognized = recognizedWords
      .map((w) => _RecognizedWord(
            _normalize(w.text),
            w.text,
            recordStartOffset + w.startTime,
          ))
      .toList();

  return LyricAlignmentResult(_align(expected, recognized));
}

/// Transcribes [recordedWavBytes] with word-level timestamps and no
/// alignment against any reference lyrics — for reference-free ("without
/// karaoke") recordings where there's nothing to align against.
/// Returns an empty list if transcription fails or nothing was recognized.
Future<List<TranscribedWord>> transcribeWords(
  Uint8List recordedWavBytes, {
  String lang = 'tl',
}) async {
  final segments = await _transcribeSegments(recordedWavBytes, lang: lang);
  if (segments == null) return [];

  final words = <TranscribedWord>[];
  for (final segment in segments) {
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

List<_ExpectedWord> _buildExpectedWords(List<LrcLine> lyrics) {
  final expected = <_ExpectedWord>[];
  for (var i = 0; i < lyrics.length; i++) {
    final line = lyrics[i];
    final words = line.text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) continue;

    final lineStart = line.timestamp;
    final lineEnd = i + 1 < lyrics.length ? lyrics[i + 1].timestamp : lineStart + const Duration(seconds: 5);
    final lineDurMs = (lineEnd - lineStart).inMilliseconds.clamp(500, 20000);

    for (var w = 0; w < words.length; w++) {
      final wordTimeMs = lineStart.inMilliseconds + (lineDurMs * w / words.length).round();
      expected.add(_ExpectedWord(_normalize(words[w]), words[w], Duration(milliseconds: wordTimeMs)));
    }
  }
  return expected;
}

List<AlignedWord> _align(List<_ExpectedWord> expected, List<_RecognizedWord> recognized) {
  const searchWindow = Duration(seconds: 3);
  var rStart = 0;
  final aligned = <AlignedWord>[];

  for (final exp in expected) {
    var bestJ = -1;
    var bestDist = 1 << 30;

    for (var j = rStart; j < recognized.length; j++) {
      final rec = recognized[j];
      final dt = rec.time - exp.time;
      if (dt > searchWindow) break; // recognized words are time-ordered
      if (dt < -searchWindow) continue;

      final dist = _levenshtein(exp.norm, rec.norm);
      final maxAllowed = exp.norm.length <= 3 ? 1 : 2;
      if (dist <= maxAllowed && dist < bestDist) {
        bestDist = dist;
        bestJ = j;
      }
    }

    if (bestJ >= 0) {
      aligned.add(AlignedWord(
        expectedWord: exp.raw,
        expectedTime: exp.time,
        recognizedWord: recognized[bestJ].raw,
        recognizedTime: recognized[bestJ].time,
      ));
      rStart = bestJ + 1;
    } else {
      aligned.add(AlignedWord(expectedWord: exp.raw, expectedTime: exp.time));
    }
  }

  return aligned;
}

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

String _normalize(String s) {
  return s
      .toLowerCase()
      .replaceAll(RegExp(r"[^\w\s']"), '')
      .replaceAll("'", '')
      .trim();
}

int _levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  var prev = List<int>.generate(b.length + 1, (i) => i);
  var curr = List<int>.filled(b.length + 1, 0);

  for (var i = 1; i <= a.length; i++) {
    curr[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      curr[j] = [
        curr[j - 1] + 1,
        prev[j] + 1,
        prev[j - 1] + cost,
      ].reduce((x, y) => x < y ? x : y);
    }
    final tmp = prev;
    prev = curr;
    curr = tmp;
  }
  return prev[b.length];
}
