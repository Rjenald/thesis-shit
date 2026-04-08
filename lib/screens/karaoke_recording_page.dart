import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../data/lyrics.dart';
import 'dart:async';
import 'results_page.dart';

class KaraokeRecordingPage extends StatefulWidget {
  final String songTitle;
  final String songArtist;
  final String songImage;

  const KaraokeRecordingPage({
    super.key,
    this.songTitle = 'Dadalhin',
    this.songArtist = 'Regine Velasquez',
    this.songImage = 'https://i.pravatar.cc/150?img=1',
  });

  @override
  State<KaraokeRecordingPage> createState() => _KaraokeRecordingPageState();
}

class _KaraokeRecordingPageState extends State<KaraokeRecordingPage>
    with SingleTickerProviderStateMixin {
  bool _isPlaying = false;
  bool _isRecording = false;
  int _currentLineIndex = 0;
  Timer? _lyricTimer;
  final ScrollController _scrollController = ScrollController();

  late final List<LyricLine> _lyrics;

  late final List<GlobalKey> _lineKeys;

  @override
  void initState() {
    super.initState();
    _lyrics = SongLyrics.forSong(widget.songTitle);
    _lineKeys = List.generate(_lyrics.length, (_) => GlobalKey());
  }

  void _startLyrics() {
    _advanceLine();
  }

  void _advanceLine() {
    if (!mounted || _currentLineIndex >= _lyrics.length) return;

    final line = _lyrics[_currentLineIndex];
    _lyricTimer = Timer(Duration(seconds: line.durationSeconds), () {
      if (!mounted) return;
      setState(() {
        if (_currentLineIndex < _lyrics.length - 1) {
          _currentLineIndex++;
        }
      });
      _scrollToCurrentLine();
      _advanceLine();
    });
  }

  void _scrollToCurrentLine() {
    final key = _lineKeys[_currentLineIndex];
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        alignment: 0.4,
      );
    }
  }

  void _pauseLyrics() {
    _lyricTimer?.cancel();
  }

  void _stopAll() {
    _lyricTimer?.cancel();
    setState(() {
      _isPlaying = false;
      _isRecording = false;
    });
  }

  @override
  void dispose() {
    _lyricTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSongInfo(),
            const SizedBox(height: 8),
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
          IconButton(
            icon: const Icon(Icons.more_horiz,
                color: AppColors.white, size: 26),
            onPressed: () {},
          ),
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
            child: Image.network(
              widget.songImage,
              width: 42,
              height: 42,
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, st) => Container(
                width: 42,
                height: 42,
                color: AppColors.inputBg,
                child: const Icon(Icons.music_note,
                    color: AppColors.grey, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.songTitle,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Roboto',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  widget.songArtist,
                  style: TextStyle(
                    color: AppColors.white.withValues(alpha: 0.55),
                    fontSize: 13,
                    fontFamily: 'Roboto',
                  ),
                ),
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
              child: Row(
                children: [
                  Container(
                    width: 7,
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
                      color: Colors.red,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
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

  Widget _buildLyricsArea() {
    return ShaderMask(
      shaderCallback: (rect) {
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
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
          // Restart lyrics
          IconButton(
            icon: Icon(Icons.skip_previous_rounded,
                color: AppColors.white.withValues(alpha: 0.7), size: 32),
            onPressed: () {
              _pauseLyrics();
              setState(() => _currentLineIndex = 0);
              _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
              if (_isPlaying) _startLyrics();
            },
          ),

          // Play / Pause
          GestureDetector(
            onTap: () {
              setState(() => _isPlaying = !_isPlaying);
              if (_isPlaying) {
                _startLyrics();
              } else {
                _pauseLyrics();
              }
            },
            child: Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: AppColors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.black,
                size: 34,
              ),
            ),
          ),

          // Record toggle
          GestureDetector(
            onTap: () {
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
                border: Border.all(
                  color: Colors.red,
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.mic,
                color: _isRecording ? AppColors.white : Colors.red,
                size: 24,
              ),
            ),
          ),

          // Stop & go to results
          GestureDetector(
            onTap: () {
              _stopAll();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => ResultsPage(
                    songTitle: widget.songTitle,
                    songArtist: widget.songArtist,
                  ),
                ),
              );
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.stop_rounded,
                color: AppColors.white.withValues(alpha: 0.8),
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
