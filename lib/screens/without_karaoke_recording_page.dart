import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../constants/app_colors.dart';
import '../core/audio_service.dart';
import '../core/note_utils.dart';
import '../services/recording_storage_service.dart';
import 'save_record_page.dart';

class WithoutKaraokeRecordingPage extends StatefulWidget {
  const WithoutKaraokeRecordingPage({super.key});

  @override
  State<WithoutKaraokeRecordingPage> createState() =>
      _WithoutKaraokeRecordingPageState();
}

class _WithoutKaraokeRecordingPageState
    extends State<WithoutKaraokeRecordingPage>
    with TickerProviderStateMixin {
  // ── Audio ──────────────────────────────────────────────────────────────────
  final AudioService _audioService = AudioService();
  StreamSubscription<NoteResult?>? _audioSub;
  StreamSubscription<List<int>>? _bytesSub;

  bool _isRecording = false;
  bool _isSaving = false;

  // PCM buffer for WAV export
  final List<int> _recordedPcm = [];

  // ── Timer ──────────────────────────────────────────────────────────────────
  int _seconds = 0;
  Timer? _timer;
  String get _timerText {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── Live pitch state ───────────────────────────────────────────────────────
  String _noteDisplay = '--';
  String _freqDisplay = '';
  double _cents = 0.0;
  double _clarity = 0.0; // CREPE confidence 0.0–1.0
  PitchFeedback _feedback = PitchFeedback.noSignal;

  // ── Waveform bars ──────────────────────────────────────────────────────────
  static const int _barCount = 30;
  final List<double> _bars = List.filled(_barCount, 0.05);
  late AnimationController _idleController;
  Timer? _waveTimer;

  @override
  void initState() {
    super.initState();
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _idleController.dispose();
    _waveTimer?.cancel();
    _timer?.cancel();
    _audioSub?.cancel();
    _bytesSub?.cancel();
    _audioService.dispose();
    super.dispose();
  }

  // ── Record toggle ──────────────────────────────────────────────────────────
  Future<void> _toggleRecording() async {
    if (_isRecording) {
      // Stop
      await _bytesSub?.cancel();
      _bytesSub = null;
      await _audioSub?.cancel();
      _audioSub = null;
      await _audioService.stop();
      _timer?.cancel();
      _waveTimer?.cancel();

      final durationSecs = _seconds;
      final pcmSnapshot = List<int>.from(_recordedPcm);

      setState(() {
        _isRecording = false;
        _isSaving = true;
        _seconds = 0;
        _noteDisplay = '--';
        _freqDisplay = '';
        _cents = 0.0;
        _clarity = 0.0;
        _feedback = PitchFeedback.noSignal;
        for (int i = 0; i < _barCount; i++) {
          _bars[i] = 0.05;
        }
      });

      if (pcmSnapshot.isNotEmpty && durationSecs >= 1) {
        await _saveWav(pcmSnapshot, durationSecs);
      }

      if (mounted) setState(() => _isSaving = false);
    } else {
      // Start
      _recordedPcm.clear();
      final started = await _audioService.start();
      if (!started) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission denied')),
          );
        }
        return;
      }

      setState(() => _isRecording = true);

      // Buffer raw PCM for saving
      _bytesSub = _audioService.rawBytes.listen((bytes) {
        _recordedPcm.addAll(bytes);
      });

      // Timer
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _seconds++);
      });

      // Waveform ticker (~30fps)
      _waveTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
        if (!mounted) return;
        setState(() {
          for (int i = 0; i < _barCount - 1; i++) {
            _bars[i] = _bars[i + 1];
          }
          final base = _feedback == PitchFeedback.noSignal ? 0.05 : 0.2;
          final noise =
              Random().nextDouble() *
              (_feedback == PitchFeedback.noSignal ? 0.05 : 0.6);
          _bars[_barCount - 1] = (base + noise).clamp(0.03, 1.0);
        });
      });

      // Pitch stream
      _audioSub = _audioService.results.listen((result) {
        if (!mounted) return;
        if (result == null) {
          setState(() {
            _noteDisplay = '--';
            _freqDisplay = '';
            _feedback = PitchFeedback.noSignal;
            _clarity = 0.0;
          });
          return;
        }
        setState(() {
          _noteDisplay = result.fullName;
          _freqDisplay = '${result.frequency.toStringAsFixed(1)} Hz';
          _cents = result.cents;
          _clarity = result.confidence;
          _feedback = result.feedback;
        });
      });
    }
  }

  // ── WAV file builder ───────────────────────────────────────────────────────
  Future<void> _saveWav(List<int> pcm, int durationSecs) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      final path = '${dir.path}/recording_$id.wav';

      final wavBytes = _buildWavBytes(pcm, sampleRate: 44100, channels: 1);
      await File(path).writeAsBytes(wavBytes);

      final now = DateTime.now();
      final title =
          'Recording ${now.year}-${_pad(now.month)}-${_pad(now.day)} '
          '${_pad(now.hour)}:${_pad(now.minute)}';

      await RecordingStorageService.saveRecording(
        RecordingEntry(
          id: id,
          title: title,
          filePath: path,
          durationSeconds: durationSecs,
          createdAt: now,
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recording saved!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }

  String _pad(int v) => v.toString().padLeft(2, '0');

  Uint8List _buildWavBytes(
    List<int> pcm, {
    required int sampleRate,
    required int channels,
  }) {
    const bitsPerSample = 16;
    final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    final blockAlign = channels * bitsPerSample ~/ 8;
    final dataLength = pcm.length;
    final buf = ByteData(44 + dataLength);

    // RIFF chunk
    buf.setUint8(0, 0x52); // R
    buf.setUint8(1, 0x49); // I
    buf.setUint8(2, 0x46); // F
    buf.setUint8(3, 0x46); // F
    buf.setUint32(4, 36 + dataLength, Endian.little);
    buf.setUint8(8, 0x57);  // W
    buf.setUint8(9, 0x41);  // A
    buf.setUint8(10, 0x56); // V
    buf.setUint8(11, 0x45); // E
    // fmt sub-chunk
    buf.setUint8(12, 0x66); // f
    buf.setUint8(13, 0x6D); // m
    buf.setUint8(14, 0x74); // t
    buf.setUint8(15, 0x20); // space
    buf.setUint32(16, 16, Endian.little);
    buf.setUint16(20, 1, Endian.little); // PCM
    buf.setUint16(22, channels, Endian.little);
    buf.setUint32(24, sampleRate, Endian.little);
    buf.setUint32(28, byteRate, Endian.little);
    buf.setUint16(32, blockAlign, Endian.little);
    buf.setUint16(34, bitsPerSample, Endian.little);
    // data sub-chunk
    buf.setUint8(36, 0x64); // d
    buf.setUint8(37, 0x61); // a
    buf.setUint8(38, 0x74); // t
    buf.setUint8(39, 0x61); // a
    buf.setUint32(40, dataLength, Endian.little);
    for (int i = 0; i < dataLength; i++) {
      buf.setUint8(44 + i, pcm[i] & 0xFF);
    }
    return buf.buffer.asUint8List();
  }

  // ── Feedback helpers ───────────────────────────────────────────────────────

  /// Colour for CREPE confidence bar: green ≥80%, yellow ≥55%, red below.
  Color get _clarityColor {
    if (_clarity >= 0.80) return const Color(0xFF4CAF50); // green
    if (_clarity >= 0.55) return Colors.orangeAccent; // yellow
    return const Color(0xFFF44336); // red
  }

  Color get _feedbackColor {
    switch (_feedback) {
      case PitchFeedback.correct:
        return AppColors.primaryCyan;
      case PitchFeedback.tooHigh:
        return Colors.orangeAccent;
      case PitchFeedback.tooLow:
        return Colors.blueAccent;
      case PitchFeedback.noSignal:
        return AppColors.grey;
    }
  }

  String get _feedbackLabel {
    switch (_feedback) {
      case PitchFeedback.correct:
        return 'In Tune ✓';
      case PitchFeedback.tooHigh:
        return 'Too High ↑';
      case PitchFeedback.tooLow:
        return 'Too Low ↓';
      case PitchFeedback.noSignal:
        return _isRecording ? 'Listening...' : '';
    }
  }

  // ── Exit dialog ────────────────────────────────────────────────────────────
  void _showExitDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Sure you want to exit?',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(dialogCtx);
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Yes',
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: const Text(
                      'No',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: AppColors.white,
                      size: 26,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Record',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                      fontFamily: 'Roboto',
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(
                      Icons.menu,
                      color: AppColors.white,
                      size: 26,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SaveRecordPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // ── Center Visualizer ────────────────────────────────────────────
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ── Live note name ─────────────────────────────────────────
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontSize: 72,
                      fontWeight: FontWeight.bold,
                      color: _isRecording ? _feedbackColor : AppColors.grey,
                      fontFamily: 'Roboto',
                    ),
                    child: Text(_noteDisplay),
                  ),

                  const SizedBox(height: 4),

                  // Frequency + feedback label
                  if (_isRecording)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_freqDisplay.isNotEmpty) ...[
                          Text(
                            _freqDisplay,
                            style: TextStyle(
                              color: AppColors.grey.withValues(alpha: 0.75),
                              fontSize: 14,
                              fontFamily: 'Roboto',
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Text(
                          _feedbackLabel,
                          style: TextStyle(
                            color: _feedbackColor,
                            fontSize: 14,
                            fontFamily: 'Roboto',
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 28),

                  // ── Waveform bars ──────────────────────────────────────────
                  SizedBox(
                    width: 260,
                    height: 80,
                    child: _isRecording
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: List.generate(_barCount, (i) {
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 30),
                                width: 5,
                                height: 80 * _bars[i],
                                decoration: BoxDecoration(
                                  color: _feedbackColor.withValues(
                                    alpha: 0.4 + _bars[i] * 0.6,
                                  ),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              );
                            }),
                          )
                        // Idle: gentle pulsing crosshair
                        : CustomPaint(
                            painter: _CrosshairPainter(),
                            size: const Size(260, 80),
                          ),
                  ),

                  const SizedBox(height: 28),

                  // ── Cents meter (only while recording) ────────────────────
                  if (_isRecording)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Flat',
                                style: TextStyle(
                                  color: AppColors.grey.withValues(alpha: 0.6),
                                  fontSize: 11,
                                  fontFamily: 'Roboto',
                                ),
                              ),
                              Text(
                                '${_cents.toStringAsFixed(1)} cents',
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 11,
                                  fontFamily: 'Roboto',
                                ),
                              ),
                              Text(
                                'Sharp',
                                style: TextStyle(
                                  color: AppColors.grey.withValues(alpha: 0.6),
                                  fontSize: 11,
                                  fontFamily: 'Roboto',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (_cents.clamp(-50, 50) + 50) / 100,
                              minHeight: 7,
                              backgroundColor: AppColors.inputBg,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _feedbackColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 16),

                  // ── Voice Clarity (CREPE confidence) ──────────────────────
                  if (_isRecording)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.graphic_eq,
                                    size: 12,
                                    color: AppColors.primaryCyan,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Voice Clarity',
                                    style: TextStyle(
                                      color: AppColors.grey.withValues(
                                        alpha: 0.7,
                                      ),
                                      fontSize: 11,
                                      fontFamily: 'Roboto',
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '${(_clarity * 100).round()}%',
                                style: TextStyle(
                                  color: _clarityColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Roboto',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _clarity,
                              minHeight: 7,
                              backgroundColor: AppColors.inputBg,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _clarityColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 16),

                  // ── Timer ──────────────────────────────────────────────────
                  Text(
                    _timerText,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: AppColors.white,
                      fontFamily: 'Roboto',
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            // ── Bottom Controls ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(bottom: 48),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Mic icon (decorative — shows recording state)
                  Icon(
                    _isRecording ? Icons.mic : Icons.mic_none,
                    color: _isRecording
                        ? AppColors.primaryCyan
                        : AppColors.white.withValues(alpha: 0.4),
                    size: 36,
                  ),

                  const SizedBox(width: 48),

                  // Record / Stop button
                  GestureDetector(
                    onTap: (_isSaving) ? null : _toggleRecording,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isRecording
                            ? Colors.red.withValues(alpha: 0.75)
                            : Colors.red,
                        boxShadow: _isRecording
                            ? [
                                BoxShadow(
                                  color: Colors.red.withValues(alpha: 0.5),
                                  blurRadius: 16,
                                  spreadRadius: 4,
                                ),
                              ]
                            : [],
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Icon(
                              _isRecording
                                  ? Icons.stop
                                  : Icons.fiber_manual_record,
                              color: Colors.white,
                              size: 30,
                            ),
                    ),
                  ),

                  const SizedBox(width: 48),

                  // Exit button
                  GestureDetector(
                    onTap: _showExitDialog,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.black,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Static crosshair (idle state) ─────────────────────────────────────────────
class _CrosshairPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
