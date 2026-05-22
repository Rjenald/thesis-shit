import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../services/session_storage_service.dart';
import '../../services/submission_service.dart';
import '../normal_user/recorded_karaoke_page.dart';

// ── Data model ────────────────────────────────────────────────────────────────

class Submission {
  final String studentName;
  final String subject;
  final String activity;
  final String date;
  final String score;
  final String className;

  const Submission({
    required this.studentName,
    required this.subject,
    required this.activity,
    required this.date,
    required this.score,
    required this.className,
  });
}

// ── Submissions list page ─────────────────────────────────────────────────────

class SubmissionsPage extends StatefulWidget {
  const SubmissionsPage({super.key});

  @override
  State<SubmissionsPage> createState() => _SubmissionsPageState();
}

class _SubmissionsPageState extends State<SubmissionsPage> {
  List<Map<String, dynamic>> _classes = [];
  bool _loading = true;

  // Sample submissions per class — in a real app these come from a backend.
  // Keyed by class name.
  final Map<String, List<Submission>> _submissions = {};

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    final cls = await SessionStorageService.loadClasses();
    if (mounted) {
      final submissionSvc = context.read<SubmissionService>();
      setState(() {
        _classes = cls;
        _loading = false;
        for (final c in cls) {
          final name = c['name'] as String? ?? 'Class';
          final realSubs = submissionSvc.forClass(name);
          _submissions[name] = realSubs
              .map(
                (s) => Submission(
                  studentName: s.studentName,
                  subject: s.activityType,
                  activity: s.activityName,
                  date:
                      '${s.submittedAt.month.toString().padLeft(2, '0')}/${s.submittedAt.day.toString().padLeft(2, '0')}/${(s.submittedAt.year % 100).toString().padLeft(2, '0')}',
                  score: '${s.score.round()}%',
                  className: name,
                ),
              )
              .toList();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primaryCyan,
          strokeWidth: 2,
        ),
      );
    }

    if (_classes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.assignment_outlined,
              color: Colors.white.withValues(alpha: 0.2),
              size: 56,
            ),
            const SizedBox(height: 14),
            Text(
              'No classes yet',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 15,
                fontFamily: 'Roboto',
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Create a class to see submissions here',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 12,
                fontFamily: 'Roboto',
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: _classes.length,
      itemBuilder: (ctx, i) {
        final cls = _classes[i];
        final name = cls['name'] as String? ?? 'Class';
        final subs = _submissions[name] ?? [];
        return _buildClassSection(name, subs);
      },
    );
  }

  Widget _buildClassSection(String className, List<Submission> subs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Cyan class header ────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
          color: AppColors.primaryCyan,
          child: Text(
            className.toUpperCase(),
            style: const TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Roboto',
              letterSpacing: 0.5,
            ),
          ),
        ),

        // ── Column headers ───────────────────────────────────────────────
        Container(
          color: const Color(0xFF1A1A1A),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: const [
              Expanded(flex: 3, child: _HeaderCell('Student')),
              Expanded(flex: 2, child: _HeaderCell('Subject')),
              Expanded(flex: 2, child: _HeaderCell('Activity')),
              Expanded(flex: 2, child: _HeaderCell('Date')),
              Expanded(flex: 1, child: _HeaderCell('Score')),
            ],
          ),
        ),

        // ── Rows ─────────────────────────────────────────────────────────
        if (subs.isEmpty)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'No submissions yet',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 13,
                fontFamily: 'Roboto',
              ),
            ),
          )
        else
          ...subs.map((s) => _buildRow(s)),

        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildRow(Submission s) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SubmissionDetailPage(submission: s)),
      ),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.white10, width: 0.5)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Student with icon
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  const Icon(
                    Icons.person_outline,
                    color: Colors.white54,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      s.studentName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontFamily: 'Roboto',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                s.subject,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontFamily: 'Roboto',
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                s.activity,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontFamily: 'Roboto',
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                s.date,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontFamily: 'Roboto',
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                s.score,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Roboto',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  const _HeaderCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.5),
        fontSize: 11,
        fontWeight: FontWeight.w600,
        fontFamily: 'Roboto',
      ),
    );
  }
}

// ── Submission detail page ────────────────────────────────────────────────────

class SubmissionDetailPage extends StatefulWidget {
  final Submission submission;
  const SubmissionDetailPage({super.key, required this.submission});

  @override
  State<SubmissionDetailPage> createState() => _SubmissionDetailPageState();
}

class _SubmissionDetailPageState extends State<SubmissionDetailPage> {
  final _scoreCtrl = TextEditingController();
  String _savedScore = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadScore();
  }

  Future<void> _loadScore() async {
    final stored = await SessionStorageService.getScore(
      widget.submission.studentName,
      widget.submission.activity,
    );
    if (mounted) {
      final display = stored ?? widget.submission.score;
      setState(() => _savedScore = display);
      _scoreCtrl.text = display;
    }
  }

  Future<void> _saveScore() async {
    final value = _scoreCtrl.text.trim();
    if (value.isEmpty) return;
    setState(() => _saving = true);
    await SessionStorageService.saveScore(
      studentName: widget.submission.studentName,
      activityName: widget.submission.activity,
      score: value,
    );
    if (mounted) {
      setState(() {
        _savedScore = value;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Score saved: $value',
            style: const TextStyle(fontFamily: 'Roboto'),
          ),
          backgroundColor: AppColors.primaryCyan,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    _scoreCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // ── Cyan header ──────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(8, 48, 20, 24),
            color: AppColors.primaryCyan,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Colors.black,
                    size: 24,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    widget.submission.studentName,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Detail fields ────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),

                  // Activity + Subject
                  Row(
                    children: [
                      Expanded(
                        child: _infoBox(
                          'Activity:',
                          widget.submission.activity,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _infoBox('Subject:', widget.submission.subject),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Submitted Date
                  _infoBox('Submitted Date:', widget.submission.date),
                  const SizedBox(height: 20),

                  // ── Score section ────────────────────────────────────────
                  Text(
                    'SET SCORE',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      fontFamily: 'Roboto',
                    ),
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _scoreCtrl,
                          keyboardType: TextInputType.text,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontFamily: 'Roboto',
                          ),
                          decoration: InputDecoration(
                            hintText: 'e.g. 10/10 or 95%',
                            hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.35),
                              fontFamily: 'Roboto',
                              fontSize: 13,
                            ),
                            filled: true,
                            fillColor: const Color(0xFF2A2A2A),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: AppColors.primaryCyan,
                                width: 1.5,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _saving ? null : _saveScore,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryCyan,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : const Text(
                                'Save',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Roboto',
                                ),
                              ),
                      ),
                    ],
                  ),

                  if (_savedScore.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryCyan.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.primaryCyan.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            color: AppColors.primaryCyan,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Current score: $_savedScore',
                            style: const TextStyle(
                              color: AppColors.primaryCyan,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Roboto',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── Listen Record button ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RecordedKaraokePage(
                        title: 'Recorded Karaoke',
                        audioPath: null,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryCyan,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Listen Record',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Roboto',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoBox(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(10),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                fontFamily: 'Roboto',
              ),
            ),
            if (value.isNotEmpty)
              TextSpan(
                text: '  $value',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                  fontFamily: 'Roboto',
                ),
              ),
          ],
        ),
      ),
    );
  }
}
