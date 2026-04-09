import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../core/audio_service.dart';
import '../core/note_utils.dart';

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

  bool _isRecording = false;

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
    _audioService.dispose();
    super.dispose();
  }

  // ── Record toggle ──────────────────────────────────────────────────────────
  Future<void> _toggleRecording() async {
    if (_isRecording) {
      // Stop
      await _audioSub?.cancel();
      _audioSub = null;
      await _audioService.stop();
      _timer?.cancel();
      _waveTimer?.cancel();
      setState(() {
        _isRecording = false;
        _seconds = 0;
        _noteDisplay = '--';
        _freqDisplay = '';
        _cents = 0.0;
        _feedback = PitchFeedback.noSignal;
        for (int i = 0; i < _barCount; i++) {
          _bars[i] = 0.05;
        }
      });
    } else {
      // Start
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

      // Timer
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _seconds++);
      });

      // Waveform ticker (updates bars ~30fps)
      _waveTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
        if (!mounted) return;
        setState(() {
          for (int i = 0; i < _barCount - 1; i++) {
            _bars[i] = _bars[i + 1];
          }
          // New bar height based on current signal
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
          });
          return;
        }
        setState(() {
          _noteDisplay = result.fullName;
          _freqDisplay = '${result.frequency.toStringAsFixed(1)} Hz';
          _cents = result.cents;
          _feedback = result.feedback;
        });
      });
    }
  }

  // ── Feedback helpers ───────────────────────────────────────────────────────
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

                  const SizedBox(height: 24),

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
                    onTap: _toggleRecording,
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
                      child: Icon(
                        _isRecording ? Icons.stop : Icons.fiber_manual_record,
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
