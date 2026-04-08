/// Generates and plays a reference sine-wave tone at any frequency.
///
/// Uses just_audio with a custom StreamAudioSource that builds a WAV file
/// in memory — no audio assets needed.
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:just_audio/just_audio.dart';

class ToneGenerator {
  final AudioPlayer _player = AudioPlayer();

  /// Play a reference tone at [frequency] Hz for [durationMs] milliseconds.
  Future<void> playTone(double frequency, {int durationMs = 1200}) async {
    try {
      await _player.stop();
      await _player.setAudioSource(
        _SineToneSource(frequency: frequency, durationMs: durationMs),
      );
      await _player.play();
    } catch (_) {
      // Swallow errors silently in MVP — tone playing is a bonus feature
    }
  }

  /// Stop any currently playing tone.
  Future<void> stop() => _player.stop();

  void dispose() => _player.dispose();
}

// ── Internal sine-wave audio source ──────────────────────────────────────────
// ignore: experimental_member_use
class _SineToneSource extends StreamAudioSource {
  final double frequency;
  final int durationMs;
  static const int _sampleRate = 44100;

  _SineToneSource({required this.frequency, required this.durationMs});

  /// Build a minimal valid WAV file containing a pure sine wave.
  Uint8List _buildWav() {
    final numSamples = _sampleRate * durationMs ~/ 1000;
    const channels = 1;
    const bitsPerSample = 16;
    const byteRate = _sampleRate * channels * bitsPerSample ~/ 8;
    const blockAlign = channels * bitsPerSample ~/ 8;
    final dataSize = numSamples * blockAlign;
    final fileSize = 44 + dataSize; // 44-byte WAV header

    final bytes = ByteData(fileSize);
    int offset = 0;

    // RIFF chunk descriptor
    _setFourCC(bytes, offset, 'RIFF');
    offset += 4;
    bytes.setUint32(offset, fileSize - 8, Endian.little);
    offset += 4;
    _setFourCC(bytes, offset, 'WAVE');
    offset += 4;

    // fmt sub-chunk
    _setFourCC(bytes, offset, 'fmt ');
    offset += 4;
    bytes.setUint32(offset, 16, Endian.little);
    offset += 4; // sub-chunk size
    bytes.setUint16(offset, 1, Endian.little);
    offset += 2; // PCM = 1
    bytes.setUint16(offset, channels, Endian.little);
    offset += 2;
    bytes.setUint32(offset, _sampleRate, Endian.little);
    offset += 4;
    bytes.setUint32(offset, byteRate, Endian.little);
    offset += 4;
    bytes.setUint16(offset, blockAlign, Endian.little);
    offset += 2;
    bytes.setUint16(offset, bitsPerSample, Endian.little);
    offset += 2;

    // data sub-chunk
    _setFourCC(bytes, offset, 'data');
    offset += 4;
    bytes.setUint32(offset, dataSize, Endian.little);
    offset += 4;

    // Sine wave samples with short fade-in/fade-out to avoid audible clicks
    const fadeSamples = 441; // 10 ms at 44100 Hz
    for (int i = 0; i < numSamples; i++) {
      double amplitude = 0.6;
      if (i < fadeSamples) amplitude *= i / fadeSamples;
      if (i > numSamples - fadeSamples) {
        amplitude *= (numSamples - i) / fadeSamples;
      }
      final sample =
          (sin(2 * pi * frequency * i / _sampleRate) * amplitude * 32767)
              .round()
              .clamp(-32768, 32767);
      bytes.setInt16(offset, sample, Endian.little);
      offset += 2;
    }

    return bytes.buffer.asUint8List();
  }

  void _setFourCC(ByteData bd, int offset, String text) {
    for (int i = 0; i < 4; i++) {
      bd.setUint8(offset + i, text.codeUnitAt(i));
    }
  }

  @override
  // ignore: experimental_member_use
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final data = _buildWav();
    final s = start ?? 0;
    final e = end ?? data.length;
    // ignore: experimental_member_use
    return StreamAudioResponse(
      sourceLength: data.length,
      contentLength: e - s,
      offset: s,
      contentType: 'audio/wav',
      stream: Stream.value(data.sublist(s, e)),
    );
  }
}
