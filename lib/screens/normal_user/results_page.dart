import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import '../../constants/app_colors.dart';
import '../../core/note_utils.dart' show PitchFeedback;
import '../../core/singing_segment_builder.dart' show groupSegmentsByLyricLine;
import '../../data/song_lyrics.dart';
import '../../models/session_result.dart';
import '../../services/downloads_service.dart';
import '../../services/ground_truth_service.dart';
import '../../services/lyrics_service.dart' show LrcLine;
import '../../services/session_storage_service.dart';
import '../../services/song_audio_service.dart';
import '../../widgets/karaoke_summary_card.dart';
import '../../widgets/pitch_timeline_view.dart';
import '../../widgets/result_share_sheet.dart';
import '../../widgets/shareable_result_card.dart';
import '../../models/singing_segment.dart' show SingingPerformanceSummary;
import 'practice_drill_page.dart';
import 'solfagepitch_page.dart';
import 'song_player_page.dart';
import 'voice_classification_page.dart';

class ResultsPage extends StatefulWidget {
  final SessionResult session;
  final Uint8List? recordedVoiceWav;

  /// If mixing the backing track into the recording hadn't finished yet
  /// when this page was pushed, this resolves to the mixed WAV once it's
  /// ready (null if mixing wasn't attempted or failed) — [recordedVoiceWav]
  /// is the mic-only take available immediately, so "Listen" works right
  /// away and silently upgrades to the mixed version in the background
  /// instead of the result screen waiting on it before it can even appear.
  final Future<Uint8List?>? pendingMixedAudio;

  const ResultsPage({
    super.key,
    required this.session,
    this.recordedVoiceWav,
    this.pendingMixedAudio,
  });

  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> {
  bool _saved = false;
  bool _saving = false;
  bool _downloaded = false;
  AudioPlayer? _listenPlayer;
  bool _isListening = false;
  File? _listenFile;
  late Uint8List? _recordedVoiceWav;

  /// The song's bundled timed lyric lines, used to group the pitch timeline
  /// into lyric-line sections. Read straight from the local bundle (never
  /// the network — this screen must work offline, and a session opened from
  /// the Library has no lyrics passed to it), and empty for songs with none,
  /// which the timeline handles by falling back to pause-based grouping.
  List<LrcLine> get _lyrics =>
      LocalSongLyrics.getLyrics(widget.session.songTitle) ?? const [];

  /// Whether this song has a reference melody at all, as opposed to this
  /// particular take having failed to produce one.
  ///
  /// Null until checked. Needed because an empty [SessionResult.singingSegments]
  /// has two very different causes and the screen used to show neither: the
  /// song ships no ground truth (ordinary — most don't yet), or it does and
  /// something in this take's analysis went wrong. Saying which is the whole
  /// difference between "nothing to compare against" and "something broke".
  bool? _songHasReference;

  @override
  void initState() {
    super.initState();
    _recordedVoiceWav = widget.recordedVoiceWav;
    _checkForReferenceMelody();
    // Auto-save session so it appears in "Recently Visited" on Home page
    _autoSaveSession();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoDownload());
    _awaitMixedAudio();
  }

  /// Only asked when there is no timeline to show, and only to explain why.
  Future<void> _checkForReferenceMelody() async {
    if (widget.session.singingSegments.isNotEmpty) return;
    try {
      final gt = await GroundTruthService.loadForSong(
          widget.session.songTitle);
      if (mounted) {
        setState(() => _songHasReference = gt != null && gt.isNotEmpty);
      }
    } catch (_) {
      // Not worth surfacing: the fallback copy covers both cases.
      if (mounted) setState(() => _songHasReference = null);
    }
  }

  /// What to tell the singer in place of the timeline, or null when there
  /// is a timeline to show.
  String? get _timelineEmptyReason {
    if (widget.session.singingSegments.isNotEmpty) return null;
    switch (_songHasReference) {
      case true:
        return 'This song has a reference melody, but no note-by-note '
            'comparison came out of this take — usually no audio reached '
            'the recorder. Try recording again.';
      case false:
        return 'No reference melody has been added for this song yet, so '
            'there is nothing to compare each note against. The score '
            'above comes from how steady your pitch was, not from whether '
            'you hit this song\'s notes.';
      default:
        return 'No note-by-note comparison is available for this take.';
    }
  }

  Future<void> _awaitMixedAudio() async {
    final pending = widget.pendingMixedAudio;
    if (pending == null) return;
    try {
      final mixed = await pending;
      if (mixed != null && mounted) {
        setState(() => _recordedVoiceWav = mixed);
      }
    } catch (e) {
      // Mixing failed — the mic-only take already in _recordedVoiceWav
      // stays the "Listen" source, so there's nothing more to do here.
      debugPrint('Background audio mixing failed: $e');
    }
  }

  Future<void> _autoSaveSession() async {
    if (_saved) return;
    await SessionStorageService.saveSession(widget.session);
    if (mounted) setState(() => _saved = true);
  }

  @override
  void dispose() {
    _listenPlayer?.stop();
    _listenPlayer?.dispose();
    _listenFile?.delete().ignore();
    super.dispose();
  }

  Future<void> _autoDownload() async {
    final s = widget.session;
    // Every bundled song is OPM; the old lookup existed only to read a
    // language off a 763-entry table of songs the app had no audio for.
    await DownloadsService.download(s.songTitle, s.songArtist, 'Tagalog');
    if (!mounted) return;
    setState(() => _downloaded = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(
              Icons.download_done_rounded,
              color: Color(0xFF4CAF50),
              size: 18,
            ),
            SizedBox(width: 8),
            Text(
              'Song saved to Downloads',
              style: TextStyle(color: Colors.white, fontFamily: 'Roboto'),
            ),
          ],
        ),
        backgroundColor: AppColors.cardBg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _toggleListen() async {
    if (_isListening) {
      await _listenPlayer?.stop();
      _listenPlayer?.dispose();
      _listenPlayer = null;
      setState(() => _isListening = false);
      return;
    }

    _listenPlayer = AudioPlayer();

    try {
      // Play recorded voice if available. Written to a temp file rather than
      // base64-encoded into a data URI — that recording can be tens of MB
      // (a full mixed song + voice WAV), and synchronously base64-encoding
      // that on the main isolate froze the UI for several seconds.
      if (_recordedVoiceWav != null) {
        final dir = await getTemporaryDirectory();
        final file = File(
            '${dir.path}/huni_listen_${DateTime.now().microsecondsSinceEpoch}.wav');
        await file.writeAsBytes(_recordedVoiceWav!, flush: true);
        _listenFile = file;
        await _listenPlayer!.setFilePath(file.path);
      } else {
        // Fallback: play original song
        final audio = SongAudioService.resolve(widget.session.songTitle);
        if (audio == null) {
          _listenPlayer?.dispose();
          _listenPlayer = null;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No recording available')),
            );
          }
          return;
        }
        if (audio.isAsset) {
          await _listenPlayer!.setAsset(audio.path);
        } else {
          await _listenPlayer!.setFilePath(audio.path);
        }
      }

      _listenPlayer!.playerStateStream.listen((state) {
        if (!mounted) return;
        if (state.processingState == ProcessingState.completed) {
          setState(() => _isListening = false);
          _listenPlayer?.dispose();
          _listenPlayer = null;
        }
      });
      await _listenPlayer!.play();
      setState(() => _isListening = true);
    } catch (_) {
      _listenPlayer?.dispose();
      _listenPlayer = null;
    }
  }

  /// Opens the share sheet with a rendered result card.
  ///
  /// This used to share plain text. An image is what the social apps
  /// actually display, and it carries the same figures, so the caption is
  /// now a fallback for the apps that take text as well rather than the
  /// whole payload.
  void _shareSong() {
    final s = widget.session;
    final scoreInt = s.score.round();
    ResultShareSheet.show(
      context,
      baseName: s.songTitle,
      shareText:
          'I just sang "${s.songTitle}" by ${s.songArtist} on Huni — '
          '$scoreInt% (${_feedbackLabel(scoreInt)})',
      card: ShareableResultCard(
        songTitle: s.songTitle,
        songArtist: s.songArtist,
        completedAt: s.completedAt,
        score: s.score,
        scoreLabel: _feedbackLabel(scoreInt),
        stats: _shareStats(s),
      ),
    );
  }

  /// The three figures worth putting on a shared card.
  ///
  /// Only lines that could be sung are counted, which is the same basis
  /// the score itself uses — counting silent or unauthored lines would
  /// make the card disagree with the number next to it.
  List<ShareStat> _shareStats(SessionResult s) {
    final total = s.totalLines;
    return [
      ShareStat('On pitch', '${s.correctLines}/$total'),
      if (s.flatLines + s.sharpLines > 0)
        ShareStat('Off pitch', '${s.flatLines + s.sharpLines}')
      else
        ShareStat('Lines', '$total'),
      ShareStat('Duration', _formatDuration(s.durationSeconds)),
    ];
  }

  static String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final sec = seconds % 60;
    return '$m:${sec.toString().padLeft(2, '0')}';
  }

  static const _onTuneColor = Color(0xFF4CAF50);
  static const _silentColor = Color(0xFF757575);
  static const _flatColor = Color(0xFF448AFF);
  static const _sharpColor = Color(0xFFFF5252);

  String _feedbackLabel(int scoreInt) {
    if (scoreInt >= 80) return 'Good';
    if (scoreInt >= 60) return 'Fair';
    return 'Needs Practice';
  }


  Future<void> _saveSession() async {
    if (_saved || _saving) return;
    setState(() => _saving = true);
    await SessionStorageService.saveSession(widget.session);

    if (!mounted) return;
    setState(() {
      _saved = true;
      _saving = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            const Text(
              'Session saved to Library',
              style: TextStyle(color: Colors.white, fontFamily: 'Roboto'),
            ),
          ],
        ),
        backgroundColor: AppColors.cardBg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Get recommendation based on performance
  String _getRecommendationTitle() {
    final s = widget.session;
    final lines = s.lyricResults.where((l) => l.lyricText.isNotEmpty).toList();

    int flatCount = 0;
    int sharpCount = 0;
    int noSignalCount = 0;

    for (final line in lines) {
      switch (line.status) {
        case LineStatus.flat:
          flatCount++;
          break;
        case LineStatus.sharp:
          sharpCount++;
          break;
        case LineStatus.noSignal:
          noSignalCount++;
          break;
        default:
          break;
      }
    }

    final total = lines.length;

    if (noSignalCount > total * 0.15) return 'Sustain Drill';
    if (flatCount > sharpCount && flatCount > total * 0.2) {
      return 'Pitch Up Drill';
    }
    if (sharpCount > flatCount && sharpCount > total * 0.2) {
      return 'Pitch Down Drill';
    }
    if (s.score < 60) return 'Scale Practice';
    if (s.score < 80) return 'Voice Classification';
    return 'Solfege Pitch';
  }

  String _getRecommendationSubtitle() {
    final title = _getRecommendationTitle();
    switch (title) {
      case 'Sustain Drill':
        return 'Hold notes steady for 3 seconds';
      case 'Pitch Up Drill':
        return 'Practice singing higher notes';
      case 'Pitch Down Drill':
        return 'Practice singing lower notes';
      case 'Scale Practice':
        return 'Run through Do to Ti scale';
      case 'Voice Classification':
        return 'Discover your vocal range';
      default:
        return 'Match pitch with piano keys';
    }
  }

  IconData _getRecommendationIcon() {
    final title = _getRecommendationTitle();
    switch (title) {
      case 'Sustain Drill':
        return Icons.timer;
      case 'Pitch Up Drill':
        return Icons.arrow_upward;
      case 'Pitch Down Drill':
        return Icons.arrow_downward;
      case 'Scale Practice':
        return Icons.music_note;
      case 'Voice Classification':
        return Icons.record_voice_over;
      default:
        return Icons.piano;
    }
  }

  Color _getRecommendationColor() {
    final title = _getRecommendationTitle();
    switch (title) {
      case 'Sustain Drill':
        return const Color(0xFF9C27B0);
      case 'Pitch Up Drill':
        return const Color(0xFF2196F3);
      case 'Pitch Down Drill':
        return const Color(0xFFFF9800);
      case 'Scale Practice':
        return AppColors.primaryCyan;
      case 'Voice Classification':
        return const Color(0xFFE91E63);
      default:
        return const Color(0xFF4CAF50);
    }
  }

  /// The lyric lines this take actually struggled on — passed to
  /// [PracticeDrillPage] so its phrase-loop drill practices the singer's own
  /// problem lines rather than a generic list. Ground-truth songs prefer the
  /// real target-vs-actual segments; everything else falls back to the
  /// line-level estimate, which is all those songs have.
  List<String> _problemLines() {
    final s = widget.session;
    if (s.singingSegments.isNotEmpty) {
      final lyrics = _lyrics;
      if (lyrics.isNotEmpty) {
        final missed = groupSegmentsByLyricLine(s.singingSegments, lyrics)
            .where((line) =>
                line.lineText.isNotEmpty &&
                line.segments.any((seg) =>
                    seg.status == PitchFeedback.tooHigh ||
                    seg.status == PitchFeedback.tooLow))
            .map((line) => line.lineText)
            .toList();
        if (missed.isNotEmpty) return missed;
      }
    }
    return s.singableLines
        .where((l) => l.status != LineStatus.correct && l.lyricText.isNotEmpty)
        .map((l) => l.lyricText)
        .toList();
  }

  /// Opens the real drill screen the recommendation points at. These are
  /// pushed directly (the same way EducationModePage opens them) rather than
  /// by named route — this app registers no `routes` table, so the named
  /// routes this used to call could never resolve and the card did nothing.
  void _navigateToDrill() {
    final title = _getRecommendationTitle();
    final Widget page;
    switch (title) {
      case 'Pitch Up Drill':
      case 'Pitch Down Drill':
      case 'Solfege Pitch':
        page = const SolfegePitchPage();
        break;
      case 'Voice Classification':
        page = const VoiceClassificationPage();
        break;
      case 'Sustain Drill':
      case 'Scale Practice':
      default:
        page = PracticeDrillPage(problemLines: _problemLines());
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final scoreInt = s.score.round();

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  const SizedBox(height: 8),
                  _buildRankDisplay(scoreInt),
                  const SizedBox(height: 12),
                  _buildFeedbackRow(scoreInt, s),
                  const SizedBox(height: 20),
                  // The Pitch Heatmap / Lyrics Performance sections below
                  // compare against the nearest chromatic note, not this
                  // song's actual melody (no reference frequency is available
                  // for most songs) — for a song WITH a real ground-truth
                  // melody, showing that alongside the genuine target-vs-
                  // actual PitchTimelineView/KaraokeSummaryCard would put two
                  // different, disagreeing notions of "in tune" on the same
                  // screen. Only shown as a fallback when there's no real
                  // comparison available at all.
                  if (s.singingSegments.isEmpty) ...[
                    _buildHeatmapStrip(s),
                    const SizedBox(height: 20),
                  ],
                  KaraokeSummaryCard(
                    summary: SingingPerformanceSummary.fromSegments(
                      s.singingSegments,
                    ),
                  ),
                  if (s.singingSegments.isNotEmpty) const SizedBox(height: 20),
                  PitchTimelineView(
                    segments: s.singingSegments,
                    lyrics: _lyrics,
                    emptyReason: _timelineEmptyReason,
                  ),
                  if (s.singingSegments.isNotEmpty) const SizedBox(height: 20),
                  _buildRecommendations(s),
                  const SizedBox(height: 24),
                  _buildRecommendationButton(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            _buildActionButtons(context, s),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
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
                  'Results',
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
          if (_downloaded)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.4),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.download_done_rounded,
                    color: Color(0xFF4CAF50),
                    size: 14,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Downloaded',
                    style: TextStyle(
                      color: Color(0xFF4CAF50),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ],
              ),
            ),
          GestureDetector(
            onTap: _shareSong,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.share_outlined,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }


  // ── RANK DISPLAY — S+/S/A/B/C/D ──
  Widget _buildRankDisplay(int scoreInt) {
    String rank;
    Color rankColor;
    String rankLabel;

    if (scoreInt >= 95) {
      rank = 'S+';
      rankColor = const Color(0xFFFFD700);
      rankLabel = 'Superstar!';
    } else if (scoreInt >= 90) {
      rank = 'S';
      rankColor = const Color(0xFFFFD700);
      rankLabel = 'Amazing!';
    } else if (scoreInt >= 80) {
      rank = 'A';
      rankColor = const Color(0xFF4CAF50);
      rankLabel = 'Great Job!';
    } else if (scoreInt >= 65) {
      rank = 'B';
      rankColor = const Color(0xFF2196F3);
      rankLabel = 'Good';
    } else if (scoreInt >= 50) {
      rank = 'C';
      rankColor = const Color(0xFFFF9800);
      rankLabel = 'Fair';
    } else {
      rank = 'D';
      rankColor = const Color(0xFFF44336);
      rankLabel = 'Keep Practicing';
    }

    return Center(
      child: Column(
        children: [
          // Rank circle
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: rankColor.withValues(alpha: 0.12),
              border: Border.all(color: rankColor, width: 3),
              boxShadow: [
                BoxShadow(
                  color: rankColor.withValues(alpha: 0.35),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Center(
              child: Text(
                rank,
                style: TextStyle(
                  color: rankColor,
                  fontSize: rank.length > 1 ? 26 : 36,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Roboto',
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            rankLabel,
            style: TextStyle(
              color: rankColor,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              fontFamily: 'Roboto',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$scoreInt%',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 28,
              fontWeight: FontWeight.w300,
              fontFamily: 'Roboto',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackRow(int scoreInt, SessionResult s) {
    final flatnessPct = s.avgFlatPercent.toStringAsFixed(0);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _chip('Feedback: ${_feedbackLabel(scoreInt)}', AppColors.primaryCyan),
        _chip('Score: $scoreInt%', AppColors.primaryCyan),
        _chip('Flatness: $flatnessPct%', Colors.white70),
      ],
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontFamily: 'Roboto',
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // SINGLE RECOMMENDATION BUTTON
  Widget _buildRecommendationButton() {
    final color = _getRecommendationColor();
    final icon = _getRecommendationIcon();
    final title = _getRecommendationTitle();
    final subtitle = _getRecommendationSubtitle();

    return GestureDetector(
      onTap: _navigateToDrill,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Practice Drills',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Roboto',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.95),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Roboto',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: color.withValues(alpha: 0.6),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  // ── LYRIC ALIGNMENT (Whisper-Tiny, on-device) ──
  // Compares when the reference lyric expected each word against when
  // Whisper actually heard it sung, from a real on-device transcription
  // of the recording — not the static playback-position timestamps used
  // for the live scrolling highlight.
  Widget _buildHeatmapStrip(SessionResult s) {
    final singable = s.singableLines;
    if (singable.isEmpty) return const SizedBox.shrink();

    Color colorFor(LyricPitchData line) {
      switch (line.status) {
        case LineStatus.correct:
          return _onTuneColor;
        case LineStatus.flat:
          return _flatColor;
        case LineStatus.sharp:
          return _sharpColor;
        case LineStatus.noSignal:
          return _silentColor;
      }
    }

    double intensityFor(LyricPitchData line) {
      if (line.status == LineStatus.noSignal) return 0.25;
      // Map 0-50 cents average deviation to 0.35-1.0 opacity so bigger
      // misses read as visually "hotter."
      final mag = line.avgCents.abs().clamp(0, 50) / 50;
      return 0.35 + mag * 0.65;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'Pitch Heatmap',
            style: TextStyle(color: Colors.white70, fontSize: 13,
                fontWeight: FontWeight.w600, fontFamily: 'Roboto', letterSpacing: 0.3),
          ),
        ),
        SizedBox(
          height: 28,
          child: Row(
            children: singable.map((line) {
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: colorFor(line).withValues(alpha: intensityFor(line)),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _legendDot(_onTuneColor, 'In tune'),
            const SizedBox(width: 10),
            _legendDot(_flatColor, 'Flat'),
            const SizedBox(width: 10),
            _legendDot(_sharpColor, 'Sharp'),
            const SizedBox(width: 10),
            _legendDot(_silentColor, 'No signal'),
          ],
        ),
      ],
    );
  }

  // ── VOCAL HEALTH ALERTS + TARGETED PRACTICE RECOMMENDATIONS ──
  Widget _buildRecommendations(SessionResult s) {
    final alerts = s.vocalHealthAlerts;
    final recs = s.practiceRecommendations;
    if (alerts.isEmpty && recs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (alerts.isNotEmpty) ...[
          const Text(
            'Vocal Health',
            style: TextStyle(color: Colors.white70, fontSize: 13,
                fontWeight: FontWeight.w600, fontFamily: 'Roboto', letterSpacing: 0.3),
          ),
          const SizedBox(height: 8),
          ...alerts.map((a) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9800).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFF9800).withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFFFF9800), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(a, style: const TextStyle(color: Colors.white70,
                          fontSize: 12.5, fontFamily: 'Roboto', height: 1.4)),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 12),
        ],
        if (recs.isNotEmpty) ...[
          const Text(
            'Practice Recommendations',
            style: TextStyle(color: Colors.white70, fontSize: 13,
                fontWeight: FontWeight.w600, fontFamily: 'Roboto', letterSpacing: 0.3),
          ),
          const SizedBox(height: 8),
          ...recs.map((r) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryCyan.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primaryCyan.withValues(alpha: 0.25)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.fitness_center, color: AppColors.primaryCyan, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(r, style: const TextStyle(color: Colors.white70,
                          fontSize: 12.5, fontFamily: 'Roboto', height: 1.4)),
                    ),
                  ],
                ),
              )),
        ],
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 9,
            fontFamily: 'Roboto',
          ),
        ),
      ],
    );
  }


  Widget _buildActionButtons(BuildContext context, SessionResult s) {
    final btnShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Row(
        children: [
          // Try Again button
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                _listenPlayer?.stop();
                _listenPlayer?.dispose();
                _listenPlayer = null;
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SongPlayerPage(
                      songTitle: widget.session.songTitle,
                      songArtist: widget.session.songArtist,
                      songImage: widget.session.songImage,
                    ),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: btnShape,
              ),
              child: const Text(
                'Try Again',
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Listen button — plays recorded voice or original song
          Expanded(
            child: ElevatedButton(
              onPressed: _toggleListen,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isListening
                    ? const Color(0xFFFF9800)
                    : const Color(0xFF2A2A2A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: btnShape,
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isListening
                        ? Icons.stop
                        : (_recordedVoiceWav != null
                            ? Icons.record_voice_over
                            : Icons.headphones),
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isListening
                        ? 'Stop'
                        : (_recordedVoiceWav != null
                            ? 'My Voice'
                            : 'Listen'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Save button
          Expanded(
            child: ElevatedButton(
              onPressed: _saving ? null : _saveSession,
              style: ElevatedButton.styleFrom(
                backgroundColor: _saved
                    ? _onTuneColor
                    : AppColors.primaryCyan,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: btnShape,
                elevation: 0,
              ),
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : Text(
                      _saved ? 'Saved' : 'Save',
                      style: const TextStyle(
                        fontSize: 14,
                        fontFamily: 'Roboto',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

