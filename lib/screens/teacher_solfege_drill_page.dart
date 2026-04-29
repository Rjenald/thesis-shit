import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../core/audio_service.dart';
import '../core/note_utils.dart';

class TeacherSolfegeDrill extends StatefulWidget {
  final List<String> sequence;
  final String lessonTitle;

  const TeacherSolfegeDrill({
    super.key,
    required this.sequence,
    this.lessonTitle = 'Solfege Drill',
  });

  @override
  State<TeacherSolfegeDrill> createState() => _TeacherSolfegeDrillState();
}

class _TeacherSolfegeDrillState extends State<TeacherSolfegeDrill> {
  final AudioService _audio = AudioService();
  StreamSubscription<NoteResult?>? _sub;

  late List<String> _sequence;
  int _currentStep = 0;
  bool _running = false;
  double _liveCents = 0;
  PitchFeedback _feedback = PitchFeedback.noSignal;
  int _holdMs = 0;
  Timer? _holdTimer;
  Timer? _pulseTimer;
  bool _pulseTick = false;

  static const _required = 1200; // ms in-tune to advance

  final Map<String, Color> _noteColorMap = {
    'Do': Color(0xFFE53935),
    'Re': Color(0xFFFF7043),
    'Mi': Color(0xFFFDD835),
    'Fa': Color(0xFF43A047),
    'Sol': Color(0xFF1E88E5),
    'La': Color(0xFF8E24AA),
    'Ti': Color(0xFF00ACC1),
  };

  @override
  void initState() {
    super.initState();
    _sequence = widget.sequence;
  }

  @override
  void dispose() {
    _sub?.cancel();
    _holdTimer?.cancel();
    _pulseTimer?.cancel();
    _audio.dispose();
    super.dispose();
  }

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

  Future<void> _toggle() async {
    if (_running) {
      await _stop();
    } else {
      await _start();
    }
  }

  Future<void> _start() async {
    if (_currentStep >= _sequence.length) return;

    final noteName = _sequence[_currentStep];
    final note = kDoReMiSequence.firstWhere(
      (n) => n.solfege == noteName,
      orElse: () => kDoReMiSequence.first,
    );

    final ok = await _audio.start(targetFreq: note.frequency);
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied')),
        );
      }
      return;
    }

    setState(() => _running = true);
    _startPulse();

    _sub = _audio.results.listen((result) {
      if (!mounted) return;
      setState(() {
        _feedback = result?.feedback ?? PitchFeedback.noSignal;
        _liveCents = result?.cents ?? 0;
      });

      if (_feedback == PitchFeedback.correct) {
        _holdTimer ??= Timer.periodic(const Duration(milliseconds: 100), (_) {
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

  Future<void> _stop() async {
    await _sub?.cancel();
    _holdTimer?.cancel();
    _holdTimer = null;
    _stopPulse();
    await _audio.stop();
    setState(() {
      _running = false;
      _feedback = PitchFeedback.noSignal;
      _liveCents = 0;
      _holdMs = 0;
    });
  }

  void _advance() async {
    if (_currentStep < _sequence.length - 1) {
      await _audio.stop();
      if (!mounted) return;
      setState(() {
        _currentStep++;
        _holdMs = 0;
        _feedback = PitchFeedback.noSignal;
      });

      // Restart audio for next note
      await Future.delayed(const Duration(milliseconds: 300));
      await _start();
    } else {
      // All steps complete
      await _stop();
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: AppColors.cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎉', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 8),
                const Text(
                  'Drill Complete!',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Roboto',
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'You sang all ${_sequence.length} notes perfectly!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.grey,
                    fontSize: 13,
                    fontFamily: 'Roboto',
                  ),
                ),
              ],
            ),
            actions: [
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _resetDrill();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryCyan,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    'Try Again! 🎵',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }
    }
  }

  void _resetDrill() {
    setState(() {
      _currentStep = 0;
      _holdMs = 0;
      _feedback = PitchFeedback.noSignal;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentNote = _currentStep < _sequence.length
        ? _sequence[_currentStep]
        : 'Complete';
    final progress = _sequence.isNotEmpty
        ? (_currentStep + 1) / _sequence.length
        : 0.0;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 16, 20),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      color: AppColors.white,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.lessonTitle,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.white,
                            fontFamily: 'Roboto',
                          ),
                        ),
                        const Row(
                          children: [
                            Icon(
                              Icons.circle,
                              color: Color(0xFF4CAF50),
                              size: 7,
                            ),
                            SizedBox(width: 5),
                            Text(
                              'Auto-progression • Real-time Detection',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.primaryCyan,
                                fontFamily: 'Roboto',
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Progress bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Progress',
                        style: TextStyle(
                          color: AppColors.grey.withValues(alpha: 0.7),
                          fontSize: 12,
                          fontFamily: 'Roboto',
                        ),
                      ),
                      Text(
                        '${_currentStep + 1}/${_sequence.length}',
                        style: const TextStyle(
                          color: AppColors.primaryCyan,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Roboto',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: AppColors.inputBg,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primaryCyan,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Current note display
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Large note circle
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          _noteColorMap[currentNote] ?? AppColors.primaryCyan,
                      boxShadow: [
                        BoxShadow(
                          color:
                              (_noteColorMap[currentNote] ??
                                      AppColors.primaryCyan)
                                  .withValues(alpha: 0.4),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        currentNote,
                        style: const TextStyle(
                          fontSize: 72,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'Roboto',
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Instruction
                  Text(
                    'Sing the note to continue',
                    style: TextStyle(
                      color: AppColors.grey.withValues(alpha: 0.7),
                      fontSize: 14,
                      fontFamily: 'Roboto',
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Pitch meter
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _PitchMeter(
                      cents: _liveCents,
                      needleColor: _fbColor(_feedback),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Feedback message
                  Text(
                    _fbMsg(_feedback),
                    style: TextStyle(
                      color: _fbColor(_feedback),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Roboto',
                    ),
                  ),

                  // Hold progress
                  if (_feedback == PitchFeedback.correct)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Column(
                        children: [
                          Text(
                            'Holding...',
                            style: TextStyle(
                              color: const Color(
                                0xFF4CAF50,
                              ).withValues(alpha: 0.7),
                              fontSize: 12,
                              fontFamily: 'Roboto',
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: 100,
                            height: 4,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: _holdMs / _required,
                                backgroundColor: AppColors.inputBg,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF4CAF50),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Start/Stop button
            Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: GestureDetector(
                onTap: _toggle,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _running
                        ? Colors.red.withValues(alpha: 0.3)
                        : AppColors.primaryCyan,
                    border: Border.all(
                      color: _running ? Colors.red : AppColors.primaryCyan,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (_running ? Colors.red : AppColors.primaryCyan)
                            .withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    _running ? Icons.mic : Icons.mic_none,
                    color: _running ? Colors.red : Colors.black,
                    size: 36,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _fbColor(PitchFeedback f) {
    switch (f) {
      case PitchFeedback.correct:
        return const Color(0xFF4CAF50);
      case PitchFeedback.tooHigh:
        return Colors.orangeAccent;
      case PitchFeedback.tooLow:
        return const Color(0xFF42A5F5);
      case PitchFeedback.noSignal:
        return AppColors.grey;
    }
  }

  String _fbMsg(PitchFeedback f) {
    switch (f) {
      case PitchFeedback.correct:
        return '🎯 Perfect! Hold it...';
      case PitchFeedback.tooLow:
        return '⬆️ Sing a bit higher!';
      case PitchFeedback.tooHigh:
        return '⬇️ Bring it down a little!';
      case PitchFeedback.noSignal:
        return '🎤 Start singing…';
    }
  }
}

class _PitchMeter extends StatelessWidget {
  final double cents;
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
              Row(
                children: [
                  Expanded(
                    flex: 35,
                    child: Container(
                      height: 18,
                      color: const Color(0xFF42A5F5).withValues(alpha: 0.25),
                    ),
                  ),
                  Expanded(
                    flex: 30,
                    child: Container(
                      height: 18,
                      color: const Color(0xFF4CAF50).withValues(alpha: 0.25),
                    ),
                  ),
                  Expanded(
                    flex: 35,
                    child: Container(
                      height: 18,
                      color: Colors.orangeAccent.withValues(alpha: 0.25),
                    ),
                  ),
                ],
              ),
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
                        boxShadow: [
                          BoxShadow(
                            color: needleColor.withValues(alpha: 0.6),
                            blurRadius: 4,
                          ),
                        ],
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
            Text(
              '♭ Flat',
              style: TextStyle(
                color: const Color(0xFF42A5F5).withValues(alpha: 0.8),
                fontSize: 10,
                fontFamily: 'Roboto',
              ),
            ),
            Text(
              'In Tune ✓',
              style: TextStyle(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.8),
                fontSize: 10,
                fontFamily: 'Roboto',
              ),
            ),
            Text(
              'Sharp ♯',
              style: TextStyle(
                color: Colors.orangeAccent.withValues(alpha: 0.8),
                fontSize: 10,
                fontFamily: 'Roboto',
              ),
            ),
          ],
        ),
      ],
    );
  }
}
