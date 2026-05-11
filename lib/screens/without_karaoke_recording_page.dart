import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../constants/app_colors.dart';
import '../core/audio_service.dart';
import '../core/note_utils.dart';
import '../services/recording_storage_service.dart';
import 'save_record_page.dart';

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
  bool _isSaving    = false;

  // PCM buffer for WAV export
  final List<int> _recordedPcm = [];

  // ── CREPE status ───────────────────────────────────────────────────────────
  bool   _crepeReady   = false;
  bool   _crepeLoading = true;
  String _pitchSource  = 'Loading…';

  // ── Session stats ──────────────────────────────────────────────────────────
  int _inTuneCount   = 0;
  int _sharpCount    = 0;
  int _flatCount     = 0;
  int _totalReadings = 0;

  // Highest and lowest note seen this session
  double _sessionMaxHz = 0;
  double _sessionMinHz = double.maxFinite;
  String _sessionMaxNote = '';
  String _sessionMinNote = '';

  // ── Timer ──────────────────────────────────────────────────────────────────
  int    _seconds = 0;
  Timer? _timer;
  String get _timerText {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── Live pitch state ───────────────────────────────────────────────────────
  String        _noteDisplay = '--';
  String        _freqDisplay = '';
  double        _cents       = 0.0;
  double        _clarity     = 0.0;
  PitchFeedback _feedback    = PitchFeedback.noSignal;

  // ── Waveform bars ──────────────────────────────────────────────────────────
  static const int _barCount = 30;
  final List<double> _bars = List.filled(_barCount, 0.05);
  late AnimationController _idleController;
  Timer? _waveTimer;

  @override
  void initState() {
    super.initState();
    _idleController = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _initCrepe(); // ← pre-load CREPE model on page open
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
      _crepeReady   = false;
      _pitchSource  = 'Loading…';
    });

    try {
      await _audioService.preloadCrepe();
      if (mounted) {
        setState(() {
          _crepeReady   = true;
          _crepeLoading = false;
          _pitchSource  = 'CREPE';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _crepeReady   = false;
          _crepeLoading = false;
          _pitchSource  = 'Local YIN';
        });
      }
    }
  }

  // ── Record toggle ──────────────────────────────────────────────────────────

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      // ── STOP ────────────────────────────────────────────────────────────────
      await _bytesSub?.cancel();
      _bytesSub = null;
      await _audioSub?.cancel();
      _audioSub = null;
      await _audioService.stop();
      _timer?.cancel();
      _waveTimer?.cancel();

      final durationSecs  = _seconds;
      final pcmSnapshot   = List<int>.from(_recordedPcm);

      // Snapshot session stats before reset
      final inTune  = _inTuneCount;
      final sharp   = _sharpCount;
      final flat    = _flatCount;
      final total   = _totalReadings;
      final maxNote = _sessionMaxNote;
      final minNote = _sessionMinNote;

      setState(() {
        _isRecording   = false;
        _isSaving      = true;
        _seconds       = 0;
        _noteDisplay   = '--';
        _freqDisplay   = '';
        _cents         = 0.0;
        _clarity       = 0.0;
        _feedback      = PitchFeedback.noSignal;
        _inTuneCount   = 0;
        _sharpCount    = 0;
        _flatCount     = 0;
        _totalReadings = 0;
        _sessionMaxHz  = 0;
        _sessionMinHz  = double.maxFinite;
        _sessionMaxNote = '';
        _sessionMinNote = '';
        for (int i = 0; i < _barCount; i++) _bars[i] = 0.05;
      });

      if (pcmSnapshot.isNotEmpty && durationSecs >= 1) {
        await _saveWav(pcmSnapshot, durationSecs);
      }

      // Show session summary
      if (mounted && total > 0) {
        _showSessionSummary(
          inTune: inTune,
          sharp:  sharp,
          flat:   flat,
          total:  total,
          maxNote: maxNote,
          minNote: minNote,
          duration: durationSecs,
        );
      }

      if (mounted) setState(() => _isSaving = false);

    } else {
      // ── START ────────────────────────────────────────────────────────────────
      _recordedPcm.clear();
      _inTuneCount    = 0;
      _sharpCount     = 0;
      _flatCount      = 0;
      _totalReadings  = 0;
      _sessionMaxHz   = 0;
      _sessionMinHz   = double.maxFinite;
      _sessionMaxNote = '';
      _sessionMinNote = '';

      final started = await _audioService.start();
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
          final base  = _feedback == PitchFeedback.noSignal ? 0.05 : 0.2;
          final noise = Random().nextDouble() *
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
            _feedback    = PitchFeedback.noSignal;
            _clarity     = 0.0;
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

        // Track highest and lowest note
        if (result.frequency > _sessionMaxHz) {
          _sessionMaxHz   = result.frequency;
          _sessionMaxNote = result.fullName;
        }
        if (result.frequency > 0 &&
            result.frequency < _sessionMinHz) {
          _sessionMinHz   = result.frequency;
          _sessionMinNote = result.fullName;
        }

        setState(() {
          _noteDisplay = result.fullName;
          _freqDisplay = '${result.frequency.toStringAsFixed(1)} Hz';
          _cents       = result.cents;
          _clarity     = result.confidence;
          _feedback    = result.feedback;
        });
      });
    }
  }

  // ── Session summary dialog ─────────────────────────────────────────────────

  void _showSessionSummary({
    required int    inTune,
    required int    sharp,
    required int    flat,
    required int    total,
    required String maxNote,
    required String minNote,
    required int    duration,
  }) {
    final inTunePct = total > 0
        ? ((inTune / total) * 100).round()
        : 0;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              Row(
                children: [
                  const Icon(
                    Icons.bar_chart_rounded,
                    color: AppColors.primaryCyan,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Session Summary',
                    style: TextStyle(
                      color:      AppColors.white,
                      fontSize:   16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Roboto',
                    ),
                  ),
                  const Spacer(),
                  // Pitch source badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical:   3,
                    ),
                    decoration: BoxDecoration(
                      color:        (_pitchSource == 'CREPE'
                              ? const Color(0xFF4CAF50)
                              : Colors.orangeAccent)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _pitchSource,
                      style: TextStyle(
                        color:      _pitchSource == 'CREPE'
                            ? const Color(0xFF4CAF50)
                            : Colors.orangeAccent,
                        fontSize:   9,
                        fontFamily: 'Roboto',
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // In-tune percentage — big number
              Text(
                '$inTunePct%',
                style: TextStyle(
                  fontSize:   56,
                  fontWeight: FontWeight.bold,
                  color:      inTunePct >= 70
                      ? AppColors.primaryCyan
                      : inTunePct >= 50
                          ? Colors.orangeAccent
                          : const Color(0xFFF44336),
                  fontFamily: 'Roboto',
                ),
              ),
              Text(
                'In-Tune Accuracy',
                style: TextStyle(
                  color:      AppColors.grey.withValues(alpha: 0.7),
                  fontSize:   12,
                  fontFamily: 'Roboto',
                ),
              ),

              const SizedBox(height: 16),

              // Stats row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _summaryChip(
                    label: 'In Tune',
                    value: '$inTune',
                    color: AppColors.primaryCyan,
                  ),
                  _summaryChip(
                    label: 'Sharp ↑',
                    value: '$sharp',
                    color: Colors.orangeAccent,
                  ),
                  _summaryChip(
                    label: 'Flat ↓',
                    value: '$flat',
                    color: Colors.blueAccent,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Range row
              if (maxNote.isNotEmpty && minNote.isNotEmpty)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _summaryChip(
                      label: 'Highest',
                      value: maxNote,
                      color: Colors.purpleAccent,
                    ),
                    _summaryChip(
                      label: 'Lowest',
                      value: minNote,
                      color: Colors.tealAccent,
                    ),
                    _summaryChip(
                      label: 'Duration',
                      value: '${_pad(duration ~/ 60)}:${_pad(duration % 60)}',
                      color: AppColors.grey,
                    ),
                  ],
                ),

              const SizedBox(height: 20),

              // Close button
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.primaryCyan.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(
                      color:      AppColors.primaryCyan,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryChip({
    required String label,
    required String value,
    required Color  color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            color:      color,
            fontSize:   18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Roboto',
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color:      AppColors.grey.withValues(alpha: 0.6),
            fontSize:   10,
            fontFamily: 'Roboto',
          ),
        ),
      ],
    );
  }

  // ── WAV file builder ───────────────────────────────────────────────────────

  Future<void> _saveWav(List<int> pcm, int durationSecs) async {
    try {
      final dir  = await getApplicationDocumentsDirectory();
      final id   = DateTime.now().millisecondsSinceEpoch.toString();
      final path = '${dir.path}/recording_$id.wav';

      // Note: AudioService now records at 16kHz for CREPE
      final wavBytes = _buildWavBytes(
        pcm,
        sampleRate: 16000,   // ← updated from 44100 to match CREPE
        channels:   1,
      );
      await File(path).writeAsBytes(wavBytes);

      final now   = DateTime.now();
      final title =
          'Recording ${now.year}-${_pad(now.month)}-${_pad(now.day)} '
          '${_pad(now.hour)}:${_pad(now.minute)}';

      await RecordingStorageService.saveRecording(
        RecordingEntry(
          id:              id,
          title:           title,
          filePath:        path,
          durationSeconds: durationSecs,
          createdAt:       now,
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recording saved!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }

  String _pad(int v) => v.toString().padLeft(2, '0');

  Uint8List _buildWavBytes(
    List<int> pcm, {
    required int sampleRate,
    required int channels,
  }) {
    const bitsPerSample = 16;
    final byteRate   = sampleRate * channels * bitsPerSample ~/ 8;
    final blockAlign = channels * bitsPerSample ~/ 8;
    final dataLength = pcm.length;
    final buf        = ByteData(44 + dataLength);

    // RIFF chunk
    buf.setUint8(0, 0x52); buf.setUint8(1, 0x49);
    buf.setUint8(2, 0x46); buf.setUint8(3, 0x46);
    buf.setUint32(4, 36 + dataLength, Endian.little);
    buf.setUint8(8, 0x57);  buf.setUint8(9, 0x41);
    buf.setUint8(10, 0x56); buf.setUint8(11, 0x45);
    // fmt sub-chunk
    buf.setUint8(12, 0x66); buf.setUint8(13, 0x6D);
    buf.setUint8(14, 0x74); buf.setUint8(15, 0x20);
    buf.setUint32(16, 16, Endian.little);
    buf.setUint16(20, 1,            Endian.little);
    buf.setUint16(22, channels,     Endian.little);
    buf.setUint32(24, sampleRate,   Endian.little);
    buf.setUint32(28, byteRate,     Endian.little);
    buf.setUint16(32, blockAlign,   Endian.little);
    buf.setUint16(34, bitsPerSample, Endian.little);
    // data sub-chunk
    buf.setUint8(36, 0x64); buf.setUint8(37, 0x61);
    buf.setUint8(38, 0x74); buf.setUint8(39, 0x61);
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
      case PitchFeedback.correct:  return AppColors.primaryCyan;
      case PitchFeedback.tooHigh:  return Colors.orangeAccent;
      case PitchFeedback.tooLow:   return Colors.blueAccent;
      case PitchFeedback.noSignal: return AppColors.grey;
    }
  }

  String get _feedbackLabel {
    switch (_feedback) {
      case PitchFeedback.correct:  return 'In Tune ✓';
      case PitchFeedback.tooHigh:  return 'Too High ↑';
      case PitchFeedback.tooLow:   return 'Too Low ↓';
      case PitchFeedback.noSignal:
        return _isRecording ? 'Listening...' : '';
    }
  }

  // In-tune percentage during recording
  double get _inTunePercent =>
      _totalReadings > 0 ? _inTuneCount / _totalReadings : 0.0;

  // ── Exit dialog ────────────────────────────────────────────────────────────

  void _showExitDialog() {
    showDialog(
      context:            context,
      barrierDismissible: false,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          width:   280,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Sure you want to exit?',
                style:     TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () {
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

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildCrepeStatusBar(),     // ← new
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
                  if (_isRecording) _buildLiveStats(), // ← new
                  if (_isRecording) const SizedBox(height: 8),
                  _buildTimer(),
                ],
              ),
            ),
            _buildControls(),
          ],
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
              size:  26,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          const Text(
            'Record',
            style: TextStyle(
              fontSize:   24,
              fontWeight: FontWeight.bold,
              color:      AppColors.white,
              fontFamily: 'Roboto',
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(
              Icons.menu,
              color: AppColors.white,
              size:  26,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SaveRecordPage(),
                ),
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
              width:  10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color:       AppColors.primaryCyan,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Loading CREPE model…',
              style: TextStyle(
                color:      AppColors.grey.withValues(alpha: 0.6),
                fontSize:   10,
                fontFamily: 'Roboto',
              ),
            ),
          ],
        ),
      );
    }

    final isCrepe  = _pitchSource == 'CREPE';
    final dotColor = isCrepe
        ? const Color(0xFF4CAF50)
        : Colors.orangeAccent;
    final label    = isCrepe
        ? 'CREPE on-device model active'
        : 'Local YIN fallback active';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width:  7,
            height: 7,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color:      dotColor.withValues(alpha: 0.85),
              fontSize:   10,
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
            fontSize:   72,
            fontWeight: FontWeight.bold,
            color:      _isRecording ? _feedbackColor : AppColors.grey,
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
                    color:      AppColors.grey.withValues(alpha: 0.75),
                    fontSize:   14,
                    fontFamily: 'Roboto',
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Text(
                _feedbackLabel,
                style: TextStyle(
                  color:      _feedbackColor,
                  fontSize:   14,
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
      width:  260,
      height: 80,
      child: _isRecording
          ? Row(
              mainAxisAlignment:  MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(_barCount, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 30),
                  width:    5,
                  height:   80 * _bars[i],
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
              size:    const Size(260, 80),
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
                  color:      AppColors.grey.withValues(alpha: 0.6),
                  fontSize:   11,
                  fontFamily: 'Roboto',
                ),
              ),
              Text(
                '${_cents.toStringAsFixed(1)} cents',
                style: const TextStyle(
                  color:      AppColors.white,
                  fontSize:   11,
                  fontFamily: 'Roboto',
                ),
              ),
              Text(
                'Sharp',
                style: TextStyle(
                  color:      AppColors.grey.withValues(alpha: 0.6),
                  fontSize:   11,
                  fontFamily: 'Roboto',
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value:           (_cents.clamp(-50, 50) + 50) / 100,
              minHeight:       7,
              backgroundColor: AppColors.inputBg,
              valueColor:
                  AlwaysStoppedAnimation<Color>(_feedbackColor),
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
                    size:  12,
                    color: AppColors.primaryCyan,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Voice Clarity  •  $_pitchSource',
                    style: TextStyle(
                      color:      AppColors.grey.withValues(alpha: 0.7),
                      fontSize:   11,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ],
              ),
              Text(
                '${(_clarity * 100).round()}%',
                style: TextStyle(
                  color:      _clarityColor,
                  fontSize:   11,
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
              value:           _clarity,
              minHeight:       7,
              backgroundColor: AppColors.inputBg,
              valueColor:
                  AlwaysStoppedAnimation<Color>(_clarityColor),
            ),
          ),
        ],
      ),
    );
  }

  // ── Live stats (new) ───────────────────────────────────────────────────────

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
              color:      AppColors.grey.withValues(alpha: 0.4),
              fontSize:   9,
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
    required Color  color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border:       Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              color:      color,
              fontSize:   10,
              fontWeight: FontWeight.bold,
              fontFamily: 'Roboto',
            ),
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color:      color.withValues(alpha: 0.7),
              fontSize:   9,
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
        fontSize:      16,
        fontWeight:    FontWeight.w400,
        color:         AppColors.white,
        fontFamily:    'Roboto',
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
          // Mic icon
          Icon(
            _isRecording ? Icons.mic : Icons.mic_none,
            color: _isRecording
                ? AppColors.primaryCyan
                : AppColors.white.withValues(alpha: 0.4),
            size: 36,
          ),

          const SizedBox(width: 48),

          // Record / Stop button
          GestureDetector(
            onTap: _isSaving ? null : _toggleRecording,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width:    64,
              height:   64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isRecording
                    ? Colors.red.withValues(alpha: 0.75)
                    : Colors.red,
                boxShadow: _isRecording
                    ? [
                        BoxShadow(
                          color:       Colors.red.withValues(alpha: 0.5),
                          blurRadius:  16,
                          spreadRadius: 4,
                        ),
                      ]
                    : [],
              ),
              child: _isSaving
                  ? const SizedBox(
                      width:  28,
                      height: 28,
                      child: CircularProgressIndicator(
                        color:       Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Icon(
                      _isRecording
                          ? Icons.stop
                          : Icons.fiber_manual_record,
                      color: Colors.white,
                      size:  30,
                    ),
            ),
          ),

          const SizedBox(width: 48),

          // Exit button
          GestureDetector(
            onTap: _showExitDialog,
            child: Container(
              width:  36,
              height: 36,
              decoration: BoxDecoration(
                color:        AppColors.white,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(
                Icons.close,
                color: Colors.black,
                size:  20,
              ),
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
      ..color       = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 1.5
      ..style       = PaintingStyle.stroke;

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