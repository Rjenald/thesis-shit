import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../constants/app_colors.dart';
import '../../data/tagalog_bisaya_songs.dart';
import '../../models/session_result.dart';
import '../../services/downloads_service.dart';
import '../../services/enrollment_service.dart';
import '../../services/session_storage_service.dart';
import '../../services/song_audio_service.dart';
import '../../services/submission_service.dart';
import 'song_player_page.dart';

class ResultsPage extends StatefulWidget {
  final SessionResult session;
  final bool isAssignment;
  final Uint8List? recordedVoiceWav;

  const ResultsPage({
    super.key,
    required this.session,
    this.isAssignment = false,
    this.recordedVoiceWav,
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoDownload());
  }

  @override
  void dispose() {
    _listenPlayer?.stop();
    _listenPlayer?.dispose();
    super.dispose();
  }

  Future<void> _autoDownload() async {
    final s = widget.session;
    final match = TagalogBisayaSongs.songs.cast<KaraokeSong?>().firstWhere(
      (song) =>
          song!.title.toLowerCase() == s.songTitle.toLowerCase() &&
          song.artist.toLowerCase() == s.songArtist.toLowerCase(),
      orElse: () => null,
    );
    final language = match?.language ?? 'Unknown';

    await DownloadsService.download(s.songTitle, s.songArtist, language);
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
      // Play recorded voice if available
      if (widget.recordedVoiceWav != null) {
        await _listenPlayer!.setAudioSource(
          _WavAudioSource(widget.recordedVoiceWav!),
        );
      } else {
        // Fallback: play original song
        final audioUrl =
            SongAudioService.getAudioUrl(widget.session.songTitle);
        if (audioUrl == null) {
          _listenPlayer?.dispose();
          _listenPlayer = null;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No recording available')),
            );
          }
          return;
        }
        await _listenPlayer!.setUrl(audioUrl);
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

  void _shareSong() {
    final s = widget.session;
    final scoreInt = s.score.round();
    final text =
        'I just sang "${s.songTitle}" by ${s.songArtist} on Huni Karaoke!\n'
        'Score: $scoreInt% - ${_feedbackLabel(scoreInt)}\n\n'
        'Try it on Huni Karaoke App';
    Share.share(text, subject: '${s.songTitle} - My Karaoke Score');
  }

  static const _onTuneColor = Color(0xFF4CAF50);
  static const _offTuneColor = Color(0xFFF44336);
  static const _silentColor = Color(0xFF757575);

  String _feedbackLabel(int scoreInt) {
    if (scoreInt >= 80) return 'Good';
    if (scoreInt >= 60) return 'Fair';
    return 'Needs Practice';
  }


  Future<void> _saveSession() async {
    if (_saved || _saving) return;
    setState(() => _saving = true);
    await SessionStorageService.saveSession(widget.session);

    if (widget.isAssignment) {
      final enrollment = context.read<EnrollmentService>();
      final username =
          await SessionStorageService.loadUsername() ?? 'Student';
      final className = enrollment.primaryClass ?? 'Unknown Class';
      await SubmissionService().addSubmission(
        StudentSubmission(
          id: '${DateTime.now().millisecondsSinceEpoch}',
          studentName: username,
          className: className,
          activityName: widget.session.songTitle,
          activityType: 'Karaoke',
          score: widget.session.score,
          submittedAt: DateTime.now(),
        ),
      );
    }

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
            Text(
              widget.isAssignment
                  ? 'Submitted to teacher!'
                  : 'Session saved to Library',
              style: const TextStyle(color: Colors.white, fontFamily: 'Roboto'),
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
        return const Color(0xFF00E5FF);
      case 'Voice Classification':
        return const Color(0xFFE91E63);
      default:
        return const Color(0xFF4CAF50);
    }
  }

  void _navigateToDrill() {
    final title = _getRecommendationTitle();
    String route;
    switch (title) {
      case 'Sustain Drill':
      case 'Scale Practice':
        route = '/practice-drills';
        break;
      case 'Pitch Up Drill':
      case 'Pitch Down Drill':
      case 'Solfege Pitch':
        route = '/solfege-pitch';
        break;
      case 'Voice Classification':
        route = '/voice-classification';
        break;
      default:
        route = '/practice-drills';
    }
    Navigator.pushNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final scoreInt = s.score.round();

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  const SizedBox(height: 8),
                  _buildFeedbackRow(scoreInt, s),
                  const SizedBox(height: 20),
                  _buildLyricsResults(s),
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
          color: const Color(0xFF1A1A1A),
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

  Widget _buildLyricsResults(SessionResult s) {
    final singable = s.lyricResults
        .where((l) => l.lyricText.isNotEmpty)
        .toList();

    if (singable.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'No lyric data recorded',
          style: TextStyle(color: Colors.white38, fontFamily: 'Roboto'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section title
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              const Icon(Icons.lyrics_outlined, color: Colors.white54, size: 16),
              const SizedBox(width: 6),
              const Text(
                'Lyrics Performance',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Roboto',
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              // Legend
              _legendDot(_onTuneColor, 'In Tune'),
              const SizedBox(width: 10),
              _legendDot(_offTuneColor, 'Off Pitch'),
              const SizedBox(width: 10),
              _legendDot(_silentColor, 'No Signal'),
            ],
          ),
        ),
        const Divider(color: Colors.white10, height: 1),
        const SizedBox(height: 6),
        // Each lyric line with pitch status
        ...singable.asMap().entries.map((entry) {
          final i = entry.key;
          final line = entry.value;

          String statusLabel;
          IconData statusIcon;
          Color color;
          switch (line.status) {
            case LineStatus.correct:
              statusLabel = 'In Tune';
              statusIcon = Icons.check_circle;
              color = _onTuneColor;
              break;
            case LineStatus.flat:
              statusLabel = 'Flat';
              statusIcon = Icons.arrow_downward;
              color = _offTuneColor;
              break;
            case LineStatus.sharp:
              statusLabel = 'Sharp';
              statusIcon = Icons.arrow_upward;
              color = _offTuneColor;
              break;
            case LineStatus.noSignal:
              statusLabel = 'No Signal';
              statusIcon = Icons.mic_off;
              color = _silentColor;
              break;
          }

          // Skip intro markers from display
          final isIntro = line.lyricText.contains('Intro') ||
              line.lyricText.contains('♪');

          return Container(
            margin: const EdgeInsets.symmetric(vertical: 3),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: color.withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Line number
                SizedBox(
                  width: 24,
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 11,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ),
                // Lyric text
                Expanded(
                  child: Text(
                    isIntro ? '♪ Intro ♪' : line.lyricText,
                    style: TextStyle(
                      color: line.status == LineStatus.correct
                          ? Colors.white
                          : line.status == LineStatus.noSignal
                              ? Colors.white.withValues(alpha: 0.4)
                              : Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                      fontWeight: line.status == LineStatus.correct
                          ? FontWeight.w500
                          : FontWeight.normal,
                      fontFamily: 'Roboto',
                      fontStyle: isIntro ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Status badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: color, size: 12),
                      const SizedBox(width: 3),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Roboto',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
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
                      isAssignment: widget.isAssignment,
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
                        : (widget.recordedVoiceWav != null
                            ? Icons.record_voice_over
                            : Icons.headphones),
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isListening
                        ? 'Stop'
                        : (widget.recordedVoiceWav != null
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

          // Save / Submit button
          Expanded(
            child: ElevatedButton(
              onPressed: _saving
                  ? null
                  : widget.isAssignment
                      ? () async {
                          final nav = Navigator.of(context);
                          await _saveSession();
                          if (!mounted) return;
                          nav.popUntil(
                            (r) => r.isFirst || r.settings.name == '/',
                          );
                        }
                      : _saveSession,
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
                      _saved
                          ? (widget.isAssignment ? 'Submitted' : 'Saved')
                          : (widget.isAssignment ? 'Submit' : 'Save'),
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

/// Custom audio source for playing WAV bytes directly via just_audio.
class _WavAudioSource extends StreamAudioSource {
  final Uint8List _bytes;
  _WavAudioSource(this._bytes);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _bytes.length;
    return StreamAudioResponse(
      sourceLength: _bytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(List<int>.from(_bytes.sublist(start, end))),
      contentType: 'audio/wav',
    );
  }
}

