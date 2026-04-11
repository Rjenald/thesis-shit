import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';

class CrepeDetector {
  Interpreter? _interpreter;
  bool _isLoaded = false;

  static const int frameSize = 1024;
  static const int numBins = 360;
  static const double minHz = 32.7;
  static const double centsPerBin = 20.0;
  static const int _inputRate = 44100;
  static const int _targetRate = 16000;

  final List<double> _accumulator = [];

  Future<void> load() async {
    try {
      _interpreter = await Interpreter.fromAsset(
        'models/crepe_tiny.tflite',
        options: InterpreterOptions()..threads = 2,
      );
      _isLoaded = true;
    } catch (e) {
      _isLoaded = false;
    }
  }

  double? addPcmBytes(Uint8List bytes) {
    if (!_isLoaded || _interpreter == null) return null;

    final bd = bytes.buffer.asByteData(
      bytes.offsetInBytes,
      bytes.lengthInBytes,
    );
    final rawSamples = <double>[];
    for (int i = 0; i + 1 < bytes.length; i += 2) {
      rawSamples.add(bd.getInt16(i, Endian.little) / 32768.0);
    }

    const double ratio = _inputRate / _targetRate;
    for (int outIdx = 0; outIdx < rawSamples.length / ratio; outIdx++) {
      final srcPos = outIdx * ratio;
      final srcIdx = srcPos.floor();
      final frac = srcPos - srcIdx;
      if (srcIdx + 1 < rawSamples.length) {
        final sample =
            rawSamples[srcIdx] * (1.0 - frac) +
            rawSamples[srcIdx + 1] * frac;
        _accumulator.add(sample);
      } else if (srcIdx < rawSamples.length) {
        _accumulator.add(rawSamples[srcIdx]);
      }
    }

    if (_accumulator.length < frameSize) return null;

    final frame = _accumulator.sublist(0, frameSize);
    _accumulator.removeRange(0, frameSize ~/ 2);

    final mean = frame.reduce((a, b) => a + b) / frame.length;
    double variance = 0;
    for (final s in frame) {
      variance += (s - mean) * (s - mean);
    }
    variance /= frame.length;
    final std = variance > 1e-8 ? _sqrt(variance) : 1.0;
    final normalized = frame.map((x) => (x - mean) / std).toList();

    final input = [normalized.map((x) => [x]).toList()];
    final output = [List.filled(numBins, 0.0)];

    try {
      _interpreter!.run(input, output);
    } catch (_) {
      return null;
    }

    final activation = output[0];
    final confidence = activation.reduce((a, b) => a > b ? a : b);
    if (confidence < 0.5) return null;

    final peakBin = activation.indexOf(confidence);

    double weightedBin = 0.0;
    double totalWeight = 0.0;
    final start = (peakBin - 4).clamp(0, numBins - 1);
    final end = (peakBin + 4).clamp(0, numBins - 1);
    for (int i = start; i <= end; i++) {
      weightedBin += i * activation[i];
      totalWeight += activation[i];
    }
    if (totalWeight > 0) weightedBin /= totalWeight;

    final cents = weightedBin * centsPerBin;
    final frequency = minHz * _pow2(cents / 1200.0);

    return frequency;
  }

  double _sqrt(double x) {
    if (x <= 0) return 0;
    double r = x / 2;
    for (int i = 0; i < 20; i++) {
      r = (r + x / r) / 2;
    }
    return r;
  }

  double _pow2(double e) {
    const ln2 = 0.6931471805599453;
    return _exp(e * ln2);
  }

  double _exp(double x) {
    double result = 1.0, term = 1.0;
    for (int i = 1; i < 25; i++) {
      term *= x / i;
      result += term;
    }
    return result;
  }

  void reset() => _accumulator.clear();
  void dispose() => _interpreter?.close();
  bool get isLoaded => _isLoaded;
}