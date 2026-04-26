import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/session_result.dart';
import '../services/session_storage_service.dart';
import 'karaoke_home_page.dart';
import 'practice_drill_page.dart';

class ResultsPage extends StatefulWidget {
  final SessionResult session;

  const ResultsPage({super.key, required this.session});

  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> {
  bool _saved = false;
  bool _saving = false;

  // ── Color helpers ──────────────────────────────────────────────────────────
  static const _correctColor = Color(0xFF4CAF50);
  static const _flatColor = Color(0xFFFFA726);
  static const _sharpColor = Color(0xFFF44336);
  static const _noSignalColor = Color(0xFF757575);

  Color _lineColor(LyricPitchData line) {
    switch (line.status) {
      case LineStatus.correct:
        return _correctColor;
      case LineStatus.flat:
        return _flatColor;
      case LineStatus.sharp:
        return _sharpColor;
      case LineStatus.noSignal:
        return _noSignalColor;
    }
  }

  String _lineLabel(LyricPitchData line) {
    switch (line.status) {
      case LineStatus.correct:
        return 'In Tune';
      case LineStatus.flat:
        return 'Flat ${line.avgCents.abs().toStringAsFixed(0)}¢';
      case LineStatus.sharp:
        return 'Sharp ${line.avgCents.abs().toStringAsFixed(0)}¢';
      case LineStatus.noSignal:
        return 'No Signal';
    }
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
        content: const Row(children: [
          Icon(Icons.check, color: Colors.white, size: 18),
          SizedBox(width: 8),
          Text('Session saved to Library',
              style: TextStyle(color: Colors.white, fontFamily: 'Roboto')),
        ]),
        backgroundColor: AppColors.cardBg,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final scoreInt = s.score.round();
    final scorePercent = s.score / 100;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                children: [
                  _buildSongCard(s),
                  const SizedBox(height: 20),
                  _buildScoreSection(scoreInt, scorePercent, s),
                  const SizedBox(height: 16),
                  _buildStatsRow(s),
                  const SizedBox(height: 16),
                  _buildPitchBreakdown(s),
                  const SizedBox(height: 16),
                  _buildLyricsResults(s),
                  if (s.vocalHealthAlerts.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildVocalHealthSection(s),
                  ],
                  const SizedBox(height: 16),
                  _buildRecommendationsSection(s),
                  const SizedBox(height: 24),
                  _buildActionButtons(context, s),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back,
                color: AppColors.white, size: 26),
            onPressed: () => Navigator.pop(context),
          ),
          const Text(
            'Results',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.white,
                fontFamily: 'Roboto'),
          ),
        ],
      ),
    );
  }

  Widget _buildSongCard(SessionResult s) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: s.songImage.isNotEmpty
                ? Image.network(s.songImage,
                    width: 46, height: 46, fit: BoxFit.cover,
                    errorBuilder: (ctx, e, st) => _songIconBox())
                : _songIconBox(),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.songTitle,
                    style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Roboto'),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(s.songArtist,
                    style: TextStyle(
                        color: AppColors.grey.withValues(alpha: 0.8),
                        fontSize: 13,
                        fontFamily: 'Roboto')),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _correctColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: _correctColor.withValues(alpha: 0.3)),
            ),
            child: const Text('Completed',
                style: TextStyle(
                    color: _correctColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Roboto')),
          ),
        ],
      ),
    );
  }

  Widget _songIconBox() => Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: AppColors.primaryCyan.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.music_note,
            color: AppColors.primaryCyan, size: 24),
      );

  Widget _buildScoreSection(
      int scoreInt, double scorePercent, SessionResult s) {
    return Column(
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: scorePercent,
                strokeWidth: 10,
                backgroundColor: AppColors.inputBg,
                valueColor: AlwaysStoppedAnimation<Color>(
                  scoreInt >= 80
                      ? _correctColor
                      : scoreInt >= 50
                          ? _flatColor
                          : _sharpColor,
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('$scoreInt',
                      style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Roboto',
                          height: 1.0)),
                  Text('pts',
                      style: TextStyle(
                          color: AppColors.grey.withValues(alpha: 0.7),
                          fontSize: 12,
                          fontFamily: 'Roboto')),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            5,
            (i) => Icon(
              i < s.stars
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
              color: i < s.stars
                  ? Colors.amber
                  : AppColors.grey.withValues(alpha: 0.35),
              size: 28,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(SessionResult s) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _statCard(s.correctLines, 'Correct', _correctColor),
        const SizedBox(width: 10),
        _statCard(s.flatLines, 'Flat', _flatColor),
        const SizedBox(width: 10),
        _statCard(s.sharpLines, 'Sharp', _sharpColor),
        const SizedBox(width: 10),
        _statCard(s.noSignalLines, 'Silent', _noSignalColor),
      ],
    );
  }

  Widget _statCard(int count, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text('$count',
              style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Roboto')),
          Text(label,
              style: TextStyle(
                  color: AppColors.grey.withValues(alpha: 0.8),
                  fontSize: 11,
                  fontFamily: 'Roboto')),
        ],
      ),
    );
  }

  Widget _buildPitchBreakdown(SessionResult s) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Pitch Analysis',
              style: TextStyle(
                  color: AppColors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Roboto')),
          const SizedBox(height: 10),
          _pitchBar(
              'In Tune',
              s.totalLines == 0
                  ? 0
                  : s.correctLines / s.totalLines,
              _correctColor),
          const SizedBox(height: 6),
          _pitchBar(
              'Flat',
              s.totalLines == 0
                  ? 0
                  : s.flatLines / s.totalLines,
              _flatColor),
          const SizedBox(height: 6),
          _pitchBar(
              'Sharp',
              s.totalLines == 0
                  ? 0
                  : s.sharpLines / s.totalLines,
              _sharpColor),
          const SizedBox(height: 6),
          Row(
            children: [
              const SizedBox(width: 70),
              Expanded(
                child: Text(
                  'Avg flat: ${s.avgFlatPercent.toStringAsFixed(0)}%  |  '
                  'Avg sharp: ${s.avgSharpPercent.toStringAsFixed(0)}%  |  '
                  'Voice activity: ${(s.overallVoiceActivity * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                      color: AppColors.grey.withValues(alpha: 0.65),
                      fontSize: 10,
                      fontFamily: 'Roboto'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pitchBar(String label, double value, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 65,
          child: Text(label,
              style: TextStyle(
                  color: AppColors.grey.withValues(alpha: 0.8),
                  fontSize: 12,
                  fontFamily: 'Roboto')),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppColors.inputBg,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('${(value * 100).round()}%',
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontFamily: 'Roboto')),
      ],
    );
  }

  Widget _buildLyricsResults(SessionResult s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Legend
        Row(
          children: [
            const Text('Result Lyrics',
                style: TextStyle(
                    color: AppColors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Roboto')),
            const SizedBox(width: 10),
            _legendDot(_correctColor, 'In Tune'),
            const SizedBox(width: 8),
            _legendDot(_flatColor, 'Flat'),
            const SizedBox(width: 8),
            _legendDot(_sharpColor, 'Sharp'),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxHeight: 260),
          decoration: BoxDecoration(
              color: AppColors.inputBg,
              borderRadius: BorderRadius.circular(12)),
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            shrinkWrap: true,
            itemCount: s.lyricResults.length,
            itemBuilder: (context, index) {
              final line = s.lyricResults[index];
              if (line.lyricText.isEmpty) {
                return const SizedBox(height: 8);
              }
              final color = _lineColor(line);
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        line.lyricText,
                        style: TextStyle(
                            color: color,
                            fontSize: 13,
                            fontFamily: 'Roboto',
                            height: 1.5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _lineLabel(line),
                      style: TextStyle(
                          color: color.withValues(alpha: 0.7),
                          fontSize: 10,
                          fontFamily: 'Roboto'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 6,
            height: 6,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                color: AppColors.grey.withValues(alpha: 0.7),
                fontSize: 11,
                fontFamily: 'Roboto')),
      ],
    );
  }

  Widget _buildVocalHealthSection(SessionResult s) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.health_and_safety_outlined,
                  color: Colors.amber, size: 18),
              const SizedBox(width: 8),
              const Text('Vocal Health Alerts',
                  style: TextStyle(
                      color: Colors.amber,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Roboto')),
              const Spacer(),
              Text('Non-diagnostic',
                  style: TextStyle(
                      color: Colors.amber.withValues(alpha: 0.6),
                      fontSize: 10,
                      fontFamily: 'Roboto')),
            ],
          ),
          const SizedBox(height: 10),
          ...s.vocalHealthAlerts.map((alert) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ',
                        style: TextStyle(
                            color: Colors.amber,
                            fontSize: 13)),
                    Expanded(
                      child: Text(alert,
                          style: TextStyle(
                              color: AppColors.white
                                  .withValues(alpha: 0.85),
                              fontSize: 12,
                              fontFamily: 'Roboto',
                              height: 1.4)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildRecommendationsSection(SessionResult s) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryCyan.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppColors.primaryCyan.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tips_and_updates_outlined,
                  color: AppColors.primaryCyan, size: 18),
              const SizedBox(width: 8),
              const Text('Practice Recommendations',
                  style: TextStyle(
                      color: AppColors.primaryCyan,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Roboto')),
            ],
          ),
          const SizedBox(height: 10),
          ...s.practiceRecommendations.map((rec) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ',
                        style: TextStyle(
                            color: AppColors.primaryCyan,
                            fontSize: 13)),
                    Expanded(
                      child: Text(rec,
                          style: TextStyle(
                              color: AppColors.white
                                  .withValues(alpha: 0.85),
                              fontSize: 12,
                              fontFamily: 'Roboto',
                              height: 1.4)),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PracticeDrillPage(
                  problemLines: s.singableLines
                      .where((l) =>
                          l.status == LineStatus.flat ||
                          l.status == LineStatus.sharp)
                      .map((l) => l.lyricText)
                      .take(5)
                      .toList(),
                ),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primaryCyan.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.primaryCyan
                        .withValues(alpha: 0.4)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.fitness_center_outlined,
                      color: AppColors.primaryCyan, size: 16),
                  SizedBox(width: 8),
                  Text('Open Practice Drills',
                      style: TextStyle(
                          color: AppColors.primaryCyan,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Roboto')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, SessionResult s) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (_) => const KaraokeHomePage()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.inputBg,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Try Again',
                style: TextStyle(
                    fontSize: 15,
                    fontFamily: 'Roboto',
                    fontWeight: FontWeight.w500)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _saving ? null : _saveSession,
            style: ElevatedButton.styleFrom(
              backgroundColor: _saved
                  ? _correctColor
                  : AppColors.primaryCyan,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.black))
                : Text(
                    _saved ? 'Saved ✓' : 'Save',
                    style: const TextStyle(
                        fontSize: 15,
                        fontFamily: 'Roboto',
                        fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ],
    );
  }
}
