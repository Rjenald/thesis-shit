import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../constants/app_colors.dart';
import '../../core/audio_service.dart';
import '../../core/note_utils.dart';
import '../../models/session_result.dart';
import '../../data/song_lyrics.dart';
import '../../services/lyrics_service.dart';
import '../../services/song_audio_service.dart';
import 'results_page.dart';

class SongPlayerPage extends StatefulWidget {
  final String songTitle;
  final String songArtist;
  final String songImage;
  final bool isAssignment;

  const SongPlayerPage({
    super.key,
    required this.songTitle,
    required this.songArtist,
    this.songImage = '',
    this.isAssignment = false,
  });

  @override
  State<SongPlayerPage> createState() => _SongPlayerPageState();
}

class _SongPlayerPageState extends State<SongPlayerPage> {
  final AudioPlayer _player = AudioPlayer();
  final AudioService _micService = AudioService();

  bool _isPlaying = false;
  bool _isRecording = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  List<LrcLine> _lyrics = [];
  bool _lyricsLoading = true;
  int _currentLyricIdx = 0;
  final ScrollController _lyricsScroll = ScrollController();

  final List<double> _rawHz = [];
  final List<double> _rawCents = [];
  StreamSubscription<NoteResult?>? _micSub;

  final ValueNotifier<NoteResult?> _pitchNotifier = ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    _initAudio();
    _loadLyrics();
  }

  Future<void> _initAudio() async {
    final audioUrl = SongAudioService.getAudioUrl(widget.songTitle);
    if (audioUrl == null) return;

    try {
      await _player.setUrl(audioUrl);
      _duration = _player.duration ?? Duration.zero;
      setState(() {});
    } catch (_) {}

    _player.positionStream.listen((pos) {
      if (!mounted) return;
      setState(() => _position = pos);
      _updateLyricIndex(pos);
    });

    _player.durationStream.listen((dur) {
      if (!mounted || dur == null) return;
      setState(() => _duration = dur);
    });

    _player.playerStateStream.listen((state) {
      if (!mounted) return;
      if (state.processingState == ProcessingState.completed) {
        _onSongComplete();
      }
      setState(() => _isPlaying = state.playing);
    });
  }

  Future<void> _loadLyrics() async {
    // Try local lyrics first (always available offline)
    final local = LocalSongLyrics.getLyrics(widget.songTitle);
    if (local != null && local.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _lyrics = local;
        _lyricsLoading = false;
      });
      return;
    }
    // Fall back to online lyrics API
    final lines = await LyricsService.fetchLyrics(
      title: widget.songTitle,
      artist: widget.songArtist,
    );
    if (!mounted) return;
    setState(() {
      _lyrics = lines;
      _lyricsLoading = false;
    });
  }

  void _updateLyricIndex(Duration pos) {
    if (_lyrics.isEmpty) return;
    final ms = pos.inMilliseconds;
    int idx = 0;
    for (int i = 0; i < _lyrics.length; i++) {
      if (_lyrics[i].timestamp.inMilliseconds <= ms) {
        idx = i;
      } else {
        break;
      }
    }
    if (idx != _currentLyricIdx) {
      setState(() => _currentLyricIdx = idx);
      _scrollToLyric(idx);
    }
  }

  void _scrollToLyric(int idx) {
    if (!_lyricsScroll.hasClients) return;
    const rowH = 52.0;
    final offset =
        (idx * rowH) -
        (_lyricsScroll.position.viewportDimension / 2 - rowH / 2);
    _lyricsScroll.animateTo(
      offset.clamp(0.0, _lyricsScroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> _toggleMic() async {
    if (_isRecording) {
      await _stopMic();
    } else {
      await _startMic();
    }
  }

  Future<void> _startMic() async {
    final ok = await _micService.start();
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied')),
        );
      }
      return;
    }
    _micSub = _micService.results.listen((result) {
      if (!mounted) return;
      _rawHz.add(result?.frequency ?? 0);
      _rawCents.add(result?.cents ?? 0);
      _pitchNotifier.value = result;
    });
    setState(() => _isRecording = true);

    if (!_isPlaying) {
      await _player.play();
    }
  }

  Future<void> _stopMic() async {
    await _micSub?.cancel();
    _micSub = null;
    await _micService.stop();
    _pitchNotifier.value = null;
    setState(() => _isRecording = false);
  }

  void _onSongComplete() {
    _stopMic();
    _showResults();
  }

  void _showResults() {
    if (_rawHz.isEmpty) {
      Navigator.pop(context);
      return;
    }

    final session = SessionResult(
      songTitle: widget.songTitle,
      songArtist: widget.songArtist,
      songImage: widget.songImage,
      completedAt: DateTime.now(),
      lyricResults: _buildLyricResults(),
      durationSeconds: _position.inSeconds,
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ResultsPage(session: session, isAssignment: widget.isAssignment),
      ),
    );
  }

  List<LyricPitchData> _buildLyricResults() {
    final total = _rawHz.length;
    if (total == 0) return [];
    final segCount = _lyrics.isNotEmpty ? _lyrics.length.clamp(1, 30) : 30;
    final segSize = (total / segCount).ceil();
    return List.generate(segCount, (i) {
      final start = i * segSize;
      final end = (start + segSize).clamp(0, total);
      if (start >= total) return null;
      final lyricText =
          i < _lyrics.length ? _lyrics[i].text : 'Segment ${i + 1}';
      return LyricPitchData(
        lyricText: lyricText,
        pitchReadings: _rawHz.sublist(start, end),
        centsReadings: _rawCents.sublist(start, end),
      );
    }).whereType<LyricPitchData>().toList();
  }

  @override
  void dispose() {
    _player.dispose();
    _micSub?.cancel();
    _micService.dispose();
    _pitchNotifier.dispose();
    _lyricsScroll.dispose();
    super.dispose();
  }

  String _fmtDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSongInfo(),
            Expanded(child: _buildLyricsPanel()),
            if (_isRecording) _buildLivePitch(),
            _buildProgressBar(),
            _buildControls(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
            onPressed: () {
              _player.stop();
              Navigator.pop(context);
            },
          ),
          const Expanded(
            child: Text(
              'Now Playing',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'Roboto',
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.stop_circle_outlined, color: Colors.redAccent, size: 24),
            tooltip: 'Finish & See Results',
            onPressed: () {
              _player.stop();
              _stopMic();
              _showResults();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSongInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFF1E1E1E),
              image: widget.songImage.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(widget.songImage),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: widget.songImage.isEmpty
                ? const Icon(Icons.music_note, color: AppColors.primaryCyan, size: 28)
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.songTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Roboto',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.songArtist,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 14,
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

  Widget _buildLyricsPanel() {
    if (_lyricsLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryCyan),
      );
    }
    if (_lyrics.isEmpty) {
      return Center(
        child: Text(
          'No lyrics available\nSing along with the music!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 14,
            fontFamily: 'Roboto',
          ),
        ),
      );
    }
    return ListView.builder(
      controller: _lyricsScroll,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: _lyrics.length,
      itemBuilder: (context, index) {
        final isCurrent = index == _currentLyricIdx;
        return Container(
          height: 52,
          alignment: Alignment.centerLeft,
          child: Text(
            _lyrics[index].text,
            style: TextStyle(
              color: isCurrent
                  ? AppColors.primaryCyan
                  : Colors.white.withValues(alpha: 0.5),
              fontSize: isCurrent ? 18 : 15,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              fontFamily: 'Roboto',
            ),
          ),
        );
      },
    );
  }

  Widget _buildLivePitch() {
    return ValueListenableBuilder<NoteResult?>(
      valueListenable: _pitchNotifier,
      builder: (context, result, _) {
        final note = result?.noteName ?? '--';
        final cents = result?.cents ?? 0;
        final feedback = result?.feedback ?? PitchFeedback.noSignal;

        Color feedbackColor;
        String feedbackText;
        switch (feedback) {
          case PitchFeedback.correct:
            feedbackColor = const Color(0xFF4CAF50);
            feedbackText = 'In Tune';
            break;
          case PitchFeedback.tooHigh:
            feedbackColor = const Color(0xFFFF9800);
            feedbackText = 'Sharp (+${cents.abs().round()}¢)';
            break;
          case PitchFeedback.tooLow:
            feedbackColor = const Color(0xFFF44336);
            feedbackText = 'Flat (${cents.round()}¢)';
            break;
          case PitchFeedback.noSignal:
            feedbackColor = Colors.grey;
            feedbackText = 'Sing...';
            break;
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: feedbackColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: feedbackColor.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.mic, color: feedbackColor, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    note,
                    style: TextStyle(
                      color: feedbackColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ],
              ),
              Text(
                feedbackText,
                style: TextStyle(
                  color: feedbackColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Roboto',
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProgressBar() {
    final totalMs = _duration.inMilliseconds.toDouble();
    final posMs = _position.inMilliseconds.toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: AppColors.primaryCyan,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
              thumbColor: AppColors.primaryCyan,
            ),
            child: Slider(
              value: totalMs > 0 ? posMs.clamp(0, totalMs) : 0,
              max: totalMs > 0 ? totalMs : 1,
              onChanged: (v) {
                _player.seek(Duration(milliseconds: v.round()));
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _fmtDuration(_position),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                    fontFamily: 'Roboto',
                  ),
                ),
                Text(
                  _fmtDuration(_duration),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
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

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Rewind 10s
          IconButton(
            onPressed: () {
              final newPos = _position - const Duration(seconds: 10);
              _player.seek(newPos < Duration.zero ? Duration.zero : newPos);
            },
            icon: const Icon(Icons.replay_10, color: Colors.white70, size: 32),
          ),

          // Play/Pause
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: AppColors.primaryCyan,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.black,
                size: 32,
              ),
            ),
          ),

          // Forward 10s
          IconButton(
            onPressed: () {
              final newPos = _position + const Duration(seconds: 10);
              _player.seek(newPos > _duration ? _duration : newPos);
            },
            icon: const Icon(Icons.forward_10, color: Colors.white70, size: 32),
          ),

          // Mic toggle
          GestureDetector(
            onTap: _toggleMic,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: _isRecording
                    ? Colors.redAccent
                    : Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _isRecording
                      ? Colors.redAccent
                      : AppColors.primaryCyan,
                  width: 2,
                ),
              ),
              child: Icon(
                _isRecording ? Icons.mic_off : Icons.mic,
                color: _isRecording ? Colors.white : AppColors.primaryCyan,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
