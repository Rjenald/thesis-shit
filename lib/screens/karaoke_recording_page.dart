import 'dart:async';
import 'dart:convert';
<<<<<<< HEAD
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../constants/app_colors.dart';
import '../core/audio_service.dart';
import '../core/note_utils.dart';
import '../core/youtube_api_config.dart';
=======
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../constants/app_colors.dart';
import '../core/audio_service.dart';
import '../core/note_utils.dart';
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f
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

<<<<<<< HEAD
=======
  // ── Background music (just_audio + youtube_explode) ────────────────────────
  final AudioPlayer _musicPlayer = AudioPlayer();
  final YoutubeExplode _yt = YoutubeExplode();
  bool _musicLoading = false;
  bool _musicReady = false;
  String _musicError = '';

>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f
  // Live pitch display
  PitchFeedback _liveFeedback = PitchFeedback.noSignal;
  String _liveNote = '';
  double _liveCents = 0;

<<<<<<< HEAD
  // Rolling pitch history for the follow-pitch graph (Hz, 0 = no signal)
  final List<double> _pitchHistory = [];
  // True once the first valid (non-zero) frequency arrives from the mic
  bool _pitchWorking = false;

=======
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f
  // ── Per-line pitch accumulation ────────────────────────────────────────────
  late List<List<double>> _linePitch;
  late List<List<double>> _lineCents;
  final List<LyricPitchData> _completedLines = [];

<<<<<<< HEAD
  // ── Background music (just_audio) ─────────────────────────────────────────
  final AudioPlayer _musicPlayer = AudioPlayer();
  bool _musicLoading = false;
  bool _musicReady = false;
  String _musicError = '';
  double _musicVolume = 0.7;

  // ── YouTube iframe player (web full-song playback) ─────────────────────────
  YoutubePlayerController? _ytController;
  bool _ytReady = false;

  // ── Position-based lyric sync (YouTube only) ──────────────────────────────
  final List<double> _lyricStartSecs = [];
  StreamSubscription<YoutubeVideoState>? _ytVideoStateSub;

=======
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f
  // ── Lyrics ─────────────────────────────────────────────────────────────────
  List<LyricLine> _lyrics = [];
  List<GlobalKey> _lineKeys = [];
  bool _lyricsLoading = true;

  @override
  void initState() {
    super.initState();
<<<<<<< HEAD
    _linePitch = [];
    _lineCents = [];
    _audioService.initialize();
    _loadLyrics();
    _loadMusic();
  }

  // ── Lyrics loading (LRCLIB → local DB) ────────────────────────────────────

  Future<void> _loadLyrics() async {
=======
    _audioService.initialize();

    // Load lyrics from LRCLIB (real synced lyrics), fallback to local DB
    _loadLyrics();

    // Always load music
    _loadMusic();
  }

  Future<void> _loadLyrics() async {
    // Try LRCLIB first for real synced lyrics
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f
    final fetched = await LrcLibService.fetchLyrics(
      title: widget.songTitle,
      artist: widget.songArtist,
    );
<<<<<<< HEAD
    final lines = fetched ?? SongLyrics.forSong(widget.songTitle);

    // Build cumulative start-time table for YouTube position-based sync
    _lyricStartSecs.clear();
    double t = 0;
    for (final line in lines) {
      _lyricStartSecs.add(t);
      t += line.durationSeconds;
    }
=======

    final lines = fetched ?? SongLyrics.forSong(widget.songTitle);
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f

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
<<<<<<< HEAD
    setState(() {
      _musicLoading = true;
      _musicError = '';
      _ytReady = false;
    });

    if (kIsWeb) {
      await _loadWebMusic();
      return;
    }

    // Android: Stingray → YouTube/Piped → iTunes → Deezer
    String? url = await _tryStingray();
    url ??= await _tryYouTube();
    url ??= await _tryiTunes();
=======
    setState(() { _musicLoading = true; _musicError = ''; });

    // Priority: Stingray (best) → YouTube → Deezer preview
    String? url = await _tryStingray();
    url ??= await _tryYouTube();
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f
    url ??= await _tryDeezer();

    if (!mounted) return;
    if (url != null) {
      try {
<<<<<<< HEAD
        await _musicPlayer.setVolume(_musicVolume);
=======
        await _musicPlayer.setVolume(0.8);
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f
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

<<<<<<< HEAD
  // ── Web: YouTube iframe for full-song playback ─────────────────────────────

  String? _getValidYtId() {
    final id = widget.songYtId.trim();
    if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(id)) return id;
    return null;
  }

  Future<String?> _searchYouTubeId(String query) async {
    final q = Uri.encodeComponent(query);

    // ── 1. Official YouTube Data API v3 (fastest, most accurate) ─────────────
    if (YouTubeApiConfig.hasKey) {
      try {
        final uri = Uri.parse(YouTubeApiConfig.searchUrl).replace(
          queryParameters: {
            'part': 'snippet',
            'q': query,
            'type': 'video',
            'videoCategoryId': '10', // Music category
            'maxResults': '10',
            'key': YouTubeApiConfig.apiKey,
          },
        );
        final res = await http.get(uri).timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final items =
              (json.decode(res.body)['items'] as List?) ?? [];
          for (final item in items) {
            final id = item['id']?['videoId'] as String?;
            if (id != null && id.length == 11) return id;
          }
        }
      } catch (_) {}
    }

    // ── 2. Invidious — free CORS-safe proxy (fallback) ────────────────────────
    const invidiousInstances = [
      'https://invidious.io',
      'https://inv.nadeko.net',
      'https://yewtu.be',
      'https://vid.puffyan.us',
    ];
    for (final base in invidiousInstances) {
      try {
        final res = await http.get(
          Uri.parse('$base/api/v1/search?q=$q&type=video'),
        ).timeout(const Duration(seconds: 8));
        if (res.statusCode != 200) continue;
        final items = json.decode(res.body) as List;
        for (final item in items.take(5)) {
          final id = item['videoId'] as String?;
          final len = item['lengthSeconds'] as int? ?? 0;
          if (id != null && id.length == 11 && len > 120) return id;
        }
      } catch (_) { continue; }
    }

    // ── 3. Piped — YouTube proxy API ──────────────────────────────────────────
    const pipedInstances = [
      'https://pipedapi.kavin.rocks',
      'https://api.piped.yt',
      'https://piped-api.privacy.com.de',
    ];
    for (final base in pipedInstances) {
      try {
        final res = await http.get(
          Uri.parse('$base/search?q=$q&filter=music_songs'),
          headers: {'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 8));
        if (res.statusCode != 200) continue;
        final items = (json.decode(res.body)['items'] as List?) ?? [];
        for (final item in items.take(5)) {
          final urlStr = item['url']?.toString() ?? '';
          final id = Uri.tryParse('https://youtube.com$urlStr')
                  ?.queryParameters['v'] ?? '';
          final dur = item['duration'] as int? ?? 999;
          if (id.length == 11 && dur > 120) return id;
        }
      } catch (_) { continue; }
    }
    return null;
  }

  Future<void> _loadWebMusic() async {
    String? videoId = _getValidYtId();

    if (videoId == null) {
      final query = widget.songYtId.trim().isNotEmpty
          ? widget.songYtId.trim()
          : '${widget.songTitle} ${widget.songArtist} karaoke';
      videoId = await _searchYouTubeId(query);
    }

    if (videoId != null) {
      _ytController?.close();
      _ytController = YoutubePlayerController(
        params: const YoutubePlayerParams(
          mute: false,
          showControls: false,
          showFullscreenButton: false,
          loop: false,
          enableCaption: false,
          strictRelatedVideos: true,
          color: 'white',
        ),
      );
      if (mounted) setState(() {});

      try {
        unawaited(_ytController!.cueVideoById(videoId: videoId));
        unawaited(_ytController!.setVolume(
            (_musicVolume * 100).round().clamp(0, 100)));
        await Future.delayed(const Duration(milliseconds: 2000));
        if (mounted) {
          setState(() {
            _musicLoading = false;
            _musicReady = true;
            _ytReady = true;
          });
        }
        return;
      } catch (_) {
        // fall through to preview
      }
    }

    await _fallbackToPreview();
  }

  Future<void> _fallbackToPreview() async {
    final url = await _tryiTunes() ?? await _tryDeezer();
    if (!mounted) return;
    if (url != null) {
      try {
        await _musicPlayer.setVolume(_musicVolume);
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

  // ── Audio source fallbacks ─────────────────────────────────────────────────

  Future<String?> _tryStingray() async => StingrayService.getStreamUrl(
      title: widget.songTitle, artist: widget.songArtist);

  Future<String?> _tryYouTube() async {
    const instances = [
      'https://pipedapi.kavin.rocks',
      'https://api.piped.yt',
      'https://piped-api.privacy.com.de',
    ];
    final query = Uri.encodeComponent(
        '${widget.songTitle} ${widget.songArtist} karaoke');
    for (final base in instances) {
      try {
        final searchRes = await http.get(
          Uri.parse('$base/search?q=$query&filter=music_songs'),
          headers: {'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 8));
        if (searchRes.statusCode != 200) continue;
        final items = json.decode(searchRes.body)['items'] as List?;
        if (items == null || items.isEmpty) continue;
        for (final item in items.take(3)) {
          try {
            final urlStr = item['url']?.toString() ?? '';
            final videoId = Uri.tryParse('https://youtube.com$urlStr')
                    ?.queryParameters['v'] ?? '';
            if (videoId.isEmpty) continue;
            final streamRes = await http.get(
              Uri.parse('$base/streams/$videoId'),
              headers: {'Accept': 'application/json'},
            ).timeout(const Duration(seconds: 8));
            if (streamRes.statusCode != 200) continue;
            final audioStreams = json.decode(streamRes.body)['audioStreams'] as List?;
            if (audioStreams == null || audioStreams.isEmpty) continue;
            final sorted = List.from(audioStreams)
              ..sort((a, b) =>
                  (b['bitrate'] as int? ?? 0).compareTo(a['bitrate'] as int? ?? 0));
            final url = sorted.first['url']?.toString();
            if (url != null && url.isNotEmpty) return url;
          } catch (_) { continue; }
        }
      } catch (_) { continue; }
    }
    return null;
  }

  Future<String?> _tryiTunes() async {
    try {
      final q = Uri.encodeComponent('${widget.songTitle} ${widget.songArtist}');
      final res = await http.get(Uri.parse(
          'https://itunes.apple.com/search?term=$q&media=music&limit=10&country=PH'),
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final results = (json.decode(res.body) as Map<String, dynamic>)['results'] as List?;
      if (results == null) return null;
      for (final t in results) {
        final p = t['previewUrl'] as String?;
        if (p != null && p.isNotEmpty) return p;
=======
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
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f
      }
      return null;
    } catch (_) { return null; }
  }

<<<<<<< HEAD
  Future<String?> _tryDeezer() async {
    try {
      final q = Uri.encodeComponent('${widget.songTitle} ${widget.songArtist}');
=======
  // ── Deezer 30-second preview fallback ─────────────────────────────────────
  Future<String?> _tryDeezer() async {
    try {
      final q = Uri.encodeComponent(
          '${widget.songTitle} ${widget.songArtist}');
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f
      final res = await http
          .get(Uri.parse('https://api.deezer.com/search?q=$q&limit=5'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
<<<<<<< HEAD
      final tracks = (json.decode(res.body))['data'] as List?;
      if (tracks == null) return null;
      for (final t in tracks) {
        final p = t['preview'] as String?;
        if (p != null && p.isNotEmpty) return p;
=======
      final data = json.decode(res.body);
      final tracks = data['data'] as List?;
      if (tracks == null || tracks.isEmpty) return null;
      // Pick track with a preview URL
      for (final t in tracks) {
        final preview = t['preview'] as String?;
        if (preview != null && preview.isNotEmpty) return preview;
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f
      }
      return null;
    } catch (_) { return null; }
  }

  // ── Lyric advancement ──────────────────────────────────────────────────────

  void _startLyrics() {
    // For just_audio (preview/non-YouTube), skip any leading empty intro lines
    // so lyrics begin at the same moment the music starts playing.
    // YouTube uses position-based sync and handles intro automatically.
    if (!_ytReady) {
      int i = _currentLineIndex;
      while (i < _lyrics.length && _lyrics[i].text.isEmpty) { i++; }
      if (i != _currentLineIndex && i < _lyrics.length) {
        setState(() => _currentLineIndex = i);
      }
    }
    _advanceLine();
  }

  void _advanceLine() {
    if (!mounted || _currentLineIndex >= _lyrics.length) return;
    final line = _lyrics[_currentLineIndex];

    _lyricTimer = Timer(Duration(seconds: line.durationSeconds), () {
      if (!mounted) return;
      _sealCurrentLine();
      setState(() {
        if (_currentLineIndex < _lyrics.length - 1) _currentLineIndex++;
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
<<<<<<< HEAD
    if (_currentLineIndex >= _lineKeys.length) return;
=======
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f
    final ctx = _lineKeys[_currentLineIndex].currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          alignment: 0.4);
    }
  }

<<<<<<< HEAD
  // ── YouTube position-based lyric sync ─────────────────────────────────────

  void _startYtLyricSync() {
    _ytVideoStateSub?.cancel();
    if (_ytController == null) return;
    _ytVideoStateSub =
        _ytController!.videoStateStream.listen((YoutubeVideoState state) {
      if (!mounted || _lyricStartSecs.isEmpty || _lyrics.isEmpty) return;
      final posSecs = state.position.inMilliseconds / 1000.0;
      if (posSecs <= 0) return;
      int idx = 0;
      for (int i = _lyricStartSecs.length - 1; i >= 0; i--) {
        if (posSecs >= _lyricStartSecs[i]) { idx = i; break; }
      }
      if (idx != _currentLineIndex && idx < _lyrics.length) {
        if (idx > _currentLineIndex) _sealCurrentLine();
        setState(() => _currentLineIndex = idx);
        _scrollToCurrentLine();
      }
    });
  }

  void _stopYtLyricSync() {
    _ytVideoStateSub?.cancel();
    _ytVideoStateSub = null;
  }

  // ── Play / Pause ───────────────────────────────────────────────────────────

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      _sessionTimer?.cancel();
      if (_ytReady && _ytController != null) {
        _stopYtLyricSync();
        await _ytController!.pauseVideo();
      } else {
        _pauseLyrics();
        if (_musicReady) await _musicPlayer.pause();
      }
      setState(() => _isPlaying = false);
    } else {
      _sessionTimer = Timer.periodic(
          const Duration(seconds: 1),
          (_) => setState(() => _elapsedSeconds++));
      setState(() => _isPlaying = true);

      if (_ytReady && _ytController != null) {
        // YouTube full song: seek to 0 first so music & lyrics both start
        // from the very beginning, then let videoStateStream drive lyrics.
        await _ytController!.seekTo(seconds: 0, allowSeekAhead: true);
        await _ytController!.playVideo();
        _startYtLyricSync();
      } else if (_musicReady) {
        // just_audio: seek to start then start music and lyrics together
        await _musicPlayer.seek(Duration.zero);
        await _musicPlayer.play();
        _startLyrics(); // skips intro blanks for previews
      } else if (_musicLoading) {
        // Music still loading — start lyric timer now; music joins when ready
        _startLyrics();
        unawaited(Future.microtask(() async {
          while (_musicLoading && mounted) {
            await Future.delayed(const Duration(milliseconds: 200));
          }
          if (!mounted || !_isPlaying) return;
          if (_ytReady && _ytController != null) {
            await _ytController!.seekTo(seconds: 0, allowSeekAhead: true);
            await _ytController!.playVideo();
            _startYtLyricSync();
          } else if (_musicReady) {
            await _musicPlayer.seek(Duration.zero);
            await _musicPlayer.play();
          }
        }));
      } else {
        // No music at all — just run lyrics
        _startLyrics();
      }
    }
  }

=======
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

>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f
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
<<<<<<< HEAD
        _linePitch[i].add(result?.frequency ?? 0);
        _lineCents[i].add(result?.cents ?? 0);
      }
      // Update rolling pitch history for graph
      final hz = result?.frequency ?? 0.0;
      _pitchHistory.add(hz);
      if (_pitchHistory.length > 200) _pitchHistory.removeAt(0);
      // Mark pitch as working once we get a valid non-zero reading
      if (hz > 0 && !_pitchWorking) _pitchWorking = true;

=======
        if (result != null) {
          _linePitch[i].add(result.frequency);
          _lineCents[i].add(result.cents);
        } else {
          _linePitch[i].add(0);
          _lineCents[i].add(0);
        }
      }
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f
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
<<<<<<< HEAD
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            path != null ? '✅ Recording saved!' : '⚠️ Could not save recording'),
        backgroundColor: path != null ? Colors.green[700] : Colors.orange,
        duration: const Duration(seconds: 3),
      ));
    }

    setState(() {
      _liveFeedback = PitchFeedback.noSignal;
      _liveNote = '';
      _liveCents = 0;
      _pitchHistory.clear();
      _pitchWorking = false;
    });
  }

  // ── Stop & navigate to results ─────────────────────────────────────────────

  Future<void> _stopAll() async {
    _lyricTimer?.cancel();
    _sessionTimer?.cancel();
    _stopYtLyricSync();
    if (_ytReady && _ytController != null) {
      await _ytController!.stopVideo();
    } else if (_musicReady) {
      await _musicPlayer.stop();
    }
    if (_isRecording) await _stopRecording();
    setState(() { _isPlaying = false; _isRecording = false; });
  }

=======
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

>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f
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
<<<<<<< HEAD
        context, MaterialPageRoute(builder: (_) => ResultsPage(session: session)));
=======
      context,
      MaterialPageRoute(
        builder: (_) => ResultsPage(session: session),
      ),
    );
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f
  }

  @override
  void dispose() {
    _lyricTimer?.cancel();
    _sessionTimer?.cancel();
<<<<<<< HEAD
    _ytVideoStateSub?.cancel();
    _audioSub?.cancel();
    _ytController?.close();
    _audioService.dispose();
    _musicPlayer.dispose();
=======
    _audioSub?.cancel();
    _audioService.dispose();
    _musicPlayer.dispose();
    _yt.close();
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f
    _scrollController.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Color get _feedbackColor {
    switch (_liveFeedback) {
<<<<<<< HEAD
      case PitchFeedback.correct:  return AppColors.primaryCyan;
      case PitchFeedback.tooHigh:  return Colors.orangeAccent;
      case PitchFeedback.tooLow:   return Colors.blueAccent;
      case PitchFeedback.noSignal: return AppColors.grey;
=======
      case PitchFeedback.correct:
        return AppColors.primaryCyan;
      case PitchFeedback.tooHigh:
        return Colors.orangeAccent;
      case PitchFeedback.tooLow:
        return Colors.blueAccent;
      case PitchFeedback.noSignal:
        return AppColors.grey;
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f
    }
  }

  String get _feedbackLabel {
    switch (_liveFeedback) {
<<<<<<< HEAD
      case PitchFeedback.correct:  return 'In Tune ✓';
      case PitchFeedback.tooHigh:  return 'Sharp ↑';
      case PitchFeedback.tooLow:   return 'Flat ↓';
      case PitchFeedback.noSignal: return _isRecording ? 'Listening…' : '';
=======
      case PitchFeedback.correct:
        return 'In Tune ✓';
      case PitchFeedback.tooHigh:
        return 'Sharp ↑';
      case PitchFeedback.tooLow:
        return 'Flat ↓';
      case PitchFeedback.noSignal:
        return _isRecording ? 'Listening…' : '';
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(
        child: Column(
          children: [
            // Hidden YouTube iframe (web) — 2 px keeps it alive without
            // affecting layout.
            if (kIsWeb && _ytController != null)
              SizedBox(height: 2, child: YoutubePlayer(controller: _ytController!)),
            _buildHeader(),
            _buildSongInfo(),
<<<<<<< HEAD
            // ── Pitch-following section (shown only while recording) ────────
            if (_isRecording) ...[
              _buildLivePitchBar(),
              _buildPitchGraph(),   // real-time pitch line on note grid
            ],
=======
            _buildMusicStatus(),
            if (_isRecording) _buildLivePitchBar(),
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f
            const SizedBox(height: 4),
            Expanded(child: _buildLyricsArea()),
            _buildControls(),
          ],
        ),
      ),
    );
  }

  // ── Top bar ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 12, 4),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        const Text('Karaoke',
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: 'Roboto')),
        const Spacer(),
        // Elapsed timer badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF272727),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${(_elapsedSeconds ~/ 60).toString().padLeft(2, '0')}:'
            '${(_elapsedSeconds % 60).toString().padLeft(2, '0')}',
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontFamily: 'Roboto',
                letterSpacing: 1),
          ),
<<<<<<< HEAD
        ),
      ]),
=======
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
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f
    );
  }

  // ── Song info row ──────────────────────────────────────────────────────────

  Widget _buildSongInfo() {
<<<<<<< HEAD
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isRecording
                  ? Colors.red.withValues(alpha: 0.4)
                  : Colors.transparent,
            ),
=======
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
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f
          ),
          child: Row(children: [
            // Album art
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: widget.songImage.isNotEmpty
                  ? Image.network(widget.songImage,
                      width: 52, height: 52, fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _musicIcon())
                  : _musicIcon(),
            ),
            const SizedBox(width: 12),
            // Title & artist
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.songTitle,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Roboto'),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(widget.songArtist,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                        fontFamily: 'Roboto'),
                    overflow: TextOverflow.ellipsis),
              ]),
            ),
            // REC badge
            if (_isRecording)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
                ),
                child: Row(children: [
                  Container(width: 7, height: 7,
                      decoration: const BoxDecoration(
                          color: Colors.red, shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  const Text('REC',
                      style: TextStyle(
                          color: Colors.red,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Roboto')),
                ]),
              ),
          ]),
        ),
      ),
      // Subtle music status below the card
      _buildMusicStatus(),
    ]);
  }

  Widget _musicIcon() => Container(
        width: 52, height: 52,
        color: const Color(0xFF272727),
        child: const Icon(Icons.music_note, color: Colors.white24, size: 24),
      );

  Widget _buildMusicStatus() {
    if (_musicLoading) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
        child: Row(children: [
          const SizedBox(width: 10, height: 10,
              child: CircularProgressIndicator(strokeWidth: 1.5,
                  color: AppColors.primaryCyan)),
          const SizedBox(width: 8),
          Text('Loading music…',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.38),
                  fontSize: 11, fontFamily: 'Roboto')),
        ]),
      );
    }
    if (_musicError.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
        child: GestureDetector(
          onTap: _loadMusic,
          child: Row(children: [
            const Icon(Icons.wifi_off, color: Colors.white38, size: 13),
            const SizedBox(width: 6),
            Text('Music unavailable — ',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 11, fontFamily: 'Roboto')),
            const Text('Retry',
                style: TextStyle(
                    color: AppColors.primaryCyan,
                    fontSize: 11,
                    decoration: TextDecoration.underline,
                    fontFamily: 'Roboto')),
          ]),
        ),
      );
    }
    if (_musicReady && _isPlaying) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
        child: Row(children: [
          const Icon(Icons.graphic_eq, color: AppColors.primaryCyan, size: 13),
          const SizedBox(width: 6),
          Text(_ytReady ? '🎵 Full song (YouTube)' : '🎵 Playing preview',
              style: const TextStyle(
                  color: AppColors.primaryCyan,
                  fontSize: 11, fontFamily: 'Roboto')),
        ]),
      );
    }
    return const SizedBox(height: 4);
  }

  // ── Live pitch bar (note + cents meter + feedback) ─────────────────────────

  Widget _buildLivePitchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: _feedbackColor.withValues(alpha: 0.4), width: 1),
        ),
        child: Row(children: [
          Icon(Icons.graphic_eq, color: _feedbackColor, size: 18),
          const SizedBox(width: 8),
          // Current note name
          Text(_liveNote.isEmpty ? '—' : _liveNote,
              style: TextStyle(
                  color: _feedbackColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Roboto')),
          const SizedBox(width: 10),
          // Cents meter
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
<<<<<<< HEAD
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Flat',
                        style: TextStyle(
                            color: AppColors.grey.withValues(alpha: 0.6),
                            fontSize: 9, fontFamily: 'Roboto')),
                    Text('${_liveCents.toStringAsFixed(0)} ¢',
                        style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 9, fontFamily: 'Roboto')),
                    Text('Sharp',
                        style: TextStyle(
                            color: AppColors.grey.withValues(alpha: 0.6),
                            fontSize: 9, fontFamily: 'Roboto')),
                  ],
                ),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: (_liveCents.clamp(-50, 50) + 50) / 100,
                    minHeight: 5,
                    backgroundColor: const Color(0xFF272727),
                    valueColor: AlwaysStoppedAnimation<Color>(_feedbackColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Feedback label
          Text(_feedbackLabel,
              style: TextStyle(
                  color: _feedbackColor,
                  fontSize: 11,
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.w600)),
        ]),
=======
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
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f
      ),
    );
  }

<<<<<<< HEAD
  // ── Pitch-follow graph ─────────────────────────────────────────────────────
  // Shows your voice as a scrolling line on a note grid so you can see exactly
  // where your pitch is and whether it is steady.

  Widget _buildPitchGraph() {
    // After 40 samples with no valid pitch, show a "no signal" hint.
    final showNoSignal = !_pitchWorking && _pitchHistory.length >= 40;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(children: [
            Text('Pitch guide — follow the line',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.38),
                    fontSize: 10,
                    letterSpacing: 0.4,
                    fontFamily: 'Roboto')),
            if (_pitchWorking) ...[
              const SizedBox(width: 6),
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(
                  color: AppColors.primaryCyan,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text('Live',
                  style: const TextStyle(
                      color: AppColors.primaryCyan,
                      fontSize: 10,
                      fontFamily: 'Roboto')),
            ],
          ]),
        ),
        Container(
          height: 96,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: (_pitchWorking ? _feedbackColor : Colors.white12)
                    .withValues(alpha: 0.35),
                width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(children: [
              // Pitch painter — always present
              CustomPaint(
                painter: _PitchGraphPainter(
                  pitchHistory: List<double>.from(_pitchHistory),
                  lineColor: _feedbackColor,
                ),
                size: Size.infinite,
              ),
              // No-signal overlay
              if (showNoSignal)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.mic_off, color: Colors.white24, size: 20),
                      const SizedBox(height: 4),
                      Text(
                        kIsWeb
                            ? 'Run the CREPE server for pitch detection\npython crepe_server.py'
                            : 'No pitch detected — sing louder',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.30),
                            fontSize: 9,
                            height: 1.5,
                            fontFamily: 'Roboto'),
                      ),
                    ],
                  ),
                ),
            ]),
          ),
        ),
      ]),
    );
  }

  // ── Lyrics area ────────────────────────────────────────────────────────────

  Widget _buildLyricsArea() {
    if (_lyricsLoading) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(color: AppColors.primaryCyan, strokeWidth: 2),
          SizedBox(height: 12),
          Text('Loading lyrics…',
              style: TextStyle(
                  color: AppColors.grey, fontSize: 13, fontFamily: 'Roboto')),
        ]),
      );
    }
    if (_lyrics.isEmpty) {
      return const Center(
        child: Text('No lyrics available',
            style: TextStyle(
                color: AppColors.grey, fontSize: 14, fontFamily: 'Roboto')),
=======
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
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f
      );
    }

    return ShaderMask(
<<<<<<< HEAD
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent, Colors.white, Colors.white, Colors.transparent
        ],
        stops: [0.0, 0.12, 0.82, 1.0],
      ).createShader(rect),
=======
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
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f
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

  // ── Controls ───────────────────────────────────────────────────────────────

  Widget _buildControls() {
    return Container(
<<<<<<< HEAD
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(children: [
        // ── Volume row ──────────────────────────────────────────────────────
        Row(children: [
          const Icon(Icons.volume_down, color: Colors.white38, size: 16),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                activeTrackColor: AppColors.primaryCyan,
                inactiveTrackColor: const Color(0xFF272727),
                thumbColor: AppColors.primaryCyan,
                overlayColor: AppColors.primaryCyan.withValues(alpha: 0.2),
              ),
              child: Slider(
                value: _musicVolume,
                onChanged: (v) {
                  setState(() => _musicVolume = v);
                  if (_ytReady && _ytController != null) {
                    unawaited(
                        _ytController!.setVolume((v * 100).round().clamp(0, 100)));
                  } else {
                    unawaited(_musicPlayer.setVolume(v));
                  }
                },
              ),
            ),
=======
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
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f
          ),
          const Icon(Icons.volume_up, color: Colors.white38, size: 16),
        ]),

<<<<<<< HEAD
        const SizedBox(height: 8),

        // ── Main controls row ───────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Restart
            GestureDetector(
              onTap: () {
                _pauseLyrics();
                if (_ytReady && _ytController != null) {
                  unawaited(_ytController!.seekTo(
                      seconds: 0, allowSeekAhead: true));
                } else if (_musicReady) {
                  unawaited(_musicPlayer.seek(Duration.zero));
                }
                setState(() => _currentLineIndex = 0);
                _scrollController.animateTo(0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut);
                if (_isPlaying) {
                  if (_ytReady && _ytController != null) {
                    _startYtLyricSync();
                  } else {
                    _startLyrics();
                  }
                }
              },
              child: Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: AppColors.inputBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.skip_previous_rounded,
                    color: AppColors.white, size: 24),
              ),
=======
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
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f
            ),

<<<<<<< HEAD
            // Play / Pause — primary action, white circle (matches home page card style)
            GestureDetector(
              onTap: _togglePlay,
              child: Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: _isPlaying ? AppColors.primaryCyan : Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (_isPlaying ? AppColors.primaryCyan : Colors.white)
                          .withValues(alpha: 0.25),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.black,
                  size: 36,
                ),
              ),
=======
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
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f
            ),

<<<<<<< HEAD
            // Record toggle — solid filled, matches home page category chip style
            GestureDetector(
              onTap: () async {
                if (_isRecording) {
                  // Stop recording only; keep music playing
                  await _stopRecording();
                  setState(() => _isRecording = false);
                } else {
                  // Auto-start music + lyrics from the beginning if not playing
                  if (!_isPlaying) {
                    setState(() => _currentLineIndex = 0);
                    await _togglePlay(); // starts music & lyric timer together
                  }
                  await _startRecording();
                  setState(() => _isRecording = true);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: _isRecording ? const Color(0xFFE53935) : AppColors.primaryCyan,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: (_isRecording
                              ? const Color(0xFFE53935)
                              : AppColors.primaryCyan)
                          .withValues(alpha: 0.30),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    _isRecording ? Icons.stop_rounded : Icons.mic,
                    color: Colors.black,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isRecording ? 'Stop' : 'Sing',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ]),
              ),
=======
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
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f
            ),

            // Finish
            GestureDetector(
              onTap: _finishAndShowResults,
              child: Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: AppColors.inputBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.stop_rounded,
                    color: AppColors.white, size: 22),
              ),
            ),
          ],
        ),
      ]),
    );
  }
}

// ── Pitch graph painter ────────────────────────────────────────────────────────
// Draws the last N pitch readings as a scrolling line on a note-grid background.
// Y axis uses a logarithmic scale so every octave has the same visual height.

class _PitchGraphPainter extends CustomPainter {
  final List<double> pitchHistory;
  final Color lineColor;

  const _PitchGraphPainter({
    required this.pitchHistory,
    required this.lineColor,
  });

  // Visible frequency range
  static const double _minHz = 100.0;
  static const double _maxHz = 900.0;

  // Natural notes with their frequencies (Hz) used as grid lines
  static const _gridNotes = <String, double>{
    'C3': 130.81, 'D3': 146.83, 'E3': 164.81,
    'G3': 196.00, 'A3': 220.00, 'B3': 246.94,
    'C4': 261.63, 'D4': 293.66, 'E4': 329.63,
    'G4': 392.00, 'A4': 440.00, 'B4': 493.88,
    'C5': 523.25, 'D5': 587.33, 'E5': 659.25,
    'G5': 783.99, 'A5': 880.00,
  };

  double _hzToY(double hz, double height) {
    final logMin = math.log(_minHz);
    final logMax = math.log(_maxHz);
    final logHz  = math.log(hz.clamp(_minHz, _maxHz));
    // High frequencies → top of graph, low → bottom
    return height - ((logHz - logMin) / (logMax - logMin)) * height;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Note grid lines
    final faintPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 0.5;
    final cPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..strokeWidth = 0.8;

    for (final entry in _gridNotes.entries) {
      final y = _hzToY(entry.value, size.height);
      final isC = entry.key.startsWith('C');
      canvas.drawLine(Offset(0, y), Offset(size.width, y),
          isC ? cPaint : faintPaint);

      // Label every C note and A4
      if (isC || entry.key == 'A4') {
        final tp = TextPainter(
          text: TextSpan(
            text: entry.key,
            style: TextStyle(
              color: Colors.white.withValues(alpha: isC ? 0.30 : 0.18),
              fontSize: 8,
              fontFamily: 'Roboto',
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(3, y - 9));
      }
    }

    // 2. Pitch line + dot
    if (pitchHistory.isEmpty) return;

    const maxSamples = 80;
    final samples = pitchHistory.length > maxSamples
        ? pitchHistory.sublist(pitchHistory.length - maxSamples)
        : pitchHistory;

    final dx = size.width / maxSamples;

    final linePaint = Paint()
      ..color = lineColor.withValues(alpha: 0.85)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    bool pathStarted = false;

    for (int i = 0; i < samples.length; i++) {
      final hz = samples[i];
      if (hz <= 0) { pathStarted = false; continue; }
      final x = dx * (maxSamples - samples.length + i);
      final y = _hzToY(hz, size.height);
      if (!pathStarted) {
        path.moveTo(x, y);
        pathStarted = true;
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, linePaint);

    // Current-position dot (rightmost valid sample)
    for (int i = samples.length - 1; i >= 0; i--) {
      if (samples[i] > 0) {
        final x = dx * (maxSamples - samples.length + i);
        final y = _hzToY(samples[i], size.height);
        canvas.drawCircle(Offset(x, y), 4.5,
            Paint()..color = lineColor..style = PaintingStyle.fill);
        // White centre
        canvas.drawCircle(Offset(x, y), 1.8,
            Paint()..color = Colors.white..style = PaintingStyle.fill);
        break;
      }
    }

    // Right-edge cursor line
    canvas.drawLine(
      Offset(size.width - 1, 0),
      Offset(size.width - 1, size.height),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(_PitchGraphPainter old) =>
      old.pitchHistory != pitchHistory || old.lineColor != lineColor;
}
