/// WithoutKaraokeRecordingPage — fully offline karaoke recorder.
///
/// FLOW
///  1. initState  — preload CREPE (fast) and Whisper model copy (slow-ish)
///  2. Record tap — start mic, collect PCM + timestamped pitch frames
///  3. Stop  tap — write WAV, run Whisper, group frames into words,
///                  compute vocal summary, push the result page.
///
/// The "live note + waveform" UI from the original version is preserved.
/// No words appear during recording (per the chosen architecture).
library;

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../constants/app_colors.dart';
import '../core/audio_service.dart';
import '../core/note_utils.dart';
import '../core/wav_writer.dart';
import '../services/vocal_analysis_service.dart';
import '../services/whisper_service.dart';
import '../services/word_note_sync_service.dart';
import 'karaoke_result_page.dart';

class WithoutKaraokeRecordingPage extends StatefulWidget {
  const WithoutKaraokeRecordingPage({super.key});

  @override
  State<WithoutKaraokeRecordingPage> createState() =>
      _WithoutKaraokeRecordingPageState();
}

class _WithoutKaraokeRecordingPageState
    extends State<WithoutKaraokeRecordingPage>
    with TickerProviderStateMixin {
  // ── Services ────────────────────────────────────────────────────────────
  final AudioService   _audioService   = AudioService();
  final WhisperService _whisperService = WhisperService();

  // ── Stream subs ─────────────────────────────────────────────────────────
  StreamSubscription<NoteResult?>? _noteSub;
  StreamSubscription<PitchFrame>?  _frameSub;
  StreamSubscription<List<int>>?   _bytesSub;

  // ── State flags ─────────────────────────────────────────────────────────
  bool _isRecording = false;
  bool _isAnalyzing = false;
  bool _crepeReady  = false;
  bool _whisperReady = false;
  String _statusLine = 'Initializing…';

  // ── Captured data ───────────────────────────────────────────────────────
  final List<int>        _recordedPcm    = [];
  final List<PitchFrame> _recordedFrames = [];

  // ── Live UI state ───────────────────────────────────────────────────────
  int _seconds = 0;
  Timer? _timer;

  String _noteDisplay = '--';
  String _freqDisplay = '';
  double _clarity = 0.0;
  PitchFeedback _feedback = PitchFeedback.noSignal;

  static const int _barCount = 30;
  final List<double> _bars = List.filled(_barCount, 0.05);
  Timer? _waveTimer;
  late final AnimationController _idleController;

  // ── Lifecycle ───────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _initModels();
  }

  @override
  void dispose() {
    _idleController.dispose();
    _waveTimer?.cancel();
    _timer?.cancel();
    _noteSub?.cancel();
    _frameSub?.cancel();
    _bytesSub?.cancel();
    _audioService.dispose();
    super.dispose();
  }

  Future<void> _initModels() async {
    setState(() => _statusLine = 'Loading CREPE…');
    try {
      await _audioService.preloadCrepe();
      _crepeReady = true;
    } catch (_) {
      _crepeReady = false;
    }

    if (!mounted) return;
    setState(() => _statusLine = 'Loading Whisper…');
    try {
      await _whisperService.init();
      _whisperReady = true;
    } catch (_) {
      _whisperReady = false;
    }

    if (!mounted) return;
    setState(() {
      _statusLine = _statusReady;
    });
  }

  String get _statusReady {
    if (_crepeReady && _whisperReady) return 'CREPE + Whisper ready';
    if (_crepeReady)                  return 'CREPE ready · Whisper unavailable';
    if (_whisperReady)                return 'Whisper ready · YIN pitch fallback';
    return 'Pitch fallback only';
  }

  // ── Recording control ───────────────────────────────────────────────────

  Future<void> _toggleRecording() async {
    if (_isAnalyzing) return;

    if (_isRecording) {
      await _stopAndAnalyze();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    _recordedPcm.clear();
    _recordedFrames.clear();
    _seconds = 0;

    final ok = await _audioService.start();
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied')),
        );
      }
      return;
    }

    setState(() => _isRecording = true);

    // Capture raw PCM for the WAV we'll send to Whisper.
    _bytesSub = _audioService.rawBytes.listen(_recordedPcm.addAll);

    // Capture timestamped pitch frames for later word grouping.
    _frameSub = _audioService.pitchFrames.listen(_recordedFrames.add);

    // Drive the existing live note + waveform UI.
    _noteSub = _audioService.results.listen((r) {
      if (!mounted) return;
      if (r == null || !r.hasSignal) {
        setState(() {
          _noteDisplay = '--';
          _freqDisplay = '';
          _clarity = 0;
          _feedback = PitchFeedback.noSignal;
        });
        return;
      }
      setState(() {
        _noteDisplay = r.fullName;
        _freqDisplay = '${r.frequency.toStringAsFixed(1)} Hz';
        _clarity = r.confidence;
        _feedback = r.feedback;
      });
    });

    // Tick the elapsed-time label every second.
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });

    // Animate the rolling waveform bars.
    _waveTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (!mounted) return;
      setState(() {
        for (int i = 0; i < _barCount - 1; i++) _bars[i] = _bars[i + 1];
        final hasSignal = _feedback != PitchFeedback.noSignal;
        final base = hasSignal ? 0.2 : 0.05;
        final noise = Random().nextDouble() * (hasSignal ? 0.6 : 0.05);
        _bars[_barCount - 1] = (base + noise).clamp(0.03, 1.0);
      });
    });
  }

  Future<void> _stopAndAnalyze() async {
    // 1. Stop the mic and tear down the live streams.
    await _bytesSub?.cancel(); _bytesSub = null;
    await _frameSub?.cancel(); _frameSub = null;
    await _noteSub?.cancel();  _noteSub  = null;
    await _audioService.stop();
    _timer?.cancel();
    _waveTimer?.cancel();

    setState(() {
      _isRecording = false;
      _isAnalyzing = true;
      _statusLine = 'Saving recording…';
    });

    if (_recordedPcm.isEmpty) {
      setState(() {
        _isAnalyzing = false;
        _statusLine = _statusReady;
      });
      return;
    }

    // 2. Persist PCM as a real 16 kHz mono WAV.
    final dir = await getApplicationDocumentsDirectory();
    final wavPath =
        '${dir.path}/take_${DateTime.now().millisecondsSinceEpoch}.wav';
    final wav = await WavWriter.save(_recordedPcm, wavPath);

    // 3. Run Whisper.
    setState(() => _statusLine = 'Transcribing with Whisper…');
    final words = _whisperReady
        ? await _whisperService.transcribe(wav)
        : <WhisperWord>[];

    // 4. Group CREPE frames into Whisper word ranges.
    setState(() => _statusLine = 'Aligning notes to words…');
    final aligned = WordNoteSyncService.sync(
      words: words,
      frames: _recordedFrames,
    );

    // 5. Compute summary stats.
    final summary = VocalAnalysisService.analyze(aligned);

    // 6. Navigate to the result page.
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => KaraokeResultPage(
        wavFile: wav,
        words: aligned,
        summary: summary,
        durationSec: _seconds,
      ),
    ));

    // 7. Reset for the next take.
    if (mounted) {
      setState(() {
        _isAnalyzing = false;
        _statusLine = _statusReady;
        _noteDisplay = '--';
        _freqDisplay = '';
        _clarity = 0;
        _feedback = PitchFeedback.noSignal;
      });
    }
  }

  // ── UI ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildStatusBar(),
            Expanded(child: _buildLiveDisplay()),
            _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _isRecording || _isAnalyzing
                ? null
                : () => Navigator.pop(context),
          ),
          const Text('Record',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    final ready = _crepeReady && _whisperReady && !_isAnalyzing;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ready ? Colors.green : Colors.orange,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_statusLine,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveDisplay() {
    if (_isAnalyzing) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        const Text('Analyzing your voice…',
            style: TextStyle(color: Colors.white)),
        const SizedBox(height: 8),
        // ← Shows the current sub-step (Saving → Transcribing → Aligning)
        Text(_statusLine,
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 16),
        const Text(
          'Whisper Tiny is transcribing on-device.\n'
          'This can take ~30s per minute of audio.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white30, fontSize: 11),
        ),
      ],
    ),
  );
}

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_noteDisplay,
              style: const TextStyle(
                  fontSize: 80,
                  color: Colors.white,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(_freqDisplay,
              style: const TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 24),
          _buildWaveform(),
          const SizedBox(height: 24),
          Text('${(_clarity * 100).round()}% clarity',
              style: const TextStyle(color: Colors.white60)),
          const SizedBox(height: 16),
          Text(_formatTime(_seconds),
              style: const TextStyle(color: Colors.white, fontSize: 18)),
        ],
      ),
    );
  }

  Widget _buildWaveform() {
    return SizedBox(
      height: 60,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_barCount, (i) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            width: 4,
            height: 60 * _bars[i],
            decoration: BoxDecoration(
              color: _feedback == PitchFeedback.noSignal
                  ? Colors.white24
                  : Colors.greenAccent,
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: GestureDetector(
        onTap: _toggleRecording,
        child: Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isRecording ? Colors.red : Colors.redAccent,
            boxShadow: [
              BoxShadow(
                color: Colors.red.withValues(alpha: 0.5),
                blurRadius: _isRecording ? 24 : 10,
                spreadRadius: _isRecording ? 4 : 0,
              ),
            ],
          ),
          child: Icon(
            _isRecording ? Icons.stop : Icons.mic,
            color: Colors.white, size: 36,
          ),
        ),
      ),
    );
  }

  String _formatTime(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final r = (s % 60).toString().padLeft(2, '0');
    return '$m:$r';
  }
}