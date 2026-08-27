import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/app_colors.dart';
import '../../core/audio_service.dart';
import '../../core/lyric_alignment_service.dart';
import '../../core/note_utils.dart';
import '../../core/ondevice_crepe_service.dart';
import '../../core/word_note_builder.dart';
import '../../models/free_sing_summary.dart';
import '../../services/free_sing_storage_service.dart';
import '../../services/recording_storage_service.dart';
import 'save_record_page.dart';
import 'without_karaoke_results_page.dart';

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
  StreamSubscription<List<int>>? _bytesSub;

  bool _isRecording = false;
  bool _isProcessing = false;

  // PCM buffer for WAV export
  final List<int> _recordedPcm = [];

  // ── CREPE status ───────────────────────────────────────────────────────────
  bool _crepeReady = false;
  bool _crepeLoading = true;
  String _pitchSource = 'Loading…';

  // ── Session stats ──────────────────────────────────────────────────────────
  int _inTuneCount = 0;
  int _sharpCount = 0;
  int _flatCount = 0;
  int _totalReadings = 0;

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
  double _clarity = 0.0;
  PitchFeedback _feedback = PitchFeedback.noSignal;

  // ── Waveform bars ──────────────────────────────────────────────────────────
  static const int _barCount = 30;
  final List<double> _bars = List.filled(_barCount, 0.05);
  late AnimationController _idleController;
  Timer? _waveTimer;

  // ── Real-time voice monitoring ───────────────────────────────────────────
  bool _isMonitoring = true;

  @override
  void initState() {
    super.initState();
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _initCrepe();
  }

  @override
  void dispose() {
    _idleController.dispose();
    _waveTimer?.cancel();
    _timer?.cancel();
    _audioSub?.cancel();
    _bytesSub?.cancel();
    _audioService.dispose();
    super.dispose();
  }

  // ── CREPE initialisation ───────────────────────────────────────────────────

  Future<void> _initCrepe() async {
    setState(() {
      _crepeLoading = true;
      _crepeReady = false;
      _pitchSource = 'Loading…';
    });

    try {
      await _audioService.preloadCrepe();
      if (mounted) {
        setState(() {
          _crepeReady = true;
          _crepeLoading = false;
          _pitchSource = 'CREPE';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _crepeReady = false;
          _crepeLoading = false;
          _pitchSource = 'Local YIN';
        });
      }
    }
  }

  // ── Record toggle ──────────────────────────────────────────────────────────

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      // ═══════════════════════════════════════════════════════════════════
      // STOP → AUTO-SAVE (no blocking dialog)
      // ═══════════════════════════════════════════════════════════════════
      await _bytesSub?.cancel();
      _bytesSub = null;
      await _audioSub?.cancel();
      _audioSub = null;
      await _audioService.stop();
      _timer?.cancel();
      _waveTimer?.cancel();

      final durationSecs = _seconds;
      final pcmSnapshot = List<int>.from(_recordedPcm);

      setState(() {
        _isRecording = false;
        _isProcessing = true;
        _seconds = 0;
        _noteDisplay = '--';
        _freqDisplay = '';
        _cents = 0.0;
        _clarity = 0.0;
        _feedback = PitchFeedback.noSignal;
        _inTuneCount = 0;
        _sharpCount = 0;
        _flatCount = 0;
        _totalReadings = 0;
        for (int i = 0; i < _barCount; i++) {
          _bars[i] = 0.05;
        }
      });

      // Save the raw take, then run the full offline analysis pipeline
      // (CREPE pitch + Whisper transcription) over it for the summary.
      if (pcmSnapshot.isNotEmpty && durationSecs >= 1) {
        await _processAndSave(pcmSnapshot, durationSecs);
      }

      if (mounted) setState(() => _isProcessing = false);
    } else {
      // ═══════════════════════════════════════════════════════════════════
      // START → WITH MONITORING
      // ═══════════════════════════════════════════════════════════════════
      // Wipe any summary banner still showing from a previous take so it
      // can't sit on screen through a whole new recording.
      if (mounted) ScaffoldMessenger.of(context).clearSnackBars();
      _recordedPcm.clear();
      _inTuneCount = 0;
      _sharpCount = 0;
      _flatCount = 0;
      _totalReadings = 0;

      final started = await _audioService.start(
        enableMonitoring: _isMonitoring,
      );
      if (!started) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission denied')),
          );
        }
        return;
      }

      setState(() {
        _isRecording = true;
        _pitchSource = _crepeReady ? 'CREPE' : 'Local YIN';
      });

      // Buffer raw PCM for WAV saving
      _bytesSub = _audioService.rawBytes.listen((bytes) {
        _recordedPcm.addAll(bytes);
      });

      // Session timer
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _seconds++);
      });

      // Waveform ticker (~30fps)
      _waveTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
        if (!mounted) return;
        setState(() {
          for (int i = 0; i < _barCount - 1; i++) {
            _bars[i] = _bars[i + 1];
          }
          final base = _feedback == PitchFeedback.noSignal ? 0.05 : 0.2;
          final noise =
              Random().nextDouble() *
              (_feedback == PitchFeedback.noSignal ? 0.05 : 0.6);
          _bars[_barCount - 1] = (base + noise).clamp(0.03, 1.0);
        });
      });

      // Pitch stream from CREPE / YIN
      _audioSub = _audioService.results.listen((result) {
        if (!mounted) return;

        if (result == null || !result.hasSignal) {
          setState(() {
            _noteDisplay = '--';
            _freqDisplay = '';
            _feedback = PitchFeedback.noSignal;
            _clarity = 0.0;
          });
          return;
        }

        // Update session stats
        _totalReadings++;
        switch (result.feedback) {
          case PitchFeedback.correct:
            _inTuneCount++;
            break;
          case PitchFeedback.tooHigh:
            _sharpCount++;
            break;
          case PitchFeedback.tooLow:
            _flatCount++;
            break;
          case PitchFeedback.noSignal:
            break;
        }

        setState(() {
          _noteDisplay = result.fullName;
          _freqDisplay = '${result.frequency.toStringAsFixed(1)} Hz';
          _cents = result.cents;
          _clarity = result.confidence;
          _feedback = result.feedback;
        });
      });
    }
  }

  // ── Post-recording pipeline ───────────────────────────────────────────────
  // Not real-time: runs once, after the mic has stopped, over the full take.

  Future<void> _processAndSave(List<int> pcmBytes, int durationSecs) async {
    try {
      final now = DateTime.now();
      final id = now.millisecondsSinceEpoch.toString();
      final title =
          'Recording ${now.year}-${_pad(now.month)}-${_pad(now.day)} '
          '${_pad(now.hour)}:${_pad(now.minute)}';

      final wavBytes = _buildWavBytes(pcmBytes, sampleRate: 16000, channels: 1);

      // Store WAV as base64 in SharedPreferences (works on web and mobile)
      final prefs = await SharedPreferences.getInstance();
      final b64 = base64Encode(wavBytes);
      await prefs.setString('wav_$id', b64);

      await RecordingStorageService.saveRecording(
        RecordingEntry(
          id: id,
          title: title,
          filePath: 'local:$id',
          durationSeconds: durationSecs,
          createdAt: now,
        ),
      );

      // Pitch (CREPE, batch) and speech-to-text (Whisper) both run once over
      // the full take, independently, then get combined by timestamp below.
      final crepe = OnDeviceCrepeService();
      List<PitchFrame> pitchFrames;
      List<TranscribedWord> words;
      try {
        final results = await Future.wait([
          crepe.analyzeOffline(_pcmBytesToInt16(pcmBytes)),
          transcribeWords(wavBytes),
        ]);
        pitchFrames = results[0] as List<PitchFrame>;
        words = results[1] as List<TranscribedWord>;
      } finally {
        crepe.dispose();
      }

      final wordNotes = buildWordNotes(words: words, pitchFrames: pitchFrames);

      final summary = FreeSingSummary(
        id: id,
        createdAt: now,
        durationSeconds: durationSecs,
        audioRef: 'local:$id',
        words: wordNotes,
      );
      await FreeSingStorageService.saveSummary(summary);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WithoutKaraokeResultsPage(summary: summary),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to process recording: $e')));
      }
    }
  }

  /// The mic's rawBytes stream (buffered into [_recordedPcm]) is raw PCM16LE
  /// bytes, one element per byte — CREPE's batch analysis needs actual int16
  /// sample values, so decode each little-endian pair.
  List<int> _pcmBytesToInt16(List<int> bytes) {
    final byteData = Uint8List.fromList(bytes).buffer.asByteData();
    final samples = <int>[];
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      samples.add(byteData.getInt16(i, Endian.little));
    }
    return samples;
  }

  String _pad(int v) => v.toString().padLeft(2, '0');

  Uint8List _buildWavBytes(
    List<int> pcm, {
    required int sampleRate,
    required int channels,
  }) {
    const bitsPerSample = 16;
    final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    final blockAlign = channels * bitsPerSample ~/ 8;
    final dataLength = pcm.length;
    final buf = ByteData(44 + dataLength);

    // RIFF chunk
    buf.setUint8(0, 0x52);
    buf.setUint8(1, 0x49);
    buf.setUint8(2, 0x46);
    buf.setUint8(3, 0x46);
    buf.setUint32(4, 36 + dataLength, Endian.little);
    buf.setUint8(8, 0x57);
    buf.setUint8(9, 0x41);
    buf.setUint8(10, 0x56);
    buf.setUint8(11, 0x45);
    // fmt sub-chunk
    buf.setUint8(12, 0x66);
    buf.setUint8(13, 0x6D);
    buf.setUint8(14, 0x74);
    buf.setUint8(15, 0x20);
    buf.setUint32(16, 16, Endian.little);
    buf.setUint16(20, 1, Endian.little);
    buf.setUint16(22, channels, Endian.little);
    buf.setUint32(24, sampleRate, Endian.little);
    buf.setUint32(28, byteRate, Endian.little);
    buf.setUint16(32, blockAlign, Endian.little);
    buf.setUint16(34, bitsPerSample, Endian.little);
    // data sub-chunk
    buf.setUint8(36, 0x64);
    buf.setUint8(37, 0x61);
    buf.setUint8(38, 0x74);
    buf.setUint8(39, 0x61);
    buf.setUint32(40, dataLength, Endian.little);
    for (int i = 0; i < dataLength; i++) {
      buf.setUint8(44 + i, pcm[i] & 0xFF);
    }
    return buf.buffer.asUint8List();
  }

  // ── Feedback helpers ───────────────────────────────────────────────────────

  Color get _clarityColor {
    if (_clarity >= 0.80) return const Color(0xFF4CAF50);
    if (_clarity >= 0.55) return Colors.orangeAccent;
    return const Color(0xFFF44336);
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
        return _isRecording ? 'Listening...' : '';
    }
  }

  double get _inTunePercent =>
      _totalReadings > 0 ? _inTuneCount / _totalReadings : 0.0;

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
                      ScaffoldMessenger.of(context).clearSnackBars();
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

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    // Captured here (not re-looked-up later) so it stays valid to call
    // clearSnackBars() on even after this page's own context is gone —
    // e.g. when the system back gesture pops this route directly, without
    // going through any of this page's own back-button handlers.
    final messenger = ScaffoldMessenger.of(context);
    return PopScope(
      canPop: !_isProcessing,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) messenger.clearSnackBars();
      },
      child: Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
          children: [
            _buildHeader(),
            _buildCrepeStatusBar(),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildNoteDisplay(),
                  const SizedBox(height: 28),
                  _buildWaveform(),
                  const SizedBox(height: 28),
                  if (_isRecording) _buildCentsMeter(),
                  if (_isRecording) const SizedBox(height: 16),
                  if (_isRecording) _buildClarityBar(),
                  if (_isRecording) const SizedBox(height: 8),
                  if (_isRecording) _buildLiveStats(),
                  if (_isRecording) const SizedBox(height: 8),
                  _buildTimer(),
                ],
              ),
            ),
            _buildControls(),
          ],
            ),
            if (_isProcessing) _buildProcessingOverlay(),
          ],
        ),
      ),
      ),
    );
  }

  // ── Processing overlay ─────────────────────────────────────────────────────

  Widget _buildProcessingOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.85),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.primaryCyan),
              SizedBox(height: 20),
              Text(
                'Analyzing your recording…',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Roboto',
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Detecting words and notes',
                style: TextStyle(
                  color: AppColors.grey,
                  fontSize: 12,
                  fontFamily: 'Roboto',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: AppColors.white,
              size: 26,
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).clearSnackBars();
              Navigator.pop(context);
            },
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
          const Spacer(),

          // Monitoring toggle (only while recording)
          if (_isRecording)
            GestureDetector(
              onTap: () {
                setState(() => _isMonitoring = !_isMonitoring);
                _audioService.setMonitoring(_isMonitoring);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _isMonitoring
                      ? AppColors.primaryCyan.withValues(alpha: 0.15)
                      : Colors.grey.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isMonitoring ? AppColors.primaryCyan : Colors.grey,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isMonitoring ? Icons.headset : Icons.headset_off,
                      color: _isMonitoring
                          ? AppColors.primaryCyan
                          : Colors.grey,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isMonitoring ? 'MONITOR ON' : 'MONITOR OFF',
                      style: TextStyle(
                        color: _isMonitoring
                            ? AppColors.primaryCyan
                            : Colors.grey,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Roboto',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(width: 8),

          IconButton(
            icon: const Icon(
              Icons.folder_open,
              color: AppColors.white,
              size: 24,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SaveRecordPage()),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── CREPE status bar ───────────────────────────────────────────────────────

  Widget _buildCrepeStatusBar() {
    if (_crepeLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: AppColors.primaryCyan,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Loading CREPE model…',
              style: TextStyle(
                color: AppColors.grey.withValues(alpha: 0.6),
                fontSize: 10,
                fontFamily: 'Roboto',
              ),
            ),
          ],
        ),
      );
    }

    final isCrepe = _pitchSource == 'CREPE';
    final dotColor = isCrepe ? const Color(0xFF4CAF50) : Colors.orangeAccent;
    final label = isCrepe
        ? 'CREPE on-device model active'
        : 'Local YIN fallback active';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: dotColor.withValues(alpha: 0.85),
              fontSize: 10,
              fontFamily: 'Roboto',
            ),
          ),
        ],
      ),
    );
  }

  // ── Note display ───────────────────────────────────────────────────────────

  Widget _buildNoteDisplay() {
    return Column(
      children: [
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
      ],
    );
  }

  // ── Waveform ───────────────────────────────────────────────────────────────

  Widget _buildWaveform() {
    return SizedBox(
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
          : CustomPaint(
              painter: _CrosshairPainter(),
              size: const Size(260, 80),
            ),
    );
  }

  // ── Cents meter ────────────────────────────────────────────────────────────

  Widget _buildCentsMeter() {
    return Padding(
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
              valueColor: AlwaysStoppedAnimation<Color>(_feedbackColor),
            ),
          ),
        ],
      ),
    );
  }

  // ── Clarity bar ────────────────────────────────────────────────────────────

  Widget _buildClarityBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.graphic_eq,
                    size: 12,
                    color: AppColors.primaryCyan,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Voice Clarity  •  $_pitchSource',
                    style: TextStyle(
                      color: AppColors.grey.withValues(alpha: 0.7),
                      fontSize: 11,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ],
              ),
              Text(
                '${(_clarity * 100).round()}%',
                style: TextStyle(
                  color: _clarityColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Roboto',
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _clarity,
              minHeight: 7,
              backgroundColor: AppColors.inputBg,
              valueColor: AlwaysStoppedAnimation<Color>(_clarityColor),
            ),
          ),
        ],
      ),
    );
  }

  // ── Live stats ─────────────────────────────────────────────────────────────

  Widget _buildLiveStats() {
    if (_totalReadings == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _liveStatChip(
            label: 'In Tune',
            value: '${(_inTunePercent * 100).round()}%',
            color: AppColors.primaryCyan,
          ),
          _liveStatChip(
            label: 'Sharp',
            value: '$_sharpCount',
            color: Colors.orangeAccent,
          ),
          _liveStatChip(
            label: 'Flat',
            value: '$_flatCount',
            color: Colors.blueAccent,
          ),
          Text(
            '$_totalReadings pts',
            style: TextStyle(
              color: AppColors.grey.withValues(alpha: 0.4),
              fontSize: 9,
              fontFamily: 'Roboto',
            ),
          ),
        ],
      ),
    );
  }

  Widget _liveStatChip({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              fontFamily: 'Roboto',
            ),
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.7),
              fontSize: 9,
              fontFamily: 'Roboto',
            ),
          ),
        ],
      ),
    );
  }

  // ── Timer ──────────────────────────────────────────────────────────────────

  Widget _buildTimer() {
    return Text(
      _timerText,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.white,
        fontFamily: 'Roboto',
        letterSpacing: 1.5,
      ),
    );
  }

  // ── Controls ───────────────────────────────────────────────────────────────

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 48),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Mic icon with monitoring indicator
          Stack(
            alignment: Alignment.topRight,
            children: [
              Icon(
                _isRecording ? Icons.mic : Icons.mic_none,
                color: _isRecording
                    ? AppColors.primaryCyan
                    : AppColors.white.withValues(alpha: 0.4),
                size: 36,
              ),
              if (_isRecording && _isMonitoring)
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),

          const SizedBox(width: 48),

          // Record / Stop button
          GestureDetector(
            onTap: _isProcessing ? null : _toggleRecording,
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
              child: _isProcessing
                  ? const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Icon(
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
              child: const Icon(Icons.close, color: Colors.black, size: 20),
            ),
          ),
        ],
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
