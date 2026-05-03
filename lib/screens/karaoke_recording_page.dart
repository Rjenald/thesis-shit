import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../core/audio_service.dart';
import '../core/note_utils.dart';
import '../data/lyrics.dart';
import '../models/session_result.dart';
import '../services/lrclib_service.dart';
import 'results_page.dart';

class KaraokeRecordingPage extends StatefulWidget {
  final String songTitle;
  final String songArtist;
  final String songImage;

  const KaraokeRecordingPage({
    super.key,
    this.songTitle = 'Dadalhin',
    this.songArtist = 'Regine Velasquez',
    this.songImage = '',
  });

  @override
  State<KaraokeRecordingPage> createState() => _KaraokeRecordingPageState();
}

class _KaraokeRecordingPageState extends State<KaraokeRecordingPage>
    with SingleTickerProviderStateMixin {
  // ── Playback state ─────────────────────────────────────────────────────────
  bool _isPlaying   = false;
  bool _isRecording = false;
  int  _currentLineIndex = 0;
  Timer? _lyricTimer;

  // ── Session timer ──────────────────────────────────────────────────────────
  int    _elapsedSeconds = 0;
  Timer? _sessionTimer;

  final ScrollController _scrollController = ScrollController();

  // ── Audio & pitch ──────────────────────────────────────────────────────────
  final AudioService _audioService = AudioService();
  StreamSubscription<NoteResult?>? _audioSub;

  // Live pitch display
  PitchFeedback _liveFeedback = PitchFeedback.noSignal;
  String _liveNote    = '';
  double _liveCents   = 0;
  double _liveClarity = 0.0; // CREPE confidence (0.0 – 1.0)

  // ── CREPE model status ─────────────────────────────────────────────────────
  bool   _crepeReady   = false;  // true once model is loaded
  bool   _crepeLoading = true;   // shows spinner while loading
  String _pitchSource  = '';     // 'CREPE' or 'Local YIN'

  // ── Real-time pitch graph history (last 80 readings) ──────────────────────
  final List<double> _pitchHistory = [];
  static const int _maxPitchHistory = 80;

  // ── Per-line pitch accumulation ────────────────────────────────────────────
  late List<List<double>> _linePitch;
  late List<List<double>> _lineCents;

  // Finalised lyric data (built as lines complete)
  final List<LyricPitchData> _completedLines = [];

  // ── Lyrics ─────────────────────────────────────────────────────────────────
  List<LyricLine>  _lyrics          = const [];
  List<GlobalKey>  _lineKeys        = const [];
  bool             _lyricsLoading   = true;
  bool             _lyricsFromBackend = false;

  // ── Stats (shown during recording) ────────────────────────────────────────
  int _inTuneCount  = 0;
  int _sharpCount   = 0;
  int _flatCount    = 0;
  int _totalReadings = 0;

  @override
  void initState() {
    super.initState();
    _linePitch = [];
    _lineCents = [];
    _loadLyrics();
    _initCrepe();   // ← pre-load CREPE model as soon as page opens
  }

  // ── CREPE initialisation ───────────────────────────────────────────────────

  /// Pre-load the CREPE TFLite model so it is ready when user hits Record.
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

  // ── Lyrics loading ─────────────────────────────────────────────────────────

  Future<void> _loadLyrics() async {
    List<LyricLine>? fetched;
    try {
      fetched = await LrcLibService.fetchLyrics(
        title:  widget.songTitle,
        artist: widget.songArtist,
      );
    } catch (_) {}

    final lines = fetched ?? SongLyrics.forSong(widget.songTitle);

    if (mounted) {
      setState(() {
        _lyrics             = lines;
        _lineKeys           = List.generate(lines.length, (_) => GlobalKey());
        _linePitch          = List.generate(lines.length, (_) => []);
        _lineCents          = List.generate(lines.length, (_) => []);
        _lyricsLoading      = false;
        _lyricsFromBackend  = fetched != null;
      });
    }
  }

  // ── Lyric advancement ──────────────────────────────────────────────────────

  void _startLyrics() => _advanceLine();

  void _advanceLine() {
    if (!mounted || _currentLineIndex >= _lyrics.length) return;
    final line = _lyrics[_currentLineIndex];

    _lyricTimer = Timer(Duration(seconds: line.durationSeconds), () {
      if (!mounted) return;
      _sealCurrentLine();
      setState(() {
        if (_currentLineIndex < _lyrics.length - 1) _currentLineIndex++;
      });
      _scrollToCurrentLine();
      _advanceLine();
    });
  }

  void _sealCurrentLine() {
    final i = _currentLineIndex;
    if (i >= _lyrics.length) return;
    _completedLines.add(
      LyricPitchData(
        lyricText:     _lyrics[i].text,
        pitchReadings: List<double>.from(_linePitch[i]),
        centsReadings: List<double>.from(_lineCents[i]),
      ),
    );
    _linePitch[i].clear();
    _lineCents[i].clear();
  }

  void _pauseLyrics() => _lyricTimer?.cancel();

  void _scrollToCurrentLine() {
    final ctx = _lineKeys[_currentLineIndex].currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration:  const Duration(milliseconds: 400),
        curve:     Curves.easeInOut,
        alignment: 0.4,
      );
    }
  }

  // ── Recording toggle ───────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    // Reset session stats
    _inTuneCount   = 0;
    _sharpCount    = 0;
    _flatCount     = 0;
    _totalReadings = 0;

    final ok = await _audioService.start();
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied')),
        );
      }
      return;
    }

    // Detect which pitch source is active after start()
    if (mounted) {
      setState(() {
        _pitchSource = _crepeReady ? 'CREPE' : 'Local YIN';
      });
    }

    _audioSub = _audioService.results.listen((result) {
      if (!mounted) return;

      final i = _currentLineIndex;
      if (i < _linePitch.length) {
        if (result != null) {
          _linePitch[i].add(result.frequency);
          _lineCents[i].add(result.cents);
        } else {
          _linePitch[i].add(0);
          _lineCents[i].add(0);
        }
      }

      // Update live stats counters
      if (result != null && result.hasSignal) {
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
      }

      setState(() {
        if (result != null) {
          _liveFeedback = result.feedback;
          _liveNote     = result.fullName;
          _liveCents    = result.cents;
          _liveClarity  = result.confidence;
          _pitchHistory.add(result.frequency);
        } else {
          _liveFeedback = PitchFeedback.noSignal;
          _liveNote     = '';
          _liveCents    = 0;
          _liveClarity  = 0.0;
          _pitchHistory.add(0);
        }
        if (_pitchHistory.length > _maxPitchHistory) {
          _pitchHistory.removeAt(0);
        }
      });
    });
  }

  Future<void> _stopRecording() async {
    await _audioSub?.cancel();
    _audioSub = null;
    await _audioService.stop();
    setState(() {
      _liveFeedback = PitchFeedback.noSignal;
      _liveNote     = '';
      _liveCents    = 0;
      _liveClarity  = 0.0;
    });
  }

  // ── Stop & navigate to results ─────────────────────────────────────────────

  Future<void> _stopAll() async {
    _lyricTimer?.cancel();
    _sessionTimer?.cancel();
    if (_isRecording) await _stopRecording();
    setState(() {
      _isPlaying   = false;
      _isRecording = false;
    });
  }

  Future<void> _finishAndShowResults() async {
    await _stopAll();
    _sealCurrentLine();

    for (int i = _completedLines.length; i < _lyrics.length; i++) {
      _completedLines.add(
        LyricPitchData(
          lyricText:     _lyrics[i].text,
          pitchReadings: const [],
          centsReadings: const [],
        ),
      );
    }

    final session = SessionResult(
      songTitle:       widget.songTitle,
      songArtist:      widget.songArtist,
      songImage:       widget.songImage,
      completedAt:     DateTime.now(),
      lyricResults:    List<LyricPitchData>.from(_completedLines),
      durationSeconds: _elapsedSeconds,
    );

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => ResultsPage(session: session)),
    );
  }

  @override
  void dispose() {
    _lyricTimer?.cancel();
    _sessionTimer?.cancel();
    _audioSub?.cancel();
    _audioService.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Color get _clarityColor {
    if (_liveClarity >= 0.80) return const Color(0xFF4CAF50);
    if (_liveClarity >= 0.55) return Colors.orangeAccent;
    return const Color(0xFFF44336);
  }

  Color get _feedbackColor {
    switch (_liveFeedback) {
      case PitchFeedback.correct:  return AppColors.primaryCyan;
      case PitchFeedback.tooHigh:  return Colors.orangeAccent;
      case PitchFeedback.tooLow:   return Colors.blueAccent;
      case PitchFeedback.noSignal: return AppColors.grey;
    }
  }

  String get _feedbackLabel {
    switch (_liveFeedback) {
      case PitchFeedback.correct:  return 'In Tune ✓';
      case PitchFeedback.tooHigh:  return 'Sharp ↑';
      case PitchFeedback.tooLow:   return 'Flat ↓';
      case PitchFeedback.noSignal: return _isRecording ? 'Listening…' : '';
    }
  }

  // In-tune percentage for the mini stats bar
  double get _inTunePercent =>
      _totalReadings > 0 ? _inTuneCount / _totalReadings : 0.0;

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSongInfo(),
            _buildCrepeStatusBar(),           // ← new: shows CREPE status
            if (_isRecording) _buildLivePitchBar(),
            if (_isRecording) _buildPitchGraph(),
            if (_isRecording) _buildMiniStats(), // ← new: live accuracy stats
            const SizedBox(height: 4),
            Expanded(child: _buildLyricsArea()),
            _buildControls(),
          ],
        ),
      ),
    );
  }

  // ── CREPE status bar ───────────────────────────────────────────────────────

  /// Small bar at the top showing which pitch engine is active.
  Widget _buildCrepeStatusBar() {
    if (_crepeLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
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

    final isCrepe  = _pitchSource == 'CREPE';
    final dotColor = isCrepe ? const Color(0xFF4CAF50) : Colors.orangeAccent;
    final label    = isCrepe
        ? 'CREPE on-device model active'
        : 'Local YIN fallback active';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width:  7,
            height: 7,
            decoration: BoxDecoration(
              color:  dotColor,
              shape:  BoxShape.circle,
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

  // ── Mini live stats bar ────────────────────────────────────────────────────

  /// Shows live in-tune / sharp / flat counts while recording.
  Widget _buildMiniStats() {
    if (_totalReadings == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      child: Row(
        children: [
          // In-tune
          _statChip(
            label: 'In Tune',
            value: '${(_inTunePercent * 100).round()}%',
            color: AppColors.primaryCyan,
          ),
          const SizedBox(width: 6),
          // Sharp
          _statChip(
            label: 'Sharp',
            value: '$_sharpCount',
            color: Colors.orangeAccent,
          ),
          const SizedBox(width: 6),
          // Flat
          _statChip(
            label: 'Flat',
            value: '$_flatCount',
            color: Colors.blueAccent,
          ),
          const Spacer(),
          // Total readings
          Text(
            '$_totalReadings readings',
            style: TextStyle(
              color:      AppColors.grey.withValues(alpha: 0.5),
              fontSize:   9,
              fontFamily: 'Roboto',
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip({
    required String label,
    required String value,
    required Color color,
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

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.keyboard_arrow_down,
              color: AppColors.white,
              size: 30,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          const Spacer(),
          Column(
            children: [
              Text(
                'KARAOKE',
                style: TextStyle(
                  color:       AppColors.white.withValues(alpha: 0.5),
                  fontSize:    11,
                  fontWeight:  FontWeight.w600,
                  letterSpacing: 2,
                  fontFamily:  'Roboto',
                ),
              ),
              Text(
                widget.songTitle,
                style: const TextStyle(
                  color:      AppColors.white,
                  fontSize:   14,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Roboto',
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            '${(_elapsedSeconds ~/ 60).toString().padLeft(2, '0')}:'
            '${(_elapsedSeconds % 60).toString().padLeft(2, '0')}',
            style: TextStyle(
              color:       AppColors.white.withValues(alpha: 0.6),
              fontSize:    12,
              fontFamily:  'Roboto',
              letterSpacing: 1,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  // ── Song info ──────────────────────────────────────────────────────────────

  Widget _buildSongInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: widget.songImage.isNotEmpty
                ? Image.network(
                    widget.songImage,
                    width:  42,
                    height: 42,
                    fit:    BoxFit.cover,
                    errorBuilder: (ctx, e, st) => _musicIcon(),
                  )
                : _musicIcon(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.songTitle,
                  style: const TextStyle(
                    color:      AppColors.white,
                    fontSize:   15,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Roboto',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  widget.songArtist,
                  style: TextStyle(
                    color:      AppColors.white.withValues(alpha: 0.55),
                    fontSize:   13,
                    fontFamily: 'Roboto',
                  ),
                ),
              ],
            ),
          ),
          if (_isRecording)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color:  Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Container(
                    width:  7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    'REC',
                    style: TextStyle(
                      color:      Colors.red,
                      fontSize:   11,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _musicIcon() => Container(
    width:  42,
    height: 42,
    color:  AppColors.inputBg,
    child:  const Icon(Icons.music_note, color: AppColors.grey, size: 20),
  );

  // ── Live pitch bar ─────────────────────────────────────────────────────────

  Widget _buildLivePitchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.inputBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _feedbackColor.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.graphic_eq, color: _feedbackColor, size: 18),
            const SizedBox(width: 8),
            // Note name
            Text(
              _liveNote.isEmpty ? '—' : _liveNote,
              style: TextStyle(
                color:      _feedbackColor,
                fontSize:   16,
                fontWeight: FontWeight.bold,
                fontFamily: 'Roboto',
              ),
            ),
            const SizedBox(width: 10),
            // Cents meter
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Flat',
                        style: TextStyle(
                          color:      AppColors.grey.withValues(alpha: 0.6),
                          fontSize:   9,
                          fontFamily: 'Roboto',
                        ),
                      ),
                      Text(
                        '${_liveCents.toStringAsFixed(0)} ¢',
                        style: const TextStyle(
                          color:      AppColors.white,
                          fontSize:   9,
                          fontFamily: 'Roboto',
                        ),
                      ),
                      Text(
                        'Sharp',
                        style: TextStyle(
                          color:      AppColors.grey.withValues(alpha: 0.6),
                          fontSize:   9,
                          fontFamily: 'Roboto',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value:           (_liveCents.clamp(-50, 50) + 50) / 100,
                      minHeight:       5,
                      backgroundColor: AppColors.inputBg,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(_feedbackColor),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Feedback label + CREPE clarity
            Column(
              mainAxisSize:        MainAxisSize.min,
              crossAxisAlignment:  CrossAxisAlignment.end,
              children: [
                Text(
                  _feedbackLabel,
                  style: TextStyle(
                    color:      _feedbackColor,
                    fontSize:   10,
                    fontFamily: 'Roboto',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(_liveClarity * 100).round()}%',
                      style: TextStyle(
                        color:      _clarityColor,
                        fontSize:   10,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Roboto',
                      ),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      'clarity',
                      style: TextStyle(
                        color:      AppColors.grey.withValues(alpha: 0.6),
                        fontSize:   9,
                        fontFamily: 'Roboto',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Lyrics area ────────────────────────────────────────────────────────────

  Widget _buildLyricsArea() {
    if (_lyricsLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color:       AppColors.primaryCyan,
              strokeWidth: 2,
            ),
            const SizedBox(height: 16),
            Text(
              'Loading lyrics…',
              style: TextStyle(
                color:      AppColors.grey.withValues(alpha: 0.6),
                fontSize:   13,
                fontFamily: 'Roboto',
              ),
            ),
          ],
        ),
      );
    }

    return ShaderMask(
      shaderCallback: (rect) {
        return const LinearGradient(
          begin:  Alignment.topCenter,
          end:    Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.white,
            Colors.white,
            Colors.transparent,
          ],
          stops: [0.0, 0.12, 0.82, 1.0],
        ).createShader(rect);
      },
      blendMode: BlendMode.dstIn,
      child: SingleChildScrollView(
        controller: _scrollController,
        physics:    const NeverScrollableScrollPhysics(),
        padding:    const EdgeInsets.symmetric(vertical: 60, horizontal: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_lyricsFromBackend)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical:   3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryCyan.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.primaryCyan.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.cloud_done_outlined,
                        size:  10,
                        color: AppColors.primaryCyan,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Lyrics from LrcLib',
                        style: TextStyle(
                          color:      AppColors.primaryCyan.withValues(alpha: 0.85),
                          fontSize:   10,
                          fontFamily: 'Roboto',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ...List.generate(_lyrics.length, (i) {
              final line      = _lyrics[i];
              final isCurrent = i == _currentLineIndex;
              final isPast    = i < _currentLineIndex;

              if (line.text.isEmpty) {
                return SizedBox(key: _lineKeys[i], height: 28);
              }

              return Padding(
                key:     _lineKeys[i],
                padding: const EdgeInsets.only(bottom: 6),
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  style: TextStyle(
                    fontSize:   isCurrent ? 28 : 22,
                    fontWeight: isCurrent
                        ? FontWeight.w800
                        : FontWeight.w600,
                    color: isCurrent
                        ? AppColors.white
                        : isPast
                            ? AppColors.white.withValues(alpha: 0.25)
                            : AppColors.white.withValues(alpha: 0.38),
                    height:     1.35,
                    fontFamily: 'Roboto',
                  ),
                  child: Text(line.text),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ── Real-time pitch graph ──────────────────────────────────────────────────

  Widget _buildPitchGraph() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: AppColors.inputBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.primaryCyan.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: CustomPaint(
            painter: _KaraokePitchGraphPainter(
              List<double>.from(_pitchHistory),
            ),
          ),
        ),
      ),
    );
  }

  // ── Controls ───────────────────────────────────────────────────────────────

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 36),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Restart
          IconButton(
            icon: Icon(
              Icons.skip_previous_rounded,
              color: AppColors.white.withValues(alpha: 0.7),
              size:  32,
            ),
            onPressed: () {
              _pauseLyrics();
              setState(() => _currentLineIndex = 0);
              _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 300),
                curve:    Curves.easeOut,
              );
              if (_isPlaying) _startLyrics();
            },
          ),

          // Play / Pause
          GestureDetector(
            onTap: _lyricsLoading
                ? null
                : () {
                    setState(() => _isPlaying = !_isPlaying);
                    if (_isPlaying) {
                      _startLyrics();
                      _sessionTimer = Timer.periodic(
                        const Duration(seconds: 1),
                        (_) => setState(() => _elapsedSeconds++),
                      );
                    } else {
                      _pauseLyrics();
                      _sessionTimer?.cancel();
                    }
                  },
            child: Container(
              width:  60,
              height: 60,
              decoration: BoxDecoration(
                color: _lyricsLoading
                    ? AppColors.grey.withValues(alpha: 0.3)
                    : AppColors.white,
                shape: BoxShape.circle,
              ),
              child: _lyricsLoading
                  ? const SizedBox(
                      width:  24,
                      height: 24,
                      child: Center(
                        child: SizedBox(
                          width:  20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color:       AppColors.primaryCyan,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                    )
                  : Icon(
                      _isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.black,
                      size:  34,
                    ),
            ),
          ),

          // Record toggle
          GestureDetector(
            onTap: () async {
              if (_isRecording) {
                await _stopRecording();
              } else {
                await _startRecording();
              }
              setState(() => _isRecording = !_isRecording);
            },
            child: Container(
              width:  52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isRecording
                    ? Colors.red
                    : Colors.red.withValues(alpha: 0.15),
                border: Border.all(color: Colors.red, width: 2),
              ),
              child: Icon(
                Icons.mic,
                color: _isRecording ? AppColors.white : Colors.red,
                size:  24,
              ),
            ),
          ),

          // Stop & go to results
          GestureDetector(
            onTap: _finishAndShowResults,
            child: Container(
              width:  40,
              height: 40,
              decoration: BoxDecoration(
                color:        AppColors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.stop_rounded,
                color: AppColors.white.withValues(alpha: 0.8),
                size:  22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Karaoke real-time pitch graph painter ─────────────────────────────────────

class _KaraokePitchGraphPainter extends CustomPainter {
  final List<double> data;
  const _KaraokePitchGraphPainter(this.data);

  double _hzToY(double hz, double height) {
    const double minHz = 80.0;
    const double maxHz = 1100.0;
    if (hz <= 0) return height;
    final logMin = math.log(minHz);
    final logMax = math.log(maxHz);
    final logHz  = math.log(hz.clamp(minHz, maxHz));
    return height - ((logHz - logMin) / (logMax - logMin)) * height;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Reference lines — C3, C4, C5
    final refPaint = Paint()
      ..color       = const Color(0xFFFFFFFF).withValues(alpha: 0.07)
      ..strokeWidth = 1;

    for (final hz in [130.81, 261.63, 523.25]) {
      final y = _hzToY(hz, h);
      canvas.drawLine(Offset(0, y), Offset(w, y), refPaint);
    }

    if (data.isEmpty) return;

    final int    count = data.length;
    final double step  = count > 1 ? w / (count - 1) : w;

    final List<Offset> points = [
      for (int i = 0; i < count; i++)
        Offset(i * step, _hzToY(data[i], h)),
    ];

    if (points.length > 1) {
      // Filled gradient area
      final fillPath = Path()..moveTo(points.first.dx, h);
      for (final p in points) fillPath.lineTo(p.dx, p.dy);
      fillPath.lineTo(points.last.dx, h);
      fillPath.close();

      canvas.drawPath(
        fillPath,
        Paint()
          ..shader = const LinearGradient(
            begin:  Alignment.topCenter,
            end:    Alignment.bottomCenter,
            colors: [Color(0x4000E0FF), Color(0x0000E0FF)],
          ).createShader(Rect.fromLTWH(0, 0, w, h)),
      );

      // Cyan line
      final linePath = Path()
        ..moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        linePath.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(
        linePath,
        Paint()
          ..color       = AppColors.primaryCyan
          ..strokeWidth = 2.0
          ..strokeCap   = StrokeCap.round
          ..strokeJoin  = StrokeJoin.round
          ..style       = PaintingStyle.stroke,
      );
    }

    // Glowing dot at latest reading
    if (points.isNotEmpty && data.last > 0) {
      final last = points.last;
      canvas.drawCircle(
        last,
        6,
        Paint()..color = AppColors.primaryCyan.withValues(alpha: 0.22),
      );
      canvas.drawCircle(last, 2.8, Paint()..color = AppColors.primaryCyan);
    }
  }

  @override
  bool shouldRepaint(_KaraokePitchGraphPainter old) =>
      old.data.length != data.length ||
      (data.isNotEmpty &&
          old.data.isNotEmpty &&
          old.data.last != data.last);
}