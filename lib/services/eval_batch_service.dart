import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../core/lyric_alignment_service.dart';

/// Transcribes a folder of WAV clips through the app's own Whisper path and
/// writes the results out as JSON, so transcription accuracy can be
/// measured on the device that ships rather than asserted.
///
/// WHY THIS RUNS ON THE PHONE
/// --------------------------
/// backend/evaluate_transcription.py scores the app's own output. One clip
/// at a time by hand is fine for a dozen takes and impossible for a
/// thousand, which is the only reason this exists — it is the same
/// [transcribeForEvaluation] call the result screens make, in a loop.
///
/// HOW CLIPS GET HERE
/// ------------------
/// Android's scoped storage makes a user-picked folder a SAF URI that
/// `File` cannot open, so this reads a fixed directory under the app's own
/// external files dir, which adb can write to without root:
///
///   adb push clips/. /storage/emulated/0/Android/data/\
///       com.example.final_thesis_ui/files/eval_clips/
///
/// backend/fetch_eval_datasets.py produces exactly that folder.
class EvalBatchService {
  /// Folder name under the app's external files dir holding the clips.
  static const folderName = 'eval_clips';

  /// Written next to the clips. `--merge` in the Python harness reads it.
  static const outputName = 'hypotheses.json';

  /// Optional, written by the dataset fetcher: per-clip language and
  /// prompt. Absent is fine — then every clip uses the batch default.
  static const clipsName = 'clips.json';

  /// The directory this scans, created if missing. Null when the device
  /// exposes no external storage, which no supported Android does.
  static Future<Directory?> clipsDir() async {
    final base = await getExternalStorageDirectory();
    if (base == null) return null;
    final dir = Directory('${base.path}/$folderName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// True for a WAV that should be transcribed as a clip.
  ///
  /// Leading-underscore names are skipped: the dataset fetcher stages each
  /// download through a `_tmp_fsc.wav` in the same folder, and an
  /// interrupted fetch leaves it behind. Transcribing that would add a
  /// phantom row with no reference to match it.
  @visibleForTesting
  static bool isClipFile(String fileName) =>
      fileName.toLowerCase().endsWith('.wav') && !fileName.startsWith('_');

  /// The WAVs waiting to be transcribed, in a stable order so two runs
  /// produce comparable output.
  static Future<List<File>> listClips() async {
    final dir = await clipsDir();
    if (dir == null) return [];
    final wavs = <File>[];
    await for (final entity in dir.list()) {
      if (entity is File && isClipFile(entity.uri.pathSegments.last)) {
        wavs.add(entity);
      }
    }
    wavs.sort((a, b) => a.path.compareTo(b.path));
    return wavs;
  }

  /// Parses a clips.json body into per-clip settings keyed by clip id.
  ///
  /// Only `lang` and `prompt` are read. `reference` is deliberately never
  /// read here — it is the answer key, and the one way to turn this whole
  /// measurement into a tautology would be to feed it to the decoder. The
  /// omission is the invariant, so it is tested
  /// (test/eval_batch_settings_test.dart) rather than just intended.
  ///
  /// Malformed input yields an empty map rather than throwing: the batch
  /// then runs on its defaults, which is better than refusing to measure
  /// anything.
  @visibleForTesting
  static Map<String, ClipSettings> parseClipSettings(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! List) return {};
      final out = <String, ClipSettings>{};
      for (final entry in decoded) {
        if (entry is! Map) continue;
        final id = entry['id'];
        if (id is! String || id.isEmpty) continue;
        final lang = entry['lang'];
        final prompt = entry['prompt'];
        out[id] = ClipSettings(
          lang: lang is String && lang.isNotEmpty ? lang : null,
          prompt: prompt is String && prompt.isNotEmpty ? prompt : null,
        );
      }
      return out;
    } catch (e) {
      debugPrint('eval: could not parse $clipsName, '
          'falling back to batch defaults: $e');
      return {};
    }
  }

  /// Per-clip settings from [clipsName] if the fetcher wrote one.
  static Future<Map<String, ClipSettings>> _loadSettings(
      Directory dir) async {
    final file = File('${dir.path}/$clipsName');
    if (!await file.exists()) return {};
    return parseClipSettings(await file.readAsString());
  }

  /// Transcribes every clip and writes [outputName] into the same folder.
  ///
  /// [defaultLang] applies to any clip [clipsName] doesn't name.
  ///
  /// A clip's `reference` is never shown to the decoder. Whisper's
  /// `initialPrompt` biases decoding toward the words it is given, so
  /// prompting with the reference transcript would have the model score
  /// near-perfectly on text it was just handed, and the resulting WER
  /// would measure nothing. Only an explicit `prompt` field is passed
  /// through, which exists for measuring the karaoke path honestly —
  /// there the lyrics genuinely are known before the singer starts, so
  /// biasing on them is what ships. Those runs are a separate condition
  /// and have to be reported as one.
  ///
  /// [onProgress] fires after each clip. [shouldCancel] is polled between
  /// clips; a cancelled run still writes what it finished.
  static Future<EvalBatchReport> runBatch({
    String defaultLang = 'tl',
    void Function(EvalBatchProgress)? onProgress,
    bool Function()? shouldCancel,
  }) async {
    final dir = await clipsDir();
    if (dir == null) {
      throw const FileSystemException('No external storage on this device');
    }

    final clips = await listClips();
    final settings = await _loadSettings(dir);
    final results = <Map<String, dynamic>>[];
    var failures = 0;
    final batchWatch = Stopwatch()..start();

    for (var i = 0; i < clips.length; i++) {
      if (shouldCancel?.call() ?? false) break;

      final file = clips[i];
      final id = file.uri.pathSegments.last.replaceAll(
          RegExp(r'\.wav$', caseSensitive: false), '');
      final conf = settings[id];
      final lang = conf?.lang ?? defaultLang;

      String hypothesis = '';
      int elapsedMs = 0;
      String? error;
      var bytes = 0;

      try {
        final wav = await file.readAsBytes();
        bytes = wav.length;
        final pass = await transcribeForEvaluation(
          Uint8List.fromList(wav),
          lang: lang,
          expectedText: conf?.prompt,
        );
        if (pass == null) {
          // Not skipped: nothing recognized is a total word loss, and
          // dropping it would flatter the score.
          failures++;
        } else {
          hypothesis = pass.rawText.trim();
          elapsedMs = pass.elapsedMs;
        }
      } catch (e) {
        failures++;
        error = e.toString();
        debugPrint('eval: $id failed: $e');
      }

      final row = <String, dynamic>{
        'id': id,
        'hypothesis': hypothesis,
        'lang': lang,
        'elapsedMs': elapsedMs,
        'wavBytes': bytes,
      };
      // Flagged so a prompted run can never be mistaken for a clean one.
      if (conf?.prompt != null) row['prompted'] = true;
      if (error != null) row['error'] = error;
      results.add(row);

      onProgress?.call(EvalBatchProgress(
        done: i + 1,
        total: clips.length,
        currentId: id,
        lastHypothesis: hypothesis,
        failures: failures,
      ));
    }

    final report = EvalBatchReport(
      outputPath: '${dir.path}/$outputName',
      transcribed: results.length,
      failures: failures,
      totalClips: clips.length,
      elapsedMs: batchWatch.elapsedMilliseconds,
    );

    final payload = {
      'generatedAt': DateTime.now().toIso8601String(),
      'model': 'bundled ggml tiny multilingual q5_1 (assets/models/'
          'huni_whisper.bin), via whisper_ggml / whisper.cpp on-device',
      'defaultLang': defaultLang,
      'clipsFound': clips.length,
      'transcribed': results.length,
      'failures': failures,
      'batchElapsedMs': report.elapsedMs,
      'results': results,
    };

    await File(report.outputPath).writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
      flush: true,
    );
    debugPrint('eval: wrote ${report.outputPath} '
        '(${results.length} clips, $failures failures)');

    return report;
  }
}

/// What clips.json says about one clip. Notably not its reference — see
/// [EvalBatchService.parseClipSettings].
class ClipSettings {
  /// Whisper language code, or null to use the batch default.
  final String? lang;

  /// Text to bias decoding toward, for measuring the karaoke path where
  /// the lyrics genuinely are known before the singer starts. Null for an
  /// ordinary measurement.
  final String? prompt;

  const ClipSettings({this.lang, this.prompt});
}

/// Progress after one clip, for the screen to render.
class EvalBatchProgress {
  final int done;
  final int total;
  final String currentId;
  final String lastHypothesis;
  final int failures;

  const EvalBatchProgress({
    required this.done,
    required this.total,
    required this.currentId,
    required this.lastHypothesis,
    required this.failures,
  });
}

/// What a finished (or cancelled) batch produced.
class EvalBatchReport {
  final String outputPath;
  final int transcribed;
  final int failures;
  final int totalClips;
  final int elapsedMs;

  const EvalBatchReport({
    required this.outputPath,
    required this.transcribed,
    required this.failures,
    required this.totalClips,
    required this.elapsedMs,
  });

  /// True when the run stopped before reaching every clip.
  bool get incomplete => transcribed < totalClips;
}
