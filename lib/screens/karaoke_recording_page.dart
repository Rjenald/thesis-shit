import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../constants/app_colors.dart';
import '../core/audio_service.dart';
import '../core/note_utils.dart';
import '../models/session_result.dart';
import '../services/youtube_service.dart';
import '../services/lyrics_service.dart';
import 'results_page.dart';

// ── How many pitch segments appear in the results heatmap ─────────────────────
const int _kResultSegments = 30;

class KaraokeRecordingPage extends StatefulWidget {
  final String songTitle;
  final String songArtist;
  final String songImage;

  /// When provided the page skips the YouTube search and uses this ID directly.
  final String? youtubeVideoId;

  /// When true the results page shows [Try Again | Submit] instead of
  /// [Try Again | Listen | Save].
  final bool isAssignment;

  const KaraokeRecordingPage({
    super.key,
    this.songTitle    = 'Dadalhin',
    this.songArtist   = 'Regine Velasquez',
    this.songImage    = '',
    this.youtubeVideoId,
    this.isAssignment = false,
  });

  @override
  State<KaraokeRecordingPage> createState() => _KaraokeRecordingPageState();
}

class _KaraokeRecordingPageState extends State<KaraokeRecordingPage>
    with SingleTickerProviderStateMixin {

  // ── Coarse state ───────────────────────────────────────────────────────────
  bool _isPlaying   = false;
  bool _isRecording = false;
  /// True when user pressed play before video finished loading.
  bool _pendingPlay = false;
  int  _currentLineIndex = 0;

  // ── Fine-grained notifier — position in ms ────────────────────────────────
  /// Position in milliseconds → drives the timer label AND lyric sync.
  final ValueNotifier<int> _posNotifier = ValueNotifier(0);

  // ── Raw pitch history (fallback segment results) ──────────────────────────
  final List<double> _rawHz    = [];
  final List<double> _rawCents = [];

  // ── Audio ──────────────────────────────────────────────────────────────────
  final AudioService               _audioService = AudioService();
  StreamSubscription<NoteResult?>? _audioSub;

  // ── YouTube ────────────────────────────────────────────────────────────────
  YoutubePlayerController? _ytController;
  bool   _ytPositionActive = false;
  Timer? _posTimer;

  // ── CREPE model status ─────────────────────────────────────────────────────
  bool   _crepeReady   = false;
  bool   _crepeLoading = true;
  String _pitchSource  = '';

  // ── Live pitch display ─────────────────────────────────────────────────────
  PitchFeedback _liveFeedback = PitchFeedback.noSignal;
  String _liveNote    = '';
  double _liveCents   = 0;
  double _liveClarity = 0.0; // CREPE confidence (0.0 – 1.0)

  // ── Real-time pitch graph history (last 80 readings) ──────────────────────
  final List<double> _pitchHistory = [];
  static const int _maxPitchHistory = 80;

  // ── Per-line pitch accumulation ────────────────────────────────────────────
  List<List<double>> _linePitch = [];
  List<List<double>> _lineCents = [];

  /// Finalised lyric data (built as lines complete).
  final List<LyricPitchData> _completedLines = [];

  // ── Lyrics ─────────────────────────────────────────────────────────────────
  List<LrcLine>   _lyrics          = [];
  List<GlobalKey> _lineKeys        = [];
  bool            _lyricsLoading   = true;
  final ScrollController _lyricsScroll = ScrollController();

  // ── Stats (shown during recording) ────────────────────────────────────────
  int _inTuneCount   = 0;
  int _sharpCount    = 0;
  int _flatCount     = 0;
  int _totalReadings = 0;

  // ══════════════════════════════════════════════════════════════════════════
  // Lifecycle
  // ══════════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _loadYouTubeVideo();
    _loadLyrics();
    _posNotifier.addListener(_updateCurrentLyric);
    _initCrepe(); // pre-load CREPE model as soon as page opens
  }

  @override
  void dispose() {
    _posTimer?.cancel();
    _audioSub?.cancel();
    _audioService.dispose();
    _ytController?.removeListener(_onYTUpdate);
    _ytController?.dispose();
    _posNotifier.removeListener(_updateCurrentLyric);
    _posNotifier.dispose();
    _lyricsScroll.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CREPE initialisation
  // ══════════════════════════════════════════════════════════════════════════

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
    } catch (_) {
      if (mounted) {
        setState(() {
          _crepeReady   = false;
          _crepeLoading = false;
          _pitchSource  = 'Local YIN';
        });
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // YouTube
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _loadYouTubeVideo() async {
    final videoId = widget.youtubeVideoId?.isNotEmpty == true
        ? widget.youtubeVideoId
        : await YouTubeService.searchVideoId(
            title:  widget.songTitle,
            artist: widget.songArtist,
          );
    if (!mounted) return;

    if (videoId != null && videoId.isNotEmpty) {
      final ctrl = YoutubePlayerController(
        initialVideoId: videoId,
        flags: YoutubePlayerFlags(
          autoPlay:        _pendingPlay,
          mute:            false,
          disableDragSeek: false,
          hideControls:    false,
          enableCaption:   false,
        ),
      );
      ctrl.addListener(_onYTUpdate);
      setState(() {
        _ytController = ctrl;
        if (_pendingPlay) {
          _isPlaying   = true;
          _pendingPlay = false;
        }
      });
    } else {
      setState(() => _pendingPlay = false);
    }
  }

  void _onYTUpdate() {
    if (!mounted || _ytController == null) return;
    final v = _ytController!.value;

    // Only setState for play-state changes (infrequent).
    if (_isPlaying != v.isPlaying) {
      setState(() => _isPlaying = v.isPlaying);
    }

    if (v.isPlaying && !_ytPositionActive) {
      _ytPositionActive = true;
      _posTimer?.cancel();
      _posTimer = null;
    }

    // Position: update notifier — does NOT rebuild the main tree.
    if (v.isPlaying || v.position.inMilliseconds > 0) {
      final ms = v.position.inMilliseconds;
      if (ms != _posNotifier.value) _posNotifier.value = ms;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Lyrics
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _loadLyrics() async {
    final lines = await LyricsService.fetchLyrics(
      title:  widget.songTitle,
      artist: widget.songArtist,
    );
    if (!mounted) return;
    setState(() {
      _lyrics        = lines;
      _lineKeys      = List.generate(lines.length, (_) => GlobalKey());
      _linePitch     = List.generate(lines.length, (_) => []);
      _lineCents     = List.generate(lines.length, (_) => []);
      _lyricsLoading = false;
    });
  }

  /// Called every time _posNotifier changes — O(log n) binary search.
  void _updateCurrentLyric() {
    if (_lyrics.isEmpty) return;
    final ms = _posNotifier.value;
    int lo = 0, hi = _lyrics.length - 1, idx = 0;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (_lyrics[mid].timestamp.inMilliseconds <= ms) {
        idx = mid;
        lo  = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    if (idx != _currentLineIndex) {
      _sealCurrentLine(); // finalise pitch data for the outgoing line
      setState(() => _currentLineIndex = idx);
      _scrollToCurrentLine();
    }
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

  void _scrollToCurrentLine() {
    if (_currentLineIndex >= _lineKeys.length) return;
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

  // ══════════════════════════════════════════════════════════════════════════
  // Play / pause
  // ══════════════════════════════════════════════════════════════════════════

  void _togglePlayPause() {
    if (_ytController == null) {
      setState(() => _pendingPlay = !_pendingPlay);
      return;
    }
    final ytPlaying = _ytController!.value.isPlaying;
    if (ytPlaying) {
      _ytController!.pause();
      _posTimer?.cancel();
      _posTimer = null;
      setState(() => _isPlaying = false);
    } else {
      _ytController!.play();
      setState(() => _isPlaying = true);
      _posTimer ??= Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (!mounted || !_isPlaying) return;
        if (!_ytPositionActive) _posNotifier.value += 200;
      });
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Microphone — never touches the video
  // ══════════════════════════════════════════════════════════════════════════

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

    if (mounted) {
      setState(() => _pitchSource = _crepeReady ? 'CREPE' : 'Local YIN');
    }

    _audioSub = _audioService.results.listen((result) {
      if (!mounted) return;

      // ── Accumulate raw data (fallback segment results) ─────────────────
      _rawHz   .add(result?.frequency ?? 0);
      _rawCents.add(result?.cents     ?? 0);

      // ── Per-line pitch accumulation ────────────────────────────────────
      final i = _currentLineIndex;
      if (i < _linePitch.length) {
        _linePitch[i].add(result?.frequency ?? 0);
        _lineCents[i].add(result?.cents     ?? 0);
      }

      // ── Live stats counters ─────────────────────────────────────────────
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

      // ── Rebuild live display ────────────────────────────────────────────
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

    setState(() => _isRecording = true);
  }

  Future<void> _stopRecording() async {
    await _audioSub?.cancel();
    _audioSub = null;
    await _audioService.stop();
    if (mounted) {
      setState(() {
        _isRecording  = false;
        _liveFeedback = PitchFeedback.noSignal;
        _liveNote     = '';
        _liveCents    = 0;
        _liveClarity  = 0.0;
      });
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Finish
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _finishAndShowResults() async {
    _posTimer?.cancel();
    _posTimer = null;
    _ytController?.pause();
    if (_isRecording) await _stopRecording();

    // Seal whatever line we're currently on
    _sealCurrentLine();

    // Fill any remaining lines with empty data
    for (int i = _completedLines.length; i < _lyrics.length; i++) {
      _completedLines.add(LyricPitchData(
        lyricText:     _lyrics[i].text,
        pitchReadings: const [],
        centsReadings: const [],
      ));
    }

    // Use per-line data if available, otherwise fall back to segments
    final results = _completedLines.isNotEmpty
        ? List<LyricPitchData>.from(_completedLines)
        : _buildSegmentResults();

    final session = SessionResult(
      songTitle:       widget.songTitle,
      songArtist:      widget.songArtist,
      songImage:       widget.songImage,
      completedAt:     DateTime.now(),
      lyricResults:    results,
      durationSeconds: _posNotifier.value ~/ 1000,
    );

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResultsPage(
          session:      session,
          isAssignment: widget.isAssignment,
        ),
      ),
    );
  }

  /// Divides raw pitch data into N equal segments — used when per-line data
  /// is unavailable (e.g. user stopped before any lyrics loaded).
  List<LyricPitchData> _buildSegmentResults() {
    final total = _rawHz.length;
    if (total == 0) return [];
    final n       = _kResultSegments.clamp(1, total);
    final segSize = (total / n).ceil();
    return List.generate(n, (i) {
      final start = i * segSize;
      final end   = (start + segSize).clamp(0, total);
      if (start >= total) return null;
      return LyricPitchData(
        lyricText:     'seg${i + 1}',
        pitchReadings: _rawHz   .sublist(start, end),
        centsReadings: _rawCents.sublist(start, end),
      );
    }).whereType<LyricPitchData>().toList();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Computed helpers
  // ══════════════════════════════════════════════════════════════════════════

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

  double get _inTunePercent =>
      _totalReadings > 0 ? _inTuneCount / _totalReadings : 0.0;

  // ══════════════════════════════════════════════════════════════════════════
  // Build — only rebuilt on coarse-state changes
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSongInfo(),
            // YouTube video strip — audio + visual playback
            SizedBox(height: 160, child: _buildVideoBox()),
            _buildCrepeStatusBar(),
            if (_isRecording) _buildLivePitchBar(),
            if (_isRecording) _buildPitchGraph(),
            if (_isRecording) _buildMiniStats(),
            Expanded(child: _buildLyricsArea()),
            _buildControls(),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
                SizedBox(width: 6),
                Text('Record',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Roboto')),
              ],
            ),
          ),
          const Spacer(),
          // Elapsed timer — rebuilt by notifier only, NOT by setState
          if (_isPlaying || _isRecording)
            ValueListenableBuilder<int>(
              valueListenable: _posNotifier,
              builder: (context2, ms, child2) {
                final s  = ms ~/ 1000;
                final mm = (s ~/ 60).toString().padLeft(2, '0');
                final ss = (s  % 60).toString().padLeft(2, '0');
                return Text('$mm:$ss',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12,
                        fontFamily: 'Roboto',
                        letterSpacing: 1.2));
              },
            ),
          const SizedBox(width: 8),
          const Icon(Icons.more_horiz, color: Colors.white, size: 22),
        ],
      ),
    );
  }

  // ── Song info ──────────────────────────────────────────────────────────────

  Widget _buildSongInfo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
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
                    errorBuilder: (ctx, err, st) => _musicIcon(),
                  )
                : _musicIcon(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.songTitle,
                    style: const TextStyle(
                      color:      Colors.white,
                      fontSize:   15,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Roboto',
                    ),
                    overflow: TextOverflow.ellipsis),
                Text(widget.songArtist,
                    style: TextStyle(
                      color:      Colors.white.withValues(alpha: 0.55),
                      fontSize:   13,
                      fontFamily: 'Roboto',
                    )),
              ],
            ),
          ),
          if (_isRecording) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color:        Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border:       Border.all(color: Colors.red.withValues(alpha: 0.5)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, color: Colors.red, size: 5),
                  SizedBox(width: 3),
                  Text('REC',
                      style: TextStyle(
                          color:      Colors.red,
                          fontSize:   9,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Roboto')),
                ],
              ),
            ),
          ],
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

  // ── Video box ──────────────────────────────────────────────────────────────

  Widget _buildVideoBox() {
    if (_ytController == null) {
      return _videoShell(
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
                color: AppColors.primaryCyan, strokeWidth: 2),
            SizedBox(height: 10),
            Text('Loading video…',
                style: TextStyle(color: Colors.white30, fontSize: 12)),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: RepaintBoundary(
          child: YoutubePlayer(
            controller:                 _ytController!,
            showVideoProgressIndicator: true,
            progressIndicatorColor:     Colors.red,
            progressColors: const ProgressBarColors(
              playedColor:     Colors.red,
              handleColor:     Colors.redAccent,
              bufferedColor:   Colors.white24,
              backgroundColor: Colors.white12,
            ),
            topActions:    const [],
            bottomActions: const [
              CurrentPosition(),
              ProgressBar(isExpanded: true),
              RemainingDuration(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _videoShell({required Widget child}) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            decoration: BoxDecoration(
              color:        const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(6),
              border:       Border.all(color: Colors.white12, width: 0.5),
            ),
            child: Center(child: child),
          ),
        ),
      );

  // ── CREPE status bar ───────────────────────────────────────────────────────

  Widget _buildCrepeStatusBar() {
    if (_crepeLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
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
            Text('Loading CREPE model…',
                style: TextStyle(
                  color:      AppColors.grey.withValues(alpha: 0.6),
                  fontSize:   10,
                  fontFamily: 'Roboto',
                )),
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
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                color:      dotColor.withValues(alpha: 0.85),
                fontSize:   10,
                fontFamily: 'Roboto',
              )),
        ],
      ),
    );
  }

  // ── Live pitch bar ─────────────────────────────────────────────────────────

  Widget _buildLivePitchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color:        AppColors.inputBg,
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
                      Text('Flat',
                          style: TextStyle(
                            color: AppColors.grey.withValues(alpha: 0.6),
                            fontSize: 9, fontFamily: 'Roboto')),
                      Text('${_liveCents.toStringAsFixed(0)} ¢',
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 9, fontFamily: 'Roboto')),
                      Text('Sharp',
                          style: TextStyle(
                            color: AppColors.grey.withValues(alpha: 0.6),
                            fontSize: 9, fontFamily: 'Roboto')),
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
              mainAxisSize:       MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_feedbackLabel,
                    style: TextStyle(
                      color:      _feedbackColor,
                      fontSize:   10,
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.w600,
                    )),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${(_liveClarity * 100).round()}%',
                        style: TextStyle(
                          color:      _clarityColor,
                          fontSize:   10,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Roboto',
                        )),
                    const SizedBox(width: 2),
                    Text('clarity',
                        style: TextStyle(
                          color:      AppColors.grey.withValues(alpha: 0.6),
                          fontSize:   9,
                          fontFamily: 'Roboto',
                        )),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Pitch graph ────────────────────────────────────────────────────────────

  Widget _buildPitchGraph() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: SizedBox(
        height: 60,
        child: CustomPaint(
          painter: _KaraokePitchGraphPainter(_pitchHistory),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  // ── Mini live stats bar ────────────────────────────────────────────────────

  Widget _buildMiniStats() {
    if (_totalReadings == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      child: Row(
        children: [
          _statChip(
            label: 'In Tune',
            value: '${(_inTunePercent * 100).round()}%',
            color: AppColors.primaryCyan,
          ),
          const SizedBox(width: 6),
          _statChip(label: 'Sharp', value: '$_sharpCount', color: Colors.orangeAccent),
          const SizedBox(width: 6),
          _statChip(label: 'Flat',  value: '$_flatCount',  color: Colors.blueAccent),
          const Spacer(),
          Text('$_totalReadings readings',
              style: TextStyle(
                color:      AppColors.grey.withValues(alpha: 0.5),
                fontSize:   9,
                fontFamily: 'Roboto',
              )),
        ],
      ),
    );
  }

  Widget _statChip({
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
          Text(value,
              style: TextStyle(
                color:      color,
                fontSize:   10,
                fontWeight: FontWeight.bold,
                fontFamily: 'Roboto',
              )),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                color:      color.withValues(alpha: 0.7),
                fontSize:   9,
                fontFamily: 'Roboto',
              )),
        ],
      ),
    );
  }

  // ── Lyrics area ────────────────────────────────────────────────────────────

  Widget _buildLyricsArea() {
    if (_lyricsLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
                color: AppColors.primaryCyan, strokeWidth: 2),
            SizedBox(height: 16),
            Text('Loading lyrics…',
                style: TextStyle(
                    color: Colors.white38,
                    fontSize: 13,
                    fontFamily: 'Roboto')),
          ],
        ),
      );
    }

    if (_lyrics.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lyrics_outlined,
                color: Colors.white.withValues(alpha: 0.2), size: 48),
            const SizedBox(height: 12),
            Text('No synced lyrics found',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 14,
                    fontFamily: 'Roboto')),
            const SizedBox(height: 4),
            Text('Sing along with the video above',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 12,
                    fontFamily: 'Roboto')),
          ],
        ),
      );
    }

    return ShaderMask(
      shaderCallback: (rect) => const LinearGradient(
        begin:  Alignment.topCenter,
        end:    Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          Colors.white,
          Colors.white,
          Colors.transparent,
        ],
        stops: [0.0, 0.12, 0.82, 1.0],
      ).createShader(rect),
      blendMode: BlendMode.dstIn,
      child: SingleChildScrollView(
        controller: _lyricsScroll,
        physics:    const NeverScrollableScrollPhysics(),
        padding:    const EdgeInsets.symmetric(vertical: 60, horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...List.generate(_lyrics.length, (i) {
              final isCurrent = i == _currentLineIndex;
              final isPast    = i < _currentLineIndex;
              final text      = _lyrics[i].text;

              if (text.isEmpty) {
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
                        ? Colors.white
                        : isPast
                            ? Colors.white.withValues(alpha: 0.25)
                            : Colors.white.withValues(alpha: 0.38),
                    height:     1.35,
                    fontFamily: 'Roboto',
                  ),
                  child: Text(text, textAlign: TextAlign.center),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ── Controls ───────────────────────────────────────────────────────────────

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 36),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ⏮  Restart — seeks video to zero and resets lyric index
          IconButton(
            icon: Icon(
              Icons.skip_previous_rounded,
              color: Colors.white.withValues(alpha: 0.7),
              size:  32,
            ),
            onPressed: () {
              _ytController?.seekTo(Duration.zero);
              setState(() {
                _currentLineIndex = 0;
                _completedLines.clear();
              });
              if (_lyricsScroll.hasClients) {
                _lyricsScroll.animateTo(0,
                    duration: const Duration(milliseconds: 300),
                    curve:    Curves.easeOut);
              }
            },
          ),

          const SizedBox(width: 8),

          // ▶ / ❚❚  Play-pause
          GestureDetector(
            onTap: _togglePlayPause,
            child: Container(
              width:  60,
              height: 60,
              decoration: BoxDecoration(
                shape:  BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: _pendingPlay
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : Icon(
                      _isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size:  34),
            ),
          ),

          const SizedBox(width: 24),

          // 🔴  Mic toggle — start/stop recording, video never pauses
          GestureDetector(
            onTap: () async {
              if (_isRecording) {
                await _stopRecording();
              } else {
                await _startRecording();
              }
            },
            child: Container(
              width:  64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isRecording ? Colors.red[700] : Colors.red,
              ),
              child: Icon(
                _isRecording ? Icons.stop_rounded : Icons.mic,
                color: Colors.white,
                size:  30,
              ),
            ),
          ),

          const SizedBox(width: 24),

          // ⬜  Finish → results
          GestureDetector(
            onTap: _finishAndShowResults,
            child: Container(
              width:  52,
              height: 52,
              decoration: BoxDecoration(
                color:        Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.stop_rounded,
                  color: Colors.black, size: 28),
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

    // Reference lines — C3 (130 Hz), C4 (261 Hz), C5 (523 Hz)
    final refPaint = Paint()
      ..color       = Colors.white.withValues(alpha: 0.07)
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
      // Filled gradient area under the line
      final fillPath = Path()..moveTo(points.first.dx, h);
      for (final p in points) { fillPath.lineTo(p.dx, p.dy); }
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

    // Glowing dot at the latest reading
    if (points.isNotEmpty && data.last > 0) {
      final last = points.last;
      canvas.drawCircle(
          last, 6, Paint()..color = AppColors.primaryCyan.withValues(alpha: 0.22));
      canvas.drawCircle(last, 2.8, Paint()..color = AppColors.primaryCyan);
    }
  }

  @override
  bool shouldRepaint(_KaraokePitchGraphPainter old) =>
      old.data.length != data.length ||
      (data.isNotEmpty && old.data.isNotEmpty && old.data.last != data.last);
}
