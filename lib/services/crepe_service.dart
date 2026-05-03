import 'dart:math';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Result from one CREPE pitch detection frame
class CrepeResult {
  final double frequencyHz;   // detected pitch in Hz
  final double confidence;    // how confident (0.0 to 1.0)
  final bool isVoiced;        // true if singing detected

  const CrepeResult({
    required this.frequencyHz,
    required this.confidence,
    required this.isVoiced,
  });

  /// Convert Hz to musical note name (e.g. 440 Hz → "A4")
  String get noteName {
    if (frequencyHz <= 0) return '';
    const noteNames = [
      'C', 'C#', 'D', 'D#', 'E', 'F',
      'F#', 'G', 'G#', 'A', 'A#', 'B'
    ];
    final midiNote = (69 + 12 * log(frequencyHz / 440.0) / log(2)).round();
    final octave = (midiNote / 12).floor() - 1;
    final name = noteNames[midiNote % 12];
    return '$name$octave';
  }

  /// How many cents flat/sharp vs a reference pitch
  /// Negative = flat, Positive = sharp
  double centsVs(double referenceHz) {
    if (frequencyHz <= 0 || referenceHz <= 0) return 0;
    return 1200 * log(frequencyHz / referenceHz) / log(2);
  }
}

class CrepeService {
  Interpreter? _interpreter;
  bool _isInitialized = false;

  static const int frameSize = 1024;  // CREPE input size
  static const int nBins = 360;       // CREPE output bins
  static const double minPitchHz = 32.70;   // C1
  static const double maxPitchHz = 1975.5;  // B6
  static const double confidenceThreshold = 0.5;

  /// Load the TFLite model from assets
  Future<void> initialize() async {
    try {
      _interpreter = await Interpreter.fromAsset(
        'models/huni_crepe.tflite',
      );
      _isInitialized = true;
      print('✅ CREPE model loaded successfully');
      print('   Input:  ${_interpreter!.getInputTensor(0).shape}');
      print('   Output: ${_interpreter!.getOutputTensor(0).shape}');
    } catch (e) {
      print('❌ Failed to load CREPE model: $e');
      _isInitialized = false;
    }
  }

  /// Detect pitch from a 1024-sample audio frame
  /// audioFrame must be exactly 1024 float32 samples at 16kHz
  CrepeResult? detectPitch(List<double> audioFrame) {
    if (!_isInitialized || _interpreter == null) {
      print('⚠️ CREPE not initialized');
      return null;
    }

    if (audioFrame.length != frameSize) {
      print('⚠️ Frame size mismatch: got ${audioFrame.length}, need $frameSize');
      return null;
    }

    // --- Normalize the frame (same as training) ---
    double mean = audioFrame.reduce((a, b) => a + b) / audioFrame.length;
    List<double> normalized = audioFrame.map((s) => s - mean).toList();
    double variance = normalized
        .map((s) => s * s)
        .reduce((a, b) => a + b) / normalized.length;
    double std = sqrt(variance);
    if (std > 1e-6) {
      normalized = normalized.map((s) => s / std).toList();
    }

    // --- Prepare input tensor: shape [1, 1024, 1] ---
    final input = [
      normalized.map((s) => [s]).toList()
    ];

    // --- Prepare output tensor: shape [1, 360] ---
    final output = [List<double>.filled(nBins, 0.0)];

    // --- Run CREPE inference ---
    _interpreter!.run(input, output);

    // --- Read 360 bin probabilities ---
    final bins = output[0];

    // --- Find highest confidence bin ---
    int maxBin = 0;
    double maxConf = bins[0];
    for (int i = 1; i < nBins; i++) {
      if (bins[i] > maxConf) {
        maxConf = bins[i];
        maxBin = i;
      }
    }

    // --- Convert bin index to Hz ---
    // CREPE covers C1 (32.7 Hz) to B6 (1975.5 Hz) across 360 bins
    final cents = maxBin * (6000.0 / (nBins - 1));
    final hz = minPitchHz * pow(2, cents / 1200.0);

    return CrepeResult(
      frequencyHz: hz,
      confidence: maxConf,
      isVoiced: maxConf >= confidenceThreshold,
    );
  }

  void dispose() {
    _interpreter?.close();
    _isInitialized = false;
  }
}