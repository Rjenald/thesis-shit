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

class _KaraokeRecordingPageState extends State<KaraokeRecordingPage>
    with SingleTickerProviderStateMixin {
  // ── Playback state ─────────────────────────────────────────────────────────
  bool _isPlaying = false;
  bool _isRecording = false;
  int _currentLineIndex = 0;
  Timer? _lyricTimer;

  // ── Session timer ──────────────────────────────────────────────────────────
  int _elapsedSeconds = 0;
  Timer? _sessionTimer;

  // ── Audio & pitch ──────────────────────────────────────────────────────────
  final AudioService _audioService = AudioService();
  StreamSubscription<NoteResult?>? _audioSub;

  // ── Real-time pitch graph history (last 80 readings) ─────────────────────
  final List<double> _pitchHistory = [];
  static const int _maxPitchHistory = 80;

  // ── Per-line pitch accumulation ────────────────────────────────────────────
  // Index mirrors _lyrics; each sub-list grows as readings arrive.
  late List<List<double>> _linePitch;
  late List<List<double>> _lineCents;

  // Finalised lyric data (in order, built as lines are completed).
  final List<LyricPitchData> _completedLines = [];
  // Elapsed-second timestamp captured when each line was sealed.
  final List<int> _lineTimestamps = [];

  // ── YouTube video ──────────────────────────────────────────────────────────
  YoutubePlayerController? _ytController;

  /// null = still loading  |  '' = search failed  |  'abc123' = loaded OK
  String? _ytVideoId;

  // ── Lyrics (loaded async from backend / LrcLib, fallback to local DB) ──────
  List<LyricLine> _lyrics = const [];
  bool _lyricsLoading = true;

  @override
  void initState() {
    super.initState();
    _linePitch = [];
    _lineCents = [];
    _loadLyrics();
    _loadYouTubeVideo();
  }

  // ── YouTube loader ─────────────────────────────────────────────────────────

  Future<void> _loadYouTubeVideo() async {
    final videoId = await YouTubeService.searchVideoId(
      title: widget.songTitle,
      artist: widget.songArtist,
    );
    if (!mounted) return;
    if (videoId != null && videoId.isNotEmpty) {
      final ctrl = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: false,
          mute: false,
          disableDragSeek: false,
          hideControls: false,
          enableCaption: false,
        ),
      );
      setState(() {
        _ytVideoId = videoId;
        _ytController = ctrl;
      });
    } else {
      // API key not set or search failed — show placeholder
      setState(() => _ytVideoId = '');
    }
  }

  Future<void> _loadLyrics() async {
    // Try external lyrics API (LrcLib / lyrics.ovh)
    List<LyricLine>? fetched;
    try {
      fetched = await LrcLibService.fetchLyrics(
        title: widget.songTitle,
        artist: widget.songArtist,
      );
    } catch (_) {}

    final lines = fetched ?? SongLyrics.forSong(widget.songTitle);

    if (mounted) {
      setState(() {
        _lyrics = lines;
        _linePitch = List.generate(lines.length, (_) => []);
        _lineCents = List.generate(lines.length, (_) => []);
        _lyricsLoading = false;
      });
    }
  }

  // ── Lyric advancement ──────────────────────────────────────────────────────

  void _startLyrics() {
    _advanceLine();
  }

  void _advanceLine() {
    if (!mounted || _currentLineIndex >= _lyrics.length) return;
    final line = _lyrics[_currentLineIndex];

    _lyricTimer = Timer(Duration(seconds: line.durationSeconds), () {
      if (!mounted) return;
      _sealCurrentLine();
      setState(() {
        if (_currentLineIndex < _lyrics.length - 1) {
          _currentLineIndex++;
        }
      });
      _advanceLine();
    });
  }

  /// Lock in the pitch data for the current lyric line and record its timestamp.
  void _sealCurrentLine() {
    final i = _currentLineIndex;
    if (i >= _lyrics.length) return;
    _completedLines.add(
      LyricPitchData(
        lyricText: _lyrics[i].text,
        pitchReadings: List<double>.from(_linePitch[i]),
        centsReadings: List<double>.from(_lineCents[i]),
      ),
    );
    _lineTimestamps.add(_elapsedSeconds);
    _linePitch[i].clear();
    _lineCents[i].clear();
  }

  void _pauseLyrics() => _lyricTimer?.cancel();

  // ── Recording toggle ───────────────────────────────────────────────────────

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
        if (result != null) {
          _linePitch[i].add(result.frequency);
          _lineCents[i].add(result.cents);
        } else {
          _linePitch[i].add(0);
          _lineCents[i].add(0);
        }
      }
      setState(() {
        // Update real-time pitch graph history
        _pitchHistory.add(result?.frequency ?? 0);
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
  }

  // ── Stop & navigate to results ─────────────────────────────────────────────

  Future<void> _stopAll() async {
    _lyricTimer?.cancel();
    _sessionTimer?.cancel();
    _ytController?.pause(); // stop the YouTube video
    if (_isRecording) await _stopRecording();
    setState(() {
      _isPlaying = false;
      _isRecording = false;
    });
  }

  Future<void> _finishAndShowResults() async {
    await _stopAll();

    // Seal whatever line we were on
    _sealCurrentLine();

    // Fill any remaining lines with empty data
    for (int i = _completedLines.length; i < _lyrics.length; i++) {
      _completedLines.add(
        LyricPitchData(
          lyricText: _lyrics[i].text,
          pitchReadings: const [],
          centsReadings: const [],
        ),
      );
    }

    final session = SessionResult(
      songTitle: widget.songTitle,
      songArtist: widget.songArtist,
      songImage: widget.songImage,
      completedAt: DateTime.now(),
      lyricResults: List<LyricPitchData>.from(_completedLines),
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
    _ytController?.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

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
                Text(
                  'Record',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Roboto',
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Timer shown only while playing
          if (_isPlaying || _isRecording)
            Text(
              '${(_elapsedSeconds ~/ 60).toString().padLeft(2, '0')}:'
              '${(_elapsedSeconds % 60).toString().padLeft(2, '0')}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 12,
                fontFamily: 'Roboto',
                letterSpacing: 1,
              ),
            ),
          const SizedBox(width: 8),
          const Icon(Icons.more_horiz, color: Colors.white, size: 22),
        ],
      ),
    );
  }

  /// Always-visible waveform / pitch graph strip.
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
              painter: _KaraokePitchGraphPainter(
                List<double>.from(_pitchHistory),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// YouTube video player.  Shows a loading spinner while searching,
  /// the real player when the video ID is ready, or a dark placeholder
  /// when the API key is not set / search failed.
  Widget _buildVideoBox() {
    // ── Still searching ────────────────────────────────────────────────────
    if (_ytVideoId == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white12, width: 0.5),
            ),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    color: AppColors.primaryCyan,
                    strokeWidth: 2,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Loading video…',
                    style: TextStyle(color: Colors.white30, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // ── API key not set or search failed — dark placeholder ────────────────
    if (_ytVideoId!.isEmpty || _ytController == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white12, width: 0.5),
            ),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.play_circle_outline,
                    color: Colors.white24,
                    size: 48,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Add YouTube API key to load video',
                    style: TextStyle(color: Colors.white24, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // ── YouTube player ─────────────────────────────────────────────────────
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: YoutubePlayer(
          controller: _ytController!,
          showVideoProgressIndicator: true,
          progressIndicatorColor: Colors.red,
          progressColors: const ProgressBarColors(
            playedColor: Colors.red,
            handleColor: Colors.redAccent,
            bufferedColor: Colors.white24,
            backgroundColor: Colors.white12,
          ),
          // Remove fullscreen button so we stay in our layout
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

  /// "Title: X   Artist: X" row matching the Figma.
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
                fontFamily: 'Roboto',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            'Artist: ${widget.songArtist}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
              fontFamily: 'Roboto',
            ),
          ),
          // REC badge
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
                  Text(
                    'REC',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLyricsArea() {
    if (_lyricsLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: AppColors.primaryCyan,
              strokeWidth: 2,
            ),
            const SizedBox(height: 16),
            Text(
              'Loading lyrics…',
              style: TextStyle(
                color: AppColors.grey.withValues(alpha: 0.6),
                fontSize: 13,
                fontFamily: 'Roboto',
              ),
            ),
          ],
        ),
      );
    }

    // ── Live result table — Figma style ────────────────────────────────────
    const colStyle = TextStyle(
      color: Colors.white38,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      fontFamily: 'Roboto',
      letterSpacing: 0.4,
    );

    return Column(
      children: [
        // Current lyric line (the one being sung right now)
        if (_currentLineIndex < _lyrics.length &&
            _lyrics[_currentLineIndex].text.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF111111),
            child: Text(
              _lyrics[_currentLineIndex].text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                fontFamily: 'Roboto',
              ),
              textAlign: TextAlign.center,
            ),
          ),

        // Table header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: const [
              SizedBox(width: 28, child: Text('#', style: colStyle)),
              SizedBox(width: 56, child: Text('Time', style: colStyle)),
              Expanded(child: Text('Pitch', style: colStyle)),
              SizedBox(
                width: 80,
                child: Text(
                  'Direction',
                  style: colStyle,
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
        const Divider(color: Colors.white10, height: 1),

        // Completed lines list
        Expanded(
          child: _completedLines.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.mic_none, color: Colors.white24, size: 36),
                      const SizedBox(height: 8),
                      Text(
                        _isPlaying
                            ? 'Sing along — results appear here'
                            : 'Press ▶ to start',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 13,
                          fontFamily: 'Roboto',
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 4),
                  itemCount: _completedLines.length,
                  itemBuilder: (ctx, i) {
                    final ts = i < _lineTimestamps.length
                        ? _lineTimestamps[i]
                        : 0;
                    return _buildLiveRow(i + 1, ts, _completedLines[i]);
                  },
                ),
        ),
      ],
    );
  }

  // ── Single live-result row ─────────────────────────────────────────────────

  Widget _buildLiveRow(int num, int seconds, LyricPitchData line) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    final ts =
        '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

    String pitch, direction;
    Color color;
    switch (line.status) {
      case LineStatus.correct:
        pitch = 'In Tune';
        direction = '—';
        color = const Color(0xFF4CAF50);
        break;
      case LineStatus.flat:
        pitch = 'Flat';
        direction = 'Too Low';
        color = const Color(0xFFF44336);
        break;
      case LineStatus.sharp:
        pitch = 'Sharp';
        direction = 'Too High';
        color = const Color(0xFFF44336);
        break;
      case LineStatus.noSignal:
        pitch = 'No Signal';
        direction = '—';
        color = Colors.grey;
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$num.',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 13,
                fontFamily: 'Roboto',
              ),
            ),
          ),
          SizedBox(
            width: 56,
            child: Text(
              ts,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontFamily: 'Roboto',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              pitch,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFamily: 'Roboto',
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              direction,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: color.withValues(alpha: 0.75),
                fontSize: 13,
                fontFamily: 'Roboto',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 36),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ── Play / Pause — outlined circle ────────────────────────────────
          GestureDetector(
            onTap: _lyricsLoading
                ? null
                : () {
                    setState(() => _isPlaying = !_isPlaying);
                    if (_isPlaying) {
                      _startLyrics();
                      _ytController?.play(); // sync YouTube video
                      _sessionTimer = Timer.periodic(
                        const Duration(seconds: 1),
                        (_) => setState(() => _elapsedSeconds++),
                      );
                    } else {
                      _pauseLyrics();
                      _ytController?.pause(); // sync YouTube video
                      _sessionTimer?.cancel();
                    }
                  },
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _lyricsLoading ? Colors.white24 : Colors.white,
                  width: 2,
                ),
              ),
              child: _lyricsLoading
                  ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: AppColors.primaryCyan,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  : Icon(
                      _isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
            ),
          ),

          const SizedBox(width: 24),

          // ── Record toggle — red filled circle (largest) ───────────────────
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
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red,
              ),
              child: Icon(
                _isRecording ? Icons.stop_rounded : Icons.mic,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),

          const SizedBox(width: 24),

          // ── Finish & go to results — white rounded square ─────────────────
          GestureDetector(
            onTap: _finishAndShowResults,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.stop_rounded,
                color: Colors.black,
                size: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Karaoke real-time pitch graph painter ────────────────────────────────────

class _KaraokePitchGraphPainter extends CustomPainter {
  final List<double> data;
  const _KaraokePitchGraphPainter(this.data);

  /// Map a frequency (Hz) to a Y pixel position using a logarithmic scale.
  /// Returns [height] (bottom) for silence (hz == 0).
  double _hzToY(double hz, double height) {
    const double minHz = 80.0; // ~E2 — lower bound
    const double maxHz = 1100.0; // ~C6 — upper bound
    if (hz <= 0) return height;
    final logMin = math.log(minHz);
    final logMax = math.log(maxHz);
    final logHz = math.log(hz.clamp(minHz, maxHz));
    return height - ((logHz - logMin) / (logMax - logMin)) * height;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── Horizontal reference lines (C3, C4, C5) ──────────────────────────
    final refPaint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.07)
      ..strokeWidth = 1;

    for (final hz in [130.81, 261.63, 523.25]) {
      final y = _hzToY(hz, h);
      canvas.drawLine(Offset(0, y), Offset(w, y), refPaint);
    }

    if (data.isEmpty) return;

    // ── Build point list ──────────────────────────────────────────────────
    final int count = data.length;
    final double step = count > 1 ? w / (count - 1) : w;

    final List<Offset> points = [
      for (int i = 0; i < count; i++) Offset(i * step, _hzToY(data[i], h)),
    ];

    // ── Filled gradient area ──────────────────────────────────────────────
    if (points.length > 1) {
      final fillPath = Path()..moveTo(points.first.dx, h);
      for (final p in points) {
        fillPath.lineTo(p.dx, p.dy);
      }
      fillPath.lineTo(points.last.dx, h);
      fillPath.close();

      final fillPaint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x4000E0FF), Color(0x0000E0FF)],
        ).createShader(Rect.fromLTWH(0, 0, w, h));
      canvas.drawPath(fillPath, fillPaint);

      // ── Cyan line ─────────────────────────────────────────────────────
      final linePath = Path()..moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        linePath.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(
        linePath,
        Paint()
          ..color = AppColors.primaryCyan
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke,
      );
    }

    // ── Glowing dot at latest reading ─────────────────────────────────────
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
      (data.isNotEmpty && old.data.isNotEmpty && old.data.last != data.last);
}
