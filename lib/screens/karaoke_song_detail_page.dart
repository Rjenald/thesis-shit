import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../constants/app_colors.dart';
import '../data/lyrics.dart';
import '../services/lrclib_service.dart';
import 'karaoke_recording_page.dart';

class KaraokeSongDetailPage extends StatefulWidget {
  final String songTitle;
  final String songArtist;
  final String songImage;
  final String youtubeId;

  const KaraokeSongDetailPage({
    super.key,
    required this.songTitle,
    required this.songArtist,
    required this.songImage,
    required this.youtubeId,
  });

  @override
  State<KaraokeSongDetailPage> createState() => _KaraokeSongDetailPageState();
}

class _KaraokeSongDetailPageState extends State<KaraokeSongDetailPage> {
  late final YoutubePlayerController _ytController;

  // ── Lyrics ──────────────────────────────────────────────────────────────────
  List<LyricLine> _lyrics = [];
  bool _lyricsLoading = true;
  int _activeLine = 0;
  Timer? _lyricTimer;

  // ── Equalizer bars ───────────────────────────────────────────────────────────
  static const int _barCount = 36;
  final List<double> _bars = List.filled(_barCount, 0.15);
  final List<double> _targets = List.filled(_barCount, 0.15);
  Timer? _eqTimer;
  final _rng = math.Random();

  // ── Scroll controller for lyrics ─────────────────────────────────────────────
  final ScrollController _lyricsScroll = ScrollController();

  @override
  void initState() {
    super.initState();

    _ytController = YoutubePlayerController(
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        playsInline: true,
        mute: false,
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ytController.cueVideoById(videoId: widget.youtubeId);
    });

    _loadLyrics();
    _startEqualizer();
  }

  @override
  void dispose() {
    _eqTimer?.cancel();
    _lyricTimer?.cancel();
    _lyricsScroll.dispose();
    _ytController.close();
    super.dispose();
  }

  // ── Equalizer animation ──────────────────────────────────────────────────────

  void _startEqualizer() {
    // Randomise targets every 120 ms, smoothly interpolate bars toward them
    _eqTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (!mounted) return;
      setState(() {
        for (int i = 0; i < _barCount; i++) {
          // Randomly update ~40% of targets each tick for natural-looking motion
          if (_rng.nextDouble() < 0.4) {
            _targets[i] = 0.05 + _rng.nextDouble() * 0.95;
          }
          // Smoothly interpolate toward target
          _bars[i] += (_targets[i] - _bars[i]) * 0.35;
        }
      });
    });
  }

  // ── Lyrics loader ─────────────────────────────────────────────────────────────

  Future<void> _loadLyrics() async {
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
        _lyricsLoading = false;
      });
      _startLyricCycle();
    }
  }

  /// Auto-cycles the active lyric line every few seconds for demo purposes.
  void _startLyricCycle() {
    if (_lyrics.isEmpty) return;
    _lyricTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      final nonEmpty = _lyrics
          .asMap()
          .entries
          .where((e) => e.value.text.isNotEmpty)
          .map((e) => e.key)
          .toList();
      if (nonEmpty.isEmpty) return;
      final idx = nonEmpty[(nonEmpty.indexOf(_activeLine) + 1) % nonEmpty.length];
      setState(() => _activeLine = idx);
      // Scroll to active line
      final itemH = 60.0;
      final offset = (_activeLine * itemH)
          .clamp(0.0, _lyricsScroll.position.maxScrollExtent);
      _lyricsScroll.animateTo(
        offset,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1 ── Frequency equalizer
                    _buildFrequencySection(),
                    // 2 ── YouTube video
                    _buildVideoSection(),
                    // 3 ── Lyrics
                    _buildLyricsSection(),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            // 4 ── Transport controls
            _buildControls(),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────────

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
                      fontFamily: 'Roboto'),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  widget.songArtist,
                  style: const TextStyle(
                      color: AppColors.grey,
                      fontSize: 12,
                      fontFamily: 'Roboto'),
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
        child:
            const Icon(Icons.music_note, color: AppColors.grey, size: 18),
      );

  // ── 1. Frequency equalizer ────────────────────────────────────────────────────

  Widget _buildFrequencySection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
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
          const SizedBox(height: 8),
          SizedBox(
            height: 80,
            child: CustomPaint(
              painter: _EqualizerPainter(_bars),
              size: const Size(double.infinity, 80),
            ),
          ),
        ],
      ),
    );
  }

  // ── 2. YouTube video ──────────────────────────────────────────────────────────

  Widget _buildVideoSection() {
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

  // ── 3. Lyrics section ─────────────────────────────────────────────────────────

  Widget _buildLyricsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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
                color: AppColors.cardBg,
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
              height: 280,
              child: ListView.builder(
                controller: _lyricsScroll,
                itemCount: _lyrics.length,
                itemBuilder: (ctx, i) {
                  final line = _lyrics[i];
                  if (line.text.isEmpty) {
                    return const SizedBox(height: 10);
                  }
                  final isActive = i == _activeLine;
                  return _buildLyricCard(line.text, isActive);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLyricCard(String text, bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFF2B1D3E) // dark purple tint
            : const Color(0xFF1C1C24),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive
              ? const Color(0xFF9C27B0) // purple border
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isActive ? AppColors.white : AppColors.grey,
          fontSize: 14,
          fontFamily: 'Roboto',
          fontWeight:
              isActive ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  // ── 4. Transport controls ─────────────────────────────────────────────────────

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D0D),
        border: Border(
            top: BorderSide(color: Colors.white10, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Time bar
          Row(
            children: [
              const Text('0:00',
                  style: TextStyle(
                      color: AppColors.grey,
                      fontSize: 11,
                      fontFamily: 'Roboto')),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 5),
                    overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 10),
                    activeTrackColor: const Color(0xFFE040FB),
                    inactiveTrackColor: AppColors.inputBg,
                    thumbColor: const Color(0xFFE040FB),
                    overlayColor:
                        const Color(0xFFE040FB).withValues(alpha: 0.2),
                  ),
                  child: Slider(value: 0, onChanged: null),
                ),
              ),
              const Text('3:24',
                  style: TextStyle(
                      color: AppColors.grey,
                      fontSize: 11,
                      fontFamily: 'Roboto')),
            ],
          ),
          const SizedBox(height: 4),
          // Buttons row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Skip back
              IconButton(
                icon: const Icon(Icons.skip_previous_rounded,
                    color: AppColors.white, size: 30),
                onPressed: () =>
                    _ytController.seekTo(seconds: 0, allowSeekAhead: true),
              ),
              // Play/Pause — pink circle
              GestureDetector(
                onTap: () async {
                  final state =
                      await _ytController.playerState;
                  if (state == PlayerState.playing) {
                    _ytController.pauseVideo();
                  } else {
                    _ytController.playVideo();
                  }
                },
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFE040FB),
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 32),
                ),
              ),
              // Skip forward
              IconButton(
                icon: const Icon(Icons.skip_next_rounded,
                    color: AppColors.white, size: 30),
                onPressed: () =>
                    _ytController.seekTo(seconds: 10, allowSeekAhead: true),
              ),
              // Volume
              IconButton(
                icon: const Icon(Icons.volume_up_rounded,
                    color: AppColors.white, size: 26),
                onPressed: () {},
              ),
              // Start Karaoke
              GestureDetector(
                onTap: () {
                  _ytController.pauseVideo();
                  _eqTimer?.cancel();
                  _lyricTimer?.cancel();
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color:
                        AppColors.primaryCyan.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.primaryCyan.withValues(alpha: 0.5)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.mic_rounded,
                          color: AppColors.primaryCyan, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Sing',
                        style: TextStyle(
                          color: AppColors.primaryCyan,
                          fontSize: 12,
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

// ── Equalizer bar chart painter ───────────────────────────────────────────────

class _EqualizerPainter extends CustomPainter {
  final List<double> bars;
  const _EqualizerPainter(this.bars);

  @override
  void paint(Canvas canvas, Size size) {
    final count = bars.length;
    final barW = (size.width / count) * 0.65;
    final gap = (size.width / count) * 0.35;
    final h = size.height;

    for (int i = 0; i < count; i++) {
      final barH = bars[i] * h;
      final x = i * (barW + gap);
      final top = h - barH;

      // Gradient: green (bottom) → yellow (mid) → red (top)
      final rect = Rect.fromLTWH(x, top, barW, barH);
      final gradient = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: const [
          Color(0xFF00E676), // green
          Color(0xFFFFEB3B), // yellow
          Color(0xFFFF5722), // orange-red
        ],
        stops: const [0.0, 0.6, 1.0],
      );

      final paint = Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.fill;

      final rRect =
          RRect.fromRectAndRadius(rect, const Radius.circular(2));
      canvas.drawRRect(rRect, paint);
    }
  }

  @override
  bool shouldRepaint(_EqualizerPainter old) => true;
}
