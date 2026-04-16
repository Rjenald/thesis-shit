import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // ── Thesis-aligned color palette ──────────────────────────────────────────
  static const _correctColor  = Color(0xFF4CAF50);
  static const _flatColor     = Color(0xFFFFA726);
  static const _sharpColor    = Color(0xFFF44336);
  static const _noSignalColor = Color(0xFF757575);

  Color _lineColor(LyricPitchData l) {
    switch (l.status) {
      case LineStatus.correct:  return _correctColor;
      case LineStatus.flat:     return _flatColor;
      case LineStatus.sharp:    return _sharpColor;
      case LineStatus.noSignal: return _noSignalColor;
    }
  }

  String _lineLabel(LyricPitchData l) {
    switch (l.status) {
      case LineStatus.correct:
        return 'In Tune';
      case LineStatus.flat:
        return 'Flat ${l.avgCents.abs().toStringAsFixed(0)}¢';
      case LineStatus.sharp:
        return 'Sharp ${l.avgCents.abs().toStringAsFixed(0)}¢';
      case LineStatus.noSignal:
        return 'No Signal';
    }
  }

  /// Heat intensity: 0.0 = no signal, 1.0 = perfect, drives background alpha.
  double _heatIntensity(LyricPitchData l) {
    if (l.voiceActivityRate < 0.15) return 0.0;
    final worst = [l.flatPercent, l.sharpPercent].reduce((a, b) => a > b ? a : b);
    return (worst / 100).clamp(0.0, 1.0);
  }

  // ── Save session ───────────────────────────────────────────────────────────
  Future<void> _saveSession() async {
    if (_saved || _saving) return;
    setState(() => _saving = true);
    await SessionStorageService.saveSession(widget.session);
    if (!mounted) return;
    setState(() { _saved = true; _saving = false; });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Row(children: [
        Icon(Icons.check, color: Colors.white, size: 18),
        SizedBox(width: 8),
        Text('Session saved to Library',
            style: TextStyle(color: Colors.white, fontFamily: 'Roboto')),
      ]),
      backgroundColor: AppColors.cardBg,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      duration: const Duration(seconds: 2),
    ));
  }

  // ── Share results ──────────────────────────────────────────────────────────
  void _shareResults() {
    final s = widget.session;
    final buf = StringBuffer();
    buf.writeln('🎤 Huni – Performance Report');
    buf.writeln('Song: ${s.songTitle} – ${s.songArtist}');
    buf.writeln('Score: ${s.score.round()} pts (${s.stars}⭐)');
    buf.writeln();
    buf.writeln('Pitch Analysis:');
    buf.writeln('  ✅ In Tune : ${s.correctLines} lines');
    buf.writeln('  🟠 Flat    : ${s.flatLines} lines (avg ${s.avgFlatPercent.toStringAsFixed(0)}%)');
    buf.writeln('  🔴 Sharp   : ${s.sharpLines} lines (avg ${s.avgSharpPercent.toStringAsFixed(0)}%)');
    buf.writeln();
    buf.writeln('Flatness/Sharpness Heatmap:');
    for (final line in s.singableLines) {
      if (line.lyricText.isEmpty) continue;
      final icon = line.status == LineStatus.correct ? '✅'
          : line.status == LineStatus.flat ? '🟠'
          : line.status == LineStatus.sharp ? '🔴' : '⬜';
      buf.writeln('$icon ${line.lyricText}');
    }
    if (s.practiceRecommendations.isNotEmpty) {
      buf.writeln();
      buf.writeln('Recommendations:');
      for (final r in s.practiceRecommendations) {
        buf.writeln('• $r');
      }
    }
    buf.writeln();
    buf.writeln('Powered by CREPE + YIN Pitch Detection | Huni App');

    Clipboard.setData(ClipboardData(text: buf.toString()));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Row(children: [
        Icon(Icons.copy, color: Colors.white, size: 16),
        SizedBox(width: 8),
        Text('Report copied to clipboard!',
            style: TextStyle(color: Colors.white, fontFamily: 'Roboto')),
      ]),
      backgroundColor: const Color(0xFF1565C0),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      duration: const Duration(seconds: 2),
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────
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
                  _buildAiBadge(),
                  const SizedBox(height: 12),
                  _buildSongCard(s),
                  const SizedBox(height: 16),
                  _buildScoreSection(scoreInt, s.score / 100, s),
                  const SizedBox(height: 16),
                  _buildStatsRow(s),
                  const SizedBox(height: 16),
                  _buildPitchBreakdown(s),
                  const SizedBox(height: 16),
                  _buildHeatmap(s),
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

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.white, size: 26),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              'Performance Report',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.white,
                  fontFamily: 'Roboto'),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined,
                color: AppColors.primaryCyan, size: 24),
            tooltip: 'Share Report',
            onPressed: _shareResults,
          ),
        ],
      ),
    );
  }

  // ── CREPE / AI badge ───────────────────────────────────────────────────────
  Widget _buildAiBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryCyan.withValues(alpha: 0.12),
            Colors.purple.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: AppColors.primaryCyan.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome, color: AppColors.primaryCyan, size: 14),
          const SizedBox(width: 6),
          Text(
            'Powered by CREPE + YIN Pitch Detection  •  Whisper-Aligned Lyrics',
            style: TextStyle(
              color: AppColors.primaryCyan.withValues(alpha: 0.9),
              fontSize: 10,
              fontFamily: 'Roboto',
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  // ── Song card ──────────────────────────────────────────────────────────────
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _correctColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _correctColor.withValues(alpha: 0.3)),
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
        width: 46, height: 46,
        decoration: BoxDecoration(
          color: AppColors.primaryCyan.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.music_note, color: AppColors.primaryCyan, size: 24),
      );

  // ── Score ──────────────────────────────────────────────────────────────────
  Widget _buildScoreSection(int scoreInt, double scorePercent, SessionResult s) {
    return Column(
      children: [
        SizedBox(
          width: 120, height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: scorePercent,
                strokeWidth: 10,
                backgroundColor: AppColors.inputBg,
                valueColor: AlwaysStoppedAnimation<Color>(
                  scoreInt >= 80 ? _correctColor
                      : scoreInt >= 50 ? _flatColor
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
          children: List.generate(5, (i) => Icon(
            i < s.stars ? Icons.star_rounded : Icons.star_outline_rounded,
            color: i < s.stars ? Colors.amber : AppColors.grey.withValues(alpha: 0.35),
            size: 28,
          )),
        ),
      ],
    );
  }

  // ── Stats row ──────────────────────────────────────────────────────────────
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
                  color: color, fontSize: 20,
                  fontWeight: FontWeight.bold, fontFamily: 'Roboto')),
          Text(label,
              style: TextStyle(
                  color: AppColors.grey.withValues(alpha: 0.8),
                  fontSize: 11, fontFamily: 'Roboto')),
        ],
      ),
    );
  }

  // ── Pitch breakdown bars ───────────────────────────────────────────────────
  Widget _buildPitchBreakdown(SessionResult s) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppColors.cardBg, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Pitch Deviation Analysis',
              style: TextStyle(
                  color: AppColors.white, fontSize: 14,
                  fontWeight: FontWeight.w600, fontFamily: 'Roboto')),
          const SizedBox(height: 10),
          _pitchBar('In Tune',
              s.totalLines == 0 ? 0 : s.correctLines / s.totalLines,
              _correctColor),
          const SizedBox(height: 6),
          _pitchBar('Flat',
              s.totalLines == 0 ? 0 : s.flatLines / s.totalLines,
              _flatColor),
          const SizedBox(height: 6),
          _pitchBar('Sharp',
              s.totalLines == 0 ? 0 : s.sharpLines / s.totalLines,
              _sharpColor),
          const SizedBox(height: 8),
          Row(children: [
            const SizedBox(width: 70),
            Expanded(
              child: Text(
                'Avg flat: ${s.avgFlatPercent.toStringAsFixed(0)}%  •  '
                'Avg sharp: ${s.avgSharpPercent.toStringAsFixed(0)}%  •  '
                'Voice activity: ${(s.overallVoiceActivity * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                    color: AppColors.grey.withValues(alpha: 0.65),
                    fontSize: 10, fontFamily: 'Roboto'),
              ),
            ),
          ]),
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
                    fontSize: 12, fontFamily: 'Roboto'))),
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
                color: color, fontSize: 11,
                fontWeight: FontWeight.w600, fontFamily: 'Roboto')),
      ],
    );
  }

  // ── HEATMAP — core thesis feature ─────────────────────────────────────────
  Widget _buildHeatmap(SessionResult s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title + legend
        Row(
          children: [
            const Icon(Icons.grid_view_rounded,
                color: AppColors.primaryCyan, size: 16),
            const SizedBox(width: 6),
            const Text('Flatness / Sharpness Heatmap',
                style: TextStyle(
                    color: AppColors.white, fontSize: 14,
                    fontWeight: FontWeight.w600, fontFamily: 'Roboto')),
            const Spacer(),
            _legendDot(_correctColor, 'Tune'),
            const SizedBox(width: 6),
            _legendDot(_flatColor, 'Flat'),
            const SizedBox(width: 6),
            _legendDot(_sharpColor, 'Sharp'),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Each lyric line is colored by pitch deviation detected during singing.',
          style: TextStyle(
              color: AppColors.grey.withValues(alpha: 0.55),
              fontSize: 10, fontFamily: 'Roboto'),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
              color: AppColors.inputBg,
              borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              for (int i = 0; i < s.lyricResults.length; i++)
                _buildHeatmapCell(s.lyricResults[i], i),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeatmapCell(LyricPitchData line, int index) {
    if (line.lyricText.isEmpty) return const SizedBox(height: 6);

    final color = _lineColor(line);
    final intensity = _heatIntensity(line);
    final isNoSignal = line.status == LineStatus.noSignal;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isNoSignal
            ? AppColors.bgDark.withValues(alpha: 0.4)
            : color.withValues(alpha: (0.08 + intensity * 0.22).clamp(0.06, 0.32)),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: isNoSignal ? _noSignalColor.withValues(alpha: 0.3) : color,
            width: 3,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Row(
        children: [
          // Lyric text
          Expanded(
            child: Text(
              line.lyricText,
              style: TextStyle(
                  color: isNoSignal
                      ? AppColors.grey.withValues(alpha: 0.4)
                      : AppColors.white.withValues(alpha: 0.92),
                  fontSize: 12,
                  fontFamily: 'Roboto',
                  height: 1.4),
            ),
          ),
          const SizedBox(width: 8),
          // Per-line stats
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _lineLabel(line),
                style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Roboto'),
              ),
              if (!isNoSignal) ...[
                const SizedBox(height: 2),
                // Mini inline bars
                SizedBox(
                  width: 70,
                  child: Row(
                    children: [
                      _miniBar(line.inTunePercent / 100, _correctColor),
                      const SizedBox(width: 2),
                      _miniBar(line.flatPercent / 100, _flatColor),
                      const SizedBox(width: 2),
                      _miniBar(line.sharpPercent / 100, _sharpColor),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${line.inTunePercent.toStringAsFixed(0)}% tune',
                  style: TextStyle(
                      color: AppColors.grey.withValues(alpha: 0.5),
                      fontSize: 9,
                      fontFamily: 'Roboto'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniBar(double value, Color color) {
    return Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          value: value.clamp(0.0, 1.0),
          minHeight: 4,
          backgroundColor: AppColors.bgDark,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                color: AppColors.grey.withValues(alpha: 0.7),
                fontSize: 10, fontFamily: 'Roboto')),
      ],
    );
  }

  // ── Vocal health ───────────────────────────────────────────────────────────
  Widget _buildVocalHealthSection(SessionResult s) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
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
                      color: Colors.amber, fontSize: 14,
                      fontWeight: FontWeight.w600, fontFamily: 'Roboto')),
              const Spacer(),
              Text('Non-diagnostic',
                  style: TextStyle(
                      color: Colors.amber.withValues(alpha: 0.6),
                      fontSize: 10, fontFamily: 'Roboto')),
            ],
          ),
          const SizedBox(height: 10),
          ...s.vocalHealthAlerts.map((alert) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ',
                        style: TextStyle(color: Colors.amber, fontSize: 13)),
                    Expanded(
                      child: Text(alert,
                          style: TextStyle(
                              color: AppColors.white.withValues(alpha: 0.85),
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

  // ── Recommendations ────────────────────────────────────────────────────────
  Widget _buildRecommendationsSection(SessionResult s) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryCyan.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryCyan.withValues(alpha: 0.25)),
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
                      color: AppColors.primaryCyan, fontSize: 14,
                      fontWeight: FontWeight.w600, fontFamily: 'Roboto')),
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
                            color: AppColors.primaryCyan, fontSize: 13)),
                    Expanded(
                      child: Text(rec,
                          style: TextStyle(
                              color: AppColors.white.withValues(alpha: 0.85),
                              fontSize: 12,
                              fontFamily: 'Roboto',
                              height: 1.4)),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => PracticeDrillPage(
                problemLines: s.singableLines
                    .where((l) =>
                        l.status == LineStatus.flat ||
                        l.status == LineStatus.sharp)
                    .map((l) => l.lyricText)
                    .take(5)
                    .toList(),
              ),
            )),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primaryCyan.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.primaryCyan.withValues(alpha: 0.4)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.fitness_center_outlined,
                      color: AppColors.primaryCyan, size: 16),
                  SizedBox(width: 8),
                  Text('Open Practice Drills',
                      style: TextStyle(
                          color: AppColors.primaryCyan, fontSize: 13,
                          fontWeight: FontWeight.w600, fontFamily: 'Roboto')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Action buttons ─────────────────────────────────────────────────────────
  Widget _buildActionButtons(BuildContext context, SessionResult s) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) => const KaraokeHomePage())),
            icon: const Icon(Icons.replay, size: 18),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.inputBg,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _shareResults,
            icon: const Icon(Icons.share_outlined, size: 18),
            label: const Text('Share'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _saving ? null : _saveSession,
            icon: Icon(_saved ? Icons.check : Icons.save_outlined, size: 18),
            label: Text(_saved ? 'Saved' : 'Save'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _saved ? _correctColor : AppColors.primaryCyan,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }
}
