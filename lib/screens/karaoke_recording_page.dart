import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../constants/app_colors.dart';
import '../core/audio_service.dart';
import '../core/note_utils.dart';
import '../data/lyrics.dart';
import '../models/session_result.dart';
import '../services/lrclib_service.dart';
import '../services/stingray_service.dart';
import 'results_page.dart';

class KaraokeRecordingPage extends StatefulWidget {
  final String songTitle;
  final String songArtist;
  final String songImage;
  final String songYtId; // YouTube video ID or search query

  const KaraokeRecordingPage({
    super.key,
    this.songTitle = 'Dadalhin',
    this.songArtist = 'Regine Velasquez',
    this.songImage = '',
    this.songYtId = '',
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

  final ScrollController _scrollController = ScrollController();

  // ── Audio & pitch ──────────────────────────────────────────────────────────
  final AudioService _audioService = AudioService();
  StreamSubscription<NoteResult?>? _audioSub;

  // ── Background music (just_audio + youtube_explode) ────────────────────────
  final AudioPlayer _musicPlayer = AudioPlayer();
  final YoutubeExplode _yt = YoutubeExplode();
  bool _musicLoading = false;
  bool _musicReady = false;
  String _musicError = '';

  // Live pitch display
  PitchFeedback _liveFeedback = PitchFeedback.noSignal;
  String _liveNote = '';
  double _liveCents = 0;

  // ── Per-line pitch accumulation ────────────────────────────────────────────
  late List<List<double>> _linePitch;
  late List<List<double>> _lineCents;
  final List<LyricPitchData> _completedLines = [];

  // ── Lyrics ─────────────────────────────────────────────────────────────────
  List<LyricLine> _lyrics = [];
  List<GlobalKey> _lineKeys = [];
  bool _lyricsLoading = true;

  @override
  void initState() {
    super.initState();
    _audioService.initialize();

    // Load lyrics from LRCLIB (real synced lyrics), fallback to local DB
    _loadLyrics();

    // Always load music
    _loadMusic();
  }

  Future<void> _loadLyrics() async {
    // Try LRCLIB first for real synced lyrics
    final fetched = await LrcLibService.fetchLyrics(
      title: widget.songTitle,
      artist: widget.songArtist,
    );

    final lines = fetched ?? SongLyrics.forSong(widget.songTitle);

    if (!mounted) return;
    setState(() {
      _lyrics = lines;
      _lineKeys = List.generate(lines.length, (_) => GlobalKey());
      _linePitch = List.generate(lines.length, (_) => []);
      _lineCents = List.generate(lines.length, (_) => []);
      _lyricsLoading = false;
    });
  }

  // ── Music loading ──────────────────────────────────────────────────────────

  Future<void> _loadMusic() async {
    if (!mounted) return;
    setState(() { _musicLoading = true; _musicError = ''; });

    // Priority: Stingray (best) → YouTube → Deezer preview
    String? url = await _tryStingray();
    url ??= await _tryYouTube();
    url ??= await _tryDeezer();

    if (!mounted) return;
    if (url != null) {
      try {
        await _musicPlayer.setVolume(0.8);
        await _musicPlayer.setUrl(url);
        setState(() { _musicLoading = false; _musicReady = true; });
      } catch (_) {
        setState(() {
          _musicLoading = false;
          _musicError = 'Music unavailable — tap to retry';
        });
      }
    } else {
      setState(() {
        _musicLoading = false;
        _musicError = 'Music unavailable — tap to retry';
      });
    }
  }

  // ── Stingray Karaoke API (primary) ────────────────────────────────────────
  Future<String?> _tryStingray() async {
    return StingrayService.getStreamUrl(
      title: widget.songTitle,
      artist: widget.songArtist,
    );
  }

  // ── YouTube audio stream ───────────────────────────────────────────────────
  Future<String?> _tryYouTube() async {
    try {
      final query = '${widget.songTitle} ${widget.songArtist} karaoke';
      final results = await _yt.search.search(query)
          .timeout(const Duration(seconds: 10));
      if (results.isEmpty) return null;

      // Try first 3 results
      for (final video in results.take(3)) {
        try {
          final manifest = await _yt.videos.streamsClient
              .getManifest(video.id)
              .timeout(const Duration(seconds: 10));
          final streams = manifest.audioOnly;
          if (streams.isEmpty) continue;
          return streams.withHighestBitrate().url.toString();
        } catch (_) { continue; }
      }
      return null;
    } catch (_) { return null; }
  }

  // ── Deezer 30-second preview fallback ─────────────────────────────────────
  Future<String?> _tryDeezer() async {
    try {
      final q = Uri.encodeComponent(
          '${widget.songTitle} ${widget.songArtist}');
      final res = await http
          .get(Uri.parse('https://api.deezer.com/search?q=$q&limit=5'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final data = json.decode(res.body);
      final tracks = data['data'] as List?;
      if (tracks == null || tracks.isEmpty) return null;
      // Pick track with a preview URL
      for (final t in tracks) {
        final preview = t['preview'] as String?;
        if (preview != null && preview.isNotEmpty) return preview;
      }
      return null;
    } catch (_) { return null; }
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
      _scrollToCurrentLine();
      _advanceLine();
    });
  }

  void _sealCurrentLine() {
    final i = _currentLineIndex;
    if (i >= _lyrics.length) return;
    _completedLines.add(LyricPitchData(
      lyricText: _lyrics[i].text,
      pitchReadings: List<double>.from(_linePitch[i]),
      centsReadings: List<double>.from(_lineCents[i]),
    ));
    _linePitch[i].clear();
    _lineCents[i].clear();
  }

  void _pauseLyrics() => _lyricTimer?.cancel();

  void _scrollToCurrentLine() {
    final ctx = _lineKeys[_currentLineIndex].currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        alignment: 0.4,
      );
    }
  }

  // ── Play / Pause toggle ────────────────────────────────────────────────────

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      // Pause
      _pauseLyrics();
      _sessionTimer?.cancel();
      if (_musicReady) await _musicPlayer.pause();
      setState(() => _isPlaying = false);
    } else {
      // Play lyrics + timer
      _startLyrics();
      _sessionTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => setState(() => _elapsedSeconds++),
      );
      setState(() => _isPlaying = true);

      // Play music — if still loading, wait for it then play
      if (_musicReady) {
        await _musicPlayer.play();
      } else if (_musicLoading) {
        // Wait for music to load then auto-play
        Future.microtask(() async {
          while (_musicLoading && mounted) {
            await Future.delayed(const Duration(milliseconds: 300));
          }
          if (mounted && _musicReady && _isPlaying) {
            await _musicPlayer.play();
          }
        });
      }
    }
  }

  // ── Recording toggle ───────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    _audioService.enableSaving();
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
        if (result != null) {
          _liveFeedback = result.feedback;
          _liveNote = result.fullName;
          _liveCents = result.cents;
        } else {
          _liveFeedback = PitchFeedback.noSignal;
          _liveNote = '';
          _liveCents = 0;
        }
      });
    });
  }

  Future<void> _stopRecording() async {
    await _audioSub?.cancel();
    _audioSub = null;
    await _audioService.stop();

    final label =
        'huni_karaoke_${widget.songTitle.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}';
    final path = await _audioService.saveRecording(label);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(path != null
              ? '✅ Recording saved!'
              : '⚠️ Could not save recording'),
          backgroundColor: path != null ? Colors.green[700] : Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
    }

    setState(() {
      _liveFeedback = PitchFeedback.noSignal;
      _liveNote = '';
      _liveCents = 0;
    });
  }

  // ── Stop all & navigate to results ────────────────────────────────────────

  Future<void> _stopAll() async {
    _lyricTimer?.cancel();
    _sessionTimer?.cancel();
    if (_musicReady) await _musicPlayer.stop();
    if (_isRecording) await _stopRecording();
    setState(() {
      _isPlaying = false;
      _isRecording = false;
    });
  }

  Future<void> _finishAndShowResults() async {
    await _stopAll();
    _sealCurrentLine();

    for (int i = _completedLines.length; i < _lyrics.length; i++) {
      _completedLines.add(LyricPitchData(
        lyricText: _lyrics[i].text,
        pitchReadings: const [],
        centsReadings: const [],
      ));
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
      MaterialPageRoute(
        builder: (_) => ResultsPage(session: session),
      ),
    );
  }

  @override
  void dispose() {
    _lyricTimer?.cancel();
    _sessionTimer?.cancel();
    _audioSub?.cancel();
    _audioService.dispose();
    _musicPlayer.dispose();
    _yt.close();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Color get _feedbackColor {
    switch (_liveFeedback) {
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
    switch (_liveFeedback) {
      case PitchFeedback.correct:
        return 'In Tune ✓';
      case PitchFeedback.tooHigh:
        return 'Sharp ↑';
      case PitchFeedback.tooLow:
        return 'Flat ↓';
      case PitchFeedback.noSignal:
        return _isRecording ? 'Listening…' : '';
    }
  }

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
            _buildMusicStatus(),
            if (_isRecording) _buildLivePitchBar(),
            const SizedBox(height: 4),
            Expanded(child: _buildLyricsArea()),
            _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down,
                color: AppColors.white, size: 30),
            onPressed: () => Navigator.pop(context),
          ),
          const Spacer(),
          Column(
            children: [
              Text(
                'KARAOKE',
                style: TextStyle(
                  color: AppColors.white.withValues(alpha: 0.5),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                  fontFamily: 'Roboto',
                ),
              ),
              Text(
                widget.songTitle,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 14,
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
              color: AppColors.white.withValues(alpha: 0.6),
              fontSize: 12,
              fontFamily: 'Roboto',
              letterSpacing: 1,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

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
                    width: 42,
                    height: 42,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, e, st) => _musicIcon(),
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
                        color: AppColors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Roboto'),
                    overflow: TextOverflow.ellipsis),
                Text(widget.songArtist,
                    style: TextStyle(
                        color: AppColors.white.withValues(alpha: 0.55),
                        fontSize: 13,
                        fontFamily: 'Roboto')),
              ],
            ),
          ),
          if (_isRecording)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
              ),
              child: Row(children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                      color: Colors.red, shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                const Text('REC',
                    style: TextStyle(
                        color: Colors.red,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Roboto')),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _musicIcon() => Container(
        width: 42,
        height: 42,
        color: AppColors.inputBg,
        child: const Icon(Icons.music_note, color: AppColors.grey, size: 20),
      );

  /// Music loading / ready / error status strip
  Widget _buildMusicStatus() {
    if (_musicLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: Row(children: [
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
                strokeWidth: 1.5, color: AppColors.primaryCyan),
          ),
          const SizedBox(width: 8),
          Text('Loading music…',
              style: TextStyle(
                  color: AppColors.white.withValues(alpha: 0.5),
                  fontSize: 11,
                  fontFamily: 'Roboto')),
        ]),
      );
    }
    if (_musicReady) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: Row(children: [
          const Icon(Icons.music_note,
              color: AppColors.primaryCyan, size: 13),
          const SizedBox(width: 6),
          Text('Music ready  •  Press ▶ to start',
              style: TextStyle(
                  color: AppColors.primaryCyan.withValues(alpha: 0.8),
                  fontSize: 11,
                  fontFamily: 'Roboto')),
          if (_isPlaying) ...[
            const SizedBox(width: 8),
            StreamBuilder<Duration>(
              stream: _musicPlayer.positionStream,
              builder: (ctx, snap) {
                final pos = snap.data ?? Duration.zero;
                final dur = _musicPlayer.duration ?? Duration.zero;
                final pct =
                    dur.inMilliseconds > 0
                        ? pos.inMilliseconds / dur.inMilliseconds
                        : 0.0;
                return Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: pct.clamp(0.0, 1.0),
                      minHeight: 3,
                      backgroundColor:
                          AppColors.white.withValues(alpha: 0.1),
                      valueColor: const AlwaysStoppedAnimation(
                          AppColors.primaryCyan),
                    ),
                  ),
                );
              },
            ),
          ],
        ]),
      );
    }
    if (_musicError.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: Row(children: [
          Icon(Icons.wifi_off,
              color: AppColors.grey.withValues(alpha: 0.5), size: 13),
          const SizedBox(width: 6),
          Text(_musicError,
              style: TextStyle(
                  color: AppColors.grey.withValues(alpha: 0.5),
                  fontSize: 11,
                  fontFamily: 'Roboto')),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _loadMusic,
            child: Text('Retry',
                style: TextStyle(
                    color: AppColors.primaryCyan.withValues(alpha: 0.8),
                    fontSize: 11,
                    decoration: TextDecoration.underline,
                    fontFamily: 'Roboto')),
          ),
        ]),
      );
    }
    return const SizedBox.shrink();
  }

  /// Real-time pitch bar shown while recording is active.
  Widget _buildLivePitchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.inputBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: _feedbackColor.withValues(alpha: 0.35), width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.graphic_eq, color: _feedbackColor, size: 18),
            const SizedBox(width: 8),
            Text(
              _liveNote.isEmpty ? '—' : _liveNote,
              style: TextStyle(
                color: _feedbackColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'Roboto',
              ),
            ),
            const SizedBox(width: 10),
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
                              fontSize: 9,
                              fontFamily: 'Roboto')),
                      Text('${_liveCents.toStringAsFixed(0)} ¢',
                          style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 9,
                              fontFamily: 'Roboto')),
                      Text('Sharp',
                          style: TextStyle(
                              color: AppColors.grey.withValues(alpha: 0.6),
                              fontSize: 9,
                              fontFamily: 'Roboto')),
                    ],
                  ),
                  const SizedBox(height: 3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: (_liveCents.clamp(-50, 50) + 50) / 100,
                      minHeight: 5,
                      backgroundColor: AppColors.inputBg,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(_feedbackColor),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              _feedbackLabel,
              style: TextStyle(
                  color: _feedbackColor,
                  fontSize: 11,
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLyricsArea() {
    if (_lyricsLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primaryCyan, strokeWidth: 2),
            SizedBox(height: 12),
            Text('Loading lyrics…',
                style: TextStyle(
                    color: AppColors.grey,
                    fontSize: 13,
                    fontFamily: 'Roboto')),
          ],
        ),
      );
    }

    return ShaderMask(
      shaderCallback: (rect) {
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.white,
            Colors.white,
            Colors.transparent
          ],
          stops: [0.0, 0.12, 0.82, 1.0],
        ).createShader(rect);
      },
      blendMode: BlendMode.dstIn,
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(_lyrics.length, (i) {
            final line = _lyrics[i];
            final isCurrent = i == _currentLineIndex;
            final isPast = i < _currentLineIndex;

            if (line.text.isEmpty) {
              return SizedBox(key: _lineKeys[i], height: 28);
            }

            return Padding(
              key: _lineKeys[i],
              padding: const EdgeInsets.only(bottom: 6),
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                style: TextStyle(
                  fontSize: isCurrent ? 28 : 22,
                  fontWeight:
                      isCurrent ? FontWeight.w800 : FontWeight.w600,
                  color: isCurrent
                      ? AppColors.white
                      : isPast
                          ? AppColors.white.withValues(alpha: 0.25)
                          : AppColors.white.withValues(alpha: 0.38),
                  height: 1.35,
                  fontFamily: 'Roboto',
                ),
                child: Text(line.text),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 36),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Restart
          IconButton(
            icon: Icon(Icons.skip_previous_rounded,
                color: AppColors.white.withValues(alpha: 0.7), size: 32),
            onPressed: () {
              _pauseLyrics();
              if (_musicReady) {
                _musicPlayer.seek(Duration.zero);
                if (!_isPlaying) _musicPlayer.pause();
              }
              setState(() => _currentLineIndex = 0);
              _scrollController.animateTo(0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut);
              if (_isPlaying) _startLyrics();
            },
          ),

          // Play / Pause
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: _musicLoading
                    ? AppColors.white.withValues(alpha: 0.5)
                    : AppColors.white,
                shape: BoxShape.circle,
              ),
              child: _musicLoading
                  ? const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black54),
                      ),
                    )
                  : Icon(
                      _isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.black,
                      size: 34,
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
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isRecording
                    ? Colors.red
                    : Colors.red.withValues(alpha: 0.15),
                border: Border.all(color: Colors.red, width: 2),
              ),
              child: Icon(Icons.mic,
                  color: _isRecording ? AppColors.white : Colors.red,
                  size: 24),
            ),
          ),

          // Stop & go to results
          GestureDetector(
            onTap: _finishAndShowResults,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.stop_rounded,
                  color: AppColors.white.withValues(alpha: 0.8), size: 22),
            ),
          ),
        ],
      ),
    );
  }
}
