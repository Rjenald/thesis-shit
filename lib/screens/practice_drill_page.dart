import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../core/audio_service.dart';
import '../core/note_utils.dart';

/// Practice Drill Module — three drills for improving pitch accuracy:
///   Drill #1: Ascending Scale Exercise (Do → Re → Mi → Fa → Sol)
///   Drill #2: Sustained Note Practice (hold a target note for 3 seconds)
///   Drill #3: Phrase Loop Practice (repeat problem phrases with real-time feedback)
class PracticeDrillPage extends StatefulWidget {
  /// Problem phrases passed from the results page for Drill #3.
  final List<String> problemLines;

  const PracticeDrillPage({super.key, this.problemLines = const []});

  @override
  State<PracticeDrillPage> createState() => _PracticeDrillPageState();
}

class _PracticeDrillPageState extends State<PracticeDrillPage> {
  int _selectedDrill = 0; // 0 = Scale, 1 = Sustained, 2 = Phrase Loop

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildDrillTabs(),
            Expanded(child: _buildDrillContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back,
                color: AppColors.white, size: 26),
            onPressed: () => Navigator.pop(context),
          ),
          const Text('Practice Drills',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.white,
                  fontFamily: 'Roboto')),
        ],
      ),
    );
  }

  Widget _buildDrillTabs() {
    final labels = ['#1 Scale', '#2 Sustain', '#3 Phrase'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: List.generate(3, (i) {
          final selected = _selectedDrill == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedDrill = i),
              child: Container(
                margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primaryCyan
                      : AppColors.inputBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(labels[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: selected
                            ? Colors.black
                            : AppColors.grey,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        fontFamily: 'Roboto')),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDrillContent() {
    switch (_selectedDrill) {
      case 0:
        return const _ScaleDrill();
      case 1:
        return const _SustainedNoteDrill();
      case 2:
        return _PhraseLoopDrill(phrases: widget.problemLines);
      default:
        return const SizedBox();
    }
  }
}

// ── Drill #1: Ascending Scale ─────────────────────────────────────────────────

class _ScaleDrill extends StatefulWidget {
  const _ScaleDrill();

  @override
  State<_ScaleDrill> createState() => _ScaleDrillState();
}

class _ScaleDrillState extends State<_ScaleDrill> {
  final AudioService _audio = AudioService();
  StreamSubscription<NoteResult?>? _sub;
  bool _running = false;
  int _step = 0;
  double _liveCents = 0;
  PitchFeedback _feedback = PitchFeedback.noSignal;
  int _holdMs = 0; // ms spent in-tune on current step
  Timer? _holdTimer;

  static const _required = 1200; // ms in-tune to advance

  // Scale: Do → Re → Mi → Fa → Sol → La → Ti → Do (C4 through C5)
  static final _scale = kDoReMiSequence;

  @override
  void initState() {
    super.initState();
    _audio.initialize(); // pre-load CREPE model
  }

  @override
  void dispose() {
    _sub?.cancel();
    _holdTimer?.cancel();
    _audio.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_running) {
      await _sub?.cancel();
      _holdTimer?.cancel();
      await _audio.stop();
      _audio.saveRecording(
          'huni_scale_${DateTime.now().millisecondsSinceEpoch}');
      setState(() {
        _running = false;
        _feedback = PitchFeedback.noSignal;
        _liveCents = 0;
      });
    } else {
      _audio.enableSaving();
      final ok = await _audio.start(
          targetFreq: _scale[_step].frequency);
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Microphone permission denied')));
        }
        return;
      }
      setState(() => _running = true);

      _sub = _audio.results.listen((result) {
        if (!mounted) return;
        setState(() {
          _feedback = result?.feedback ?? PitchFeedback.noSignal;
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
        final ok = await _audio.start(
            targetFreq: _scale[_step].frequency);
        if (!ok || !mounted) return;
        _sub?.cancel();
        _sub = _audio.results.listen((result) {
          if (!mounted) return;
          setState(() {
            _feedback = result?.feedback ?? PitchFeedback.noSignal;
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
      // Completed all steps
      _audio.stop();
      _sub?.cancel();
      setState(() {
        _running = false;
        _step = 0;
        _holdMs = 0;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Scale complete! Great work!'),
            backgroundColor: AppColors.cardBg,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
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

  @override
  Widget build(BuildContext context) {
    final note = _scale[_step];
    final progress = _holdMs / _required;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Text(
            'Sing each note until the bar fills.\nHold the note in tune for 1.2 seconds.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppColors.grey,
                fontSize: 13,
                fontFamily: 'Roboto',
                height: 1.5),
          ),
          const SizedBox(height: 28),

          // Scale step indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_scale.length, (i) {
              final done = i < _step;
              final active = i == _step;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: active ? 32 : 20,
                height: 20,
                decoration: BoxDecoration(
                  color: done
                      ? AppColors.primaryCyan
                      : active
                          ? AppColors.primaryCyan.withValues(alpha: 0.3)
                          : AppColors.inputBg,
                  borderRadius: BorderRadius.circular(10),
                  border: active
                      ? Border.all(
                          color: AppColors.primaryCyan, width: 1.5)
                      : null,
                ),
                child: active
                    ? null
                    : done
                        ? const Icon(Icons.check,
                            color: Colors.black, size: 12)
                        : null,
              );
            }),
          ),

          const SizedBox(height: 32),

          // Target note
          Text(note.solfege,
              style: TextStyle(
                  color: _feedbackColor,
                  fontSize: 72,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Roboto')),
          Text(note.noteName,
              style: TextStyle(
                  color: AppColors.grey.withValues(alpha: 0.7),
                  fontSize: 20,
                  fontFamily: 'Roboto')),
          Text('${note.frequency.toStringAsFixed(1)} Hz',
              style: TextStyle(
                  color: AppColors.grey.withValues(alpha: 0.5),
                  fontSize: 14,
                  fontFamily: 'Roboto')),

          const SizedBox(height: 32),

          // Hold progress
          if (_running) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Hold Progress',
                    style: TextStyle(
                        color: AppColors.grey.withValues(alpha: 0.7),
                        fontSize: 12,
                        fontFamily: 'Roboto')),
                Text('${_liveCents.toStringAsFixed(0)} ¢',
                    style: TextStyle(
                        color: _feedbackColor,
                        fontSize: 12,
                        fontFamily: 'Roboto')),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 12,
                backgroundColor: AppColors.inputBg,
                valueColor:
                    AlwaysStoppedAnimation<Color>(_feedbackColor),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _feedback == PitchFeedback.correct
                  ? 'Hold it!'
                  : _feedback == PitchFeedback.tooLow
                      ? 'Too flat — sing higher'
                      : _feedback == PitchFeedback.tooHigh
                          ? 'Too sharp — sing lower'
                          : 'Start singing…',
              style: TextStyle(
                  color: _feedbackColor,
                  fontSize: 14,
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.w600),
            ),
          ],

          const Spacer(),

          ElevatedButton.icon(
            onPressed: _toggle,
            icon: Icon(_running ? Icons.stop : Icons.mic,
                size: 20),
            label:
                Text(_running ? 'Stop Drill' : 'Start Drill #1'),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _running ? Colors.red : AppColors.primaryCyan,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(
                  horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Drill #2: Sustained Note ──────────────────────────────────────────────────

class _SustainedNoteDrill extends StatefulWidget {
  const _SustainedNoteDrill();

  @override
  State<_SustainedNoteDrill> createState() => _SustainedNoteDrillState();
}

class _SustainedNoteDrillState extends State<_SustainedNoteDrill> {
  final AudioService _audio = AudioService();
  StreamSubscription<NoteResult?>? _sub;
  bool _running = false;
  double _liveCents = 0;
  PitchFeedback _feedback = PitchFeedback.noSignal;
  String _noteDisplay = '';

  int _holdMs = 0;
  Timer? _holdTimer;
  int _passCount = 0;

  // Target: A4 = 440 Hz (La). User can change.
  int _targetIndex = 5; // index into kDoReMiSequence
  static const _requiredMs = 3000;

  @override
  void initState() {
    super.initState();
    _audio.initialize(); // pre-load CREPE model
  }

  @override
  void dispose() {
    _sub?.cancel();
    _holdTimer?.cancel();
    _audio.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_running) {
      await _sub?.cancel();
      _holdTimer?.cancel();
      await _audio.stop();
      _audio.saveRecording(
          'huni_sustain_${DateTime.now().millisecondsSinceEpoch}');
      setState(() {
        _running = false;
        _feedback = PitchFeedback.noSignal;
        _holdMs = 0;
      });
    } else {
      _audio.enableSaving();
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
        _holdMs = 0;
      });

      _sub = _audio.results.listen((result) {
        if (!mounted) return;
        setState(() {
          _feedback = result?.feedback ?? PitchFeedback.noSignal;
          _liveCents = result?.cents ?? 0;
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
                  content: Text('Held note! Total: $_passCount reps'),
                  backgroundColor: AppColors.cardBg,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
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

  @override
  Widget build(BuildContext context) {
    final target = kDoReMiSequence[_targetIndex];
    final progress = _holdMs / _requiredMs;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Text(
            'Hold the target note in tune for 3 seconds.\nThis builds pitch stability and breath control.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppColors.grey,
                fontSize: 13,
                fontFamily: 'Roboto',
                height: 1.5),
          ),
          const SizedBox(height: 20),

          // Note picker
          if (!_running)
            Wrap(
              spacing: 8,
              children: List.generate(
                kDoReMiSequence.length,
                (i) => GestureDetector(
                  onTap: () => setState(() => _targetIndex = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _targetIndex == i
                          ? AppColors.primaryCyan
                          : AppColors.inputBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${kDoReMiSequence[i].solfege} (${kDoReMiSequence[i].noteName})',
                      style: TextStyle(
                          color: _targetIndex == i
                              ? Colors.black
                              : AppColors.grey,
                          fontSize: 12,
                          fontFamily: 'Roboto'),
                    ),
                  ),
                ),
              ),
            ),

          const SizedBox(height: 28),

          // Target display
          Text(target.solfege,
              style: TextStyle(
                  color: _feedbackColor,
                  fontSize: 72,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Roboto')),
          Text('${target.noteName} — ${target.frequency.toStringAsFixed(0)} Hz',
              style: TextStyle(
                  color: AppColors.grey.withValues(alpha: 0.6),
                  fontSize: 16,
                  fontFamily: 'Roboto')),

          const SizedBox(height: 16),

          if (_running) ...[
            Text(
              _noteDisplay.isEmpty ? '—' : _noteDisplay,
              style: TextStyle(
                  color: _feedbackColor,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Roboto'),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Flat',
                    style: TextStyle(
                        color: AppColors.grey.withValues(alpha: 0.6),
                        fontSize: 11,
                        fontFamily: 'Roboto')),
                Text('${_liveCents.toStringAsFixed(0)} ¢',
                    style: TextStyle(
                        color: _feedbackColor,
                        fontSize: 11,
                        fontFamily: 'Roboto')),
                Text('Sharp',
                    style: TextStyle(
                        color: AppColors.grey.withValues(alpha: 0.6),
                        fontSize: 11,
                        fontFamily: 'Roboto')),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (_liveCents.clamp(-50, 50) + 50) / 100,
                minHeight: 7,
                backgroundColor: AppColors.inputBg,
                valueColor:
                    AlwaysStoppedAnimation<Color>(_feedbackColor),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Hold (${(_holdMs / 1000).toStringAsFixed(1)}s / 3.0s)',
                    style: TextStyle(
                        color: AppColors.grey.withValues(alpha: 0.7),
                        fontSize: 12,
                        fontFamily: 'Roboto')),
                Text('Reps: $_passCount',
                    style: const TextStyle(
                        color: AppColors.primaryCyan,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Roboto')),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 12,
                backgroundColor: AppColors.inputBg,
                valueColor:
                    AlwaysStoppedAnimation<Color>(_feedbackColor),
              ),
            ),
          ],

          const Spacer(),

          ElevatedButton.icon(
            onPressed: _toggle,
            icon: Icon(_running ? Icons.stop : Icons.mic, size: 20),
            label: Text(_running ? 'Stop Drill' : 'Start Drill #2'),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _running ? Colors.red : AppColors.primaryCyan,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(
                  horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Drill #3: Phrase Loop ──────────────────────────────────────────────────────

class _PhraseLoopDrill extends StatefulWidget {
  final List<String> phrases;
  const _PhraseLoopDrill({required this.phrases});

  @override
  State<_PhraseLoopDrill> createState() => _PhraseLoopDrillState();
}

class _PhraseLoopDrillState extends State<_PhraseLoopDrill> {
  final AudioService _audio = AudioService();
  StreamSubscription<NoteResult?>? _sub;
  bool _running = false;
  int _phraseIndex = 0;
  double _liveCents = 0;
  PitchFeedback _feedback = PitchFeedback.noSignal;
  String _liveNote = '';

  @override
  void initState() {
    super.initState();
    _audio.initialize(); // pre-load CREPE model
  }

  // Accumulate readings for this rep
  final List<double> _repCents = [];
  int _repCount = 0;
  String _lastRepResult = '';

  // Custom phrase input
  final TextEditingController _customPhraseCtrl = TextEditingController();
  bool _useCustom = false;

  List<String> get _phrases {
    if (_useCustom && _customPhraseCtrl.text.trim().isNotEmpty) {
      return [_customPhraseCtrl.text.trim()];
    }
    return widget.phrases.isEmpty
        ? ['Sing any phrase here…']
        : widget.phrases;
  }

  String get _currentPhrase => _phrases[_phraseIndex % _phrases.length];

  @override
  void dispose() {
    _sub?.cancel();
    _audio.dispose();
    _customPhraseCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_running) {
      await _endRep();
    } else {
      await _startRep();
    }
  }

  Future<void> _startRep() async {
    _repCents.clear();
    _audio.enableSaving();
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
    _sub = _audio.results.listen((result) {
      if (!mounted) return;
      setState(() {
        _feedback = result?.feedback ?? PitchFeedback.noSignal;
        _liveCents = result?.cents ?? 0;
        _liveNote = result?.fullName ?? '';
      });
      if (result != null) _repCents.add(result.cents);
    });
  }

  Future<void> _endRep() async {
    await _sub?.cancel();
    _sub = null;
    await _audio.stop();
    _audio.saveRecording(
        'huni_phrase_${DateTime.now().millisecondsSinceEpoch}');

    // Compute result
    String result = 'No signal';
    if (_repCents.isNotEmpty) {
      final avg =
          _repCents.reduce((a, b) => a + b) / _repCents.length;
      final flatPct =
          _repCents.where((c) => c < -15).length / _repCents.length * 100;
      final sharpPct =
          _repCents.where((c) => c > 15).length / _repCents.length * 100;
      final tunePct =
          _repCents.where((c) => c.abs() <= 15).length / _repCents.length * 100;
      if (tunePct >= 50) {
        result = 'In Tune ✓ (${tunePct.toStringAsFixed(0)}%)';
      } else if (flatPct > sharpPct) {
        result =
            'Flat — avg ${avg.abs().toStringAsFixed(0)}¢ low (${flatPct.toStringAsFixed(0)}%)';
      } else {
        result =
            'Sharp — avg ${avg.abs().toStringAsFixed(0)}¢ high (${sharpPct.toStringAsFixed(0)}%)';
      }
      _repCount++;
      // Advance phrase on 3rd rep
      if (_repCount % 3 == 0 && _phrases.length > 1) {
        _phraseIndex = (_phraseIndex + 1) % _phrases.length;
      }
    }

    setState(() {
      _running = false;
      _feedback = PitchFeedback.noSignal;
      _liveNote = '';
      _liveCents = 0;
      _lastRepResult = result;
      _repCents.clear();
    });
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Text(
            'Sing the phrase, then tap Stop to see your result.\nRepeat until in tune.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppColors.grey,
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
              const Text('Custom phrase',
                  style: TextStyle(
                      color: AppColors.grey,
                      fontSize: 13,
                      fontFamily: 'Roboto')),
            ],
          ),
          if (_useCustom)
            TextField(
              controller: _customPhraseCtrl,
              style: const TextStyle(color: AppColors.white),
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

          const SizedBox(height: 24),

          // Current phrase
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.inputBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.primaryCyan.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Text('Phrase ${_phraseIndex + 1} of ${_phrases.length}',
                    style: TextStyle(
                        color: AppColors.grey.withValues(alpha: 0.5),
                        fontSize: 11,
                        fontFamily: 'Roboto')),
                const SizedBox(height: 6),
                Text(_currentPhrase,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 16,
                        fontFamily: 'Roboto',
                        fontWeight: FontWeight.w600,
                        height: 1.4)),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Live feedback
          if (_running) ...[
            Text(_liveNote.isEmpty ? '—' : _liveNote,
                style: TextStyle(
                    color: _feedbackColor,
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Roboto')),
            const SizedBox(height: 4),
            Text('${_liveCents.toStringAsFixed(0)} ¢',
                style: TextStyle(
                    color: _feedbackColor,
                    fontSize: 14,
                    fontFamily: 'Roboto')),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (_liveCents.clamp(-50, 50) + 50) / 100,
                minHeight: 7,
                backgroundColor: AppColors.inputBg,
                valueColor:
                    AlwaysStoppedAnimation<Color>(_feedbackColor),
              ),
            ),
          ],

          // Last rep result
          if (_lastRepResult.isNotEmpty && !_running) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.history,
                      color: AppColors.grey, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Last rep: $_lastRepResult  (Total reps: $_repCount)',
                      style: const TextStyle(
                          color: AppColors.grey,
                          fontSize: 12,
                          fontFamily: 'Roboto'),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const Spacer(),

          ElevatedButton.icon(
            onPressed: _toggle,
            icon: Icon(_running ? Icons.stop : Icons.mic, size: 20),
            label: Text(_running ? 'Stop & Score' : 'Sing Phrase'),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _running ? Colors.red : AppColors.primaryCyan,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(
                  horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}
