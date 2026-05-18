import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../core/audio_service.dart';
import '../../core/note_utils.dart';
import '../../widgets/bottom_nav_bar.dart';

class SolfegePitchPage extends StatefulWidget {
  const SolfegePitchPage({super.key});

  @override
  State<SolfegePitchPage> createState() => _SolfegePitchPageState();
}

class _SolfegePitchPageState extends State<SolfegePitchPage>
    with TickerProviderStateMixin {
  // NEW: Fresh AudioService instance per page
  final AudioService _audioService = AudioService();
  StreamSubscription<NoteResult?>? _sub;

  bool _isListening = false;

  // Live display
  String _solfegeDisplay = '--';
  String _noteDisplay = '';
  double _cents = 0.0;
  PitchFeedback _feedback = PitchFeedback.noSignal;
  int? _detectedMidi;

  // Pitch status
  String _pitchStatus = '--';
  Color _statusColor = Colors.grey;

  // Animation controllers
  late AnimationController _noteScaleController;
  late AnimationController _pulseController;
  late AnimationController _glowController;
  late Animation<double> _noteScaleAnimation;
  late Animation<double> _glowAnimation;

  // Details
  String _accuracy = '--';
  String _userRange = '--';

  // Accuracy & Range tracking
  final List<double> _centsList = [];
  int? _minMidi;
  int? _maxMidi;

  @override
  void initState() {
    super.initState();

    _noteScaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _noteScaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _noteScaleController, curve: Curves.easeOut),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _glowAnimation = Tween<double>(
      begin: 0.2,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _glowController, curve: Curves.easeOut));
  }

  void _handlePitchResult(NoteResult? result) {
    if (result == null || !result.hasSignal) {
      if (mounted) {
        setState(() {
          _solfegeDisplay = '...';
          _noteDisplay = '';
          _feedback = PitchFeedback.noSignal;
          _detectedMidi = null;
          _pitchStatus = '--';
          _statusColor = Colors.grey;
        });
      }
      return;
    }

    _centsList.add(result.cents.abs());
    if (_centsList.length > 50) _centsList.removeAt(0);

    final avgCentsOff = _centsList.reduce((a, b) => a + b) / _centsList.length;
    final accuracyPct = (100 - avgCentsOff * 2).clamp(0, 100).toInt();

    _minMidi = _minMidi == null
        ? result.midiNote
        : math.min(_minMidi!, result.midiNote);
    _maxMidi = _maxMidi == null
        ? result.midiNote
        : math.max(_maxMidi!, result.midiNote);

    final minNote = _minMidi != null
        ? '${midiToNoteName(_minMidi!)}${midiToOctave(_minMidi!)}'
        : '--';
    final maxNote = _maxMidi != null
        ? '${midiToNoteName(_maxMidi!)}${midiToOctave(_maxMidi!)}'
        : '--';

    final newSolfege = result.solfege != null
        ? result.solfege!
        : result.noteName;

    _updatePitchStatus(result);

    if (newSolfege != _solfegeDisplay) {
      _noteScaleController.forward(from: 0.0);
      _glowController.forward(from: 0.0);
    }

    if (mounted) {
      setState(() {
        _solfegeDisplay = newSolfege;
        _noteDisplay = result.fullName;
        _cents = result.cents;
        _feedback = result.feedback;
        _accuracy = '$accuracyPct%';
        _userRange = '$minNote – $maxNote';
        _detectedMidi = result.midiNote;
      });
    }
  }

  void _updatePitchStatus(NoteResult note) {
    switch (note.feedback) {
      case PitchFeedback.correct:
        _pitchStatus = 'In Tune ✓';
        _statusColor = AppColors.primaryCyan;
        break;
      case PitchFeedback.tooHigh:
        _pitchStatus = 'Sharp ↑ (${note.cents.toStringAsFixed(1)}¢)';
        _statusColor = Colors.orangeAccent;
        break;
      case PitchFeedback.tooLow:
        _pitchStatus = 'Flat ↓ (${note.cents.toStringAsFixed(1)}¢)';
        _statusColor = Colors.blueAccent;
        break;
      case PitchFeedback.noSignal:
        _pitchStatus = '--';
        _statusColor = Colors.grey;
        break;
    }
  }

  @override
  void dispose() {
    // FIX: Cancel stream subscription first
    _sub?.cancel();
    _sub = null;

    // FIX: Fully dispose AudioService (not just stop)
    _audioService.dispose();

    _noteScaleController.dispose();
    _pulseController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      // ── STOP ──────────────────────────────────────────────────────────────
      await _sub?.cancel();
      _sub = null;

      await _audioService.stop();

      _pulseController.stop();

      if (mounted) {
        setState(() {
          _isListening = false;
          _resetDisplay();
        });
      }
    } else {
      // ── START ──────────────────────────────────────────────────────────────
      // FIX: Preload CREPE before starting
      await _audioService.preloadCrepe();

      final started = await _audioService.start();
      if (!started) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission denied')),
          );
        }
        return;
      }

      _pulseController.repeat(reverse: true);

      if (mounted) {
        setState(() => _isListening = true);
      }

      _sub = _audioService.results.listen(
        _handlePitchResult,
        onError: (error) {
          debugPrint('Pitch detection error: $error');
        },
      );
    }
  }

  void _resetDisplay() {
    _solfegeDisplay = '--';
    _noteDisplay = '';
    _cents = 0.0;
    _feedback = PitchFeedback.noSignal;
    _accuracy = '--';
    _userRange = '--';
    _centsList.clear();
    _minMidi = null;
    _maxMidi = null;
    _detectedMidi = null;
    _pitchStatus = '--';
    _statusColor = Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ───────────────────────────────────────────────────────
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
                    onPressed: () async {
                      // FIX: Properly stop mic before leaving
                      if (_isListening) {
                        await _sub?.cancel();
                        _sub = null;
                        await _audioService.stop();
                        _pulseController.stop();
                        _isListening = false;
                      }
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                  const Text(
                    'Solfege Pitch',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Roboto',
                    ),
                  ),
                  const Spacer(),
                  if (_isListening)
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _statusColor.withValues(
                                  alpha: 0.5 + _pulseController.value * 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'LIVE',
                              style: TextStyle(
                                color: _statusColor.withValues(alpha: 0.8),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),

            const Spacer(),

            // ── Note Display ─────────────────────────────────────────────────
            AnimatedBuilder(
              animation: _noteScaleAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _noteScaleAnimation.value,
                  child: Container(
                    width: double.infinity,
                    height: 160,
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: AppColors.inputBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            _isListening && _feedback != PitchFeedback.noSignal
                            ? _statusColor
                            : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow:
                          _isListening && _feedback == PitchFeedback.correct
                          ? [
                              BoxShadow(
                                color: AppColors.primaryCyan.withValues(
                                  alpha: 0.3,
                                ),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 100),
                          style: TextStyle(
                            color:
                                _isListening &&
                                    _feedback != PitchFeedback.noSignal
                                ? _statusColor
                                : AppColors.white,
                            fontSize: 72,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Roboto',
                          ),
                          child: Text(_solfegeDisplay),
                        ),
                        const SizedBox(height: 8),
                        if (_isListening)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 100),
                                child: Text(
                                  _noteDisplay.isNotEmpty
                                      ? _noteDisplay
                                      : '...',
                                  key: ValueKey(_noteDisplay),
                                  style: TextStyle(
                                    color: AppColors.grey.withValues(
                                      alpha: 0.8,
                                    ),
                                    fontSize: 14,
                                    fontFamily: 'Roboto',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 100),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: _statusColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: _statusColor.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  _pitchStatus,
                                  style: TextStyle(
                                    color: _statusColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Roboto',
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 14),

            // ── Cents Meter ───────────────────────────────────────────────────
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: _isListening ? 50 : 0,
              margin: const EdgeInsets.symmetric(horizontal: 24),
              child: _isListening
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Flat',
                              style: TextStyle(
                                color: AppColors.grey.withValues(alpha: 0.7),
                                fontSize: 12,
                                fontFamily: 'Roboto',
                              ),
                            ),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 80),
                              child: Text(
                                '${_cents.toStringAsFixed(1)} cents',
                                key: ValueKey(_cents),
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 12,
                                  fontFamily: 'Roboto',
                                ),
                              ),
                            ),
                            Text(
                              'Sharp',
                              style: TextStyle(
                                color: AppColors.grey.withValues(alpha: 0.7),
                                fontSize: 12,
                                fontFamily: 'Roboto',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(
                              begin: 0.5,
                              end: (_cents.clamp(-50, 50) + 50) / 100,
                            ),
                            duration: const Duration(milliseconds: 100),
                            builder: (context, value, child) {
                              return LinearProgressIndicator(
                                value: value,
                                minHeight: 8,
                                backgroundColor: AppColors.inputBg,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _statusColor,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    )
                  : null,
            ),

            const SizedBox(height: 18),

            // ── Piano Keyboard ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.piano, color: AppColors.primaryCyan, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Voice → Piano',
                        style: TextStyle(
                          color: AppColors.grey.withValues(alpha: 0.8),
                          fontSize: 12,
                          fontFamily: 'Roboto',
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (_isListening && _noteDisplay.isNotEmpty) ...[
                        const Spacer(),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 100),
                          child: Text(
                            _noteDisplay,
                            key: ValueKey(_noteDisplay),
                            style: TextStyle(
                              color: _statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Roboto',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  AnimatedBuilder(
                    animation: _glowAnimation,
                    builder: (context, child) {
                      return Container(
                        height: 112,
                        decoration: BoxDecoration(
                          color: const Color(0xFF141414),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _isListening && _detectedMidi != null
                                ? _statusColor.withValues(
                                    alpha: 0.4 + _glowAnimation.value * 0.4,
                                  )
                                : Colors.white.withValues(alpha: 0.08),
                            width: 1.5,
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                        child: CustomPaint(
                          painter: _PianoPainter(
                            detectedMidi: _detectedMidi,
                            highlightColor: _statusColor,
                            isListening: _isListening,
                            glowIntensity: _glowAnimation.value,
                          ),
                          size: Size.infinite,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const Spacer(),

            // ── Details ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Details',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Roboto',
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildDetailBar('Accuracy:', _accuracy),
                  const SizedBox(height: 8),
                  _buildDetailBar('User Range:', _userRange),
                  const SizedBox(height: 8),
                  _buildDetailBarWithColor(
                    'Pitch Status:',
                    _pitchStatus,
                    _statusColor,
                  ),
                  const SizedBox(height: 8),
                  _buildDetailBar(
                    'Cents:',
                    _isListening && _feedback != PitchFeedback.noSignal
                        ? '${_cents.toStringAsFixed(1)}¢'
                        : '--',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── Mic Button ───────────────────────────────────────────────────
            GestureDetector(
              onTap: _toggleListening,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final pulseSize = _isListening
                      ? 68 + _pulseController.value * 8
                      : 68.0;

                  return Container(
                    width: pulseSize,
                    height: pulseSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isListening
                          ? Colors.red.withValues(alpha: 0.75)
                          : Colors.red,
                      boxShadow: _isListening
                          ? [
                              BoxShadow(
                                color: Colors.red.withValues(
                                  alpha: 0.4 + _pulseController.value * 0.3,
                                ),
                                blurRadius: 16 + _pulseController.value * 8,
                                spreadRadius: 4 + _pulseController.value * 2,
                              ),
                            ]
                          : null,
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        _isListening ? Icons.mic : Icons.mic_none,
                        key: ValueKey(_isListening),
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 8),
            Text(
              _isListening ? 'Tap to stop' : 'Tap to start',
              style: TextStyle(
                color: AppColors.grey.withValues(alpha: 0.7),
                fontSize: 12,
                fontFamily: 'Roboto',
              ),
            ),

            const SizedBox(height: 20),

            BottomNavBar(
              currentIndex: 3,
              onTap: (index) {
                if (index != 3) Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailBar(String label, String value) {
    return Container(
      width: double.infinity,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.inputBg,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.grey.withValues(alpha: 0.8),
              fontSize: 13,
              fontFamily: 'Roboto',
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: Text(
              value,
              key: ValueKey(value),
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 13,
                fontFamily: 'Roboto',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailBarWithColor(
    String label,
    String value,
    Color valueColor,
  ) {
    return Container(
      width: double.infinity,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.inputBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: valueColor.withValues(alpha: 0.3), width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.grey.withValues(alpha: 0.8),
              fontSize: 13,
              fontFamily: 'Roboto',
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: valueColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFamily: 'Roboto',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Piano Keyboard Painter ──────────────────────────────────────────────────
class _PianoPainter extends CustomPainter {
  final int? detectedMidi;
  final Color highlightColor;
  final bool isListening;
  final double glowIntensity;

  const _PianoPainter({
    required this.detectedMidi,
    required this.highlightColor,
    required this.isListening,
    this.glowIntensity = 1.0,
  });

  static const List<int> _whiteKeys = [60, 62, 64, 65, 67, 69, 71, 72];
  static const List<String> _solfegeLabels = [
    'Do',
    'Re',
    'Mi',
    'Fa',
    'Sol',
    'La',
    'Ti',
    'Do',
  ];
  static const Map<int, double> _blackKeyCenters = {
    61: 1.0,
    63: 2.0,
    66: 4.0,
    68: 5.0,
    70: 6.0,
  };

  int? _normalise(int? midi) {
    if (midi == null) return null;
    final pitchClass = midi % 12;
    return 60 + pitchClass;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final highlighted = _normalise(detectedMidi);
    final numWhite = _whiteKeys.length;
    final whiteW = size.width / numWhite;
    final whiteH = size.height;
    final blackW = whiteW * 0.56;
    final blackH = whiteH * 0.60;

    for (int i = 0; i < _whiteKeys.length; i++) {
      final midi = _whiteKeys[i];
      final isHit = isListening && midi == highlighted;

      final rect = Rect.fromLTWH(i * whiteW + 1, 0, whiteW - 2, whiteH - 1);
      final rRect = RRect.fromRectAndCorners(
        rect,
        bottomLeft: const Radius.circular(5),
        bottomRight: const Radius.circular(5),
      );

      if (isHit) {
        canvas.drawRRect(
          rRect.inflate(2),
          Paint()
            ..style = PaintingStyle.fill
            ..color = highlightColor.withValues(alpha: 0.3 * glowIntensity)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      }

      canvas.drawRRect(
        rRect,
        Paint()
          ..style = PaintingStyle.fill
          ..color = isHit
              ? highlightColor.withValues(alpha: 0.88)
              : Colors.white,
      );

      canvas.drawRRect(
        rRect,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = isHit ? highlightColor : Colors.black38
          ..strokeWidth = isHit ? 2 : 1,
      );

      final textSpan = TextSpan(
        text: _solfegeLabels[i],
        style: TextStyle(
          color: isHit ? Colors.black : Colors.black45,
          fontSize: whiteW * 0.26,
          fontWeight: isHit ? FontWeight.bold : FontWeight.normal,
          fontFamily: 'Roboto',
        ),
      );
      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
      tp.layout(maxWidth: whiteW);
      tp.paint(
        canvas,
        Offset(i * whiteW + (whiteW - tp.width) / 2, whiteH - tp.height - 4),
      );
    }

    _blackKeyCenters.forEach((midi, centerFrac) {
      final isHit = isListening && midi == highlighted;
      final x = centerFrac * whiteW - blackW / 2;
      final rect = Rect.fromLTWH(x, 0, blackW, blackH);
      final rRect = RRect.fromRectAndCorners(
        rect,
        bottomLeft: const Radius.circular(4),
        bottomRight: const Radius.circular(4),
      );

      if (isHit) {
        canvas.drawRRect(
          rRect.inflate(2),
          Paint()
            ..style = PaintingStyle.fill
            ..color = highlightColor.withValues(alpha: 0.4 * glowIntensity)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
      }

      canvas.drawRRect(
        rRect,
        Paint()
          ..style = PaintingStyle.fill
          ..color = isHit ? highlightColor : Colors.black,
      );

      if (isHit) {
        canvas.drawRRect(
          rRect,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = highlightColor.withValues(alpha: 0.6)
            ..strokeWidth = 1.5,
        );
      }
    });
  }

  @override
  bool shouldRepaint(_PianoPainter old) =>
      old.detectedMidi != detectedMidi ||
      old.highlightColor != highlightColor ||
      old.isListening != isListening ||
      old.glowIntensity != glowIntensity;
}
