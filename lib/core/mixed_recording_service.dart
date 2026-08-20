/// Mixes a bundled karaoke song asset with a recorded mic WAV into a single
/// file, using ffmpeg. This is what makes the saved recording contain both
/// the song and the singer's voice together, instead of mic-only audio.
library;

import 'dart:io';
import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

/// Returns the mixed WAV bytes, or null if mixing failed for any reason
/// (caller should fall back to the mic-only recording in that case).
Future<Uint8List?> mixSongAndVoice({
  required String songAssetPath,
  required Duration songStartOffset,
  required Uint8List micWavBytes,
  double playbackSpeed = 1.0,
}) async {
  File? songFile, micFile, outFile;
  try {
    final tempDir = await getTemporaryDirectory();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    songFile = File('${tempDir.path}/huni_mix_song_$stamp.mp3');
    micFile = File('${tempDir.path}/huni_mix_mic_$stamp.wav');
    outFile = File('${tempDir.path}/huni_mix_out_$stamp.wav');

    final songBytes = (await rootBundle.load(songAssetPath)).buffer.asUint8List();
    await songFile.writeAsBytes(songBytes, flush: true);
    await micFile.writeAsBytes(micWavBytes, flush: true);

    final startSeconds = (songStartOffset.inMilliseconds / 1000.0).clamp(0.0, double.infinity);
    // The singer heard (and paced themselves to) the song at playbackSpeed,
    // so the exported song segment needs the same tempo applied, or the
    // mixed voice track will drift out of sync with it. atempo is a
    // time-stretch (pitch-corrected) — a reasonable approximation of the
    // "tape slowed down" character heard live, at the tradeoff of matching
    // sync exactly rather than pitch exactly.
    final songFilter = playbackSpeed != 1.0
        ? '[0:a]atempo=${playbackSpeed.toStringAsFixed(3)}[song];'
        : '[0:a]anull[song];';

    final session = await FFmpegKit.executeWithArguments([
      '-y',
      '-ss', startSeconds.toStringAsFixed(3),
      '-i', songFile.path,
      '-i', micFile.path,
      '-filter_complex',
      '$songFilter[song][1:a]amix=inputs=2:duration=shortest[aout]',
      '-map', '[aout]',
      '-ar', '44100',
      '-ac', '2',
      outFile.path,
    ]);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode) && await outFile.exists()) {
      return await outFile.readAsBytes();
    }
    debugPrint('Mix failed: ffmpeg return code $returnCode');
    return null;
  } catch (e) {
    debugPrint('Mix failed: $e');
    return null;
  } finally {
    for (final f in [songFile, micFile, outFile]) {
      if (f != null && await f.exists()) {
        try {
          await f.delete();
        } catch (_) {}
      }
    }
  }
}
