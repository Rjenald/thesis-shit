/// Writes raw 16-bit PCM mono samples to a valid .wav file.
///
/// AudioService records at 16 kHz mono PCM16 — exactly what Whisper expects.
/// We just have to prepend the standard 44-byte RIFF/WAVE header.
library;

import 'dart:io';
import 'dart:typed_data';

class WavWriter {
  static const int _sampleRate = 16000;
  static const int _numChannels = 1;
  static const int _bitsPerSample = 16;

  /// Saves the given PCM byte stream as a `.wav` at `outPath`.
  /// Returns the file you can hand straight to WhisperService.transcribe().
  static Future<File> save(List<int> pcmBytes, String outPath) async {
    final pcmLen = pcmBytes.length;
    final byteRate = _sampleRate * _numChannels * _bitsPerSample ~/ 8;
    final blockAlign = _numChannels * _bitsPerSample ~/ 8;

    final header = ByteData(44)
      // RIFF chunk
      ..setUint8(0, 0x52) // R
      ..setUint8(1, 0x49) // I
      ..setUint8(2, 0x46) // F
      ..setUint8(3, 0x46) // F
      ..setUint32(4, 36 + pcmLen, Endian.little)
      ..setUint8(8,  0x57) // W
      ..setUint8(9,  0x41) // A
      ..setUint8(10, 0x56) // V
      ..setUint8(11, 0x45) // E
      // fmt subchunk
      ..setUint8(12, 0x66) // f
      ..setUint8(13, 0x6d) // m
      ..setUint8(14, 0x74) // t
      ..setUint8(15, 0x20) // (space)
      ..setUint32(16, 16, Endian.little)          // PCM header size
      ..setUint16(20, 1, Endian.little)           // format = PCM
      ..setUint16(22, _numChannels, Endian.little)
      ..setUint32(24, _sampleRate, Endian.little)
      ..setUint32(28, byteRate, Endian.little)
      ..setUint16(32, blockAlign, Endian.little)
      ..setUint16(34, _bitsPerSample, Endian.little)
      // data subchunk
      ..setUint8(36, 0x64) // d
      ..setUint8(37, 0x61) // a
      ..setUint8(38, 0x74) // t
      ..setUint8(39, 0x61) // a
      ..setUint32(40, pcmLen, Endian.little);

    final out = BytesBuilder()
      ..add(header.buffer.asUint8List())
      ..add(pcmBytes);

    final file = File(outPath);
    await file.writeAsBytes(out.takeBytes(), flush: true);
    return file;
  }
}