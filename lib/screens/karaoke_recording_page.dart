import 'dart:async';
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
    this.songTitle     = 'Dadalhin',
    this.songArtist    = 'Regine Velasquez',
    this.songImage     = '',
    this.youtubeVideoId,
    this.isAssignment  = false,
  });

  @override
  State<KaraokeRecordingPage> createState() => _KaraokeRecordingPageState();
}

<<<<<<< HEAD
class _KaraokeRecordingPageState extends State<KaraokeRecordingPage> {
  // ── Coarse state — only these trigger a full-tree rebuild ──────────────────
  bool _isPlaying   = false;
  bool _isRecording = false;
  /// True when user pressed play before video finished loading.
  bool _pendingPlay = false;

  // ── Fine-grained notifiers — rebuild only the widgets that need it ─────────
  /// Current pitch reading. Rebuilt: status row only.
  final ValueNotifier<NoteResult?> _pitchNotifier = ValueNotifier(null);
  /// Position in milliseconds. Rebuilt: timer label only.
  final ValueNotifier<int> _posNotifier = ValueNotifier(0);
=======
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
>>>>>>> origin/yosef

  // ── Pitch history (raw, never triggers rebuilds directly) ─────────────────
  final List<double> _rawHz    = [];
  final List<double> _rawCents = [];

  // ── Audio ──────────────────────────────────────────────────────────────────
  final AudioService               _audioService = AudioService();
  StreamSubscription<NoteResult?>? _audioSub;

<<<<<<< HEAD
  // ── YouTube ────────────────────────────────────────────────────────────────
  YoutubePlayerController? _ytController;
  bool _ytPositionActive = false;
  Timer?  _posTimer;         // fallback position ticker

  // ── Lyrics ─────────────────────────────────────────────────────────────────
  List<LrcLine> _lyrics      = [];
  bool _lyricsLoading        = true;
  final ValueNotifier<int> _lyricIdxNotifier = ValueNotifier(0);
  final ScrollController    _lyricsScroll    = ScrollController();
  static const double _lyricRowHeight        = 56.0;

  // ── Pitch colours ──────────────────────────────────────────────────────────
  static const _colorInTune  = Color(0xFF4CAF50);
  static const _colorOffTune = Color(0xFFF44336);
  static const _colorSilent  = Color(0xFF757575);

  // ══════════════════════════════════════════════════════════════════════════
  // Lifecycle
  // ══════════════════════════════════════════════════════════════════════════
=======
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
>>>>>>> origin/yosef

  @override
  void initState() {
    super.initState();
    _loadYouTubeVideo();
    _loadLyrics();
<<<<<<< HEAD
    _posNotifier.addListener(_updateCurrentLyric);
    // Mic is NOT auto-started — user presses the mic button when ready to sing.
  }

  @override
  void dispose() {
    _posTimer?.cancel();
    _audioSub?.cancel();
    _audioService.dispose();
    _ytController?.removeListener(_onYTUpdate);
    _ytController?.dispose();
    _pitchNotifier.dispose();
    _posNotifier.removeListener(_updateCurrentLyric);
    _posNotifier.dispose();
    _lyricIdxNotifier.dispose();
    _lyricsScroll.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // YouTube
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _loadYouTubeVideo() async {
    // Use the pre-supplied ID if available, otherwise search the API.
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
=======
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
>>>>>>> origin/yosef
      );
      ctrl.addListener(_onYTUpdate);
      setState(() {
<<<<<<< HEAD
        _ytController = ctrl;
        if (_pendingPlay) {
          _isPlaying   = true;
          _pendingPlay = false;
        }
=======
        _lyrics             = lines;
        _lineKeys           = List.generate(lines.length, (_) => GlobalKey());
        _linePitch          = List.generate(lines.length, (_) => []);
        _lineCents          = List.generate(lines.length, (_) => []);
        _lyricsLoading      = false;
        _lyricsFromBackend  = fetched != null;
>>>>>>> origin/yosef
      });
    } else {
      setState(() => _pendingPlay = false);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Lyrics
  // ══════════════════════════════════════════════════════════════════════════

<<<<<<< HEAD
  Future<void> _loadLyrics() async {
    final lines = await LyricsService.fetchLyrics(
      title:  widget.songTitle,
      artist: widget.songArtist,
    );
    if (!mounted) return;
    setState(() {
      _lyrics        = lines;
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
    if (idx != _lyricIdxNotifier.value) {
      _lyricIdxNotifier.value = idx;
      _scrollToLyric(idx);
=======
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
>>>>>>> origin/yosef
    }
  }

  void _scrollToLyric(int idx) {
    if (!_lyricsScroll.hasClients) return;
    final offset = (idx * _lyricRowHeight) -
        (_lyricsScroll.position.viewportDimension / 2 - _lyricRowHeight / 2);
    _lyricsScroll.animateTo(
      offset.clamp(0.0, _lyricsScroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve:    Curves.easeInOut,
    );
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
        // Update notifier — no setState needed.
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

    // Detect which pitch source is active after start()
    if (mounted) {
      setState(() {
        _pitchSource = _crepeReady ? 'CREPE' : 'Local YIN';
      });
    }

    _audioSub = _audioService.results.listen((result) {
      if (!mounted) return;

<<<<<<< HEAD
      // ── Accumulate raw data — O(1), no rebuild ────────────────────────
      _rawHz   .add(result?.frequency ?? 0);
      _rawCents.add(result?.cents     ?? 0);

      // ── Pitch notifier — only rebuilds status row ────────────────────
      _pitchNotifier.value = result;
      // NO setState here — main widget tree is NOT rebuilt.
=======
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
>>>>>>> origin/yosef
    });

    // One setState to flip the recording button.
    setState(() => _isRecording = true);
  }

  Future<void> _stopRecording() async {
    await _audioSub?.cancel();
    _audioSub = null;
    await _audioService.stop();
<<<<<<< HEAD
    _pitchNotifier.value = null;
    if (mounted) setState(() => _isRecording = false);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Finish
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _finishAndShowResults() async {
    _posTimer?.cancel();
    _posTimer = null;
    _ytController?.pause();
    if (_isRecording) await _stopRecording();
=======
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
>>>>>>> origin/yosef

    final session = SessionResult(
      songTitle:       widget.songTitle,
      songArtist:      widget.songArtist,
      songImage:       widget.songImage,
      completedAt:     DateTime.now(),
<<<<<<< HEAD
      lyricResults:    _buildLyricResults(),
      durationSeconds: _posNotifier.value ~/ 1000,
=======
      lyricResults:    List<LyricPitchData>.from(_completedLines),
      durationSeconds: _elapsedSeconds,
>>>>>>> origin/yosef
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

  List<LyricPitchData> _buildLyricResults() {
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

<<<<<<< HEAD
  // ══════════════════════════════════════════════════════════════════════════
  // Build — rebuilt only when _isPlaying / _isRecording / _ytVideoId changes
  // ══════════════════════════════════════════════════════════════════════════
=======
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
>>>>>>> origin/yosef

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
<<<<<<< HEAD
            _buildSongInfoRow(),
            // YouTube player hidden but alive so audio keeps playing
            // Small video strip at top
            SizedBox(height: 180, child: _buildVideoBox()),
            // Scrolling lyrics — main content
            Expanded(child: _buildLyricsPanel()),
            // Real-time pitch bar while mic is on
            if (_isRecording) _buildLivePitchRow(),
=======
            _buildSongInfo(),
            _buildCrepeStatusBar(),           // ← new: shows CREPE status
            if (_isRecording) _buildLivePitchBar(),
            if (_isRecording) _buildPitchGraph(),
            if (_isRecording) _buildMiniStats(), // ← new: live accuracy stats
            const SizedBox(height: 4),
            Expanded(child: _buildLyricsArea()),
>>>>>>> origin/yosef
            _buildControls(),
          ],
        ),
      ),
    );
  }

<<<<<<< HEAD
  // ── Video box ──────────────────────────────────────────────────────────────

  Widget _buildVideoBox() {
    if (_ytController == null) {
      return _videoShell(child: const Column(
        mainAxisSize: MainAxisSize.min,
=======
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
>>>>>>> origin/yosef
        children: [
          CircularProgressIndicator(
              color: AppColors.primaryCyan, strokeWidth: 2),
          SizedBox(height: 10),
          Text('Loading video…',
              style: TextStyle(color: Colors.white30, fontSize: 12)),
        ],
      ));
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
<<<<<<< HEAD
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
=======
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
>>>>>>> origin/yosef
            ),
          ),
          const Spacer(),

          // ── Elapsed timer — rebuilt by notifier, NOT by setState ──────
          if (_isPlaying || _isRecording)
            ValueListenableBuilder<int>(
              valueListenable: _posNotifier,
              builder: (ctx2, ms, child2) {
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

<<<<<<< HEAD
  // ── Song info row ──────────────────────────────────────────────────────────

  Widget _buildSongInfoRow() {
=======
  // ── Song info ──────────────────────────────────────────────────────────────

  Widget _buildSongInfo() {
>>>>>>> origin/yosef
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Row(
        children: [
<<<<<<< HEAD
          const Icon(Icons.music_note, color: AppColors.primaryCyan, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(widget.songTitle,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Roboto'),
                overflow: TextOverflow.ellipsis),
=======
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
>>>>>>> origin/yosef
          ),
          Text(widget.songArtist,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                  fontFamily: 'Roboto'),
              overflow: TextOverflow.ellipsis),
          if (_isRecording) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color:  Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
<<<<<<< HEAD
                  Icon(Icons.circle, color: Colors.red, size: 5),
                  SizedBox(width: 3),
                  Text('REC',
                      style: TextStyle(
                          color: Colors.red,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Roboto')),
=======
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
>>>>>>> origin/yosef
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

<<<<<<< HEAD
  // ── Lyrics panel (WeSing-style scrolling) ─────────────────────────────────

  Widget _buildLyricsPanel() {
=======
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
>>>>>>> origin/yosef
    if (_lyricsLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
<<<<<<< HEAD
            CircularProgressIndicator(color: AppColors.primaryCyan, strokeWidth: 2),
            SizedBox(height: 10),
            Text('Loading lyrics…',
                style: TextStyle(color: Colors.white38, fontSize: 13,
                    fontFamily: 'Roboto')),
=======
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
>>>>>>> origin/yosef
          ],
        ),
      );
    }

<<<<<<< HEAD
    if (_lyrics.isEmpty) {
      return Center(
=======
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
>>>>>>> origin/yosef
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
<<<<<<< HEAD
            Icon(Icons.lyrics_outlined,
                color: Colors.white.withValues(alpha: 0.2), size: 48),
            const SizedBox(height: 12),
            Text('No synced lyrics found',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 14, fontFamily: 'Roboto')),
            const SizedBox(height: 4),
            Text('Sing along with the video above',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 12, fontFamily: 'Roboto')),
          ],
        ),
      );
    }

    return ValueListenableBuilder<int>(
      valueListenable: _lyricIdxNotifier,
      builder: (ctx, currentIdx, _) {
        return ValueListenableBuilder<NoteResult?>(
          valueListenable: _pitchNotifier,
          builder: (ctx2, pitch, _) {
            // Determine pitch color for current line highlight
            Color lineColor = Colors.white.withValues(alpha: 0.15);
            if (_isRecording && pitch != null && pitch.frequency > 0) {
              switch (pitch.feedback) {
                case PitchFeedback.correct:
                  lineColor = _colorInTune.withValues(alpha: 0.25);
                  break;
                case PitchFeedback.tooHigh:
                case PitchFeedback.tooLow:
                  lineColor = _colorOffTune.withValues(alpha: 0.2);
                  break;
                case PitchFeedback.noSignal:
                  lineColor = Colors.white.withValues(alpha: 0.15);
                  break;
              }
            }

            return ListView.builder(
              controller:   _lyricsScroll,
              padding: const EdgeInsets.symmetric(vertical: 32),
              itemCount:    _lyrics.length,
              itemExtent:   _lyricRowHeight,
              itemBuilder:  (ctx3, i) {
                final isCurrent = i == currentIdx;
                final isPast    = i < currentIdx;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  alignment: Alignment.center,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  decoration: isCurrent
                      ? BoxDecoration(
                          color:        lineColor,
                          borderRadius: BorderRadius.circular(10),
                        )
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      _lyrics[i].text,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isCurrent
                            ? Colors.white
                            : isPast
                                ? Colors.white.withValues(alpha: 0.3)
                                : Colors.white.withValues(alpha: 0.55),
                        fontSize:   isCurrent ? 20 : 15,
                        fontWeight: isCurrent
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontFamily: 'Roboto',
                        height: 1.3,
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // ── Live pitch status row — only rebuilt via ValueListenableBuilder ─────────

  Widget _buildLivePitchRow() {
    return ValueListenableBuilder<NoteResult?>(
      valueListenable: _pitchNotifier,
      builder: (ctx2, pitch, child2) {
        final bool active = pitch != null &&
            pitch.frequency > 0 &&
            pitch.feedback != PitchFeedback.noSignal;

        final Color  color;
        final String statusText;
        final String noteText;
        final String centsText;

        if (!active) {
          color      = _colorSilent;
          statusText = 'Listening…';
          noteText   = '';
          centsText  = '';
        } else {
          noteText  = pitch.fullName;
          centsText =
              '${pitch.cents >= 0 ? '+' : ''}${pitch.cents.toStringAsFixed(0)}¢';
          switch (pitch.feedback) {
            case PitchFeedback.correct:
              color      = _colorInTune;
              statusText = 'In Tune ✓';
              break;
            case PitchFeedback.tooHigh:
              color      = _colorOffTune;
              statusText = 'Too High ↑';
              break;
            case PitchFeedback.tooLow:
              color      = _colorOffTune;
              statusText = 'Too Low ↓';
              break;
            case PitchFeedback.noSignal:
              color      = _colorSilent;
              statusText = 'Listening…';
              break;
          }
        }

        // Plain Container — no AnimatedContainer (saves layout passes)
        return Container(
          color: color.withValues(alpha: 0.07),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                    color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              if (noteText.isNotEmpty) ...[
                Text(noteText,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Roboto')),
                const SizedBox(width: 8),
              ],
              Text(statusText,
                  style: TextStyle(
                      color:      color,
                      fontSize:   13,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Roboto')),
              const Spacer(),
              if (centsText.isNotEmpty)
                Text(centsText,
                    style: TextStyle(
                        color:     color.withValues(alpha: 0.75),
                        fontSize:  12,
                        fontFamily: 'Roboto')),
            ],
          ),
        );
      },
=======
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
>>>>>>> origin/yosef
    );
  }

  // ── Controls ───────────────────────────────────────────────────────────────

  // ── Controls ───────────────────────────────────────────────────────────────

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 36),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
<<<<<<< HEAD
          // ▶ / ❚❚  Play-pause
=======
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
>>>>>>> origin/yosef
          GestureDetector(
            onTap: _togglePlayPause,
            child: Container(
<<<<<<< HEAD
              width: 52, height: 52,
=======
              width:  60,
              height: 60,
>>>>>>> origin/yosef
              decoration: BoxDecoration(
                shape:  BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
<<<<<<< HEAD
              child: _pendingPlay
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
=======
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
>>>>>>> origin/yosef
                    )
                  : Icon(
                      _isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
<<<<<<< HEAD
                      color: Colors.white, size: 28),
=======
                      color: Colors.black,
                      size:  34,
                    ),
>>>>>>> origin/yosef
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
<<<<<<< HEAD
              width: 64, height: 64,
=======
              width:  52,
              height: 52,
>>>>>>> origin/yosef
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isRecording ? Colors.red[700] : Colors.red,
              ),
              child: Icon(
<<<<<<< HEAD
                _isRecording ? Icons.stop_rounded : Icons.mic,
                color: Colors.white, size: 30),
=======
                Icons.mic,
                color: _isRecording ? AppColors.white : Colors.red,
                size:  24,
              ),
>>>>>>> origin/yosef
            ),
          ),

          const SizedBox(width: 24),

          // ⬜  Finish → results
          GestureDetector(
            onTap: _finishAndShowResults,
            child: Container(
<<<<<<< HEAD
              width: 52, height: 52,
              decoration: BoxDecoration(
                color:        Colors.white,
                borderRadius: BorderRadius.circular(12),
=======
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
>>>>>>> origin/yosef
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

<<<<<<< HEAD
=======
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
>>>>>>> origin/yosef
