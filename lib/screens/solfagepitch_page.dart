import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../core/audio_service.dart';
import '../core/note_utils.dart';
import '../widgets/bottom_nav_bar.dart';

class SolfegePitchPage extends StatefulWidget {
  const SolfegePitchPage({super.key});

  @override
  State<SolfegePitchPage> createState() => _SolfegePitchPageState();
}

class _SolfegePitchPageState extends State<SolfegePitchPage> {
  final AudioService _audioService = AudioService();
  StreamSubscription<NoteResult?>? _sub;

  bool _isListening = false;

  // Live display
  String _solfegeDisplay = '--';
  String _noteDisplay = '';
  double _cents = 0.0;
  PitchFeedback _feedback = PitchFeedback.noSignal;
  int? _detectedMidi; // for piano key highlight

  // Details
  String _accuracy = '--';
  String _userRange = '--';

  // Accuracy tracking
  final List<double> _centsList = [];

  // Range tracking
  int? _minMidi;
  int? _maxMidi;

  @override
  void dispose() {
    _sub?.cancel();
    _audioService.dispose();
    super.dispose();
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _sub?.cancel();
      _sub = null;
      await _audioService.stop();
      setState(() {
        _isListening = false;
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
      });
    } else {
      final started = await _audioService.start();
      if (!started) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission denied')),
          );
        }
        return;
      }

      setState(() => _isListening = true);

      _sub = _audioService.results.listen((result) {
        if (!mounted) return;

        if (result == null) {
          setState(() {
            _solfegeDisplay = '--';
            _noteDisplay = '';
            _feedback = PitchFeedback.noSignal;
            _detectedMidi = null;
          });
          return;
        }

        // Track cents for accuracy calculation
        _centsList.add(result.cents.abs());
        if (_centsList.length > 60) _centsList.removeAt(0);

        final avgCentsOff =
            _centsList.reduce((a, b) => a + b) / _centsList.length;
        final accuracyPct = (100 - avgCentsOff * 2).clamp(0, 100).toInt();

        // Track min/max MIDI for range
        _minMidi = _minMidi == null
            ? result.midiNote
            : (_minMidi! < result.midiNote ? _minMidi! : result.midiNote);
        _maxMidi = _maxMidi == null
            ? result.midiNote
            : (_maxMidi! > result.midiNote ? _maxMidi! : result.midiNote);

        final minNote = _minMidi != null
            ? '${midiToNoteName(_minMidi!)}${midiToOctave(_minMidi!)}'
            : '--';
        final maxNote = _maxMidi != null
            ? '${midiToNoteName(_maxMidi!)}${midiToOctave(_maxMidi!)}'
            : '--';

        setState(() {
          _solfegeDisplay = result.solfege != null
              ? result.solfege!.toLowerCase()
              : result.noteName.toLowerCase();
          _noteDisplay = result.fullName;
          _cents = result.cents;
          _feedback = result.feedback;
          _accuracy = '$accuracyPct%';
          _userRange = '$minNote – $maxNote';
          _detectedMidi = result.midiNote;
        });
      });
    }
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
        return _isListening ? 'Listening...' : '';
    }
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
                      if (_isListening) {
                        await _sub?.cancel();
                        _sub = null;
                        await _audioService.stop();
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
                ],
              ),
            ),

            const Spacer(),

            // ── Solfège Display Box ──────────────────────────────────────────
            Container(
              width: double.infinity,
              height: 160,
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: AppColors.inputBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isListening ? _feedbackColor : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Solfège syllable (e.g. "do", "re", "mi")
                  Text(
                    _solfegeDisplay,
                    style: TextStyle(
                      color: _isListening ? _feedbackColor : AppColors.white,
                      fontSize: 72,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Roboto',
                    ),
                  ),

                  // Note name + feedback label
                  if (_isListening && _noteDisplay.isNotEmpty)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _noteDisplay,
                          style: TextStyle(
                            color: AppColors.grey.withValues(alpha: 0.8),
                            fontSize: 14,
                            fontFamily: 'Roboto',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _feedbackLabel,
                          style: TextStyle(
                            color: _feedbackColor,
                            fontSize: 14,
                            fontFamily: 'Roboto',
                          ),
                        ),
                      ],
                    )
                  else if (_isListening)
                    Text(
                      _feedbackLabel,
                      style: TextStyle(
                        color: AppColors.grey.withValues(alpha: 0.6),
                        fontSize: 14,
                        fontFamily: 'Roboto',
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── Cents Meter Bar ──────────────────────────────────────────────
            if (_isListening)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
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
                        Text(
                          '${_cents.toStringAsFixed(1)} cents',
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 12,
                            fontFamily: 'Roboto',
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
                      child: LinearProgressIndicator(
                        value: (_cents.clamp(-50, 50) + 50) / 100,
                        minHeight: 8,
                        backgroundColor: AppColors.inputBg,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _feedbackColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 18),

            // ── Piano Keyboard (Voice → Key Highlight) ───────────────────────
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
                        Text(
                          _noteDisplay,
                          style: TextStyle(
                            color: _feedbackColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Roboto',
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 112,
                    decoration: BoxDecoration(
                      color: const Color(0xFF141414),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _isListening && _detectedMidi != null
                            ? _feedbackColor.withValues(alpha: 0.4)
                            : Colors.white.withValues(alpha: 0.08),
                        width: 1.5,
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                    child: CustomPaint(
                      painter: _PianoPainter(
                        detectedMidi: _detectedMidi,
                        highlightColor: _feedbackColor,
                        isListening: _isListening,
                      ),
                      size: Size.infinite,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // ── Details Section ──────────────────────────────────────────────
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
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── Mic Button ───────────────────────────────────────────────────
            GestureDetector(
              onTap: _toggleListening,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isListening
                      ? Colors.red.withValues(alpha: 0.75)
                      : Colors.red,
                  boxShadow: _isListening
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
                  _isListening ? Icons.mic : Icons.mic_none,
                  color: Colors.white,
                  size: 32,
                ),
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

            // ── Bottom Nav ───────────────────────────────────────────────────
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
          Text(
            value,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 13,
              fontFamily: 'Roboto',
            ),
          ),
        ],
      ),
    );
  }
}

// ── Piano Keyboard Painter ────────────────────────────────────────────────────
//
// Draws one octave C4–C5 (MIDI 60–72).
// Any detected MIDI note is mapped to its pitch class in this octave before
// highlighting, so singing C3 still lights up the C key, etc.

class _PianoPainter extends CustomPainter {
  final int? detectedMidi;
  final Color highlightColor;
  final bool isListening;

  const _PianoPainter({
    required this.detectedMidi,
    required this.highlightColor,
    required this.isListening,
  });

  // White keys: C4(60) D4(62) E4(64) F4(65) G4(67) A4(69) B4(71) C5(72)
  static const List<int> _whiteKeys = [60, 62, 64, 65, 67, 69, 71, 72];

  // Solfège labels for white keys
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

  // Black keys: MIDI value → center position as a fraction of whiteKeyWidth
  // (i.e. how many white-key widths from the left edge to the black key centre)
  static const Map<int, double> _blackKeyCenters = {
    61: 1.0, // C#4 – between C4 (index 0) and D4 (index 1)
    63: 2.0, // D#4 – between D4 and E4
    66: 4.0, // F#4 – between F4 (index 3) and G4 (index 4)
    68: 5.0, // G#4 – between G4 and A4
    70: 6.0, // A#4 – between A4 and B4
  };

  // Map any MIDI note to its equivalent pitch class in C4–B4 (MIDI 60–71).
  // C5 (72) stays as 72 so the last white key can also light up.
  int? _normalise(int? midi) {
    if (midi == null) return null;
    final pitchClass = midi % 12;
    // Remap to C4 octave (MIDI 60 = C4, pitch class 0)
    return 60 + pitchClass;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final highlighted = _normalise(detectedMidi);

    final numWhite = _whiteKeys.length; // 8
    final whiteW = size.width / numWhite;
    final whiteH = size.height;
    final blackW = whiteW * 0.56;
    final blackH = whiteH * 0.60;

    // ── White keys ──────────────────────────────────────────────────────────
    for (int i = 0; i < _whiteKeys.length; i++) {
      final midi = _whiteKeys[i];
      final isHit = isListening && midi == highlighted;

      final rect = Rect.fromLTWH(i * whiteW + 1, 0, whiteW - 2, whiteH - 1);
      final rRect = RRect.fromRectAndCorners(
        rect,
        bottomLeft: const Radius.circular(5),
        bottomRight: const Radius.circular(5),
      );

      // Fill
      canvas.drawRRect(
        rRect,
        Paint()
          ..style = PaintingStyle.fill
          ..color = isHit
              ? highlightColor.withValues(alpha: 0.88)
              : Colors.white,
      );

      // Glow ring on hit
      if (isHit) {
        canvas.drawRRect(
          rRect,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = highlightColor
            ..strokeWidth = 2,
        );
      } else {
        canvas.drawRRect(
          rRect,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = Colors.black38
            ..strokeWidth = 1,
        );
      }

      // Solfège label at bottom of each white key
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

    // ── Black keys (drawn on top) ────────────────────────────────────────────
    _blackKeyCenters.forEach((midi, centerFrac) {
      final isHit = isListening && midi == highlighted;
      final x = centerFrac * whiteW - blackW / 2;
      final rect = Rect.fromLTWH(x, 0, blackW, blackH);
      final rRect = RRect.fromRectAndCorners(
        rect,
        bottomLeft: const Radius.circular(4),
        bottomRight: const Radius.circular(4),
      );

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
      old.isListening != isListening;
}
