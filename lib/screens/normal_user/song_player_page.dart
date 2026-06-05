import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../constants/app_colors.dart';
import '../../core/audio_service.dart';
import '../../core/note_utils.dart';
import '../../models/session_result.dart';
import '../../data/song_lyrics.dart';
import '../../services/lyrics_service.dart';
import '../../services/song_audio_service.dart';
import '../../services/karaoke_video_service.dart';
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
  AudioService? _micService;

  bool _isPlaying = false;
  bool _isRecording = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  List<LrcLine> _lyrics = [];
  bool _lyricsLoading = true;
  int _currentLyricIdx = -1;

  final List<double> _rawHz = [];
  final List<double> _rawCents = [];
  StreamSubscription<NoteResult?>? _micSub;

  // Voice recording
  StreamSubscription<List<int>>? _bytesSub;
  final List<int> _recordedPcm = [];

  // Live scoring
  int _correctCount = 0;
  int _totalDetections = 0;

  // Pitch feedback
  String _pitchLabel = '';
  Color _pitchColor = Colors.transparent;
  IconData _pitchIcon = Icons.mic_none;

  // YouTube
  YoutubePlayerController? _ytController;

  @override
  void initState() {
    super.initState();
    _initYouTube();
    _initAudio();
    _loadLyrics();
  }

  void _initYouTube() {
    final videoId = KaraokeVideoService.getVideoId(widget.songTitle);
    if (videoId != null) {
      _ytController = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: false,
          mute: true,
          hideControls: true,
          disableDragSeek: true,
          loop: true,
          showLiveFullscreenButton: false,
          forceHD: false,
          enableCaption: false,
        ),
      );
    }
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
      if (state.processingState == ProcessingState.completed) _onSongComplete();
      setState(() => _isPlaying = state.playing);
    });
  }

  Future<void> _loadLyrics() async {
    final local = LocalSongLyrics.getLyrics(widget.songTitle);
    if (local != null && local.isNotEmpty) {
      if (!mounted) return;
      setState(() { _lyrics = local; _lyricsLoading = false; });
      return;
    }
    try {
      final online = await LyricsService.fetchLyrics(
          title: widget.songTitle, artist: widget.songArtist);
      if (online.isNotEmpty && mounted) {
        setState(() { _lyrics = online; _lyricsLoading = false; });
        return;
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() => _lyricsLoading = false);
  }

  void _updateLyricIndex(Duration pos) {
    if (_lyrics.isEmpty) return;
    final ms = pos.inMilliseconds;
    int idx = -1;
    for (int i = 0; i < _lyrics.length; i++) {
      if (_lyrics[i].timestamp.inMilliseconds <= ms) idx = i;
      else break;
    }
    if (idx == -1 && _isPlaying && _lyrics.first.timestamp.inMilliseconds == 0) {
      idx = 0;
    }
    if (idx != _currentLyricIdx) {
      _currentLyricIdx = idx;
      if (mounted) setState(() {});
    }
  }

  /// How many words of the current line should be highlighted (word-by-word)
  int _getHighlightedWordCount() {
    if (_currentLyricIdx < 0 || _currentLyricIdx >= _lyrics.length) return 0;
    final lineStart = _lyrics[_currentLyricIdx].timestamp.inMilliseconds;
    final lineEnd = _currentLyricIdx + 1 < _lyrics.length
        ? _lyrics[_currentLyricIdx + 1].timestamp.inMilliseconds
        : lineStart + 5000;
    final dur = lineEnd - lineStart;
    if (dur <= 0) return 0;
    final elapsed = _position.inMilliseconds - lineStart;
    final progress = (elapsed / dur).clamp(0.0, 1.0);
    final words = _lyrics[_currentLyricIdx].text.split(' ');
    return (progress * words.length).ceil().clamp(0, words.length);
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
      _ytController?.pause();
    } else {
      await _player.play();
      _ytController?.play();
    }
  }

  Future<void> _toggleMic() async {
    _isRecording ? await _stopMic() : await _startMic();
  }

  Future<void> _startMic() async {
    _micService = AudioService();
    final ok = await _micService!.start();
    if (!ok) {
      _micService?.dispose(); _micService = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission denied')));
      }
      return;
    }
    _recordedPcm.clear(); _correctCount = 0; _totalDetections = 0;

    _bytesSub = _micService!.rawBytes.listen((b) => _recordedPcm.addAll(b));

    _micSub = _micService!.results.listen((result) {
      if (!mounted) return;
      _rawHz.add(result?.frequency ?? 0);
      _rawCents.add(result?.cents ?? 0);
      if (result != null && result.feedback != PitchFeedback.noSignal) {
        _totalDetections++;
        setState(() {
          if (result.feedback == PitchFeedback.correct) {
            _correctCount++;
            final ac = result.cents.abs();
            if (ac <= 5) {
              _pitchLabel = 'PERFECT'; _pitchColor = const Color(0xFF4CAF50);
              _pitchIcon = Icons.star;
            } else if (ac <= 10) {
              _pitchLabel = 'GREAT'; _pitchColor = const Color(0xFF2196F3);
              _pitchIcon = Icons.check_circle;
            } else {
              _pitchLabel = 'GOOD'; _pitchColor = const Color(0xFFFF9800);
              _pitchIcon = Icons.thumb_up;
            }
          } else {
            _pitchLabel = 'MISS'; _pitchColor = const Color(0xFFF44336);
            _pitchIcon = Icons.close;
          }
        });
      }
    });
    setState(() => _isRecording = true);
    if (!_isPlaying) { await _player.play(); _ytController?.play(); }
  }

  Future<void> _stopMic() async {
    await _bytesSub?.cancel(); _bytesSub = null;
    await _micSub?.cancel(); _micSub = null;
    await _micService?.stop(); _micService?.dispose(); _micService = null;
    setState(() { _isRecording = false; _pitchLabel = ''; _pitchColor = Colors.transparent; });
  }

  void _onSongComplete() { _stopMic(); _showResults(); }

  void _showResults() {
    if (_rawHz.isEmpty) { Navigator.pop(context); return; }
    Uint8List? wav;
    if (_recordedPcm.isNotEmpty) wav = _buildWav(_recordedPcm);
    final session = SessionResult(
      songTitle: widget.songTitle, songArtist: widget.songArtist,
      songImage: widget.songImage, completedAt: DateTime.now(),
      lyricResults: _buildLyricResults(), durationSeconds: _position.inSeconds,
    );
    Navigator.pushReplacement(context, MaterialPageRoute(
      builder: (_) => ResultsPage(
        session: session, isAssignment: widget.isAssignment, recordedVoiceWav: wav),
    ));
  }

  List<LyricPitchData> _buildLyricResults() {
    final total = _rawHz.length;
    if (total == 0) return [];
    final seg = _lyrics.isNotEmpty ? _lyrics.length.clamp(1, 30) : 30;
    final sz = (total / seg).ceil();
    return List.generate(seg, (i) {
      final s = i * sz; final e = (s + sz).clamp(0, total);
      if (s >= total) return null;
      return LyricPitchData(
        lyricText: i < _lyrics.length ? _lyrics[i].text : 'Segment ${i + 1}',
        pitchReadings: _rawHz.sublist(s, e), centsReadings: _rawCents.sublist(s, e));
    }).whereType<LyricPitchData>().toList();
  }

  Uint8List _buildWav(List<int> pcm) {
    const sr = 16000; const ch = 1; const bps = 16;
    final br = sr * ch * bps ~/ 8; final ba = ch * bps ~/ 8; final n = pcm.length;
    final b = ByteData(44 + n);
    b.setUint8(0,0x52);b.setUint8(1,0x49);b.setUint8(2,0x46);b.setUint8(3,0x46);
    b.setUint32(4,36+n,Endian.little);
    b.setUint8(8,0x57);b.setUint8(9,0x41);b.setUint8(10,0x56);b.setUint8(11,0x45);
    b.setUint8(12,0x66);b.setUint8(13,0x6D);b.setUint8(14,0x74);b.setUint8(15,0x20);
    b.setUint32(16,16,Endian.little);b.setUint16(20,1,Endian.little);
    b.setUint16(22,ch,Endian.little);b.setUint32(24,sr,Endian.little);
    b.setUint32(28,br,Endian.little);b.setUint16(32,ba,Endian.little);
    b.setUint16(34,bps,Endian.little);
    b.setUint8(36,0x64);b.setUint8(37,0x61);b.setUint8(38,0x74);b.setUint8(39,0x61);
    b.setUint32(40,n,Endian.little);
    for(int i=0;i<n;i++) b.setUint8(44+i,pcm[i]&0xFF);
    return b.buffer.asUint8List();
  }

  double get _liveScore => _totalDetections > 0 ? (_correctCount / _totalDetections * 100) : 0;
  String _getRank(double s) {
    if(s>=95)return'S+';if(s>=90)return'S';if(s>=80)return'A';
    if(s>=65)return'B';if(s>=50)return'C';return'D';
  }
  Color _getRankColor(String r) {
    switch(r){case'S+':case'S':return const Color(0xFFFFD700);
    case'A':return const Color(0xFF4CAF50);case'B':return const Color(0xFF2196F3);
    case'C':return const Color(0xFFFF9800);default:return const Color(0xFFF44336);}
  }
  String _fmt(Duration d) {
    final m=d.inMinutes.toString().padLeft(2,'0');
    final s=(d.inSeconds%60).toString().padLeft(2,'0');return'$m:$s';
  }

  @override
  void dispose() {
    _ytController?.dispose(); _player.dispose();
    _bytesSub?.cancel(); _micSub?.cancel(); _micService?.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            // Video + lyrics overlay (fills main area)
            Expanded(child: _buildVideoWithLyrics()),
            // Pitch + score bar
            if (_isRecording) _buildBottomInfo(),
            // Progress + controls
            _buildProgressBar(),
            _buildControls(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── HEADER ──
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            onPressed: () { _player.stop(); _ytController?.pause(); _stopMic(); Navigator.pop(context); },
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.songTitle,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700, fontFamily: 'Roboto'),
                    overflow: TextOverflow.ellipsis),
                Text(widget.songArtist,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11, fontFamily: 'Roboto'),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (_isRecording)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(10)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.fiber_manual_record, color: Colors.white, size: 8),
                SizedBox(width: 3),
                Text('REC', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Roboto')),
              ]),
            ),
        ],
      ),
    );
  }

  // ── VIDEO + LYRICS OVERLAY (like real karaoke TV) ──
  Widget _buildVideoWithLyrics() {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Layer 1: Video background ──
          _buildVideo(),

          // ── Layer 2: Dark gradient at bottom for lyrics readability ──
          Positioned(
            left: 0, right: 0, bottom: 0,
            height: 140,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                    Colors.black.withValues(alpha: 0.9),
                  ],
                ),
              ),
            ),
          ),

          // ── Layer 3: Lyrics at bottom (word-by-word karaoke) ──
          Positioned(
            left: 16, right: 16, bottom: 16,
            child: _buildKaraokeLyrics(),
          ),
        ],
      ),
    );
  }

  Widget _buildVideo() {
    if (_ytController != null) {
      return IgnorePointer(
        child: YoutubePlayer(
          controller: _ytController!,
          showVideoProgressIndicator: false,
          aspectRatio: 16 / 9,
        ),
      );
    }
    // Fallback gradient
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF0D1B2A), Color(0xFF1A0A3E), Color(0xFF0A2A4E), Color(0xFF0D1B2A)],
        ),
      ),
      child: Center(
        child: Icon(Icons.music_note, color: Colors.white.withValues(alpha: 0.1), size: 64),
      ),
    );
  }

  // ── KARAOKE LYRICS — word-by-word highlighting like real karaoke machine ──
  Widget _buildKaraokeLyrics() {
    if (_lyricsLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)));
    }
    if (_lyrics.isEmpty) {
      return Text('Sing along!',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 16, fontFamily: 'Roboto'));
    }

    final idx = _currentLyricIdx < 0 ? 0 : _currentLyricIdx;
    final currentText = idx < _lyrics.length ? _lyrics[idx].text : '';
    final nextText = idx + 1 < _lyrics.length ? _lyrics[idx + 1].text : '';
    final highlightCount = _getHighlightedWordCount();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── CURRENT LINE — word-by-word yellow highlight ──
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _buildWordByWordLine(currentText, highlightCount, idx),
        ),
        if (nextText.isNotEmpty) ...[
          const SizedBox(height: 8),
          // ── NEXT LINE — white, waiting ──
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              nextText,
              key: ValueKey('next_${idx + 1}'),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'Roboto',
                shadows: const [
                  Shadow(offset: Offset(-1, -1), blurRadius: 1, color: Colors.black),
                  Shadow(offset: Offset(1, 1), blurRadius: 1, color: Colors.black),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Builds a line where the first [highlightCount] words are yellow (sung)
  /// and the rest are white (not yet sung) — like a real karaoke machine.
  Widget _buildWordByWordLine(String text, int highlightCount, int lineIdx) {
    final words = text.split(' ');

    const yellowShadows = [
      Shadow(offset: Offset(-2, -2), blurRadius: 1, color: Colors.black),
      Shadow(offset: Offset(2, -2), blurRadius: 1, color: Colors.black),
      Shadow(offset: Offset(-2, 2), blurRadius: 1, color: Colors.black),
      Shadow(offset: Offset(2, 2), blurRadius: 1, color: Colors.black),
      Shadow(color: Color(0x99FFD700), blurRadius: 12),
    ];

    const whiteShadows = [
      Shadow(offset: Offset(-1.5, -1.5), blurRadius: 1, color: Colors.black),
      Shadow(offset: Offset(1.5, -1.5), blurRadius: 1, color: Colors.black),
      Shadow(offset: Offset(-1.5, 1.5), blurRadius: 1, color: Colors.black),
      Shadow(offset: Offset(1.5, 1.5), blurRadius: 1, color: Colors.black),
    ];

    return RichText(
      key: ValueKey('wbw_$lineIdx'),
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        children: words.asMap().entries.map((entry) {
          final i = entry.key;
          final word = entry.value;
          final isSung = i < highlightCount;
          final space = i < words.length - 1 ? ' ' : '';

          return TextSpan(
            text: '$word$space',
            style: TextStyle(
              color: isSung ? const Color(0xFFFFD700) : Colors.white,
              fontSize: 20,
              fontWeight: isSung ? FontWeight.w900 : FontWeight.w700,
              fontFamily: 'Roboto',
              letterSpacing: 0.3,
              shadows: isSung ? yellowShadows : whiteShadows,
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── BOTTOM INFO: Score + Pitch badge ──
  Widget _buildBottomInfo() {
    final score = _liveScore;
    final rank = _getRank(score);
    final rc = _getRankColor(rank);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: [
          // Score + Rank
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${score.toStringAsFixed(0)}%',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Roboto')),
                const SizedBox(width: 8),
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: rc.withValues(alpha: 0.15), shape: BoxShape.circle,
                    border: Border.all(color: rc, width: 2),
                  ),
                  child: Center(child: Text(rank,
                      style: TextStyle(color: rc, fontSize: rank.length > 1 ? 9 : 13,
                          fontWeight: FontWeight.w900, fontFamily: 'Roboto'))),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Pitch badge
          if (_pitchLabel.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: _pitchColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _pitchColor.withValues(alpha: 0.5), width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_pitchIcon, color: _pitchColor, size: 14),
                  const SizedBox(width: 4),
                  Text(_pitchLabel,
                      style: TextStyle(color: _pitchColor, fontSize: 12,
                          fontWeight: FontWeight.w800, fontFamily: 'Roboto', letterSpacing: 1)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── PROGRESS ──
  Widget _buildProgressBar() {
    final p = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Row(
        children: [
          Text(_fmt(_position), style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10, fontFamily: 'Roboto')),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: p, minHeight: 3,
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(_fmt(_duration), style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10, fontFamily: 'Roboto')),
        ],
      ),
    );
  }

  // ── CONTROLS ──
  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ctrlBtn(icon: _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, onTap: _togglePlay),
          // Record button
          GestureDetector(
            onTap: _toggleMic,
            child: Container(
              width: 58, height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _isRecording ? Colors.red : Colors.white, width: 3),
              ),
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: _isRecording ? 20 : 40, height: _isRecording ? 20 : 40,
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(_isRecording ? 5 : 20)),
                ),
              ),
            ),
          ),
          _ctrlBtn(icon: Icons.stop_rounded, onTap: () {
            _player.stop(); _ytController?.pause(); _stopMic();
            _rawHz.isNotEmpty ? _showResults() : Navigator.pop(context);
          }),
        ],
      ),
    );
  }

  Widget _ctrlBtn({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46, height: 46,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08), shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}
