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
      _posTimer ??= Timer.periodic(const Duration(milliseconds: 100), (_) {
          if (!mounted || !_isPlaying) return;
          // Only use the timer if YT is NOT driving position.
          if (!_ytPositionActive) {
            _syncToPosition(_posMs + 100);
          }
        });
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
            _buildVideoWithSubtitles(),
            _buildSongInfoRow(),
            if (_isRecording)
              _buildTuner(_currentPitch),
            const Spacer(),
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

  // ── Video + subtitle overlay ───────────────────────────────────────────────

  Widget _buildVideoWithSubtitles() {
    // Build the video layer
    Widget videoContent;
    if (_ytVideoId == null) {
      videoContent = _videoPlaceholder(child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.primaryCyan, strokeWidth: 2),
          SizedBox(height: 10),
          Text('Loading video…',
              style: TextStyle(color: Colors.white30, fontSize: 12)),
        ],
      ));
    } else if (_ytVideoId!.isEmpty || _ytController == null) {
      videoContent = _videoPlaceholder(child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.play_circle_outline, color: Colors.white24, size: 48),
          SizedBox(height: 8),
          Text('No video found',
              style: TextStyle(color: Colors.white24, fontSize: 11)),
        ],
      ));
    } else {
      videoContent = YoutubePlayer(
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
      );
    }

    // Subtitle text data
    final currentText = _currentLineIndex < _lyrics.length
        ? _lyrics[_currentLineIndex].text
        : '';
    final prevText = (_currentLineIndex > 0 &&
            _lyrics[_currentLineIndex - 1].text.isNotEmpty)
        ? _lyrics[_currentLineIndex - 1].text
        : null;
    final nextText = (_currentLineIndex + 1 < _lyrics.length &&
            _lyrics[_currentLineIndex + 1].text.isNotEmpty)
        ? _lyrics[_currentLineIndex + 1].text
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            videoContent,
            // Subtitle overlay — sits just above the YT progress bar
            if (!_lyricsLoading)
              Positioned(
                bottom: 34,
                left: 8,
                right: 8,
                child: _buildSubtitleOverlay(prevText, currentText, nextText),
              ),
          ],
        ),
      ),
    );
  }

  Widget _videoPlaceholder({required Widget child}) => AspectRatio(
    aspectRatio: 16 / 9,
    child: Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white12, width: 0.5),
      ),
      child: Center(child: child),
    ),
  );

  // ── Subtitle overlay ───────────────────────────────────────────────────────

  Widget _buildSubtitleOverlay(String? prev, String current, String? next) {
    final isGap = current.isEmpty;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (child, anim) =>
          FadeTransition(opacity: anim, child: child),
      child: Column(
        key: ValueKey(_currentLineIndex),
        mainAxisSize: MainAxisSize.min,
        children: [
          // Previous line — ghost
          if (prev != null)
            _subtitleText(prev, opacity: 0.45, fontSize: 13),

          // Current line — hero
          _subtitleText(
            isGap
                ? (_isPlaying ? '♪  Instrumental  ♪' : '')
                : current,
            opacity: isGap ? 0.55 : 1.0,
            fontSize: 17,
            bold: !isGap,
            italic: isGap,
          ),

          // Next line — preview
          if (next != null)
            _subtitleText(next, opacity: 0.45, fontSize: 13),
        ],
      ),
    );
  }

  Widget _subtitleText(
    String text, {
    double opacity = 1.0,
    double fontSize = 16,
    bool bold = false,
    bool italic = false,
  }) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withValues(alpha: opacity),
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          fontStyle: italic ? FontStyle.italic : FontStyle.normal,
          fontFamily: 'Roboto',
          shadows: const [
            Shadow(color: Colors.black87, blurRadius: 6, offset: Offset(0, 1)),
          ],
        ),
      ),
    );
  }

  // ── Song info row ──────────────────────────────────────────────────────────

  Widget _buildSongInfoRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
      child: Row(
        children: [
          const Icon(Icons.music_note, color: AppColors.primaryCyan, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              widget.songTitle,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Roboto'),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            widget.songArtist,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
                fontFamily: 'Roboto'),
            overflow: TextOverflow.ellipsis,
          ),
          if (_isRecording) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, color: Colors.red, size: 5),
                  SizedBox(width: 3),
                  Text('REC',
                      style: TextStyle(
                          color: Colors.red,
                          fontSize: 9,
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

  // ── Chromatic tuner widget ─────────────────────────────────────────────────
  // Shows like a real guitar/vocal tuner:
  //   • Full-width needle meter (−50¢ … 0 … +50¢)
  //   • Note name + octave in the centre
  //   • Colour: green = in-tune, red = sharp/flat, grey = no signal
  // Always visible while the mic is on so the singer never wonders if
  // their mic is working.

  Widget _buildTuner(NoteResult? pitch) {
    // Decide colour & status from pitch feedback
    final bool hasSignal = pitch != null &&
        pitch.feedback != PitchFeedback.noSignal &&
        pitch.frequency > 0;

    final Color tunerColor;
    final String noteLabel;
    final String statusLabel;
    final double cents;

    if (!hasSignal) {
      tunerColor  = _colorSilent;
      noteLabel   = '—';
      statusLabel = 'Listening…';
      cents       = 0.0;
    } else {
      cents = pitch.cents;
      switch (pitch.feedback) {
        case PitchFeedback.correct:
          tunerColor  = _colorInTune;
          statusLabel = 'In Tune ✓';
        case PitchFeedback.tooHigh:
          tunerColor  = _colorOffTune;
          statusLabel = 'Too High ↑';
        case PitchFeedback.tooLow:
          tunerColor  = _colorOffTune;
          statusLabel = 'Too Low ↓';
        case PitchFeedback.noSignal:
          tunerColor  = _colorSilent;
          statusLabel = 'Listening…';
      }
      noteLabel = pitch.fullName; // e.g. "A4"
    }

    final centsStr = hasSignal
        ? '${cents >= 0 ? '+' : ''}${cents.toStringAsFixed(0)}¢'
        : '';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      decoration: BoxDecoration(
        color:        tunerColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: tunerColor.withValues(alpha: 0.30), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Top row: ♭  note  cents  ♯ ─────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Flat indicator
              Text('♭',
                  style: TextStyle(
                      color: (!hasSignal || cents >= -10)
                          ? Colors.white12
                          : tunerColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),

              // Centre: note name + cents
              Column(
                children: [
                  Text(
                    noteLabel,
                    style: TextStyle(
                        color: tunerColor,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Roboto',
                        letterSpacing: 1),
                  ),
                  if (centsStr.isNotEmpty)
                    Text(centsStr,
                        style: TextStyle(
                            color: tunerColor.withValues(alpha: 0.7),
                            fontSize: 11,
                            fontFamily: 'Roboto')),
                ],
              ),

              // Sharp indicator
              Text('♯',
                  style: TextStyle(
                      color: (!hasSignal || cents <= 10)
                          ? Colors.white12
                          : tunerColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ],
          ),

          const SizedBox(height: 8),

          // ── Needle meter ────────────────────────────────────────────────
          _buildNeedle(cents, tunerColor, hasSignal),

          const SizedBox(height: 6),

          // ── Status label ────────────────────────────────────────────────
          Text(
            statusLabel,
            style: TextStyle(
                color: tunerColor.withValues(alpha: 0.80),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: 'Roboto',
                letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  /// Horizontal needle meter — range −50¢ (left) … 0 (centre) … +50¢ (right).
  Widget _buildNeedle(double cents, Color color, bool active) {
    // Map cents −50…+50 to fraction 0.0…1.0
    final fraction = active
        ? ((cents.clamp(-50.0, 50.0) + 50.0) / 100.0)
        : 0.5; // needle rests in the centre when silent

    return LayoutBuilder(builder: (_, constraints) {
      final w = constraints.maxWidth;
      // Needle position in pixels (leave 8px margin each side for the knob)
      final needleX = 8.0 + fraction * (w - 16.0);

      return SizedBox(
        height: 24,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // ── Track ──────────────────────────────────────────────────────
            Positioned(
              top: 10,
              left: 0,
              right: 0,
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _colorOffTune.withValues(alpha: 0.4),
                      _colorInTune.withValues(alpha: 0.5),
                      _colorOffTune.withValues(alpha: 0.4),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Centre mark ────────────────────────────────────────────────
            Positioned(
              top: 5,
              left: w / 2 - 1,
              child: Container(width: 2, height: 14, color: Colors.white24),
            ),

            // ── Tick marks (−25, +25) ──────────────────────────────────────
            Positioned(
              top: 8,
              left: w * 0.25 - 1,
              child: Container(width: 1, height: 8, color: Colors.white12),
            ),
            Positioned(
              top: 8,
              left: w * 0.75 - 1,
              child: Container(width: 1, height: 8, color: Colors.white12),
            ),

            // ── Animated needle knob ───────────────────────────────────────
            AnimatedPositioned(
              duration: const Duration(milliseconds: 80),
              curve:    Curves.easeOut,
              top: 2,
              left: needleX - 10,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color:  active ? color : _colorSilent,
                  shape:  BoxShape.circle,
                  boxShadow: active
                      ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6)]
                      : [],
                ),
              ),
            ),
          ],
        ),
      );
    });
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
