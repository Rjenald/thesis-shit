# YouTube Karaoke Integration Guide

## Overview
This guide integrates YouTube video playback with your existing karaoke system, synchronizing lyrics and pitch detection with YouTube videos.

---

## 1. REQUIRED PACKAGES

Your `pubspec.yaml` already has most dependencies. Ensure these are present:

```yaml
dependencies:
  flutter:
    sdk: flutter
  youtube_player_iframe: ^5.0.0      # ✓ Already installed
  video_player: ^2.9.2               # ✓ Already installed
  youtube_explode_dart: ^3.0.5       # ✓ Already installed (for metadata)
  record: ^6.0.0                     # ✓ Already installed
  just_audio: ^0.10.5                # ✓ Already installed
  permission_handler: ^12.0.1        # ✓ Already installed
  http: ^1.2.0                       # ✓ Already installed
  shared_preferences: ^2.3.0         # ✓ Already installed
  
  # NEW - Optional enhancements
  audio_waveforms: ^1.0.7            # For waveform visualization
  vibration: ^1.8.4                  # For haptic feedback
```

---

## 2. ARCHITECTURE OVERVIEW

```
YouTube Karaoke Flow:
┌─────────────────────────────────────────────────────────┐
│ User selects song → YouTube video fetched              │
├─────────────────────────────────────────────────────────┤
│ YouTubeKaraokePlayer (Main Widget)                      │
│   ├── YouTube Video Player (Top)                        │
│   ├── Lyrics Display (Middle) - synced with video time  │
│   ├── Pitch Detection (Real-time)                       │
│   └── Controls (Bottom)                                 │
├─────────────────────────────────────────────────────────┤
│ Data Flow:                                              │
│   1. Video plays → currentTime updates                  │
│   2. currentTime compared to lyric timestamps           │
│   3. Highlight current lyric line                       │
│   4. Capture user voice & detect pitch                  │
│   5. Store results with timestamps                      │
└─────────────────────────────────────────────────────────┘
```

---

## 3. KEY SERVICES & MODELS

### 3.1 YouTube Karaoke Session Model

```dart
// lib/models/youtube_karaoke_session.dart
class YouTubeKaraokeSession {
  final String videoId;
  final String title;
  final String artist;
  final String thumbnailUrl;
  final Duration videoDuration;
  final List<TimedLyricLine> lyrics;
  final DateTime startedAt;
  
  YouTubeKaraokeSession({
    required this.videoId,
    required this.title,
    required this.artist,
    required this.thumbnailUrl,
    required this.videoDuration,
    required this.lyrics,
    DateTime? startedAt,
  }) : startedAt = startedAt ?? DateTime.now();
}

class TimedLyricLine {
  final String text;
  final Duration startTime;   // When lyric appears
  final Duration endTime;     // When lyric disappears
  final double targetPitch;   // Reference pitch (optional)
  
  TimedLyricLine({
    required this.text,
    required this.startTime,
    required this.endTime,
    this.targetPitch = 0.0,
  });
  
  bool isActive(Duration currentTime) =>
      currentTime >= startTime && currentTime < endTime;
}
```

### 3.2 YouTube Service

```dart
// lib/services/youtube_karaoke_service.dart
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class YouTubeKaraokeService {
  static final _yt = YoutubeExplode();
  
  /// Extract video ID from URL
  static String extractVideoId(String url) {
    // Handle various YouTube URL formats
    if (url.contains('youtube.com')) {
      return url.split('v=')[1].split('&').first;
    } else if (url.contains('youtu.be/')) {
      return url.split('youtu.be/')[1].split('?').first;
    }
    return url;
  }
  
  /// Fetch video metadata
  static Future<Video?> getVideoMetadata(String videoId) async {
    try {
      final video = await _yt.videos.get(videoId);
      return video;
    } catch (e) {
      print('Error fetching video: $e');
      return null;
    }
  }
  
  /// Search for karaoke videos
  static Future<List<Video>> searchKaraokeVideos(String query) async {
    try {
      final searchQuery = '$query karaoke';
      final results = await _yt.search.search(searchQuery);
      return results.whereType<Video>().toList();
    } catch (e) {
      print('Error searching: $e');
      return [];
    }
  }
  
  void dispose() => _yt.close();
}
```

### 3.3 Lyrics Sync Service

```dart
// lib/services/lyrics_sync_service.dart
class LyricsSyncService {
  /// Calculate which lyric line should be displayed
  static int getCurrentLineIndex(
    Duration currentTime,
    List<TimedLyricLine> lyrics,
  ) {
    for (int i = 0; i < lyrics.length; i++) {
      if (lyrics[i].isActive(currentTime)) {
        return i;
      }
    }
    return -1; // No active line
  }
  
  /// Parse lyrics with timestamps (LRC format)
  /// Format: [00:12.34]This is a lyric line
  static List<TimedLyricLine> parseLrcLyrics(String lrcContent) {
    final lines = <TimedLyricLine>[];
    final pattern = RegExp(r'\[(\d{2}):(\d{2}\.\d{2})\](.*?)(?=\[|$)');
    
    for (final match in pattern.allMatches(lrcContent)) {
      final minutes = int.parse(match.group(1)!);
      final secondsStr = match.group(2)!;
      final seconds = double.parse(secondsStr);
      final text = match.group(3)!.trim();
      
      if (text.isNotEmpty) {
        final startTime = Duration(
          milliseconds: (minutes * 60000 + seconds * 1000).toInt(),
        );
        
        lines.add(TimedLyricLine(
          text: text,
          startTime: startTime,
          endTime: startTime + const Duration(seconds: 3), // 3 sec per line
        ));
      }
    }
    
    return lines;
  }
  
  /// Adjust lyric timings (for syncing issues)
  static List<TimedLyricLine> offsetLyrics(
    List<TimedLyricLine> lyrics,
    Duration offset,
  ) {
    return lyrics.map((lyric) {
      return TimedLyricLine(
        text: lyric.text,
        startTime: lyric.startTime + offset,
        endTime: lyric.endTime + offset,
        targetPitch: lyric.targetPitch,
      );
    }).toList();
  }
}
```

---

## 4. MAIN YOUTUBE KARAOKE PLAYER WIDGET

```dart
// lib/screens/youtube_karaoke_player.dart
import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'dart:async';

import '../models/youtube_karaoke_session.dart';
import '../services/youtube_karaoke_service.dart';
import '../services/lyrics_sync_service.dart';
import '../core/audio_service.dart';
import '../constants/app_colors.dart';

class YouTubeKaraokePlayer extends StatefulWidget {
  final YouTubeKaraokeSession session;
  
  const YouTubeKaraokePlayer({
    super.key,
    required this.session,
  });

  @override
  State<YouTubeKaraokePlayer> createState() => _YouTubeKaraokePlayerState();
}

class _YouTubeKaraokePlayerState extends State<YouTubeKaraokePlayer> {
  // ── YouTube Player ─────────────────────────────────────────────────────
  late YoutubePlayerController _youtubeController;
  bool _playerReady = false;
  
  // ── Playback State ─────────────────────────────────────────────────────
  bool _isPlaying = false;
  bool _isRecording = false;
  Duration _currentPosition = Duration.zero;
  Timer? _positionUpdateTimer;
  
  // ── Lyrics & Sync ──────────────────────────────────────────────────────
  int _currentLyricIndex = -1;
  final ScrollController _lyricsScrollController = ScrollController();
  final List<GlobalKey> _lyricLineKeys = [];
  
  // ── Audio & Pitch ──────────────────────────────────────────────────────
  final AudioService _audioService = AudioService();
  StreamSubscription<NoteResult?>? _audioSub;
  
  // Live feedback
  PitchFeedback _liveFeedback = PitchFeedback.noSignal;
  String _liveNote = '';
  double _liveCents = 0;
  double _liveClarity = 0.0;
  final List<double> _pitchHistory = [];
  static const int _maxPitchHistory = 80;
  
  // Per-line pitch data
  late List<List<double>> _linePitches;
  late List<List<double>> _lineCents;

  @override
  void initState() {
    super.initState();
    _initializeYouTubePlayer();
    _initializeLyricsUI();
  }

  void _initializeYouTubePlayer() {
    _youtubeController = YoutubePlayerController(
      params: YoutubePlayerParams(
        playlist: [widget.session.videoId],
        autoPlay: false,
        showControls: false,
        showFullscreenButton: false,
      ),
    );
    
    _youtubeController.onPlayerStateChange.listen((state) {
      setState(() {
        _isPlaying = state == PlayerState.playing;
      });
      
      if (_isPlaying) {
        _startPositionTracking();
        _startRecording();
      } else {
        _positionUpdateTimer?.cancel();
      }
    });
  }

  void _initializeLyricsUI() {
    _lyricLineKeys.clear();
    for (int i = 0; i < widget.session.lyrics.length; i++) {
      _lyricLineKeys.add(GlobalKey());
    }
    
    _linePitches = List.generate(
      widget.session.lyrics.length,
      (_) => [],
    );
    _lineCents = List.generate(
      widget.session.lyrics.length,
      (_) => [],
    );
  }

  /// Track video position in real-time
  void _startPositionTracking() {
    _positionUpdateTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) async {
        final position = await _youtubeController.currentTime;
        
        setState(() {
          _currentPosition = Duration(seconds: position.toInt());
          _currentLyricIndex = LyricsSyncService.getCurrentLineIndex(
            _currentPosition,
            widget.session.lyrics,
          );
        });
        
        _scrollToCurrentLyric();
      },
    );
  }

  /// Auto-scroll to current lyric
  void _scrollToCurrentLyric() {
    if (_currentLyricIndex >= 0 && 
        _currentLyricIndex < _lyricLineKeys.length) {
      final ctx = _lyricLineKeys[_currentLyricIndex].currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.4,
        );
      }
    }
  }

  /// Start capturing user voice
  Future<void> _startRecording() async {
    final ok = await _audioService.start();
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission denied')),
      );
      return;
    }

    _audioSub = _audioService.results.listen((result) {
      if (!mounted) return;
      
      final i = _currentLyricIndex;
      if (i >= 0 && i < _linePitches.length) {
        if (result != null) {
          _linePitches[i].add(result.frequency);
          _lineCents[i].add(result.cents);
        }
      }
      
      setState(() {
        if (result != null) {
          _liveFeedback = result.feedback;
          _liveNote = result.fullName;
          _liveCents = result.cents;
          _liveClarity = result.confidence;
          _pitchHistory.add(result.frequency);
        } else {
          _pitchHistory.add(0);
        }
        
        if (_pitchHistory.length > _maxPitchHistory) {
          _pitchHistory.removeAt(0);
        }
      });
    });
    
    setState(() => _isRecording = true);
  }

  Future<void> _stopRecording() async {
    await _audioSub?.cancel();
    _audioSub = null;
    await _audioService.stop();
    setState(() {
      _isRecording = false;
      _liveFeedback = PitchFeedback.noSignal;
    });
  }

  @override
  void dispose() {
    _youtubeController.close();
    _positionUpdateTimer?.cancel();
    _audioSub?.cancel();
    _audioService.dispose();
    _lyricsScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ─────────────────────────────────────────────────────
            _buildHeader(),
            
            // ── YouTube Player ─────────────────────────────────────────────
            _buildYouTubePlayer(),
            
            // ── Live Pitch Display ─────────────────────────────────────────
            if (_isRecording) _buildLivePitchBar(),
            if (_isRecording) _buildPitchGraph(),
            
            // ── Lyrics Display ─────────────────────────────────────────────
            Expanded(child: _buildLyricsArea()),
            
            // ── Controls ───────────────────────────────────────────────────
            _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const Spacer(),
          Column(
            children: [
              Text(
                'YOUTUBE KARAOKE',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                widget.session.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          const Spacer(),
          Text(
            _formatDuration(_currentPosition),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildYouTubePlayer() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 8,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: YoutubePlayer(
          controller: _youtubeController,
          aspectRatio: 16 / 9,
        ),
      ),
    );
  }

  Widget _buildLivePitchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.inputBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _feedbackColor.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.graphic_eq, color: _feedbackColor, size: 16),
            const SizedBox(width: 8),
            Text(
              _liveNote.isEmpty ? '—' : _liveNote,
              style: TextStyle(
                color: _feedbackColor,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: (_liveCents.clamp(-50, 50) + 50) / 100,
                  minHeight: 4,
                  backgroundColor: AppColors.inputBg,
                  valueColor: AlwaysStoppedAnimation<Color>(_feedbackColor),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _feedbackLabel,
              style: TextStyle(
                color: _feedbackColor,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPitchGraph() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: AppColors.inputBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.primaryCyan.withValues(alpha: 0.1),
          ),
        ),
        child: CustomPaint(
          painter: _PitchGraphPainter(List<double>.from(_pitchHistory)),
        ),
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
          stops: [0.0, 0.15, 0.85, 1.0],
        ).createShader(rect);
      },
      blendMode: BlendMode.dstIn,
      child: SingleChildScrollView(
        controller: _lyricsScrollController,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...List.generate(widget.session.lyrics.length, (i) {
              final lyric = widget.session.lyrics[i];
              final isCurrent = i == _currentLyricIndex;
              final isPast = i < _currentLyricIndex;

              return Padding(
                key: _lyricLineKeys[i],
                padding: const EdgeInsets.only(bottom: 8),
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 250),
                  style: TextStyle(
                    fontSize: isCurrent ? 26 : 18,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                    color: isCurrent
                        ? Colors.white
                        : isPast
                        ? Colors.white.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.4),
                    height: 1.4,
                  ),
                  child: Text(lyric.text),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Play / Pause
          GestureDetector(
            onTap: () {
              if (_isPlaying) {
                _youtubeController.pauseVideo();
                _positionUpdateTimer?.cancel();
              } else {
                _youtubeController.playVideo();
              }
            },
            child: Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.black,
                size: 28,
              ),
            ),
          ),

          // Record Toggle
          GestureDetector(
            onTap: () async {
              if (_isRecording) {
                await _stopRecording();
              } else {
                await _startRecording();
              }
            },
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isRecording
                    ? Colors.red
                    : Colors.red.withValues(alpha: 0.15),
                border: Border.all(color: Colors.red, width: 2),
              ),
              child: Icon(
                Icons.mic,
                color: _isRecording ? Colors.white : Colors.red,
                size: 20,
              ),
            ),
          ),

          // Finish
          GestureDetector(
            onTap: () {
              _youtubeController.pauseVideo();
              Navigator.pop(context);
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.stop,
                color: Colors.white.withValues(alpha: 0.8),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────

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

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

// ── Pitch Graph Painter ────────────────────────────────────────────────────

class _PitchGraphPainter extends CustomPainter {
  final List<double> data;
  _PitchGraphPainter(this.data);

  double _hzToY(double hz, double height) {
    const double minHz = 80.0;
    const double maxHz = 1100.0;
    if (hz <= 0) return height;
    final logMin = math.log(minHz);
    final logMax = math.log(maxHz);
    final logHz = math.log(hz.clamp(minHz, maxHz));
    return height - ((logHz - logMin) / (logMax - logMin)) * height;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final w = size.width;
    final h = size.height;
    final count = data.length;
    final step = count > 1 ? w / (count - 1) : w;

    final points = [
      for (int i = 0; i < count; i++)
        Offset(i * step, _hzToY(data[i], h)),
    ];

    if (points.length > 1) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }

      canvas.drawPath(
        path,
        Paint()
          ..color = AppColors.primaryCyan
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(_PitchGraphPainter old) =>
      old.data.length != data.length;
}

import 'dart:math' as math;
```

---

## 5. HOW TO SYNC LYRICS WITH VIDEO TIMESTAMPS

### 5.1 LRC Format (Recommended)
Save lyrics in `.lrc` format with timestamps:

```
[00:12.34]First line of lyrics
[00:18.56]Second line of lyrics
[00:24.78]Third line of lyrics
```

### 5.2 Fetch from Online Services

```dart
// lib/services/lyrics_sync_service.dart - Extension
class LyricsSyncService {
  /// Fetch lyrics with timestamps from LrcLib
  static Future<List<TimedLyricLine>> fetchTimedLyrics(
    String songTitle,
    String artist,
  ) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://lrclib.net/api/get?'
          'artist_name=${Uri.encodeComponent(artist)}&'
          'track_name=${Uri.encodeComponent(songTitle)}'
        ),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final plainLyrics = json['plainLyrics'] as String?;
        
        if (plainLyrics != null) {
          return parseLrcLyrics(plainLyrics);
        }
      }
    } catch (e) {
      print('Error fetching timed lyrics: $e');
    }
    return [];
  }
}
```

### 5.3 Manual Sync Adjustment

```dart
// Allow user to adjust sync if timing is off
void adjustLyricSync(Duration offset) {
  widget.session.lyrics = LyricsSyncService.offsetLyrics(
    widget.session.lyrics,
    offset,
  );
}
```

---

## 6. REAL-TIME PITCH DETECTION INTEGRATION

Your `AudioService` already handles pitch detection. Here's how to enhance it:

```dart
// lib/core/audio_service.dart - Enhancement
extension PitchFeedback on AudioService {
  /// Compare user pitch with target pitch from karaoke track
  PitchFeedback compareWithTarget(
    double userPitch,
    double targetPitch,
  ) {
    if (userPitch == 0) return PitchFeedback.noSignal;
    
    final ratio = userPitch / targetPitch;
    final cents = 1200 * math.log2(ratio);
    
    if (cents.abs() < 25) {
      return PitchFeedback.correct;
    } else if (cents > 0) {
      return PitchFeedback.tooHigh;
    } else {
      return PitchFeedback.tooLow;
    }
  }
}
```

---

## 7. IMPLEMENTATION CHECKLIST

### Phase 1: Basic YouTube Integration
- [ ] Create `YouTubeKaraokeSession` model
- [ ] Create `YouTubeKaraokeService` for video fetching
- [ ] Build basic YouTube player widget
- [ ] Test video playback

### Phase 2: Lyrics Synchronization
- [ ] Create `TimedLyricLine` model
- [ ] Implement `LyricsSyncService` for LRC parsing
- [ ] Integrate lyrics fetching (LrcLib)
- [ ] Build lyrics display UI
- [ ] Test position tracking & lyric highlighting

### Phase 3: Pitch Detection
- [ ] Integrate existing `AudioService`
- [ ] Capture user voice while video plays
- [ ] Store pitch readings with timestamps
- [ ] Display live pitch feedback

### Phase 4: Results & Scoring
- [ ] Save karaoke session data
- [ ] Generate accuracy score based on pitch match
- [ ] Display results page with replay option

---

## 8. SAMPLE FLOW: LAUNCHING KARAOKE SESSION

```dart
// From search results or song selection
void launchYouTubeKaraoke(String videoId, String title, String artist) async {
  // 1. Fetch video metadata
  final service = YouTubeKaraokeService();
  final video = await service.getVideoMetadata(videoId);
  
  // 2. Fetch lyrics with timestamps
  final lyrics = await LyricsSyncService.fetchTimedLyrics(title, artist);
  
  // 3. Create session
  final session = YouTubeKaraokeSession(
    videoId: videoId,
    title: title,
    artist: artist,
    thumbnailUrl: video?.thumbnails.highResUrl ?? '',
    videoDuration: video?.duration ?? const Duration(minutes: 3),
    lyrics: lyrics,
  );
  
  // 4. Launch player
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => YouTubeKaraokePlayer(session: session),
    ),
  );
}
```

---

## 9. OPTIONAL ENHANCEMENTS

### Score Calculation
```dart
class KaraokeScore {
  final double accuracyPercent;
  final int notesHit;
  final int totalNotes;
  
  String get grade {
    if (accuracyPercent >= 90) return 'S';
    if (accuracyPercent >= 80) return 'A';
    if (accuracyPercent >= 70) return 'B';
    if (accuracyPercent >= 60) return 'C';
    return 'D';
  }
}
```

### Haptic Feedback
```dart
import 'package:vibration/vibration.dart';

// Vibrate when hitting correct pitch
if (feedback == PitchFeedback.correct) {
  Vibration.vibrate(duration: 50, amplitude: 80);
}
```

### Waveform Visualization
```dart
// Add to pitch graph or use audio_waveforms package
// Displays real-time waveform while singing
```

---

## 10. TESTING CHECKLIST

- [ ] YouTube video loads and plays
- [ ] Video position tracking works accurately
- [ ] Lyrics sync with video time
- [ ] Pitch detection captures user voice
- [ ] Real-time feedback displays correctly
- [ ] Lyrics scroll smoothly
- [ ] Results saved with accuracy score
- [ ] Works offline (cached lyrics)
- [ ] Handles network errors gracefully

