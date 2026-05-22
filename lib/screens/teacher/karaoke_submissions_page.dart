import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/session_result.dart';
import '../../services/session_storage_service.dart';

/// Teacher page — shows a table of student karaoke submissions.
/// Matches Figma "View Submission" frame for Lesson 2: Karaoke Practice.
class KaraokeSubmissionsPage extends StatefulWidget {
  final Map<String, dynamic> classData;
  final String lessonTitle;

  const KaraokeSubmissionsPage({
    super.key,
    required this.classData,
    required this.lessonTitle,
  });

  @override
  State<KaraokeSubmissionsPage> createState() => _KaraokeSubmissionsPageState();
}

class _KaraokeSubmissionsPageState extends State<KaraokeSubmissionsPage> {
  List<SessionResult> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final all = await SessionStorageService.loadSessions();
    if (mounted) {
      setState(() {
        _sessions = all;
        _loading = false;
      });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final className = widget.classData['name'] as String? ?? '';

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Column(
        children: [
          // ── Cyan header ────────────────────────────────────────────────
          Container(
            width: double.infinity,
            color: AppColors.primaryCyan,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              right: 16,
              bottom: 22,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.black,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        className.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Roboto',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 36),
                  child: Text(
                    '${widget.lessonTitle}  /  Submission',
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 12,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Section title ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '1.1  Practice Karaoke',
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Roboto',
                ),
              ),
            ),
          ),

          const Divider(color: Colors.white10, height: 1),

          // ── Table ─────────────────────────────────────────────────────
          _loading
              ? const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryCyan,
                      strokeWidth: 2,
                    ),
                  ),
                )
              : Expanded(
                  child: Column(
                    children: [
                      // Header row
                      _buildHeaderRow(),
                      const Divider(color: Colors.white12, height: 1),
                      // Data rows
                      Expanded(
                        child: _sessions.isEmpty
                            ? Center(
                                child: Text(
                                  'No submissions yet',
                                  style: TextStyle(
                                    color: AppColors.grey.withValues(
                                      alpha: 0.5,
                                    ),
                                    fontFamily: 'Roboto',
                                    fontSize: 13,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: EdgeInsets.zero,
                                itemCount: _sessions.length,
                                separatorBuilder: (context2, i2) =>
                                    const Divider(
                                      color: Colors.white10,
                                      height: 1,
                                    ),
                                itemBuilder: (_, i) =>
                                    _buildDataRow(i, _sessions[i]),
                              ),
                      ),
                    ],
                  ),
                ),
        ],
      ),
    );
  }

  // ── Table header ───────────────────────────────────────────────────────────

  Widget _buildHeaderRow() {
    const style = TextStyle(
      color: Colors.white54,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      fontFamily: 'Roboto',
      letterSpacing: 0.3,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: const [
          Expanded(flex: 3, child: Text('Student', style: style)),
          Expanded(flex: 2, child: Text('Student ID', style: style)),
          Expanded(flex: 2, child: Text('Submission', style: style)),
          Expanded(flex: 2, child: Text('Date', style: style)),
          SizedBox(
            width: 48,
            child: Text('Score', style: style, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  // ── Table data row ─────────────────────────────────────────────────────────

  Widget _buildDataRow(int index, SessionResult s) {
    // In this prototype the "student name" is the saved song title,
    // and we derive a student-ID from the index for demo purposes.
    final studentName = s.songTitle;
    final studentId = 'STU${(index + 1).toString().padLeft(3, '0')}';
    final submission = s.songArtist.isNotEmpty ? s.songArtist : '—';
    final date =
        '${s.completedAt.month.toString().padLeft(2, '0')}/'
        '${s.completedAt.day.toString().padLeft(2, '0')}/'
        '${s.completedAt.year}';
    final score = s.score.round();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              studentName,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 12,
                fontFamily: 'Roboto',
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              studentId,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontFamily: 'Roboto',
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              submission,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontFamily: 'Roboto',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              date,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontFamily: 'Roboto',
              ),
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(
              '$score',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: score >= 80
                    ? const Color(0xFF4CAF50)
                    : score >= 60
                    ? AppColors.primaryCyan
                    : const Color(0xFFF44336),
                fontSize: 13,
                fontWeight: FontWeight.w700,
                fontFamily: 'Roboto',
              ),
            ),
          ),
        ],
      ),
    );
  }

}
