import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../core/audio_service.dart';
import '../core/note_utils.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Shared colour & message helpers
// ─────────────────────────────────────────────────────────────────────────────

/// One colour per diatonic solfège syllable (matches kDoReMiSequence).
const Map<String, Color> _noteColorMap = {
  'Do':  Color(0xFFE53935),
  'Re':  Color(0xFFFF7043),
  'Mi':  Color(0xFFFDD835),
  'Fa':  Color(0xFF43A047),
  'Sol': Color(0xFF1E88E5),
  'La':  Color(0xFF8E24AA),
  'Ti':  Color(0xFF00ACC1),
};

Color _noteColor(String? solfege) =>
    _noteColorMap[solfege] ?? AppColors.primaryCyan;

Color _fbColor(PitchFeedback f) {
  switch (f) {
    case PitchFeedback.correct:  return const Color(0xFF4CAF50);
    case PitchFeedback.tooHigh:  return Colors.orangeAccent;
    case PitchFeedback.tooLow:   return const Color(0xFF42A5F5);
    case PitchFeedback.noSignal: return AppColors.grey;
  }
}

String _fbMsg(PitchFeedback f) {
  switch (f) {
    case PitchFeedback.correct:  return '🎯  Hold it — perfect!';
    case PitchFeedback.tooLow:   return '⬆️  Sing a bit higher!';
    case PitchFeedback.tooHigh:  return '⬇️  Bring it down a little!';
    case PitchFeedback.noSignal: return '🎤  Start singing…';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PracticeDrillPage
// ─────────────────────────────────────────────────────────────────────────────

/// Practice Drill Module — three student-friendly drills with
/// CREPE AI real-time pitch detection.
class PracticeDrillPage extends StatefulWidget {
  /// Problem phrases handed in from a results page for Drill #3.
  final List<String> problemLines;
  const PracticeDrillPage({super.key, this.problemLines = const []});

  @override
  State<PracticeDrillPage> createState() => _PracticeDrillPageState();
}

class _PracticeDrillPageState extends State<PracticeDrillPage> {
  int _tab = 0;

  static const _tabIcons = [
    Icons.music_note_rounded,
    Icons.timer_rounded,
    Icons.loop_rounded,
  ];
  static const _tabLabels = ['Scale', 'Sustain', 'Phrase'];
  static const _tabDescs  = ['Do → Ti', '3-sec hold', 'Sing & score'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildTabBar(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 16, 6),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                color: AppColors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Practice Drills',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.white,
                        fontFamily: 'Roboto')),
                Row(children: [
                  Icon(Icons.circle, color: Color(0xFF4CAF50), size: 7),
                  SizedBox(width: 5),
                  Text('CREPE AI  •  Real-time Pitch Detection',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.primaryCyan,
                          fontFamily: 'Roboto',
                          letterSpacing: 0.4)),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab bar ───────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: List.generate(3, (i) {
          final sel = _tab == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tab = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? AppColors.primaryCyan : AppColors.inputBg,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: sel
                      ? [BoxShadow(
                          color: AppColors.primaryCyan.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 2))]
                      : [],
                ),
                child: Column(
                  children: [
                    Icon(_tabIcons[i],
                        color: sel ? Colors.black : AppColors.grey,
                        size: 22),
                    const SizedBox(height: 2),
                    Text(_tabLabels[i],
                        style: TextStyle(
                            color: sel ? Colors.black : AppColors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Roboto')),
                    Text(_tabDescs[i],
                        style: TextStyle(
                            color: sel
                                ? Colors.black87
                                : AppColors.grey.withValues(alpha: 0.6),
                            fontSize: 10,
                            fontFamily: 'Roboto')),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Body ──────────────────────────────────────────────────────────────────

  Widget _buildBody() {
    switch (_tab) {
      case 0: return const _ScaleDrill();
      case 1: return const _SustainedNoteDrill();
      case 2: return _PhraseLoopDrill(phrases: widget.problemLines);
      default: return const SizedBox();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Horizontal pitch meter: blue (flat) | green (in tune) | orange (sharp).
class _PitchMeter extends StatelessWidget {
  final double cents;       // −50 … +50
  final Color needleColor;
  const _PitchMeter({required this.cents, required this.needleColor});

  @override
  Widget build(BuildContext context) {
    final norm = ((cents.clamp(-50.0, 50.0) + 50) / 100).clamp(0.0, 1.0);
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              // Colour zones
              Row(children: [
                Expanded(flex: 35,
                    child: Container(height: 18,
                        color: const Color(0xFF42A5F5).withValues(alpha: 0.25))),
                Expanded(flex: 30,
                    child: Container(height: 18,
                        color: const Color(0xFF4CAF50).withValues(alpha: 0.25))),
                Expanded(flex: 35,
                    child: Container(height: 18,
                        color: Colors.orangeAccent.withValues(alpha: 0.25))),
              ]),
              // Needle
              Positioned.fill(
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: norm,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: 3,
                      height: 18,
                      decoration: BoxDecoration(
                        color: needleColor,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [BoxShadow(
                            color: needleColor.withValues(alpha: 0.6),
                            blurRadius: 4)],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('♭ Flat',
                style: TextStyle(
                    color: const Color(0xFF42A5F5).withValues(alpha: 0.8),
                    fontSize: 10,
                    fontFamily: 'Roboto')),
            Text('In Tune ✓',
                style: TextStyle(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.8),
                    fontSize: 10,
                    fontFamily: 'Roboto')),
            Text('Sharp ♯',
                style: TextStyle(
                    color: Colors.orangeAccent.withValues(alpha: 0.8),
                    fontSize: 10,
                    fontFamily: 'Roboto')),
          ],
        ),
      ],
    );
  }
}

/// Animated "LIVE • Mic Active" badge shown when the mic is running.
class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: Colors.red, size: 7),
          SizedBox(width: 5),
          Text('LIVE  •  Mic Active',
              style: TextStyle(
                  color: Colors.red,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Roboto',
                  letterSpacing: 0.5)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Drill #1 — Ascending Scale  (Do → Re → Mi → Fa → Sol → La → Ti → Do)
// ─────────────────────────────────────────────────────────────────────────────

class _ScaleDrill extends StatefulWidget {
  const _ScaleDrill();
  @override
  State<_ScaleDrill> createState() => _ScaleDrillState();
}

class _ScaleDrillState extends State<_ScaleDrill> {
  final AudioService _audio = AudioService();
  StreamSubscription<NoteResult?>? _sub;

  bool _running = false;
  int  _step    = 0;
  double _liveCents = 0;
  PitchFeedback _feedback = PitchFeedback.noSignal;
  int  _holdMs  = 0;
  Timer? _holdTimer;

  // Mic pulse
  bool  _pulseTick = false;
  Timer? _pulseTimer;

  static const _required = 1200; // ms in-tune to advance
  static final _scale    = kDoReMiSequence;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _sub?.cancel();
    _holdTimer?.cancel();
    _pulseTimer?.cancel();
    _audio.dispose();
    super.dispose();
  }

  // ── Pulse helpers ──────────────────────────────────────────────────────────

  void _startPulse() {
    _pulseTimer = Timer.periodic(const Duration(milliseconds: 600), (_) {
      if (mounted) setState(() => _pulseTick = !_pulseTick);
    });
  }

  void _stopPulse() {
    _pulseTimer?.cancel();
    _pulseTimer = null;
    if (mounted) setState(() => _pulseTick = false);
  }

  // ── Logic (unchanged from original) ───────────────────────────────────────

  Future<void> _toggle() async {
    if (_running) {
      await _sub?.cancel();
      _holdTimer?.cancel();
      _holdTimer = null;
      _stopPulse();
      await _audio.stop();
      setState(() {
        _running  = false;
        _feedback = PitchFeedback.noSignal;
        _liveCents = 0;
        _holdMs   = 0;
      });
    } else {
      final ok =
          await _audio.start(targetFreq: _scale[_step].frequency);
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Microphone permission denied')));
        }
        return;
      }
      setState(() => _running = true);
      _startPulse();

      _sub = _audio.results.listen((result) {
        if (!mounted) return;
        setState(() {
          _feedback  = result?.feedback ?? PitchFeedback.noSignal;
          _liveCents = result?.cents ?? 0;
        });
        if (_feedback == PitchFeedback.correct) {
          _holdTimer ??= Timer.periodic(
              const Duration(milliseconds: 100), (_) {
            if (!mounted) return;
            setState(() => _holdMs += 100);
            if (_holdMs >= _required) {
              _holdTimer?.cancel();
              _holdTimer = null;
              _advance();
            }
          });
        } else {
          _holdTimer?.cancel();
          _holdTimer = null;
          if (mounted) setState(() => _holdMs = 0);
        }
      });
    }
  }

  void _advance() {
    if (_step < _scale.length - 1) {
      _audio.stop().then((_) async {
        if (!mounted) return;
        setState(() {
          _step++;
          _holdMs = 0;
        });
        final ok =
            await _audio.start(targetFreq: _scale[_step].frequency);
        if (!ok || !mounted) return;
        _sub?.cancel();
        _sub = _audio.results.listen((result) {
          if (!mounted) return;
          setState(() {
            _feedback  = result?.feedback ?? PitchFeedback.noSignal;
            _liveCents = result?.cents ?? 0;
          });
          if (_feedback == PitchFeedback.correct) {
            _holdTimer ??= Timer.periodic(
                const Duration(milliseconds: 100), (_) {
              if (!mounted) return;
              setState(() => _holdMs += 100);
              if (_holdMs >= _required) {
                _holdTimer?.cancel();
                _holdTimer = null;
                _advance();
              }
            });
          } else {
            _holdTimer?.cancel();
            _holdTimer = null;
            if (mounted) setState(() => _holdMs = 0);
          }
        });
      });
    } else {
      // All steps complete
      _audio.stop();
      _sub?.cancel();
      _stopPulse();
      setState(() {
        _running = false;
        _step    = 0;
        _holdMs  = 0;
      });
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: AppColors.cardBg,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24)),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🎉', style: TextStyle(fontSize: 64)),
                SizedBox(height: 8),
                Text('Scale Complete!',
                    style: TextStyle(
                        color: AppColors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Roboto')),
                SizedBox(height: 6),
                Text('Awesome — you sang all 8 notes!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppColors.grey,
                        fontSize: 13,
                        fontFamily: 'Roboto')),
              ],
            ),
            actions: [
              Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryCyan,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 12),
                  ),
                  child: const Text('Try Again! 🎵',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Roboto')),
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        );
      }
    }
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final note      = _scale[_step];
    final noteColor = _noteColor(note.solfege);
    final fbColor   = _running ? _fbColor(_feedback) : noteColor;
    final progress  = (_holdMs / _required).clamp(0.0, 1.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        children: [
          // Instruction
          Text(
            'Sing each note and hold it in tune for 1.2 seconds',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppColors.grey.withValues(alpha: 0.8),
                fontSize: 13,
                fontFamily: 'Roboto',
                height: 1.5),
          ),
          const SizedBox(height: 18),

          // Step progress dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_scale.length, (i) {
              final done   = i < _step;
              final active = i == _step;
              final c      = _noteColor(_scale[i].solfege);
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 38 : 26,
                height: 26,
                decoration: BoxDecoration(
                  color: done
                      ? c
                      : active
                          ? c.withValues(alpha: 0.2)
                          : AppColors.inputBg,
                  borderRadius: BorderRadius.circular(13),
                  border: active
                      ? Border.all(color: c, width: 2)
                      : null,
                ),
                child: Center(
                  child: done
                      ? const Icon(Icons.check,
                          color: Colors.white, size: 13)
                      : Text(
                          _scale[i].solfege.substring(0, 1),
                          style: TextStyle(
                              color: active
                                  ? c
                                  : AppColors.grey.withValues(alpha: 0.4),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Roboto'),
                        ),
                ),
              );
            }),
          ),
          const SizedBox(height: 6),

          // Solfège labels under dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_scale.length, (i) {
              final active = i == _step;
              final c      = _noteColor(_scale[i].solfege);
              return SizedBox(
                width: active ? 44 : 32,
                child: Text(
                  _scale[i].solfege,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: active ? c : AppColors.grey.withValues(alpha: 0.35),
                      fontSize: active ? 10 : 9,
                      fontWeight: active ? FontWeight.bold : FontWeight.normal,
                      fontFamily: 'Roboto'),
                ),
              );
            }),
          ),
          const SizedBox(height: 22),

          // Main note card
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: fbColor.withValues(alpha: _running ? 0.65 : 0.3),
                width: 2,
              ),
              boxShadow: _running
                  ? [BoxShadow(
                      color: fbColor.withValues(alpha: 0.14),
                      blurRadius: 22,
                      spreadRadius: 3)]
                  : [],
            ),
            child: Column(
              children: [
                // Live badge
                if (_running) ...[
                  const _LiveBadge(),
                  const SizedBox(height: 14),
                ],

                // Big solfège syllable
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  style: TextStyle(
                      color: fbColor,
                      fontSize: 82,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Roboto',
                      letterSpacing: -2),
                  child: Text(note.solfege),
                ),
                Text(note.noteName,
                    style: TextStyle(
                        color: AppColors.grey.withValues(alpha: 0.7),
                        fontSize: 20,
                        fontFamily: 'Roboto')),
                Text('${note.frequency.toStringAsFixed(1)} Hz',
                    style: TextStyle(
                        color: AppColors.grey.withValues(alpha: 0.45),
                        fontSize: 13,
                        fontFamily: 'Roboto')),

                // Running feedback
                if (_running) ...[
                  const SizedBox(height: 18),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      _fbMsg(_feedback),
                      key: ValueKey(_feedback),
                      style: TextStyle(
                          color: fbColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Roboto'),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Pitch meter
                  _PitchMeter(cents: _liveCents, needleColor: fbColor),
                  const SizedBox(height: 18),

                  // Hold progress bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Hold Progress',
                          style: TextStyle(
                              color: AppColors.grey.withValues(alpha: 0.7),
                              fontSize: 12,
                              fontFamily: 'Roboto')),
                      Text(
                          '${(_holdMs / 1000).toStringAsFixed(1)}s / 1.2s',
                          style: TextStyle(
                              color: fbColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Roboto')),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 14,
                      backgroundColor: AppColors.inputBg,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(fbColor),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Mic button
          _buildMicButton(fbColor),
          const SizedBox(height: 8),
          Text(
            _running ? 'Tap to stop' : 'Tap the mic to start',
            style: TextStyle(
                color: AppColors.grey.withValues(alpha: 0.5),
                fontSize: 12,
                fontFamily: 'Roboto'),
          ),
        ],
      ),
    );
  }

  Widget _buildMicButton(Color accentColor) {
    return GestureDetector(
      onTap: _toggle,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_running)
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              width: _pulseTick ? 102 : 88,
              height: _pulseTick ? 102 : 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    Colors.red.withValues(alpha: _pulseTick ? 0.1 : 0.04),
                border: Border.all(
                    color: Colors.red
                        .withValues(alpha: _pulseTick ? 0.5 : 0.18),
                    width: 2),
              ),
            ),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _running ? Colors.red : AppColors.primaryCyan,
              boxShadow: [
                BoxShadow(
                  color: (_running ? Colors.red : AppColors.primaryCyan)
                      .withValues(alpha: 0.45),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              _running ? Icons.stop_rounded : Icons.mic_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Drill #2 — Sustained Note (hold any note for 3 seconds)
// ─────────────────────────────────────────────────────────────────────────────

class _SustainedNoteDrill extends StatefulWidget {
  const _SustainedNoteDrill();
  @override
  State<_SustainedNoteDrill> createState() => _SustainedNoteDrillState();
}

class _SustainedNoteDrillState extends State<_SustainedNoteDrill> {
  final AudioService _audio = AudioService();
  StreamSubscription<NoteResult?>? _sub;

  bool   _running      = false;
  double _liveCents    = 0;
  PitchFeedback _feedback = PitchFeedback.noSignal;
  String _noteDisplay  = '';
  int    _holdMs       = 0;
  Timer? _holdTimer;
  int    _passCount    = 0;
  int    _targetIndex  = 5; // A4 = La (index 5 in kDoReMiSequence)

  bool  _pulseTick  = false;
  Timer? _pulseTimer;

  static const _requiredMs = 3000;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _sub?.cancel();
    _holdTimer?.cancel();
    _pulseTimer?.cancel();
    _audio.dispose();
    super.dispose();
  }

  // ── Pulse helpers ──────────────────────────────────────────────────────────

  void _startPulse() {
    _pulseTimer =
        Timer.periodic(const Duration(milliseconds: 600), (_) {
      if (mounted) setState(() => _pulseTick = !_pulseTick);
    });
  }

  void _stopPulse() {
    _pulseTimer?.cancel();
    _pulseTimer = null;
    if (mounted) setState(() => _pulseTick = false);
  }

  // ── Logic (unchanged from original) ───────────────────────────────────────

  Future<void> _toggle() async {
    if (_running) {
      await _sub?.cancel();
      _holdTimer?.cancel();
      _holdTimer = null;
      _stopPulse();
      await _audio.stop();
      setState(() {
        _running  = false;
        _feedback = PitchFeedback.noSignal;
        _holdMs   = 0;
      });
    } else {
      final target = kDoReMiSequence[_targetIndex];
      final ok = await _audio.start(targetFreq: target.frequency);
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Microphone permission denied')));
        }
        return;
      }
      setState(() {
        _running = true;
        _holdMs  = 0;
      });
      _startPulse();

      _sub = _audio.results.listen((result) {
        if (!mounted) return;
        setState(() {
          _feedback    = result?.feedback ?? PitchFeedback.noSignal;
          _liveCents   = result?.cents ?? 0;
          _noteDisplay = result?.fullName ?? '';
        });

        if (_feedback == PitchFeedback.correct) {
          _holdTimer ??= Timer.periodic(
              const Duration(milliseconds: 100), (_) {
            if (!mounted) return;
            setState(() => _holdMs += 100);
            if (_holdMs >= _requiredMs) {
              _holdTimer?.cancel();
              _holdTimer = null;
              setState(() {
                _holdMs = 0;
                _passCount++;
              });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('⭐  Great hold!  Rep $_passCount',
                      style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Roboto',
                          fontWeight: FontWeight.w600)),
                  backgroundColor: const Color(0xFF1B3A1B),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  duration: const Duration(seconds: 1),
                ));
              }
            }
          });
        } else {
          _holdTimer?.cancel();
          _holdTimer = null;
          if (mounted) setState(() => _holdMs = 0);
        }
      });
    }
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final target    = kDoReMiSequence[_targetIndex];
    final noteColor = _noteColor(target.solfege);
    final fbColor   = _running ? _fbColor(_feedback) : noteColor;
    final progress  = (_holdMs / _requiredMs).clamp(0.0, 1.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Hold the target note in tune for 3 seconds\nBuilds pitch stability and breath control',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppColors.grey.withValues(alpha: 0.8),
                fontSize: 13,
                fontFamily: 'Roboto',
                height: 1.5),
          ),
          const SizedBox(height: 16),

          // Note picker (hidden while running)
          if (!_running) ...[
            const Text('Pick a note to practise:',
                style: TextStyle(
                    color: AppColors.grey,
                    fontSize: 12,
                    fontFamily: 'Roboto')),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(kDoReMiSequence.length, (i) {
                final n   = kDoReMiSequence[i];
                final sel = _targetIndex == i;
                final c   = _noteColor(n.solfege);
                return GestureDetector(
                  onTap: () => setState(() => _targetIndex = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel
                          ? c.withValues(alpha: 0.18)
                          : AppColors.inputBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: sel ? c : Colors.transparent,
                          width: 1.5),
                    ),
                    child: Text(
                      '${n.solfege}  ${n.noteName}',
                      style: TextStyle(
                          color: sel ? c : AppColors.grey,
                          fontSize: 12,
                          fontWeight: sel
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontFamily: 'Roboto'),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
          ],

          // Main card
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding:
                const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                  color: fbColor
                      .withValues(alpha: _running ? 0.65 : 0.3),
                  width: 2),
              boxShadow: _running
                  ? [BoxShadow(
                      color: fbColor.withValues(alpha: 0.13),
                      blurRadius: 22,
                      spreadRadius: 3)]
                  : [],
            ),
            child: Column(
              children: [
                if (_running) ...[
                  const _LiveBadge(),
                  const SizedBox(height: 14),
                ],

                // Target note
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  style: TextStyle(
                      color: fbColor,
                      fontSize: 76,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Roboto'),
                  child: Text(target.solfege),
                ),
                Text(
                  '${target.noteName}  •  ${target.frequency.toStringAsFixed(0)} Hz',
                  style: TextStyle(
                      color: AppColors.grey.withValues(alpha: 0.6),
                      fontSize: 14,
                      fontFamily: 'Roboto'),
                ),

                if (_running) ...[
                  const SizedBox(height: 18),

                  // Live detected note
                  if (_noteDisplay.isNotEmpty)
                    Text(_noteDisplay,
                        style: TextStyle(
                            color: fbColor,
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Roboto')),
                  const SizedBox(height: 4),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      _fbMsg(_feedback),
                      key: ValueKey(_feedback),
                      style: TextStyle(
                          color: fbColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Roboto'),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Pitch meter
                  _PitchMeter(cents: _liveCents, needleColor: fbColor),
                  const SizedBox(height: 18),

                  // Hold progress
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Hold  ${(_holdMs / 1000).toStringAsFixed(1)}s / 3.0s',
                        style: TextStyle(
                            color: AppColors.grey.withValues(alpha: 0.7),
                            fontSize: 12,
                            fontFamily: 'Roboto'),
                      ),
                      // Star reps (up to 5 visible)
                      Row(
                        children: List.generate(
                            _passCount.clamp(0, 5),
                            (_) => const Padding(
                                  padding: EdgeInsets.only(left: 2),
                                  child: Icon(Icons.star_rounded,
                                      color: Color(0xFFFDD835), size: 16),
                                )),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 16,
                      backgroundColor: AppColors.inputBg,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(fbColor),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text('Total reps: $_passCount',
                        style: const TextStyle(
                            color: AppColors.primaryCyan,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Roboto')),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Mic button
          Center(child: _buildMicButton()),
          const SizedBox(height: 8),
          Center(
            child: Text(
              _running ? 'Tap to stop' : 'Tap the mic to start',
              style: TextStyle(
                  color: AppColors.grey.withValues(alpha: 0.5),
                  fontSize: 12,
                  fontFamily: 'Roboto'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMicButton() {
    return GestureDetector(
      onTap: _toggle,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_running)
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              width: _pulseTick ? 102 : 88,
              height: _pulseTick ? 102 : 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red
                    .withValues(alpha: _pulseTick ? 0.1 : 0.04),
                border: Border.all(
                    color: Colors.red.withValues(
                        alpha: _pulseTick ? 0.5 : 0.18),
                    width: 2),
              ),
            ),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _running ? Colors.red : AppColors.primaryCyan,
              boxShadow: [
                BoxShadow(
                  color:
                      (_running ? Colors.red : AppColors.primaryCyan)
                          .withValues(alpha: 0.45),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              _running ? Icons.stop_rounded : Icons.mic_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Drill #3 — Phrase Loop  (sing → score → repeat)
// ─────────────────────────────────────────────────────────────────────────────

class _PhraseLoopDrill extends StatefulWidget {
  final List<String> phrases;
  const _PhraseLoopDrill({required this.phrases});
  @override
  State<_PhraseLoopDrill> createState() => _PhraseLoopDrillState();
}

class _PhraseLoopDrillState extends State<_PhraseLoopDrill> {
  final AudioService _audio = AudioService();
  StreamSubscription<NoteResult?>? _sub;

  bool   _running      = false;
  int    _phraseIndex  = 0;
  double _liveCents    = 0;
  PitchFeedback _feedback = PitchFeedback.noSignal;
  String _liveNote     = '';

  // Accumulate readings for this rep
  final List<double> _repCents = [];
  int    _repCount       = 0;
  String _lastRepResult  = '';
  Color  _lastRepColor   = AppColors.grey;

  // Custom phrase
  final TextEditingController _customPhraseCtrl = TextEditingController();
  bool _useCustom = false;

  // Pulse
  bool  _pulseTick  = false;
  Timer? _pulseTimer;

  // ── Helpers ────────────────────────────────────────────────────────────────

  List<String> get _phrases {
    if (_useCustom && _customPhraseCtrl.text.trim().isNotEmpty) {
      return [_customPhraseCtrl.text.trim()];
    }
    return widget.phrases.isEmpty
        ? ['Sing any phrase here…']
        : widget.phrases;
  }

  String get _currentPhrase =>
      _phrases[_phraseIndex % _phrases.length];

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _sub?.cancel();
    _pulseTimer?.cancel();
    _audio.dispose();
    _customPhraseCtrl.dispose();
    super.dispose();
  }

  // ── Pulse helpers ──────────────────────────────────────────────────────────

  void _startPulse() {
    _pulseTimer =
        Timer.periodic(const Duration(milliseconds: 600), (_) {
      if (mounted) setState(() => _pulseTick = !_pulseTick);
    });
  }

  void _stopPulse() {
    _pulseTimer?.cancel();
    _pulseTimer = null;
    if (mounted) setState(() => _pulseTick = false);
  }

  // ── Logic (unchanged from original) ───────────────────────────────────────

  Future<void> _toggle() async {
    if (_running) {
      await _endRep();
    } else {
      await _startRep();
    }
  }

  Future<void> _startRep() async {
    _repCents.clear();
    final ok = await _audio.start();
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Microphone permission denied')));
      }
      return;
    }
    setState(() => _running = true);
    _startPulse();

    _sub = _audio.results.listen((result) {
      if (!mounted) return;
      setState(() {
        _feedback  = result?.feedback ?? PitchFeedback.noSignal;
        _liveCents = result?.cents ?? 0;
        _liveNote  = result?.fullName ?? '';
      });
      if (result != null) _repCents.add(result.cents);
    });
  }

  Future<void> _endRep() async {
    await _sub?.cancel();
    _sub = null;
    _stopPulse();
    await _audio.stop();

    String result = 'No signal';
    Color  resultColor = AppColors.grey;

    if (_repCents.isNotEmpty) {
      final avg      = _repCents.reduce((a, b) => a + b) / _repCents.length;
      final flatPct  =
          _repCents.where((c) => c < -15).length / _repCents.length * 100;
      final sharpPct =
          _repCents.where((c) => c > 15).length / _repCents.length * 100;
      final tunePct  =
          _repCents.where((c) => c.abs() <= 15).length /
              _repCents.length *
              100;

      if (tunePct >= 50) {
        result      = '✅  In Tune  (${tunePct.toStringAsFixed(0)}%)';
        resultColor = const Color(0xFF4CAF50);
      } else if (flatPct > sharpPct) {
        result = '⬆️  Flat — avg ${avg.abs().toStringAsFixed(0)}¢ low'
            '  (${flatPct.toStringAsFixed(0)}%)';
        resultColor = const Color(0xFF42A5F5);
      } else {
        result = '⬇️  Sharp — avg ${avg.abs().toStringAsFixed(0)}¢ high'
            '  (${sharpPct.toStringAsFixed(0)}%)';
        resultColor = Colors.orangeAccent;
      }
      _repCount++;
      // Advance phrase every 3 reps
      if (_repCount % 3 == 0 && _phrases.length > 1) {
        _phraseIndex = (_phraseIndex + 1) % _phrases.length;
      }
    }

    setState(() {
      _running       = false;
      _feedback      = PitchFeedback.noSignal;
      _liveNote      = '';
      _liveCents     = 0;
      _lastRepResult = result;
      _lastRepColor  = resultColor;
      _repCents.clear();
    });
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final fbColor = _running ? _fbColor(_feedback) : AppColors.grey;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Sing the phrase, then tap Stop to score.\nRepeat until consistently in tune.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppColors.grey.withValues(alpha: 0.8),
                fontSize: 13,
                fontFamily: 'Roboto',
                height: 1.5),
          ),
          const SizedBox(height: 16),

          // Custom phrase toggle
          Row(
            children: [
              Switch(
                value: _useCustom,
                onChanged: (v) => setState(() => _useCustom = v),
                activeThumbColor: AppColors.primaryCyan,
                activeTrackColor: AppColors.primaryCyan.withValues(alpha: 0.4),
              ),
              const Text('Use custom phrase',
                  style: TextStyle(
                      color: AppColors.grey,
                      fontSize: 13,
                      fontFamily: 'Roboto')),
            ],
          ),
          if (_useCustom) ...[
            const SizedBox(height: 6),
            TextField(
              controller: _customPhraseCtrl,
              style: const TextStyle(
                  color: AppColors.white, fontFamily: 'Roboto'),
              decoration: InputDecoration(
                hintText: 'Type a lyric phrase…',
                hintStyle: TextStyle(
                    color: AppColors.grey.withValues(alpha: 0.5),
                    fontFamily: 'Roboto'),
                filled: true,
                fillColor: AppColors.inputBg,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
          const SizedBox(height: 16),

          // Phrase card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppColors.primaryCyan.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Text(
                  'Phrase ${_phraseIndex + 1} of ${_phrases.length}',
                  style: TextStyle(
                      color: AppColors.grey.withValues(alpha: 0.5),
                      fontSize: 11,
                      fontFamily: 'Roboto'),
                ),
                const SizedBox(height: 8),
                Text(
                  _currentPhrase,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Roboto',
                      height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Live feedback area
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: _running
                ? const EdgeInsets.all(20)
                : EdgeInsets.zero,
            decoration: BoxDecoration(
              color: _running ? AppColors.cardBg : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: _running
                  ? Border.all(
                      color: fbColor.withValues(alpha: 0.5))
                  : null,
            ),
            child: _running
                ? Column(
                    children: [
                      const _LiveBadge(),
                      const SizedBox(height: 12),
                      // Live note display
                      Text(
                        _liveNote.isEmpty ? '—' : _liveNote,
                        style: TextStyle(
                            color: fbColor,
                            fontSize: 52,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Roboto'),
                      ),
                      const SizedBox(height: 4),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          _fbMsg(_feedback),
                          key: ValueKey(_feedback),
                          style: TextStyle(
                              color: fbColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Roboto'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _PitchMeter(
                          cents: _liveCents, needleColor: fbColor),
                    ],
                  )
                : const SizedBox.shrink(),
          ),

          // Last rep result
          if (_lastRepResult.isNotEmpty && !_running) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _lastRepColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: _lastRepColor.withValues(alpha: 0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Rep #$_repCount Result',
                      style: TextStyle(
                          color: _lastRepColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Roboto')),
                  const SizedBox(height: 4),
                  Text(_lastRepResult,
                      style: TextStyle(
                          color: _lastRepColor,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Roboto')),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),

          // Mic button
          Center(child: _buildMicButton()),
          const SizedBox(height: 8),
          Center(
            child: Text(
              _running
                  ? 'Tap to stop & score'
                  : 'Tap the mic to start singing',
              style: TextStyle(
                  color: AppColors.grey.withValues(alpha: 0.5),
                  fontSize: 12,
                  fontFamily: 'Roboto'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMicButton() {
    return GestureDetector(
      onTap: _toggle,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_running)
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              width: _pulseTick ? 102 : 88,
              height: _pulseTick ? 102 : 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red
                    .withValues(alpha: _pulseTick ? 0.1 : 0.04),
                border: Border.all(
                    color: Colors.red.withValues(
                        alpha: _pulseTick ? 0.5 : 0.18),
                    width: 2),
              ),
            ),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _running ? Colors.red : AppColors.primaryCyan,
              boxShadow: [
                BoxShadow(
                  color:
                      (_running ? Colors.red : AppColors.primaryCyan)
                          .withValues(alpha: 0.45),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              _running ? Icons.stop_rounded : Icons.mic_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
        ],
      ),
    );
  }
}
