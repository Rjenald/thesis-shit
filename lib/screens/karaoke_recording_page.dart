import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../constants/app_colors.dart';
import '../core/audio_service.dart';
import '../core/note_utils.dart';
import '../models/session_result.dart';
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
  // ── Playback ───────────────────────────────────────────────────────────────
  bool _isPlaying   = false;
  bool _isRecording = false;

  // ── Position (ms) — drives the elapsed timer display ──────────────────────
  int   _posMs = 0;
  Timer? _posTimer;

  // ── Audio / pitch ──────────────────────────────────────────────────────────
  final AudioService _audioService = AudioService();
  StreamSubscription<NoteResult?>? _audioSub;
  NoteResult? _currentPitch;

  // ── Pitch history for the waveform strip (last 80 samples) ────────────────
  final List<double> _pitchHistory = [];
  static const int _maxPitchHistory = 80;

  // ── YouTube ────────────────────────────────────────────────────────────────
  YoutubePlayerController? _ytController;
  /// null = searching  |  '' = not found  |  videoId = ready
  String? _ytVideoId;
  bool _ytPositionActive = false;

  // ── Tuner colours ──────────────────────────────────────────────────────────
  static const _colorInTune  = Color(0xFF4CAF50);
  static const _colorOffTune = Color(0xFFF44336);
  static const _colorSilent  = Color(0xFF9E9E9E);

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
  // YouTube position listener — keeps the elapsed timer in sync
  // ══════════════════════════════════════════════════════════════════════════

  void _onYTUpdate() {
    if (!mounted || _ytController == null) return;
    final v = _ytController!.value;

    if (_isPlaying != v.isPlaying) {
      setState(() => _isPlaying = v.isPlaying);
    }

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
  // Play / pause
  // ══════════════════════════════════════════════════════════════════════════

  void _togglePlayPause() {
    final ytPlaying = _ytController?.value.isPlaying ?? false;

    if (ytPlaying) {
      _ytController?.pause();
      _posTimer?.cancel();
      _posTimer = null;
      setState(() => _isPlaying = false);
    } else {
      _ytController?.play();
      setState(() => _isPlaying = true);

      // Fallback timer — increments _posMs when YT position isn't firing yet.
      _posTimer ??= Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (!mounted || !_isPlaying) return;
        if (!_ytPositionActive) setState(() => _posMs += 100);
      });
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Microphone / recording
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
        _pitchHistory.add(result?.frequency ?? 0);
        if (_pitchHistory.length > _maxPitchHistory) {
          _pitchHistory.removeAt(0);
        }
        _currentPitch = result;
      });
    });

    setState(() => _isRecording = true);
  }

  Future<void> _stopRecording() async {
    await _audioSub?.cancel();
    _audioSub = null;
    await _audioService.stop();
    if (mounted) setState(() { _isRecording = false; _currentPitch = null; });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Finish
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
      lyricResults:    const [],
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
            _buildWaveform(),
            _buildVideoBox(),
            _buildSongInfoRow(),
            if (_isRecording) _buildTuner(_currentPitch),
            const Spacer(),
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

  // ── Waveform strip ─────────────────────────────────────────────────────────

  Widget _buildWaveform() {
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
              painter: _PitchGraphPainter(List<double>.from(_pitchHistory)),
            ),
          ),
        ),
      ),
    );
  }

  // ── YouTube video box ──────────────────────────────────────────────────────

  Widget _buildVideoBox() {
    Widget content;
    if (_ytVideoId == null) {
      content = _videoShell(child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.primaryCyan, strokeWidth: 2),
          SizedBox(height: 10),
          Text('Loading video…',
              style: TextStyle(color: Colors.white30, fontSize: 12)),
        ],
      ));
    } else if (_ytVideoId!.isEmpty || _ytController == null) {
      content = _videoShell(child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.play_circle_outline, color: Colors.white24, size: 48),
          SizedBox(height: 8),
          Text('No video found',
              style: TextStyle(color: Colors.white24, fontSize: 11)),
        ],
      ));
    } else {
      content = Padding(
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
    return content;
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
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

  // ══════════════════════════════════════════════════════════════════════════
  // Chromatic tuner — always shown while mic is active
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildTuner(NoteResult? pitch) {
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
      noteLabel = pitch.fullName; // e.g. "A4", "C#3"
    }

    final centsStr = hasSignal
        ? '${cents >= 0 ? '+' : ''}${cents.toStringAsFixed(0)}¢'
        : '';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color:        tunerColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: tunerColor.withValues(alpha: 0.30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── ♭  Note  ♯ row ──────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Flat indicator — lights up when voice is flat (cents < −10)
              Text('♭',
                  style: TextStyle(
                      color: (hasSignal && cents < -10)
                          ? tunerColor
                          : Colors.white12,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),

              // Note name + cents deviation
              Column(
                children: [
                  Text(
                    noteLabel,
                    style: TextStyle(
                        color: tunerColor,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Roboto',
                        letterSpacing: 1.5),
                  ),
                  if (centsStr.isNotEmpty)
                    Text(centsStr,
                        style: TextStyle(
                            color: tunerColor.withValues(alpha: 0.75),
                            fontSize: 12,
                            fontFamily: 'Roboto')),
                ],
              ),

              // Sharp indicator — lights up when voice is sharp (cents > +10)
              Text('♯',
                  style: TextStyle(
                      color: (hasSignal && cents > 10)
                          ? tunerColor
                          : Colors.white12,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
            ],
          ),

          const SizedBox(height: 10),

          // ── Needle meter ─────────────────────────────────────────────────
          _buildNeedle(cents, tunerColor, hasSignal),

          const SizedBox(height: 8),

          // ── Status text ──────────────────────────────────────────────────
          Text(
            statusLabel,
            style: TextStyle(
                color: tunerColor.withValues(alpha: 0.85),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFamily: 'Roboto',
                letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  // ── Needle meter: −50¢ ←── ●──→ +50¢ ────────────────────────────────────

  Widget _buildNeedle(double cents, Color color, bool active) {
    final fraction = active
        ? (cents.clamp(-50.0, 50.0) + 50.0) / 100.0
        : 0.5;

    return LayoutBuilder(builder: (_, c) {
      final w = c.maxWidth;
      final needleX = 8.0 + fraction * (w - 16.0);

      return SizedBox(
        height: 28,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Track gradient: red ── green ── red
            Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    _colorOffTune.withValues(alpha: 0.45),
                    _colorInTune.withValues(alpha: 0.55),
                    _colorOffTune.withValues(alpha: 0.45),
                  ]),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Centre tick
            Positioned(
              top: 6,
              left: w / 2 - 1,
              child: Container(width: 2, height: 16, color: Colors.white30),
            ),
            // ±25¢ ticks
            Positioned(
              top: 9,
              left: w * 0.25 - 1,
              child: Container(width: 1, height: 10, color: Colors.white12),
            ),
            Positioned(
              top: 9,
              left: w * 0.75 - 1,
              child: Container(width: 1, height: 10, color: Colors.white12),
            ),
            // Animated needle knob
            AnimatedPositioned(
              duration: const Duration(milliseconds: 80),
              curve:    Curves.easeOut,
              top: 4,
              left: (needleX - 10).clamp(0.0, w - 20),
              child: Container(
                width:  20,
                height: 20,
                decoration: BoxDecoration(
                  color:  active ? color : _colorSilent,
                  shape:  BoxShape.circle,
                  boxShadow: active
                      ? [BoxShadow(
                          color:     color.withValues(alpha: 0.55),
                          blurRadius: 8,
                        )]
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
          // ▶ / ❚❚  Play-pause
          GestureDetector(
            onTap: _togglePlayPause,
            child: Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                shape:  BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(
                  _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white, size: 28),
            ),
          ),

          const SizedBox(width: 24),

          // 🎤  Mic toggle (tap to start, tap again to stop)
          GestureDetector(
            onTap: () async {
              if (_isRecording) {
                await _stopRecording();
              } else {
                await _startRecording();
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 68, height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isRecording ? Colors.red[700] : Colors.red,
                boxShadow: _isRecording
                    ? [const BoxShadow(
                        color: Colors.red,
                        blurRadius: 18,
                        spreadRadius: 2,
                      )]
                    : [],
              ),
              child: Icon(
                  _isRecording ? Icons.mic_off : Icons.mic,
                  color: Colors.white, size: 30),
            ),
          ),

          const SizedBox(width: 24),

          // ⬜  Finish / stop
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
// Pitch waveform painter
// ══════════════════════════════════════════════════════════════════════════════

class _PitchGraphPainter extends CustomPainter {
  final List<double> data;
  const _PitchGraphPainter(this.data);

  double _hzToY(double hz, double h) {
    const minHz = 80.0;
    const maxHz = 1100.0;
    if (hz <= 0) return h;
    final logMin = math.log(minHz);
    final logMax = math.log(maxHz);
    return h - ((math.log(hz.clamp(minHz, maxHz)) - logMin) / (logMax - logMin)) * h;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Reference lines (C3, C4, C5)
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
    final pts = [
      for (int i = 0; i < count; i++) Offset(i * step, _hzToY(data[i], h)),
    ];

    if (pts.length > 1) {
      // Fill under curve
      final fill = Path()..moveTo(pts.first.dx, h);
      for (final p in pts) { fill.lineTo(p.dx, p.dy); }
      fill.lineTo(pts.last.dx, h);
      fill.close();
      canvas.drawPath(
        fill,
        Paint()
          ..shader = const LinearGradient(
            begin:  Alignment.topCenter,
            end:    Alignment.bottomCenter,
            colors: [Color(0x4000E0FF), Color(0x0000E0FF)],
          ).createShader(Rect.fromLTWH(0, 0, w, h)),
      );

      // Curve line
      final line = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (int i = 1; i < pts.length; i++) { line.lineTo(pts[i].dx, pts[i].dy); }
      canvas.drawPath(
        line,
        Paint()
          ..color       = AppColors.primaryCyan
          ..strokeWidth = 2.0
          ..strokeCap   = StrokeCap.round
          ..strokeJoin  = StrokeJoin.round
          ..style       = PaintingStyle.stroke,
      );
    }

    // Live dot
    if (pts.isNotEmpty && data.last > 0) {
      final p = pts.last;
      canvas.drawCircle(p, 6,
          Paint()..color = AppColors.primaryCyan.withValues(alpha: 0.22));
      canvas.drawCircle(p, 2.8, Paint()..color = AppColors.primaryCyan);
    }
  }

  @override
  bool shouldRepaint(_PitchGraphPainter old) =>
      old.data.length != data.length ||
      (data.isNotEmpty && old.data.isNotEmpty && old.data.last != data.last);
}
