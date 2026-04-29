import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../core/audio_service.dart';
import '../core/note_utils.dart';
import '../widgets/piano_keyboard_widget.dart';

/// Lesson 3: Piano-Voice Matching
///
/// Teacher (or student) taps a piano key → the key plays its note and becomes
/// the active target. The mic listens in real time; a pitch gauge shows how
/// close the singer is.  A cents-accurate needle and a colour-coded hold bar
/// give instant feedback, matching the UX already used in piano_mode_page.dart.
class PianoVoiceMatchingPage extends StatefulWidget {
  final Map<String, dynamic> classData;
  final String lessonTitle;

  const PianoVoiceMatchingPage({
    super.key,
    required this.classData,
    required this.lessonTitle,
  });

  @override
  State<PianoVoiceMatchingPage> createState() =>
      _PianoVoiceMatchingPageState();
}

class _PianoVoiceMatchingPageState extends State<PianoVoiceMatchingPage> {
  // ── Audio service ─────────────────────────────────────────────────────────
  final AudioService _audioService = AudioService();
  StreamSubscription<NoteResult?>? _audioSub;

  // ── State ─────────────────────────────────────────────────────────────────
  PianoKey? _targetKey;      // last key pressed on the piano
  bool _isListening = false;
  double _currentCents = 0;  // deviation from target
  double _detectedHz = 0;
  int _correctFrames = 0;
  String _feedback = '';
  bool _matchAchieved = false;

  static const _framesNeeded = 8; // ~0.5 s in-tune hold to trigger success

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _audioSub?.cancel();
    _audioService.dispose();
    super.dispose();
  }

  // ── Mic control ───────────────────────────────────────────────────────────

  Future<void> _startListening() async {
    if (_targetKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tap a piano key first to set the target note'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final ok = await _audioService.start(targetFreq: _targetKey!.freq);
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied')),
        );
      }
      return;
    }

    setState(() {
      _isListening = true;
      _currentCents = 0;
      _detectedHz = 0;
      _correctFrames = 0;
      _feedback = 'Sing into the mic…';
      _matchAchieved = false;
    });

    _audioSub = _audioService.results.listen((result) {
      if (!mounted || _targetKey == null) return;

      if (result == null || result.frequency <= 0) {
        setState(() {
          _feedback = 'Sing into the mic…';
          _currentCents = 0;
          _detectedHz = 0;
        });
        _correctFrames = 0;
        return;
      }

      final cents =
          1200 * log(result.frequency / _targetKey!.freq) / log(2);

      setState(() {
        _detectedHz = result.frequency;
        _currentCents = cents;
      });

      if (cents.abs() <= 60) {
        _correctFrames++;
        setState(() =>
            _feedback = '✓  ${_targetKey!.solfege}  •  in tune!');
        if (_correctFrames >= _framesNeeded) {
          _correctFrames = 0;
          setState(() {
            _matchAchieved = true;
            _feedback = '🎉  Perfect match!';
          });
          _stopListening();
        }
      } else {
        _correctFrames = 0;
        final dir = cents > 0 ? '↑ Too high' : '↓ Too low';
        setState(() =>
            _feedback =
                '$dir  (${cents.abs().toStringAsFixed(0)}¢ off)');
      }
    });
  }

  Future<void> _stopListening() async {
    await _audioSub?.cancel();
    _audioSub = null;
    await _audioService.stop();
    if (mounted) setState(() => _isListening = false);
  }

  void _onKeyPressed(PianoKey key) {
    setState(() {
      _targetKey = key;
      _matchAchieved = false;
      _feedback = '';
      _currentCents = 0;
      _detectedHz = 0;
      _correctFrames = 0;
    });
    // If already listening, restart with new target
    if (_isListening) {
      _stopListening().then((_) => _startListening());
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final className = widget.classData['name'] as String? ?? '';

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Column(
        children: [
          // ── Teal header ──────────────────────────────────────────────────
          Container(
            width: double.infinity,
            color: AppColors.primaryCyan,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              right: 16,
              bottom: 22,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.black, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      className.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Roboto',
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 36),
                  child: Text(
                    '${widget.lessonTitle}  /  Piano-Voice Matching',
                    style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 12,
                        fontFamily: 'Roboto'),
                  ),
                ),
              ],
            ),
          ),

          // ── Body ────────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Instructions
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryCyan.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color:
                              AppColors.primaryCyan.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline,
                            color: AppColors.primaryCyan, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '1. Tap a piano key to set the target note.\n'
                            '2. Tap the mic button.\n'
                            '3. Sing the note — hold it until the gauge turns green.',
                            style: TextStyle(
                              color: AppColors.white.withValues(alpha: 0.85),
                              fontSize: 12,
                              fontFamily: 'Roboto',
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Target note display ──────────────────────────────────
                  _buildTargetDisplay(),
                  const SizedBox(height: 20),

                  // ── Piano keyboard ───────────────────────────────────────
                  const Text(
                    'Piano  —  tap a key',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Roboto',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 148,
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: PianoKeyboardWidget(
                      keyHeight: 148,
                      whiteKeyWidth: 46,
                      highlightedNote: _targetKey?.name,
                      onKeyPressed: _onKeyPressed,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Mic button + feedback ────────────────────────────────
                  _buildMicSection(),

                  // ── Pitch gauge (visible while listening) ────────────────
                  if (_isListening) ...[
                    const SizedBox(height: 20),
                    _buildPitchGauge(),
                  ],

                  // ── Match achieved banner ────────────────────────────────
                  if (_matchAchieved) ...[
                    const SizedBox(height: 20),
                    _buildSuccessBanner(),
                  ],

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  // ── Widgets ───────────────────────────────────────────────────────────────

  Widget _buildTargetDisplay() {
    final hasTarget = _targetKey != null;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: _matchAchieved
            ? const Color(0xFF4CAF50).withValues(alpha: 0.15)
            : hasTarget
                ? AppColors.primaryCyan.withValues(alpha: 0.10)
                : AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _matchAchieved
              ? const Color(0xFF4CAF50).withValues(alpha: 0.5)
              : hasTarget
                  ? AppColors.primaryCyan.withValues(alpha: 0.4)
                  : AppColors.inputBg,
        ),
      ),
      child: Column(
        children: [
          Text(
            hasTarget ? _targetKey!.solfege : '—',
            style: TextStyle(
              color: _matchAchieved
                  ? const Color(0xFF4CAF50)
                  : AppColors.primaryCyan,
              fontSize: 52,
              fontWeight: FontWeight.bold,
              fontFamily: 'Roboto',
            ),
          ),
          if (hasTarget) ...[
            const SizedBox(height: 4),
            Text(
              '${_targetKey!.name}  •  ${_targetKey!.freq.toStringAsFixed(1)} Hz',
              style: TextStyle(
                color: AppColors.grey.withValues(alpha: 0.6),
                fontSize: 12,
                fontFamily: 'Roboto',
              ),
            ),
          ],
          if (!hasTarget)
            Text(
              'Tap a key above',
              style: TextStyle(
                color: AppColors.grey.withValues(alpha: 0.45),
                fontSize: 13,
                fontFamily: 'Roboto',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMicSection() {
    return Row(
      children: [
        GestureDetector(
          onTap: _isListening ? _stopListening : _startListening,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isListening
                  ? Colors.red
                  : Colors.red.withValues(alpha: 0.12),
              border: Border.all(color: Colors.red, width: 2),
              boxShadow: _isListening
                  ? [
                      BoxShadow(
                          color: Colors.red.withValues(alpha: 0.35),
                          blurRadius: 16,
                          spreadRadius: 4)
                    ]
                  : [],
            ),
            child: Icon(
              _isListening ? Icons.mic : Icons.mic_none,
              color: _isListening ? Colors.white : Colors.red,
              size: 28,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isListening ? 'Listening…' : 'Tap mic to start',
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Roboto',
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _isListening
                    ? _feedback.isNotEmpty
                        ? _feedback
                        : 'Detecting pitch…'
                    : _targetKey == null
                        ? 'Tap a piano key first'
                        : 'Then sing ${_targetKey!.solfege} (${_targetKey!.name})',
                style: TextStyle(
                  color: _feedback.startsWith('✓') ||
                          _feedback.startsWith('🎉')
                      ? const Color(0xFF4CAF50)
                      : _feedback.startsWith('↑') ||
                              _feedback.startsWith('↓')
                          ? AppColors.errorRed
                          : AppColors.grey.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontFamily: 'Roboto',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPitchGauge() {
    final clampedCents = _currentCents.clamp(-200.0, 200.0);
    final needleX = (clampedCents + 200) / 400;
    final inTune = _currentCents.abs() <= 60;
    final close = _currentCents.abs() <= 120;
    final hasSignal = _detectedHz > 0;

    final needleColor = !hasSignal
        ? AppColors.grey
        : inTune
            ? const Color(0xFF4CAF50)
            : close
                ? const Color(0xFFFFA726)
                : AppColors.errorRed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Direction labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('↓ Lower',
                style: TextStyle(
                    color: AppColors.grey.withValues(alpha: 0.5),
                    fontSize: 10,
                    fontFamily: 'Roboto')),
            Text(
              hasSignal
                  ? '${_detectedHz.toStringAsFixed(1)} Hz'
                  : '— Hz',
              style: TextStyle(
                  color: needleColor,
                  fontSize: 11,
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.w600),
            ),
            Text('↑ Higher',
                style: TextStyle(
                    color: AppColors.grey.withValues(alpha: 0.5),
                    fontSize: 10,
                    fontFamily: 'Roboto')),
          ],
        ),
        const SizedBox(height: 6),

        // Gauge bar
        SizedBox(
          height: 44,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Colour zones
              Positioned.fill(
                top: 10,
                bottom: 10,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Row(children: [
                    Expanded(
                        flex: 2,
                        child: Container(
                            color: AppColors.errorRed
                                .withValues(alpha: 0.2))),
                    Expanded(
                        flex: 1,
                        child: Container(
                            color: const Color(0xFFFFA726)
                                .withValues(alpha: 0.22))),
                    Expanded(
                        flex: 1,
                        child: Container(
                            color: const Color(0xFF4CAF50)
                                .withValues(alpha: 0.28))),
                    Expanded(
                        flex: 1,
                        child: Container(
                            color: const Color(0xFFFFA726)
                                .withValues(alpha: 0.22))),
                    Expanded(
                        flex: 2,
                        child: Container(
                            color: AppColors.errorRed
                                .withValues(alpha: 0.2))),
                  ]),
                ),
              ),

              // Center target line
              Align(
                alignment: Alignment.center,
                child: Container(
                  width: 2,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),

              // TARGET label
              Align(
                alignment: const Alignment(0, 1),
                child: Text(
                  'TARGET',
                  style: TextStyle(
                      color: const Color(0xFF4CAF50).withValues(alpha: 0.7),
                      fontSize: 7,
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5),
                ),
              ),

              // Needle
              Align(
                alignment: FractionalOffset(needleX, 0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 80),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CustomPaint(
                        size: const Size(10, 8),
                        painter: _TrianglePainter(needleColor),
                      ),
                      Container(
                        width: 3,
                        height: 30,
                        decoration: BoxDecoration(
                          color: needleColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Cents readout
        Center(
          child: Text(
            hasSignal
                ? inTune
                    ? '${_currentCents.toStringAsFixed(0)}¢  —  in tune!'
                    : '${_currentCents > 0 ? '+' : ''}${_currentCents.toStringAsFixed(0)}¢  '
                        '${_currentCents > 0 ? '(sing lower)' : '(sing higher)'}'
                : 'Waiting for signal…',
            style: TextStyle(
                color: needleColor,
                fontSize: 12,
                fontFamily: 'Roboto',
                fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 10),

        // Hold progress
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (_correctFrames / _framesNeeded).clamp(0.0, 1.0),
            minHeight: 5,
            backgroundColor: AppColors.inputBg,
            valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF4CAF50)),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            'Hold in tune to register a match',
            style: TextStyle(
                color: AppColors.grey.withValues(alpha: 0.45),
                fontSize: 10,
                fontFamily: 'Roboto'),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFF4CAF50).withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              color: Color(0xFF4CAF50), size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Match achieved!',
                  style: TextStyle(
                    color: Color(0xFF4CAF50),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Roboto',
                  ),
                ),
                Text(
                  'You sang ${_targetKey?.solfege ?? ''} (${_targetKey?.name ?? ''}) in tune.',
                  style: TextStyle(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.8),
                    fontSize: 12,
                    fontFamily: 'Roboto',
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _matchAchieved = false;
                _feedback = '';
                _currentCents = 0;
                _detectedHz = 0;
              });
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color:
                        const Color(0xFF4CAF50).withValues(alpha: 0.4)),
              ),
              child: const Text(
                'Again',
                style: TextStyle(
                  color: Color(0xFF4CAF50),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Roboto',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom nav ─────────────────────────────────────────────────────────────

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      height: 70,
      color: AppColors.bottomNavBg,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navIcon(Icons.notifications_outlined),
          _navIcon(Icons.home_outlined,
              onTap: () => Navigator.pop(context)),
          _navIcon(Icons.person_outline),
        ],
      ),
    );
  }

  Widget _navIcon(IconData icon, {VoidCallback? onTap}) => GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon,
              color: AppColors.grey.withValues(alpha: 0.5), size: 26),
        ),
      );
}

// ── Triangle needle painter ───────────────────────────────────────────────────

class _TrianglePainter extends CustomPainter {
  final Color color;
  const _TrianglePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TrianglePainter old) => old.color != color;
}
