import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../constants/app_colors.dart';
import '../data/lyrics.dart';
import '../services/lrclib_service.dart';
import '../services/youtube_search_service.dart';
import 'karaoke_recording_page.dart';

class KaraokeSongDetailPage extends StatefulWidget {
  final String songTitle;
  final String songArtist;
  final String songImage;

  /// Pre-resolved YouTube video ID. Pass empty string to auto-search.
  final String youtubeId;

  const KaraokeSongDetailPage({
    super.key,
    required this.songTitle,
    required this.songArtist,
    required this.songImage,
    this.youtubeId = '',
  });

  @override
  State<KaraokeSongDetailPage> createState() => _KaraokeSongDetailPageState();
}

class _KaraokeSongDetailPageState extends State<KaraokeSongDetailPage> {
  // ── YouTube ────────────────────────────────────────────────────────────────
  late final YoutubePlayerController _ytController;
  StreamSubscription<YoutubePlayerValue>? _ytSub;

  /// Ordered list of candidate video IDs to try when one is not embeddable.
  final List<String> _videoQueue = [];
  int _videoAttempt = 0; // index into _videoQueue currently being played
  bool _tryingNextVideo = false; // guard: avoid multiple simultaneous retries

  String? _resolvedVideoId; // currently cued ID (null = none yet)
  bool _isSearching = false;
  bool _searchFailed = false; // true when queue exhausted with no playable video

  // ── Playback tracking ──────────────────────────────────────────────────────
  bool _isPlaying = false;
  int _elapsedMs = 0;
  Timer? _playbackTimer;  // fires every 100 ms — increments _elapsedMs
  Timer? _syncTimer;      // fires every 2 s — corrects position + play-state

  // ── Lyrics ─────────────────────────────────────────────────────────────────
  List<LyricLine> _lyrics = [];
  List<double> _startTimes = []; // cumulative start seconds per line
  List<GlobalKey> _lyricKeys = [];
  bool _lyricsLoading = true;
  int _activeLine = 0;
  final ScrollController _lyricsScroll = ScrollController();

  // ── Equalizer bars ──────────────────────────────────────────────────────────
  static const int _barCount = 32;
  final List<double> _bars = List.filled(_barCount, 0.15);
  final List<double> _targets = List.filled(_barCount, 0.15);
  Timer? _eqTimer;
  final _rng = math.Random();

  // ── Computed helpers ───────────────────────────────────────────────────────

  double get _totalDurationSecs =>
      _lyrics.fold(0.0, (s, l) => s + l.durationSeconds);

  double get _progressValue {
    if (_totalDurationSecs <= 0) return 0;
    return (_elapsedMs / 1000.0 / _totalDurationSecs).clamp(0.0, 1.0);
  }

  String _formatMs(int ms) {
    final s = (ms / 1000).floor();
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _ytController = YoutubePlayerController(
      params: const YoutubePlayerParams(
        showControls: false,
        showFullscreenButton: false,
        playsInline: true,
        mute: false,
      ),
    );

    _loadLyrics();
    _startEqualizer();
    _startSyncTimer();
    _listenForPlayerErrors();

    if (widget.youtubeId.isNotEmpty) {
      // Pre-resolved ID: put it first in the queue, search for fallbacks too.
      _videoQueue.add(widget.youtubeId);
      _resolvedVideoId = widget.youtubeId;
      _cueVideo(widget.youtubeId);
      // Also fetch extra candidates in background for fallback.
      _searchYouTube(prefillOnly: true);
    } else {
      _isSearching = true; // set before first build
      _searchYouTube();
    }
  }

  @override
  void dispose() {
    _eqTimer?.cancel();
    _playbackTimer?.cancel();
    _syncTimer?.cancel();
    _ytSub?.cancel();
    _lyricsScroll.dispose();
    _ytController.close();
    super.dispose();
  }

  // ── YouTube setup ──────────────────────────────────────────────────────────

  /// Fetches up to 8 candidate video IDs from YouTube.
  /// [prefillOnly] = true → only fills [_videoQueue] without touching UI state
  /// (used when a youtubeId was already provided).
  Future<void> _searchYouTube({bool prefillOnly = false}) async {
    final ids = await YoutubeSearchService.findVideoIds(
      widget.songTitle,
      widget.songArtist,
    );
    if (!mounted) return;

    // Merge into queue (avoid duplicates)
    for (final id in ids) {
      if (!_videoQueue.contains(id)) _videoQueue.add(id);
    }

    if (prefillOnly) return; // caller already set the first video

    if (_videoQueue.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchFailed = true;
      });
      return;
    }

    // Start with the first candidate
    _videoAttempt = 0;
    setState(() {
      _resolvedVideoId = _videoQueue[0];
      _isSearching = false;
    });
    _cueVideo(_videoQueue[0]);
  }

  void _cueVideo(String id) {
    // Wait for the YoutubePlayer widget to be in the tree before calling cue.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ytController.cueVideoById(videoId: id);
    });
  }

  /// Listens to the YouTube player value stream.
  /// When any error occurs (especially notEmbeddable / error 152), tries the
  /// next candidate video in [_videoQueue] automatically.
  void _listenForPlayerErrors() {
    _ytSub = _ytController.listen((value) {
      if (!mounted || !value.hasError || _tryingNextVideo) return;
      _tryingNextVideo = true;
      _tryNextVideo();
    });
  }

  void _tryNextVideo() {
    _videoAttempt++;
    if (_videoAttempt < _videoQueue.length) {
      final nextId = _videoQueue[_videoAttempt];
      setState(() => _resolvedVideoId = nextId);
      _ytController.cueVideoById(videoId: nextId);
      // Allow next error to trigger another retry after 3 s
      Future.delayed(const Duration(seconds: 3), () {
        _tryingNextVideo = false;
      });
    } else {
      // All candidates exhausted
      if (mounted) setState(() => _searchFailed = true);
      _ytSub?.cancel();
    }
  }

  // ── Lyrics ─────────────────────────────────────────────────────────────────

  Future<void> _loadLyrics() async {
    List<LyricLine>? fetched;
    try {
      fetched = await LrcLibService.fetchLyrics(
        title: widget.songTitle,
        artist: widget.songArtist,
      );
    } catch (_) {}

    final lines = fetched ?? SongLyrics.forSong(widget.songTitle);

    // Build cumulative start times
    final starts = <double>[];
    double t = 0;
    for (final l in lines) {
      starts.add(t);
      t += l.durationSeconds;
    }

    if (mounted) {
      setState(() {
        _lyrics = lines;
        _startTimes = starts;
        _lyricKeys = List.generate(lines.length, (_) => GlobalKey());
        _lyricsLoading = false;
      });
    }
  }

  void _updateActiveLine(double positionSecs) {
    if (_startTimes.isEmpty) return;
    int newActive = 0;
    for (int i = 0; i < _startTimes.length; i++) {
      if (positionSecs >= _startTimes[i]) {
        newActive = i;
      } else {
        break;
      }
    }
    if (newActive != _activeLine) {
      setState(() => _activeLine = newActive);
      _scrollToLine(newActive);
    }
  }

  void _scrollToLine(int index) {
    if (index >= _lyricKeys.length) return;
    final ctx = _lyricKeys[index].currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        alignment: 0.3,
      );
    }
  }

  // ── Playback control ───────────────────────────────────────────────────────

  void _play() {
    _ytController.playVideo();
    setState(() => _isPlaying = true);
    _startPlaybackTimer();
  }

  void _pause() {
    _ytController.pauseVideo();
    setState(() => _isPlaying = false);
    _playbackTimer?.cancel();
    _playbackTimer = null;
  }

  void _startPlaybackTimer() {
    _playbackTimer?.cancel();
    _playbackTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() {
        _elapsedMs += 100;
        _updateActiveLine(_elapsedMs / 1000.0);
      });
    });
  }

  /// Every 2 s: fetch real position from YouTube (JS bridge) to correct our
  /// internal counter, and detect if the user tapped the video directly.
  void _startSyncTimer() {
    _syncTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!mounted) return;
      try {
        // Correct position from the actual player
        final pos = await _ytController.currentTime;
        if (mounted) {
          setState(() {
            _elapsedMs = (pos * 1000).round();
            _updateActiveLine(pos);
          });
        }

        // Sync play/pause state (handles user tapping the video directly)
        final state = await _ytController.playerState;
        if (!mounted) return;
        final ytPlaying = state == PlayerState.playing;
        if (ytPlaying && !_isPlaying) {
          setState(() => _isPlaying = true);
          _startPlaybackTimer();
        } else if (!ytPlaying && _isPlaying) {
          setState(() => _isPlaying = false);
          _playbackTimer?.cancel();
          _playbackTimer = null;
        }
      } catch (_) {}
    });
  }

  void _restart() {
    _playbackTimer?.cancel();
    _playbackTimer = null;
    _ytController.seekTo(seconds: 0, allowSeekAhead: true);
    setState(() {
      _elapsedMs = 0;
      _activeLine = 0;
      _isPlaying = false;
    });
    _lyricsScroll.animateTo(0,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  void _seekForward() {
    final newMs = _elapsedMs + 10000;
    _ytController.seekTo(seconds: newMs / 1000.0, allowSeekAhead: true);
    setState(() {
      _elapsedMs = newMs;
      _updateActiveLine(newMs / 1000.0);
    });
  }

  // ── Equalizer animation ────────────────────────────────────────────────────

  void _startEqualizer() {
    _eqTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (!mounted) return;
      setState(() {
        for (int i = 0; i < _barCount; i++) {
          if (_rng.nextDouble() < 0.4) {
            _targets[i] = 0.05 + _rng.nextDouble() * 0.95;
          }
          _bars[i] += (_targets[i] - _bars[i]) * 0.35;
        }
      });
    });
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
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFrequencySection(),
                    _buildVideoSection(),
                    _buildLyricsSection(),
                  ],
                ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios,
                color: AppColors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: widget.songImage.isNotEmpty
                ? Image.network(
                    widget.songImage,
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, e, st) => _fallbackIcon(),
                  )
                : _fallbackIcon(),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.songTitle,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Roboto',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  widget.songArtist,
                  style: const TextStyle(
                    color: AppColors.grey,
                    fontSize: 12,
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

  Widget _fallbackIcon() => Container(
        width: 36,
        height: 36,
        color: AppColors.inputBg,
        child: const Icon(Icons.music_note, color: AppColors.grey, size: 18),
      );

  // ── 1. Frequency / Equalizer ───────────────────────────────────────────────

  Widget _buildFrequencySection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Frequency',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFamily: 'Roboto',
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 72,
            width: double.infinity,
            child: CustomPaint(
              painter: _EqualizerPainter(_bars),
            ),
          ),
        ],
      ),
    );
  }

  // ── 2. YouTube video ───────────────────────────────────────────────────────

  Widget _buildVideoSection() {
    // Still searching
    if (_isSearching) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        height: 196,
        decoration: BoxDecoration(
          color: AppColors.inputBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                  color: AppColors.primaryCyan, strokeWidth: 2),
              SizedBox(height: 12),
              Text('Finding video…',
                  style: TextStyle(
                      color: AppColors.grey,
                      fontSize: 13,
                      fontFamily: 'Roboto')),
            ],
          ),
        ),
      );
    }

    // Search failed or no ID
    if (_searchFailed || _resolvedVideoId == null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        height: 160,
        decoration: BoxDecoration(
          color: AppColors.inputBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.video_library_outlined,
                  color: AppColors.grey.withValues(alpha: 0.5), size: 40),
              const SizedBox(height: 8),
              Text(
                'Video not available',
                style: TextStyle(
                    color: AppColors.grey.withValues(alpha: 0.7),
                    fontFamily: 'Roboto',
                    fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    // Show player
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: YoutubePlayer(
          controller: _ytController,
          aspectRatio: 16 / 9,
        ),
      ),
    );
  }

  // ── 3. Lyrics ──────────────────────────────────────────────────────────────

  Widget _buildLyricsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lyrics',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFamily: 'Roboto',
            ),
          ),
          const SizedBox(height: 8),
          if (_lyricsLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(
                    color: AppColors.primaryCyan, strokeWidth: 2),
              ),
            )
          else if (_lyrics.every((l) => l.text.isEmpty))
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C24),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'No lyrics available.',
                style: TextStyle(
                    color: AppColors.grey,
                    fontFamily: 'Roboto',
                    fontSize: 14),
                textAlign: TextAlign.center,
              ),
            )
          else
            SizedBox(
              height: 270,
              child: ListView.builder(
                controller: _lyricsScroll,
                padding: EdgeInsets.zero,
                itemCount: _lyrics.length,
                itemBuilder: (ctx, i) {
                  final line = _lyrics[i];
                  final key = _lyricKeys.length > i ? _lyricKeys[i] : null;
                  final isActive = i == _activeLine;

                  if (line.text.isEmpty) {
                    return SizedBox(key: key, height: 10);
                  }

                  return AnimatedContainer(
                    key: key,
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 13),
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFF2B1D3E)
                          : const Color(0xFF1C1C24),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isActive
                            ? const Color(0xFF9C27B0)
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      line.text,
                      style: TextStyle(
                        color: isActive ? AppColors.white : AppColors.grey,
                        fontSize: 14,
                        fontFamily: 'Roboto',
                        fontWeight: isActive
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // ── 4. Controls ────────────────────────────────────────────────────────────

  Widget _buildControls() {
    final elapsedStr = _formatMs(_elapsedMs);
    final totalStr = _formatMs((_totalDurationSecs * 1000).round());
    final canPlay = !_isSearching && _resolvedVideoId != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D0D),
        border: Border(top: BorderSide(color: Colors.white10, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Progress bar ──────────────────────────────────────────────────
          Row(
            children: [
              Text(elapsedStr,
                  style: const TextStyle(
                      color: AppColors.grey,
                      fontSize: 11,
                      fontFamily: 'Roboto')),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 5),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 10),
                    activeTrackColor: const Color(0xFFE040FB),
                    inactiveTrackColor: AppColors.inputBg,
                    thumbColor: const Color(0xFFE040FB),
                    overlayColor:
                        const Color(0xFFE040FB).withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    value: _progressValue,
                    onChanged: canPlay && !_lyricsLoading
                        ? (v) {
                            final newMs =
                                (v * _totalDurationSecs * 1000).round();
                            _ytController.seekTo(
                                seconds: newMs / 1000.0, allowSeekAhead: true);
                            setState(() {
                              _elapsedMs = newMs;
                              _updateActiveLine(newMs / 1000.0);
                            });
                          }
                        : null,
                  ),
                ),
              ),
              Text(totalStr,
                  style: const TextStyle(
                      color: AppColors.grey,
                      fontSize: 11,
                      fontFamily: 'Roboto')),
            ],
          ),
          const SizedBox(height: 2),
          // ── Buttons ───────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Restart
              IconButton(
                icon: Icon(Icons.skip_previous_rounded,
                    color: AppColors.white.withValues(alpha: 0.85), size: 30),
                onPressed: canPlay ? _restart : null,
              ),

              // Play / Pause
              GestureDetector(
                onTap: !canPlay
                    ? null
                    : () {
                        if (_isPlaying) {
                          _pause();
                        } else {
                          _play();
                        }
                      },
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: !canPlay
                        ? AppColors.grey.withValues(alpha: 0.25)
                        : const Color(0xFFE040FB),
                  ),
                  child: _isSearching
                      ? const Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          ),
                        )
                      : Icon(
                          _isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                ),
              ),

              // Forward 10 s
              IconButton(
                icon: Icon(Icons.forward_10_rounded,
                    color: AppColors.white.withValues(alpha: 0.85), size: 28),
                onPressed: canPlay ? _seekForward : null,
              ),

              // ─ Sing button ────────────────────────────────────────────────
              GestureDetector(
                onTap: () {
                  if (_isPlaying) _pause();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => KaraokeRecordingPage(
                        songTitle: widget.songTitle,
                        songArtist: widget.songArtist,
                        songImage: widget.songImage,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppColors.primaryCyan.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.primaryCyan.withValues(alpha: 0.5)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.mic_rounded,
                          color: AppColors.primaryCyan, size: 16),
                      SizedBox(width: 5),
                      Text(
                        'Sing',
                        style: TextStyle(
                          color: AppColors.primaryCyan,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Roboto',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Equalizer bar painter ─────────────────────────────────────────────────────

class _EqualizerPainter extends CustomPainter {
  final List<double> bars;
  const _EqualizerPainter(this.bars);

  @override
  void paint(Canvas canvas, Size size) {
    final count = bars.length;
    if (count == 0) return;
    final barW = (size.width / count) * 0.6;
    final gap = (size.width / count) * 0.4;
    final h = size.height;

    for (int i = 0; i < count; i++) {
      final barH = (bars[i] * h).clamp(2.0, h);
      final x = i * (barW + gap);
      final top = h - barH;
      final rect = Rect.fromLTWH(x, top, barW, barH);

      final paint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Color(0xFF00E676), // green
            Color(0xFFFFEB3B), // yellow
            Color(0xFFFF5722), // orange-red
          ],
          stops: [0.0, 0.6, 1.0],
        ).createShader(rect)
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(2)), paint);
    }
  }

  @override
  bool shouldRepaint(_EqualizerPainter old) => true;
}
