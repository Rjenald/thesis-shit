import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../constants/app_colors.dart';
import '../data/tagalog_bisaya_songs.dart';
import '../models/session_result.dart';
import '../services/downloads_service.dart';
import '../services/session_storage_service.dart';

class ResultsPage extends StatefulWidget {
  final SessionResult session;
  final bool isAssignment;

  const ResultsPage({
    super.key,
    required this.session,
    this.isAssignment = false,
  });

  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> {
  bool _saved = false;
  bool _saving = false;
  bool _downloaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoDownload());
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

  void _shareSong() {
    final s = widget.session;
    final scoreInt = s.score.round();
    final text =
        'I just sang "${s.songTitle}" by ${s.songArtist} on Huni Karaoke!\n'
        'Score: $scoreInt% - ${_feedbackLabel(scoreInt)}\n\n'
        'Search on YouTube: https://www.youtube.com/results?search_query='
        '${Uri.encodeComponent('${s.songTitle} ${s.songArtist} karaoke')}\n\n'
        'Try it on Huni Karaoke App';
    Share.share(text, subject: '${s.songTitle} - My Karaoke Score');
  }

  static const _onTuneColor = Color(0xFF4CAF50);
  static const _offTuneColor = Color(0xFFF44336);
  static const _silentColor = Color(0xFF757575);

  Color _lineColor(LyricPitchData line) {
    switch (line.status) {
      case LineStatus.correct:
        return _onTuneColor;
      case LineStatus.flat:
      case LineStatus.sharp:
        return _offTuneColor;
      case LineStatus.noSignal:
        return _silentColor;
    }
  }

  String _feedbackLabel(int scoreInt) {
    if (scoreInt >= 80) return 'Good';
    if (scoreInt >= 60) return 'Fair';
    return 'Needs Practice';
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return s == 0 ? '${m}m' : '${m}m${s}s';
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
        content: const Row(
          children: [
            Icon(Icons.check, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text(
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
    if (flatCount > sharpCount && flatCount > total * 0.2)
      return 'Pitch Up Drill';
    if (sharpCount > flatCount && sharpCount > total * 0.2)
      return 'Pitch Down Drill';
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
                  _buildHeatmap(s),
                  const SizedBox(height: 16),
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

  Widget _buildHeatmap(SessionResult s) {
    final lines = s.lyricResults.where((l) => l.lyricText.isNotEmpty).toList();
    final duration = s.durationSeconds > 0 ? s.durationSeconds : 210;

    final ticks = <int>[];
    for (int t = 30; t <= duration; t += 30) {
      ticks.add(t);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _legendDot(_offTuneColor, 'Flat / Sharp'),
            const SizedBox(width: 16),
            _legendDot(_onTuneColor, 'On Tune'),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 36,
            width: double.infinity,
            child: lines.isEmpty
                ? Container(color: Colors.white12)
                : CustomPaint(painter: _HeatmapPainter(lines, _lineColor)),
          ),
        ),
        const SizedBox(height: 4),
        if (ticks.isNotEmpty)
          Row(
            children: ticks.map((t) {
              return Expanded(
                child: Text(
                  _formatTime(t),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 9,
                    fontFamily: 'Roboto',
                  ),
                ),
              );
            }).toList(),
          ),
      ],
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
    final totalSec = s.durationSeconds;
    final perLine = singable.isEmpty ? 0 : totalSec ~/ singable.length;

    const headerStyle = TextStyle(
      color: Colors.white38,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      fontFamily: 'Roboto',
      letterSpacing: 0.4,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: const [
              SizedBox(width: 28, child: Text('#', style: headerStyle)),
              SizedBox(width: 56, child: Text('Time', style: headerStyle)),
              Expanded(child: Text('Pitch', style: headerStyle)),
              SizedBox(
                width: 80,
                child: Text(
                  'Direction',
                  style: headerStyle,
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
        const Divider(color: Colors.white10, height: 1),
        const SizedBox(height: 4),
        ...singable.asMap().entries.map((entry) {
          final i = entry.key;
          final line = entry.value;
          final sec = perLine * (i + 1);
          final m = sec ~/ 60;
          final s2 = sec % 60;
          final ts =
              '${m.toString().padLeft(2, '0')}:${s2.toString().padLeft(2, '0')}';

          String pitch, direction;
          Color color;
          switch (line.status) {
            case LineStatus.correct:
              pitch = 'In Tune';
              direction = '-';
              color = _onTuneColor;
              break;
            case LineStatus.flat:
              pitch = 'Flat';
              direction = 'Too Low';
              color = _offTuneColor;
              break;
            case LineStatus.sharp:
              pitch = 'Sharp';
              direction = 'Too High';
              color = _offTuneColor;
              break;
            case LineStatus.noSignal:
              pitch = 'No Signal';
              direction = '-';
              color = _silentColor;
              break;
          }

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    '${i + 1}.',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ),
                SizedBox(
                  width: 56,
                  child: Text(
                    ts,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    pitch,
                    style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: Text(
                    direction,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: color.withValues(alpha: 0.75),
                      fontSize: 13,
                      fontFamily: 'Roboto',
                    ),
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
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
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

    final tryAgainBtn = Expanded(
      child: OutlinedButton(
        onPressed: () => Navigator.pop(context),
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
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Row(
        children: widget.isAssignment
            ? [
                tryAgainBtn,
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saving
                        ? null
                        : () async {
                            final nav = Navigator.of(context);
                            await _saveSession();
                            if (!mounted) return;
                            nav.popUntil(
                              (r) => r.isFirst || r.settings.name == '/',
                            );
                          },
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
                            _saved ? 'Submitted' : 'Submit',
                            style: const TextStyle(
                              fontSize: 14,
                              fontFamily: 'Roboto',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ]
            : [
                tryAgainBtn,
                const SizedBox(width: 8),
                SizedBox(
                  width: 46,
                  child: ElevatedButton(
                    onPressed: _downloaded ? null : _autoDownload,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _downloaded
                          ? _onTuneColor.withValues(alpha: 0.15)
                          : const Color(0xFF2A2A2A),
                      foregroundColor: _downloaded
                          ? _onTuneColor
                          : Colors.white,
                      padding: EdgeInsets.zero,
                      shape: btnShape,
                      elevation: 0,
                    ),
                    child: Icon(
                      _downloaded
                          ? Icons.download_done_rounded
                          : Icons.download_outlined,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 46,
                  child: ElevatedButton(
                    onPressed: _shareSong,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2A2A2A),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                      shape: btnShape,
                      elevation: 0,
                    ),
                    child: const Icon(Icons.share_outlined, size: 20),
                  ),
                ),
                const SizedBox(width: 8),
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

class _HeatmapPainter extends CustomPainter {
  final List<LyricPitchData> lines;
  final Color Function(LyricPitchData) colorFor;

  const _HeatmapPainter(this.lines, this.colorFor);

  @override
  void paint(Canvas canvas, Size size) {
    if (lines.isEmpty) return;
    final segW = size.width / lines.length;
    for (int i = 0; i < lines.length; i++) {
      final paint = Paint()..color = colorFor(lines[i]);
      canvas.drawRect(Rect.fromLTWH(i * segW, 0, segW - 1, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_HeatmapPainter old) => old.lines.length != lines.length;
}
