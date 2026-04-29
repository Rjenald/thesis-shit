import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../core/audio_service.dart';
import '../core/note_utils.dart';

class SolfegeDrillModePage extends StatefulWidget {
  final List<String> sequence;
  final String className;
  final bool startInActivityMode;

  const SolfegeDrillModePage({
    super.key,
    required this.sequence,
    required this.className,
    this.startInActivityMode = false,
  });

  @override
  State<SolfegeDrillModePage> createState() => _SolfegeDrillModePageState();
}

class _SolfegeDrillModePageState extends State<SolfegeDrillModePage> {
  late bool _isActivityMode;

  @override
  void initState() {
    super.initState();
    _isActivityMode = widget.startInActivityMode;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            // Cyan header
            Container(
              width: double.infinity,
              color: AppColors.primaryCyan,
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.black,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            widget.className.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                              fontFamily: 'Roboto',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Lesson 1: Solfege Drill / ',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            fontFamily: 'Roboto',
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(
                            () => _isActivityMode = !_isActivityMode,
                          ),
                          child: Text(
                            _isActivityMode
                                ? 'Solfege Activity'
                                : 'Practice Solfege',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              fontFamily: 'Roboto',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isActivityMode
                        ? 'Tap to switch to Practice'
                        : 'Tap to switch to Activity',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.black.withValues(alpha: 0.6),
                      fontFamily: 'Roboto',
                    ),
                  ),
                ],
              ),
            ),

            // Body
            Expanded(
              child: _isActivityMode
                  ? _SolfegeActivityView(sequence: widget.sequence)
                  : const _PracticeSolfegeView(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Practice Solfege View (matches Figma screenshot 3)
// ─────────────────────────────────────────────────────────────────
class _PracticeSolfegeView extends StatefulWidget {
  const _PracticeSolfegeView();

  @override
  State<_PracticeSolfegeView> createState() => _PracticeSolfegeViewState();
}

class _PracticeSolfegeViewState extends State<_PracticeSolfegeView> {
  static const _syllables = ['do', 're', 'mi', 'fa', 'so', 'la', 'ti'];

  int _index = 0;
  bool _recording = false;
  String _accuracy = '—';
  String _userRange = '—';
  Timer? _recordTimer;

  String get _current => _syllables[_index];

  @override
  void dispose() {
    _recordTimer?.cancel();
    super.dispose();
  }

  void _toggleRecord() {
    if (_recording) {
      _recordTimer?.cancel();
      setState(() {
        _recording = false;
        _accuracy = '${(78 + _index * 3) % 100}%';
        _userRange = 'C3 – C4';
      });
    } else {
      setState(() {
        _recording = true;
        _accuracy = '—';
        _userRange = '—';
      });
      _recordTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _recording = false;
            _accuracy = '${(78 + _index * 3) % 100}%';
            _userRange = 'C3 – C4';
            _index = (_index + 1) % _syllables.length;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Big note display card
          Container(
            height: 300,
            decoration: BoxDecoration(
              color: AppColors.inputBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                _current,
                style: const TextStyle(
                  fontSize: 120,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'Roboto',
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Details
          const Text(
            'Details',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: 'Roboto',
            ),
          ),
          const SizedBox(height: 12),
          _detailRow('Accuracy:', _accuracy),
          const SizedBox(height: 10),
          _detailRow('User Range:', _userRange),
          const SizedBox(height: 32),

          // Record button
          Center(
            child: GestureDetector(
              onTap: _toggleRecord,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: _recording ? Colors.red.shade700 : Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.4),
                      blurRadius: _recording ? 20 : 0,
                      spreadRadius: _recording ? 4 : 0,
                    ),
                  ],
                ),
                child: Icon(
                  _recording ? Icons.stop : Icons.mic,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              _recording ? 'Recording...' : 'Tap to record',
              style: TextStyle(
                color: AppColors.grey.withValues(alpha: 0.7),
                fontSize: 12,
                fontFamily: 'Roboto',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.inputBg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              fontFamily: 'Roboto',
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: AppColors.grey.withValues(alpha: 0.9),
              fontSize: 14,
              fontFamily: 'Roboto',
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Solfege Activity View (matches Figma screenshot 4)
// ─────────────────────────────────────────────────────────────────
class _SolfegeActivityView extends StatefulWidget {
  final List<String> sequence;

  const _SolfegeActivityView({required this.sequence});

  @override
  State<_SolfegeActivityView> createState() => _SolfegeActivityViewState();
}

class _SolfegeActivityViewState extends State<_SolfegeActivityView> {
  final AudioService _audio = AudioService();
  StreamSubscription<NoteResult?>? _sub;

  late List<String> _activeSequence;
  int _currentStep = 0;
  bool _running = false;
  PitchFeedback _feedback = PitchFeedback.noSignal;
  int _holdMs = 0;
  Timer? _holdTimer;
  int _score = 0;
  bool? _hitYes; // null = no result yet, true = YES, false = NO

  static const _required = 1200;

  @override
  void initState() {
    super.initState();
    _activeSequence = widget.sequence.isNotEmpty
        ? widget.sequence
        : const ['Do', 'Mi', 'Mi', 'Mi', 'Fa', 'Mi', 'So', 'La', 'La', 'Mi'];
  }

  @override
  void dispose() {
    _sub?.cancel();
    _holdTimer?.cancel();
    _audio.stop();
    super.dispose();
  }

  Future<void> _toggleRecord() async {
    if (_running) {
      _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    setState(() {
      _running = true;
      _hitYes = null;
    });
    try {
      await _audio.start();
      _sub = _audio.results.listen(_onNoteResult);
    } catch (e) {
      setState(() => _running = false);
    }
  }

  void _stopRecording() {
    _sub?.cancel();
    _sub = null;
    _holdTimer?.cancel();
    _audio.stop();
    setState(() {
      _running = false;
      _holdMs = 0;
    });
  }

  void _onNoteResult(NoteResult? result) {
    if (result == null || !_running) return;
    if (_currentStep >= _activeSequence.length) return;

    final target = _activeSequence[_currentStep];
    final detected = result.solfege;

    setState(() {
      _feedback = result.feedback;
    });

    if (detected == target && result.feedback == PitchFeedback.correct) {
      _holdMs += 50;
      if (_holdMs >= _required) {
        _holdMs = 0;
        setState(() {
          _hitYes = true;
          _score++;
          _currentStep++;
        });
        if (_currentStep >= _activeSequence.length) {
          _stopRecording();
        }
      }
    } else {
      _holdMs = 0;
      if (detected != null && detected != target) {
        setState(() => _hitYes = false);
      }
    }
  }

  void _submit() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text(
          'Activity Submitted',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Your score: $_score out of ${_activeSequence.length}',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text(
              'OK',
              style: TextStyle(color: AppColors.primaryCyan),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentTarget = _currentStep < _activeSequence.length
        ? _activeSequence[_currentStep]
        : _activeSequence.last;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Instruction box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.inputBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Instruction: Hit each note in the sequence in order. The note will advance automatically when you sing it correctly.',
              style: TextStyle(
                color: AppColors.grey.withValues(alpha: 0.9),
                fontSize: 13,
                fontFamily: 'Roboto',
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Two-column note grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 3.2,
            ),
            itemCount: _activeSequence.length,
            itemBuilder: (context, index) {
              final isCurrent = index == _currentStep;
              final isDone = index < _currentStep;
              return Container(
                decoration: BoxDecoration(
                  color: isCurrent
                      ? AppColors.primaryCyan
                      : (isDone
                            ? const Color(0xFF4CAF50).withValues(alpha: 0.3)
                            : Colors.white),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    _activeSequence[index],
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isCurrent ? Colors.black : Colors.black87,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Hit Note + YES/NO
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.inputBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text(
                      'Hit Note: ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Roboto',
                      ),
                    ),
                    Text(
                      currentTarget,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Roboto',
                      ),
                    ),
                    const Spacer(),
                    if (_hitYes != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _hitYes!
                              ? const Color(0xFF4CAF50)
                              : Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _hitYes! ? 'YES' : 'NO',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Roboto',
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                // Tuning indicator
                Row(
                  children: [
                    Text(
                      'TOO HIGH',
                      style: TextStyle(
                        color: AppColors.grey.withValues(alpha: 0.7),
                        fontSize: 10,
                        fontFamily: 'Roboto',
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 1,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        color: AppColors.grey.withValues(alpha: 0.5),
                        child: Align(
                          alignment: _feedback == PitchFeedback.correct
                              ? Alignment.center
                              : (_feedback == PitchFeedback.tooHigh
                                    ? Alignment.centerLeft
                                    : Alignment.centerRight),
                          child: Container(
                            width: 2,
                            height: 12,
                            color: AppColors.primaryCyan,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      'TOO LOW',
                      style: TextStyle(
                        color: AppColors.grey.withValues(alpha: 0.7),
                        fontSize: 10,
                        fontFamily: 'Roboto',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Score
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primaryCyan,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Score:\n$_score out of ${_activeSequence.length}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Roboto',
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Record button
          Center(
            child: GestureDetector(
              onTap: _toggleRecord,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: _running ? Colors.red.shade700 : Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.4),
                      blurRadius: _running ? 20 : 0,
                      spreadRadius: _running ? 4 : 0,
                    ),
                  ],
                ),
                child: Icon(
                  _running ? Icons.stop : Icons.mic,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Submit button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.inputBg,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Submit',
                style: TextStyle(
                  fontSize: 16,
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
