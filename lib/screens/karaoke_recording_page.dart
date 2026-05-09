import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../constants/app_colors.dart';
import '../core/audio_service.dart';
import '../core/note_utils.dart';
import '../data/lyrics.dart';
import '../models/session_result.dart';
import '../services/lrclib_service.dart';
import '../services/youtube_service.dart';
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

class _KaraokeRecordingPageState extends State<KaraokeRecordingPage> {
  // ── Playback state ─────────────────────────────────────────────────────────
  bool _isPlaying   = false;
  bool _isRecording = false;
  int  _currentLineIndex = 0;

  // ── Position tracking ──────────────────────────────────────────────────────
  // _posMs is the single source of truth for where we are in the song.
  // It is either read from the YouTube controller or driven by a 100ms fallback timer.
  int _posMs = 0;

  /// Fallback position timer: increments _posMs by 100ms when YT is not
  /// supplying position updates (video still loading / API failed).
  Timer? _posTimer;

  // ── Audio & pitch ──────────────────────────────────────────────────────────
  final AudioService _audioService = AudioService();
  StreamSubscription<NoteResult?>? _audioSub;
  NoteResult? _currentPitch;

  // ── Pitch graph history (last 80 samples) ─────────────────────────────────
  final List<double> _pitchHistory = [];
  static const int _maxPitchHistory = 80;

  // ── Per-line pitch accumulation ────────────────────────────────────────────
  late List<List<double>> _linePitch;
  late List<List<double>> _lineCents;

  final List<LyricPitchData> _completedLines = [];
  final List<int>            _lineTimestamps = [];

  // ── YouTube ────────────────────────────────────────────────────────────────
  YoutubePlayerController? _ytController;
  /// null = searching  |  '' = failed  |  videoId = ready
  String? _ytVideoId;
  /// True once the YT controller is firing position updates.
  bool _ytPositionActive = false;

  // ── Lyrics ─────────────────────────────────────────────────────────────────
  List<LyricLine> _lyrics       = const [];
  bool            _lyricsLoading = true;

  // ── Colour palette ─────────────────────────────────────────────────────────
  static const _colorInTune  = Color(0xFF4CAF50);
  static const _colorOffTune = Color(0xFFF44336);
  static const _colorSilent  = Color(0xFF9E9E9E);

  // ══════════════════════════════════════════════════════════════════════════
  // Lifecycle
  // ══════════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _linePitch = [];
    _lineCents = [];
    _loadLyrics();
    _loadYouTubeVideo();
  }

  @override
  void dispose() {
    _posTimer?.cancel();
    _audioSub?.cancel();
    _audioService.dispose();
    _ytController?.removeListener(_onYTUpdate);
    _ytController?.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Lyrics loader
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _loadLyrics() async {
    List<LyricLine>? fetched;
    try {
      fetched = await LrcLibService.fetchLyrics(
        title:  widget.songTitle,
        artist: widget.songArtist,
      );
    } catch (_) {}

    final raw = fetched ?? SongLyrics.forSong(widget.songTitle);

    // Give every line a position timestamp so the sync engine always works.
    // Real LRC timestamps are kept as-is; plain lyrics get virtual timestamps
    // derived from their durationSeconds.
    final lines = _assignTimestamps(raw);

    if (mounted) {
      setState(() {
        _lyrics        = lines;
        _linePitch     = List.generate(lines.length, (_) => []);
        _lineCents     = List.generate(lines.length, (_) => []);
        _lyricsLoading = false;
      });
    }
  }

  /// Ensures every LyricLine has a startMs.
  /// Lines that already have startMs > 0 (real LRC data) are kept unchanged.
  /// Lines with startMs == 0 get virtual timestamps by summing durations.
  static List<LyricLine> _assignTimestamps(List<LyricLine> raw) {
    final hasReal = raw.any((l) => l.startMs > 0);
    if (hasReal) return raw; // Already has real LRC timestamps — no change needed.

    // Plain lyrics: assign virtual timestamps from cumulative durations.
    final result = <LyricLine>[];
    int accMs = 0;
    for (final line in raw) {
      result.add(LyricLine(line.text, line.durationSeconds, startMs: accMs));
      accMs += line.durationSeconds * 1000;
    }
    return result;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // YouTube loader
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _loadYouTubeVideo() async {
    final videoId = await YouTubeService.searchVideoId(
      title:  widget.songTitle,
      artist: widget.songArtist,
    );
    if (!mounted) return;

    if (videoId != null && videoId.isNotEmpty) {
      final ctrl = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay:        false,
          mute:            false,
          disableDragSeek: false,
          hideControls:    false,
          enableCaption:   false,
        ),
      );
      ctrl.addListener(_onYTUpdate);
      setState(() {
        _ytVideoId    = videoId;
        _ytController = ctrl;
      });
    } else {
      setState(() => _ytVideoId = '');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Core sync engine — called from both YT listener and fallback timer
  // ══════════════════════════════════════════════════════════════════════════

  /// Advances lyrics to match [posMs].  Called by _onYTUpdate (primary) and
  /// _posTimer (fallback when video is loading or API failed).
  void _syncToPosition(int posMs) {
    if (!mounted || _lyrics.isEmpty) return;

    bool dirty = false;

    // Update position tracking.
    if (posMs != _posMs) {
      _posMs = posMs;
      dirty = true;
    }

    // Find which lyric line belongs to this position.
    int newLine = 0;
    for (int i = 0; i < _lyrics.length; i++) {
      if (_lyrics[i].startMs <= posMs) {
        newLine = i;
      } else {
        break;
      }
    }

    if (newLine > _currentLineIndex) {
      // Seal every line we advanced past.
      while (_currentLineIndex < newLine) {
        final i = _currentLineIndex;
        if (i < _lyrics.length && _completedLines.length == i) {
          _completedLines.add(LyricPitchData(
            lyricText:     _lyrics[i].text,
            pitchReadings: List<double>.from(
                i < _linePitch.length ? _linePitch[i] : const []),
            centsReadings: List<double>.from(
                i < _lineCents.length ? _lineCents[i] : const []),
          ));
          _lineTimestamps.add(_lyrics[i].startMs ~/ 1000);
          if (i < _linePitch.length) { _linePitch[i].clear(); }
          if (i < _lineCents.length) { _lineCents[i].clear(); }
        }
        _currentLineIndex++;
      }
      dirty = true;
    } else if (newLine < _currentLineIndex) {
      // User seeked backward — roll back.
      _currentLineIndex = newLine;
      while (_completedLines.length > newLine) { _completedLines.removeLast(); }
      while (_lineTimestamps.length > newLine) { _lineTimestamps.removeLast(); }
      dirty = true;
    }

    if (dirty && mounted) setState(() {});
  }

  // ══════════════════════════════════════════════════════════════════════════
  // YouTube position listener
  // ══════════════════════════════════════════════════════════════════════════

  void _onYTUpdate() {
    if (!mounted || _ytController == null) return;
    final v = _ytController!.value;

    // Sync play state so our ▶/❚❚ icon tracks the video's actual state.
    if (_isPlaying != v.isPlaying) {
      setState(() => _isPlaying = v.isPlaying);
    }

    // Once the YT controller starts delivering real position data, cancel the
    // fallback timer so we don't double-advance.
    if (v.isPlaying && !_ytPositionActive) {
      _ytPositionActive = true;
      _posTimer?.cancel();
      _posTimer = null;
    }

    // Drive lyric sync from the video's real position.
    if (v.isPlaying || v.position.inMilliseconds > 0) {
      _syncToPosition(v.position.inMilliseconds);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Play / pause
  // ══════════════════════════════════════════════════════════════════════════

  void _togglePlayPause() {
    final ytPlaying = _ytController?.value.isPlaying ?? false;

    if (ytPlaying) {
      // ── Pause ───────────────────────────────────────────────────────────
      _ytController?.pause();
      _posTimer?.cancel();
      _posTimer = null;
      setState(() => _isPlaying = false);
    } else {
      // ── Play ────────────────────────────────────────────────────────────
      _ytController?.play();
      setState(() => _isPlaying = true);

      // Start a 100ms fallback timer.  It drives lyrics while the video is
      // buffering or if the YT API failed completely.  _onYTUpdate() cancels
      // it as soon as real position data starts arriving.
      if (_posTimer == null) {
        _posTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
          if (!mounted || !_isPlaying) return;
          // Only use the timer if YT is NOT driving position.
          if (!_ytPositionActive) {
            _syncToPosition(_posMs + 100);
          }
        });
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Recording toggle
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _startRecording() async {
    final ok = await _audioService.start();
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied')),
        );
      }
      return;
    }

    _audioSub = _audioService.results.listen((result) {
      if (!mounted) return;
      final i = _currentLineIndex;
      if (i < _linePitch.length) {
        _linePitch[i].add(result?.frequency ?? 0);
        _lineCents[i].add(result?.cents ?? 0);
      }
      setState(() {
        _pitchHistory.add(result?.frequency ?? 0);
        if (_pitchHistory.length > _maxPitchHistory) { _pitchHistory.removeAt(0); }
        _currentPitch = result;
      });
    });
  }

  Future<void> _stopRecording() async {
    await _audioSub?.cancel();
    _audioSub = null;
    await _audioService.stop();
    if (mounted) setState(() => _currentPitch = null);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Stop & go to results
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _stopAll() async {
    _posTimer?.cancel();
    _posTimer = null;
    _ytController?.pause();
    if (_isRecording) await _stopRecording();
    if (mounted) setState(() { _isPlaying = false; _isRecording = false; });
  }

  void _sealCurrentLine() {
    final i = _currentLineIndex;
    if (i >= _lyrics.length || _completedLines.length != i) return;
    _completedLines.add(LyricPitchData(
      lyricText:     _lyrics[i].text,
      pitchReadings: List<double>.from(_linePitch[i]),
      centsReadings: List<double>.from(_lineCents[i]),
    ));
    _lineTimestamps.add(_posMs ~/ 1000);
    _linePitch[i].clear();
    _lineCents[i].clear();
  }

  Future<void> _finishAndShowResults() async {
    await _stopAll();
    _sealCurrentLine();

    for (int i = _completedLines.length; i < _lyrics.length; i++) {
      _completedLines.add(LyricPitchData(
        lyricText:     _lyrics[i].text,
        pitchReadings: const [],
        centsReadings: const [],
      ));
    }

    final session = SessionResult(
      songTitle:       widget.songTitle,
      songArtist:      widget.songArtist,
      songImage:       widget.songImage,
      completedAt:     DateTime.now(),
      lyricResults:    List<LyricPitchData>.from(_completedLines),
      durationSeconds: _posMs ~/ 1000,
    );

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => ResultsPage(session: session)),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Build
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildWaveformBox(),
            _buildVideoBox(),
            _buildSongInfoRow(),
            Expanded(child: _buildLyricsArea()),
            _buildControls(),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final elapsedSec = _posMs ~/ 1000;
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
          if (_isPlaying || _isRecording)
            Text(
              '${(elapsedSec ~/ 60).toString().padLeft(2, '0')}:'
              '${(elapsedSec % 60).toString().padLeft(2, '0')}',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 12,
                  fontFamily: 'Roboto',
                  letterSpacing: 1),
            ),
          const SizedBox(width: 8),
          const Icon(Icons.more_horiz, color: Colors.white, size: 22),
        ],
      ),
    );
  }

  // ── Waveform strip ─────────────────────────────────────────────────────────

  Widget _buildWaveformBox() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: SizedBox(
        height: 52,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(4),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: CustomPaint(
              painter: _KaraokePitchGraphPainter(List<double>.from(_pitchHistory)),
            ),
          ),
        ),
      ),
    );
  }

  // ── YouTube video box ──────────────────────────────────────────────────────

  Widget _buildVideoBox() {
    if (_ytVideoId == null) {
      return _videoShell(child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.primaryCyan, strokeWidth: 2),
          SizedBox(height: 10),
          Text('Loading video…',
              style: TextStyle(color: Colors.white30, fontSize: 12)),
        ],
      ));
    }

    if (_ytVideoId!.isEmpty || _ytController == null) {
      return _videoShell(child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.play_circle_outline, color: Colors.white24, size: 48),
          SizedBox(height: 8),
          Text('No video found',
              style: TextStyle(color: Colors.white24, fontSize: 11)),
        ],
      ));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: YoutubePlayer(
          controller: _ytController!,
          showVideoProgressIndicator: true,
          progressIndicatorColor: Colors.red,
          progressColors: const ProgressBarColors(
            playedColor:     Colors.red,
            handleColor:     Colors.redAccent,
            bufferedColor:   Colors.white24,
            backgroundColor: Colors.white12,
          ),
          topActions: const [],
          bottomActions: const [
            CurrentPosition(),
            ProgressBar(isExpanded: true),
            RemainingDuration(),
          ],
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
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white12, width: 0.5),
        ),
        child: Center(child: child),
      ),
    ),
  );

  // ── Song info row ──────────────────────────────────────────────────────────

  Widget _buildSongInfoRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Title: ${widget.songTitle}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Roboto'),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            'Artist: ${widget.songArtist}',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
                fontFamily: 'Roboto'),
          ),
          if (_isRecording) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, color: Colors.red, size: 6),
                  SizedBox(width: 4),
                  Text('REC',
                      style: TextStyle(
                          color: Colors.red,
                          fontSize: 10,
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

  // ── Lyrics area ────────────────────────────────────────────────────────────

  Widget _buildLyricsArea() {
    if (_lyricsLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
                color: AppColors.primaryCyan, strokeWidth: 2),
            const SizedBox(height: 16),
            Text('Loading lyrics…',
                style: TextStyle(
                    color: AppColors.grey.withValues(alpha: 0.6),
                    fontSize: 13,
                    fontFamily: 'Roboto')),
          ],
        ),
      );
    }

    const colStyle = TextStyle(
      color: Colors.white38,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      fontFamily: 'Roboto',
      letterSpacing: 0.4,
    );

    final currentText = _currentLineIndex < _lyrics.length
        ? _lyrics[_currentLineIndex].text
        : '';
    final isGap = currentText.isEmpty;

    return Column(
      children: [
        // ── Active lyric line ──────────────────────────────────────────────
        Container(
          width: double.infinity,
          color: const Color(0xFF111111),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: isGap
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.music_note,
                        color: Colors.white24, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      _isPlaying
                          ? '♪  Intro / Instrumental  ♪'
                          : 'Press ▶ to start',
                      style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 15,
                          fontStyle: FontStyle.italic,
                          fontFamily: 'Roboto'),
                    ),
                  ],
                )
              : Text(
                  currentText,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Roboto'),
                  textAlign: TextAlign.center,
                ),
        ),

        // ── Live pitch bar ─────────────────────────────────────────────────
        if (_isRecording && !isGap && _currentPitch != null)
          _buildPitchBar(_currentPitch!),

        // ── Table header ───────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: const [
              SizedBox(width: 28, child: Text('#',         style: colStyle)),
              SizedBox(width: 56, child: Text('Time',      style: colStyle)),
              Expanded(           child: Text('Pitch',     style: colStyle)),
              SizedBox(width: 80,
                  child: Text('Direction', style: colStyle,
                      textAlign: TextAlign.right)),
            ],
          ),
        ),
        const Divider(color: Colors.white10, height: 1),

        // ── Completed lines ────────────────────────────────────────────────
        Expanded(
          child: _completedLines.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.mic_none, color: Colors.white24, size: 36),
                      const SizedBox(height: 8),
                      Text(
                        _isPlaying
                            ? 'Sing along — results appear here'
                            : 'Press ▶ to start',
                        style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 13,
                            fontFamily: 'Roboto'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 4),
                  itemCount: _completedLines.length,
                  itemBuilder: (_, i) => _buildLiveRow(
                    i + 1,
                    i < _lineTimestamps.length ? _lineTimestamps[i] : 0,
                    _completedLines[i],
                  ),
                ),
        ),
      ],
    );
  }

  // ── Real-time pitch bar ────────────────────────────────────────────────────

  Widget _buildPitchBar(NoteResult pitch) {
    Color    barColor;
    String   statusLabel;
    IconData icon;

    switch (pitch.feedback) {
      case PitchFeedback.correct:
        barColor = _colorInTune;  statusLabel = 'In Tune';    icon = Icons.check_circle_outline; break;
      case PitchFeedback.tooHigh:
        barColor = _colorOffTune; statusLabel = 'Too High ↑'; icon = Icons.arrow_upward;         break;
      case PitchFeedback.tooLow:
        barColor = _colorOffTune; statusLabel = 'Too Low ↓';  icon = Icons.arrow_downward;       break;
      case PitchFeedback.noSignal:
        barColor = _colorSilent;  statusLabel = 'No Signal';  icon = Icons.mic_off;              break;
    }

    final centsStr =
        '${pitch.cents >= 0 ? '+' : ''}${pitch.cents.toStringAsFixed(0)}¢';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color:        barColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: barColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: barColor, size: 15),
          const SizedBox(width: 8),
          Text(pitch.fullName,
              style: TextStyle(
                  color: barColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Roboto')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Container(
                width: 1, height: 18, color: barColor.withValues(alpha: 0.3)),
          ),
          Text(statusLabel,
              style: TextStyle(
                  color: barColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Roboto')),
          const SizedBox(width: 10),
          Text(centsStr,
              style: TextStyle(
                  color: barColor.withValues(alpha: 0.65),
                  fontSize: 11,
                  fontFamily: 'Roboto')),
          const SizedBox(width: 10),
          _buildCentsMeter(pitch.cents, barColor),
        ],
      ),
    );
  }

  Widget _buildCentsMeter(double cents, Color color) {
    final fraction = (cents.clamp(-50.0, 50.0) + 50.0) / 100.0;
    return SizedBox(
      width: 60,
      height: 10,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Center(child: Container(width: 1, height: 10, color: Colors.white24)),
          Positioned(
            left: (fraction * 57).clamp(0.0, 54.0),
            child: Container(
              width: 6,
              height: 10,
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(3)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Completed-line row ─────────────────────────────────────────────────────

  Widget _buildLiveRow(int num, int seconds, LyricPitchData line) {
    final m  = seconds ~/ 60;
    final s  = seconds % 60;
    final ts = '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

    String pitch, direction;
    Color  color;
    switch (line.status) {
      case LineStatus.correct:
        pitch = 'In Tune';   direction = '—';        color = _colorInTune;  break;
      case LineStatus.flat:
        pitch = 'Flat';      direction = 'Too Low';  color = _colorOffTune; break;
      case LineStatus.sharp:
        pitch = 'Sharp';     direction = 'Too High'; color = _colorOffTune; break;
      case LineStatus.noSignal:
        pitch = 'No Signal'; direction = '—';        color = _colorSilent;  break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text('$num.',
                style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                    fontFamily: 'Roboto')),
          ),
          SizedBox(
            width: 56,
            child: Text(ts,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Roboto')),
          ),
          Expanded(
            child: Text(pitch,
                style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Roboto')),
          ),
          SizedBox(
            width: 80,
            child: Text(direction,
                textAlign: TextAlign.right,
                style: TextStyle(
                    color: color.withValues(alpha: 0.75),
                    fontSize: 13,
                    fontFamily: 'Roboto')),
          ),
        ],
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
          // ▶ / ❚❚
          GestureDetector(
            onTap: _lyricsLoading ? null : _togglePlayPause,
            child: Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: _lyricsLoading ? Colors.white24 : Colors.white,
                    width: 2),
              ),
              child: _lyricsLoading
                  ? const Center(
                      child: SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            color: AppColors.primaryCyan, strokeWidth: 2),
                      ))
                  : Icon(
                      _isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white, size: 28),
            ),
          ),

          const SizedBox(width: 24),

          // 🔴 Mic
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
              width: 64, height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isRecording ? Colors.red[700] : Colors.red,
              ),
              child: Icon(
                  _isRecording ? Icons.stop_rounded : Icons.mic,
                  color: Colors.white, size: 30),
            ),
          ),

          const SizedBox(width: 24),

          // ⬜ Finish
          GestureDetector(
            onTap: _finishAndShowResults,
            child: Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.stop_rounded, color: Colors.black, size: 28),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Pitch graph painter
// ══════════════════════════════════════════════════════════════════════════════

class _KaraokePitchGraphPainter extends CustomPainter {
  final List<double> data;
  const _KaraokePitchGraphPainter(this.data);

  double _hzToY(double hz, double h) {
    const minHz = 80.0;
    const maxHz = 1100.0;
    if (hz <= 0) return h;
    final logMin = math.log(minHz);
    final logMax = math.log(maxHz);
    return h -
        ((math.log(hz.clamp(minHz, maxHz)) - logMin) / (logMax - logMin)) * h;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final refPaint = Paint()
      ..color       = Colors.white.withValues(alpha: 0.07)
      ..strokeWidth = 1;
    for (final hz in [130.81, 261.63, 523.25]) {
      final y = _hzToY(hz, h);
      canvas.drawLine(Offset(0, y), Offset(w, y), refPaint);
    }

    if (data.isEmpty) return;

    final count = data.length;
    final step  = count > 1 ? w / (count - 1) : w;
    final pts   = [
      for (int i = 0; i < count; i++) Offset(i * step, _hzToY(data[i], h)),
    ];

    if (pts.length > 1) {
      final fillPath = Path()..moveTo(pts.first.dx, h);
      for (final p in pts) { fillPath.lineTo(p.dx, p.dy); }
      fillPath.lineTo(pts.last.dx, h);
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

      final linePath = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (int i = 1; i < pts.length; i++) { linePath.lineTo(pts[i].dx, pts[i].dy); }
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

    if (pts.isNotEmpty && data.last > 0) {
      final last = pts.last;
      canvas.drawCircle(last, 6,
          Paint()..color = AppColors.primaryCyan.withValues(alpha: 0.22));
      canvas.drawCircle(last, 2.8, Paint()..color = AppColors.primaryCyan);
    }
  }

  @override
  bool shouldRepaint(_KaraokePitchGraphPainter old) =>
      old.data.length != data.length ||
      (data.isNotEmpty && old.data.isNotEmpty && old.data.last != data.last);
}
