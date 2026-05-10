import 'dart:async';
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../constants/app_colors.dart';
import '../core/audio_service.dart';
import '../core/note_utils.dart';
import '../models/session_result.dart';
import '../services/youtube_service.dart';
import 'results_page.dart';

// ── Number of segments the pitch history is bucketed into for the results ──────
const int _kResultSegments = 30;

class KaraokeRecordingPage extends StatefulWidget {
  final String songTitle;
  final String songArtist;
  final String songImage;

  /// When true the results page shows [Try Again | Submit] instead of
  /// [Try Again | Listen | Save].
  final bool isAssignment;

  const KaraokeRecordingPage({
    super.key,
    this.songTitle  = 'Dadalhin',
    this.songArtist = 'Regine Velasquez',
    this.songImage  = '',
    this.isAssignment = false,
  });

  @override
  State<KaraokeRecordingPage> createState() => _KaraokeRecordingPageState();
}

class _KaraokeRecordingPageState extends State<KaraokeRecordingPage> {
  // ── Playback ───────────────────────────────────────────────────────────────
  bool _isPlaying    = false;
  bool _isRecording  = false;
  /// True when the user pressed play before the video finished loading.
  /// The button shows a spinner and playback starts automatically once ready.
  bool _pendingPlay  = false;

  // ── Position (ms) ─────────────────────────────────────────────────────────
  int    _posMs = 0;
  Timer? _posTimer;

  // ── Audio / pitch ──────────────────────────────────────────────────────────
  final AudioService             _audioService = AudioService();
  StreamSubscription<NoteResult?>? _audioSub;
  NoteResult? _currentPitch;

  // ── Pitch sample history (accumulated over the whole recording session) ────
  // One entry per audio callback; Hz = 0 means silence / no signal.
  final List<double> _rawHz    = [];
  final List<double> _rawCents = [];

  // ── YouTube ────────────────────────────────────────────────────────────────
  YoutubePlayerController? _ytController;
  String? _ytVideoId;       // null = searching | '' = not found | id = ready
  bool    _ytPositionActive = false;

  // ── Pitch colours ──────────────────────────────────────────────────────────
  static const _colorInTune  = Color(0xFF4CAF50);
  static const _colorOffTune = Color(0xFFF44336);
  static const _colorSilent  = Color(0xFF757575);

  // ══════════════════════════════════════════════════════════════════════════
  // Lifecycle
  // ══════════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
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
  // YouTube
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
        flags: YoutubePlayerFlags(
          autoPlay:        _pendingPlay, // honour queued play request
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
        if (_pendingPlay) {
          _isPlaying   = true;
          _pendingPlay = false;
        }
      });
    } else {
      setState(() {
        _ytVideoId   = '';
        _pendingPlay = false;
      });
    }
  }

  void _onYTUpdate() {
    if (!mounted || _ytController == null) return;
    final v = _ytController!.value;

    if (_isPlaying != v.isPlaying) setState(() => _isPlaying = v.isPlaying);

    if (v.isPlaying && !_ytPositionActive) {
      _ytPositionActive = true;
      _posTimer?.cancel();
      _posTimer = null;
    }

    if (v.isPlaying || v.position.inMilliseconds > 0) {
      final posMs = v.position.inMilliseconds;
      if (posMs != _posMs) setState(() => _posMs = posMs);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Play / pause  —  video only; mic is independent
  // ══════════════════════════════════════════════════════════════════════════

  void _togglePlayPause() {
    // ── Video not loaded yet — queue the play request ──────────────────────
    if (_ytController == null) {
      setState(() => _pendingPlay = !_pendingPlay);
      return;
    }

    // ── Video ready ────────────────────────────────────────────────────────
    final ytPlaying = _ytController!.value.isPlaying;
    if (ytPlaying) {
      _ytController!.pause();
      _posTimer?.cancel();
      _posTimer = null;
      setState(() => _isPlaying = false);
    } else {
      _ytController!.play();
      setState(() => _isPlaying = true);
      _posTimer ??= Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (!mounted || !_isPlaying) return;
        if (!_ytPositionActive) setState(() => _posMs += 100);
      });
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Microphone — toggling mic NEVER touches the video
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
      setState(() {
        _currentPitch = result;
        // Accumulate pitch samples for the live heatmap + results
        _rawHz   .add(result?.frequency ?? 0);
        _rawCents.add(result?.cents     ?? 0);
      });
    });

    setState(() => _isRecording = true);
  }

  Future<void> _stopRecording() async {
    await _audioSub?.cancel();
    _audioSub = null;
    await _audioService.stop();
    // Keep _rawHz / _rawCents — accumulated data is preserved across
    // start/stop cycles so the full session heatmap is accurate.
    if (mounted) setState(() { _isRecording = false; _currentPitch = null; });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Finish — build results and navigate
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _finishAndShowResults() async {
    _posTimer?.cancel();
    _posTimer = null;
    _ytController?.pause();
    if (_isRecording) await _stopRecording();

    final session = SessionResult(
      songTitle:       widget.songTitle,
      songArtist:      widget.songArtist,
      songImage:       widget.songImage,
      completedAt:     DateTime.now(),
      lyricResults:    _buildLyricResults(),
      durationSeconds: _posMs ~/ 1000,
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

  /// Buckets all raw pitch samples into [_kResultSegments] LyricPitchData
  /// entries so the results heatmap & table reflect real performance.
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
        lyricText:     'seg${i + 1}',            // non-empty → visible in heatmap
        pitchReadings: _rawHz   .sublist(start, end),
        centsReadings: _rawCents.sublist(start, end),
      );
    }).whereType<LyricPitchData>().toList();
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
            _buildSongInfoRow(),
            // Video takes all remaining space minus controls
            Expanded(child: _buildVideoBox()),
            // Live pitch status shown while recording
            if (_isRecording) _buildLivePitchRow(),
            _buildControls(),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final s = _posMs ~/ 1000;
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
              '${(s ~/ 60).toString().padLeft(2, '0')}:'
              '${(s % 60).toString().padLeft(2, '0')}',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 12,
                  fontFamily: 'Roboto',
                  letterSpacing: 1.2),
            ),
          const SizedBox(width: 8),
          const Icon(Icons.more_horiz, color: Colors.white, size: 22),
        ],
      ),
    );
  }

  // ── Song info row ──────────────────────────────────────────────────────────

  Widget _buildSongInfoRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
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

  // ── Video with live heatmap overlay ───────────────────────────────────────

  Widget _buildVideoBox() {
    if (_ytVideoId == null) {
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

    if (_ytVideoId!.isEmpty || _ytController == null) {
      return _videoShell(
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_circle_outline, color: Colors.white24, size: 48),
            SizedBox(height: 8),
            Text('No video found',
                style: TextStyle(color: Colors.white24, fontSize: 11)),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(
          children: [
            // ── YouTube player ─────────────────────────────────────────
            YoutubePlayer(
              controller: _ytController!,
              showVideoProgressIndicator: true,
              progressIndicatorColor: Colors.red,
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

            // ── Live heatmap strip — overlaid at top of video ──────────
            if (_rawHz.isNotEmpty)
              Positioned(
                top:   0,
                left:  0,
                right: 0,
                child: SizedBox(
                  height: 12,
                  child: CustomPaint(
                    painter: _LiveHeatmapPainter(
                      rawHz:    List<double>.from(_rawHz),
                      rawCents: List<double>.from(_rawCents),
                    ),
                    size: Size.infinite,
                  ),
                ),
              ),

            // ── Current note badge — bottom-right of video while mic on ─
            if (_isRecording && _currentPitch != null)
              Positioned(
                bottom: 36, // above progress bar
                right:  10,
                child: _buildNoteBadge(_currentPitch!),
              ),
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
              color:         const Color(0xFF1A1A1A),
              borderRadius:  BorderRadius.circular(6),
              border:        Border.all(color: Colors.white12, width: 0.5),
            ),
            child: Center(child: child),
          ),
        ),
      );

  // ── Note badge (shown on video while mic active) ──────────────────────────

  Widget _buildNoteBadge(NoteResult pitch) {
    final bool active = pitch.frequency > 0 &&
        pitch.feedback != PitchFeedback.noSignal;

    final Color color;
    final String label;
    if (!active) {
      color = _colorSilent;
      label = '•••';
    } else {
      switch (pitch.feedback) {
        case PitchFeedback.correct:
          color = _colorInTune;
          label = pitch.fullName;
          break;
        case PitchFeedback.tooHigh:
          color = _colorOffTune;
          label = '${pitch.fullName} ↑';
          break;
        case PitchFeedback.tooLow:
          color = _colorOffTune;
          label = '${pitch.fullName} ↓';
          break;
        case PitchFeedback.noSignal:
          color = _colorSilent;
          label = '•••';
          break;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color:        Colors.black.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(8),
        border:       Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            fontFamily: 'Roboto',
            letterSpacing: 0.5),
      ),
    );
  }

  // ── Live pitch status row (below video while recording) ───────────────────

  Widget _buildLivePitchRow() {
    final pitch = _currentPitch;
    final bool active = pitch != null &&
        pitch.frequency > 0 &&
        pitch.feedback != PitchFeedback.noSignal;

    final Color color;
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
      centsText = '${pitch.cents >= 0 ? '+' : ''}${pitch.cents.toStringAsFixed(0)}¢';
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

    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      color: color.withValues(alpha: 0.07),
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Roboto')),
          const Spacer(),
          if (centsText.isNotEmpty)
            Text(centsText,
                style: TextStyle(
                    color: color.withValues(alpha: 0.75),
                    fontSize: 12,
                    fontFamily: 'Roboto')),
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
          // ▶ / ❚❚  Play-pause (video only)
          GestureDetector(
            onTap: _togglePlayPause,
            child: Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                shape:  BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: _pendingPlay
                  // Queued-play spinner — video is still loading
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(
                      _isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white, size: 28,
                    ),
            ),
          ),

          const SizedBox(width: 24),

          // 🔴  Mic toggle — video keeps playing
          GestureDetector(
            onTap: () async {
              if (_isRecording) {
                await _stopRecording();
              } else {
                await _startRecording();
              }
            },
            child: Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isRecording ? Colors.red[700] : Colors.red,
              ),
              child: Icon(
                _isRecording ? Icons.stop_rounded : Icons.mic,
                color: Colors.white, size: 30,
              ),
            ),
          ),

          const SizedBox(width: 24),

          // ⬜  Finish → navigate to results
          GestureDetector(
            onTap: _finishAndShowResults,
            child: Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color:         Colors.white,
                borderRadius:  BorderRadius.circular(12),
              ),
              child: const Icon(Icons.stop_rounded, color: Colors.black, size: 28),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Live heatmap painter
//
// Renders a horizontal color strip where each sample is coloured:
//   green  = in tune  (|cents| ≤ 25)
//   red    = off tune (|cents| > 25)
//   grey   = silence  (hz == 0)
// ══════════════════════════════════════════════════════════════════════════════

class _LiveHeatmapPainter extends CustomPainter {
  final List<double> rawHz;
  final List<double> rawCents;

  const _LiveHeatmapPainter({required this.rawHz, required this.rawCents});

  static const _inTune  = Color(0xFF4CAF50);
  static const _offTune = Color(0xFFF44336);
  static const _silent  = Color(0xFF616161);

  Color _colorFor(int i) {
    final hz    = rawHz[i];
    final cents = rawCents[i];
    if (hz <= 0) return _silent;
    return cents.abs() <= 25 ? _inTune : _offTune;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (rawHz.isEmpty) return;
    final n    = rawHz.length;
    final segW = size.width / n;
    for (int i = 0; i < n; i++) {
      canvas.drawRect(
        Rect.fromLTWH(i * segW, 0, segW - 0.3, size.height),
        Paint()..color = _colorFor(i),
      );
    }
  }

  @override
  bool shouldRepaint(_LiveHeatmapPainter old) =>
      old.rawHz.length != rawHz.length;
}
