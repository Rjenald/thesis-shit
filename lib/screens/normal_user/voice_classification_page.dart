import 'dart:async';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../widgets/playable_piano.dart';
import '../../core/audio_service.dart';
import '../../core/note_utils.dart';
import '../../widgets/bottom_nav_bar.dart';

class VoiceClassificationPage extends StatefulWidget {
  const VoiceClassificationPage({super.key});

  @override
  State<VoiceClassificationPage> createState() =>
      _VoiceClassificationPageState();
}

class _VoiceClassificationPageState extends State<VoiceClassificationPage> {
  final AudioService _audioService = AudioService();

  bool _isListening = false;
  String _noteDisplay = '--';
  String _voiceType = '--';
  String _range = '--';
  String _frequency = '--';
  double _cents = 0.0;
  PitchFeedback _feedback = PitchFeedback.noSignal;
  int? _detectedMidi; // for piano key highlight

  // Collect recent frequencies to determine voice type
  final List<double> _recentFreqs = [];

  StreamSubscription<NoteResult?>? _sub;

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
        _noteDisplay = '--';
        _voiceType = '--';
        _range = '--';
        _frequency = '--';
        _cents = 0.0;
        _feedback = PitchFeedback.noSignal;
        _recentFreqs.clear();
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
            _noteDisplay = '--';
            _feedback = PitchFeedback.noSignal;
            _detectedMidi = null;
          });
          return;
        }

        // Accumulate frequencies for voice type classification
        _recentFreqs.add(result.frequency);
        if (_recentFreqs.length > 40) _recentFreqs.removeAt(0);

        final avgFreq =
            _recentFreqs.reduce((a, b) => a + b) / _recentFreqs.length;

        setState(() {
          _noteDisplay = result.fullName;
          _frequency = '${result.frequency.toStringAsFixed(1)} Hz';
          _cents = result.cents;
          _feedback = result.feedback;
          _detectedMidi = result.midiNote;

          // Classify voice type from average detected frequency
          if (avgFreq < 165) {
            _voiceType = 'Bass';
            _range = 'E2 – E4';
          } else if (avgFreq < 220) {
            _voiceType = 'Baritone';
            _range = 'G2 – G4';
          } else if (avgFreq < 330) {
            _voiceType = 'Tenor';
            _range = 'C3 – C5';
          } else if (avgFreq < 440) {
            _voiceType = 'Alto';
            _range = 'F3 – F5';
          } else if (avgFreq < 587) {
            _voiceType = 'Mezzo-Soprano';
            _range = 'G3 – G5';
          } else {
            _voiceType = 'Soprano';
            _range = 'C4 – C6';
          }
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
        return 'Listening...';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      // Scrollable, because this column mixes fixed-height pieces with
      // Spacers, and a Spacer cannot shrink past zero: on a short screen
      // the fixed content simply overflows, which is what the striped
      // banner was.
      //
      // SliverFillRemaining rather than the usual LayoutBuilder +
      // ConstrainedBox + IntrinsicHeight recipe. That recipe runs its
      // builder during LAYOUT, so everything inside registers its
      // inherited dependencies then — and this page is full of gesture
      // detectors, which read MediaQuery. A dependency registered during
      // layout can outlive the element holding it, which is the
      // `'_dependents.isEmpty': is not true` assert. The sliver gets the
      // same "fill the viewport, scroll when taller" behaviour with no
      // layout-time builder at all.
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
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
                    onPressed: () async {
                      if (_isListening) {
                        await _sub?.cancel();
                        _sub = null;
                        await _audioService.stop();
                      }
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                  // Expanded, because a 20px bold title beside a 48px icon
                  // button has no give: it overflowed by 109px at 360
                  // logical pixels wide. A narrow handset or a raised
                  // system text scale does the same thing on a real
                  // device.
                  const Expanded(
                    child: Text(
                      'Voice Classification',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Roboto',
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // ── Note Display Box ─────────────────────────────────────────────
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
                  // Detected note name (e.g. "A4")
                  Text(
                    _noteDisplay,
                    style: TextStyle(
                      color: _isListening ? _feedbackColor : AppColors.white,
                      fontSize: 72,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Roboto',
                    ),
                  ),

                  // Feedback label
                  if (_isListening)
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
                      const Icon(
                        Icons.piano,
                        color: AppColors.primaryCyan,
                        size: 16,
                      ),
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
                      if (_isListening && _noteDisplay != '--') ...[
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
                    // This screen has no glow animation, so the glow is
                    // held steady rather than faked.
                    child: PlayablePiano(
                      detectedMidi: _detectedMidi,
                      highlightColor: _feedbackColor,
                      isListening: _isListening,
                      height: double.infinity,
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
                  _buildDetailBar('Voice Type:', _voiceType),
                  const SizedBox(height: 8),
                  _buildDetailBar('Range:', _range),
                  const SizedBox(height: 8),
                  _buildDetailBar('Frequency:', _frequency),
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
// highlighting, so singing C2 still lights up the C key, etc.
