import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../data/lyrics.dart';
import '../models/session_result.dart';
import '../services/session_storage_service.dart';

/// MAPEH Teacher Mode — class management, song assignment, batch session review.
///
/// All data is stored locally via SessionStorageService.
/// Each class is a Map with keys: name, students, assignedSongs.
class TeacherModePage extends StatefulWidget {
  const TeacherModePage({super.key});

  @override
  State<TeacherModePage> createState() => _TeacherModePageState();
}

class _TeacherModePageState extends State<TeacherModePage> {
  List<Map<String, dynamic>> _classes = [];
  List<SessionResult> _allSessions = [];
  bool _loading = true;
  int _tab = 0; // 0 = Classes, 1 = Reports, 2 = Session Log

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final classes = await SessionStorageService.loadClasses();
    final sessions = await SessionStorageService.loadSessions();
    if (mounted) {
      setState(() {
        _classes = classes;
        _allSessions = sessions;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildTabs(),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primaryCyan))
                  : _buildTabContent(),
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
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Teacher Mode',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                      fontFamily: 'Roboto')),
              Text('MAPEH Class Management',
                  style: TextStyle(
                      color: AppColors.grey,
                      fontSize: 12,
                      fontFamily: 'Roboto')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    final tabs = ['Classes', 'Reports', 'Session Log'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: List.generate(3, (i) {
          final selected = _tab == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tab = i),
              child: Container(
                margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primaryCyan
                      : AppColors.inputBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(tabs[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: selected
                            ? Colors.black
                            : AppColors.grey,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        fontFamily: 'Roboto')),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_tab) {
      case 0:
        return _buildClassesTab();
      case 1:
        return _buildReportsTab();
      case 2:
        return _buildSessionLogTab();
      default:
        return const SizedBox();
    }
  }

  // ── Tab 0: Classes ───────────────────────────────────────────────────────

  Widget _buildClassesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ElevatedButton.icon(
            onPressed: _showAddClassDialog,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add New Class'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryCyan,
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
        ),
        Expanded(
          child: _classes.isEmpty
              ? _emptyState('No classes yet',
                  'Add a class to get started', Icons.class_outlined)
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _classes.length,
                  itemBuilder: (context, i) =>
                      _buildClassCard(_classes[i], i),
                ),
        ),
      ],
    );
  }

  Widget _buildClassCard(Map<String, dynamic> cls, int index) {
    final name = cls['name'] as String? ?? 'Class';
    final students =
        (cls['students'] as List<dynamic>? ?? []).cast<String>();
    final songs =
        (cls['assignedSongs'] as List<dynamic>? ?? []).cast<String>();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(14)),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding:
              const EdgeInsets.fromLTRB(16, 0, 16, 12),
          title: Text(name,
              style: const TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  fontFamily: 'Roboto')),
          subtitle: Text(
              '${students.length} students • ${songs.length} songs assigned',
              style: TextStyle(
                  color: AppColors.grey.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontFamily: 'Roboto')),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined,
                    color: AppColors.grey, size: 18),
                onPressed: () => _showEditClassDialog(index, cls),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Color(0xFFF44336), size: 18),
                onPressed: () => _confirmDeleteClass(index),
              ),
            ],
          ),
          children: [
            // Students
            _sectionLabel('Students'),
            ...students.map((s) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_outline,
                      color: AppColors.grey, size: 18),
                  title: Text(s,
                      style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 13,
                          fontFamily: 'Roboto')),
                )),
            if (students.isEmpty)
              Text('No students added.',
                  style: TextStyle(
                      color: AppColors.grey.withValues(alpha: 0.5),
                      fontSize: 12,
                      fontFamily: 'Roboto')),

            const SizedBox(height: 8),

            // Assigned songs
            _sectionLabel('Assigned Songs'),
            ...songs.map((song) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.music_note_outlined,
                      color: AppColors.grey, size: 18),
                  title: Text(song,
                      style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 13,
                          fontFamily: 'Roboto')),
                )),
            if (songs.isEmpty)
              Text('No songs assigned.',
                  style: TextStyle(
                      color: AppColors.grey.withValues(alpha: 0.5),
                      fontSize: 12,
                      fontFamily: 'Roboto')),

            const SizedBox(height: 8),

            // Export rubric
            ElevatedButton.icon(
              onPressed: () => _exportRubric(name, students, songs),
              icon: const Icon(Icons.copy_outlined, size: 16),
              label: const Text('Export Rubric to Clipboard'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.inputBg,
                foregroundColor: AppColors.white,
                minimumSize: const Size(double.infinity, 38),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                elevation: 0,
                textStyle: const TextStyle(
                    fontSize: 13, fontFamily: 'Roboto'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text,
            style: TextStyle(
                color: AppColors.primaryCyan.withValues(alpha: 0.8),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                fontFamily: 'Roboto')),
      );

  // ── Tab 1: Reports ───────────────────────────────────────────────────────

  Widget _buildReportsTab() {
    if (_allSessions.isEmpty) {
      return _emptyState('No sessions yet',
          'Students must save results to see reports here',
          Icons.bar_chart_outlined);
    }

    // Group sessions by song title
    final Map<String, List<SessionResult>> bySong = {};
    for (final s in _allSessions) {
      bySong.putIfAbsent(s.songTitle, () => []).add(s);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Batch Report — ${_allSessions.length} total sessions',
            style: const TextStyle(
                color: AppColors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                fontFamily: 'Roboto')),
        const SizedBox(height: 12),
        ...bySong.entries.map((entry) {
          final sessions = entry.value;
          final avgScore = sessions
                  .map((s) => s.score)
                  .reduce((a, b) => a + b) /
              sessions.length;
          final avgFlat = sessions
                  .map((s) => s.avgFlatPercent)
                  .reduce((a, b) => a + b) /
              sessions.length;
          final avgSharp = sessions
                  .map((s) => s.avgSharpPercent)
                  .reduce((a, b) => a + b) /
              sessions.length;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(entry.key,
                          style: const TextStyle(
                              color: AppColors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              fontFamily: 'Roboto')),
                    ),
                    _scoreBadge(avgScore.round()),
                  ],
                ),
                const SizedBox(height: 6),
                Text('${sessions.length} attempt(s)',
                    style: TextStyle(
                        color: AppColors.grey.withValues(alpha: 0.6),
                        fontSize: 12,
                        fontFamily: 'Roboto')),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _miniStat('Avg Flat',
                        '${avgFlat.toStringAsFixed(0)}%',
                        const Color(0xFFFFA726)),
                    const SizedBox(width: 10),
                    _miniStat('Avg Sharp',
                        '${avgSharp.toStringAsFixed(0)}%',
                        const Color(0xFFF44336)),
                    const SizedBox(width: 10),
                    _miniStat('Avg Score',
                        avgScore.toStringAsFixed(0),
                        AppColors.primaryCyan),
                  ],
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _exportAllReportsToClipboard,
          icon: const Icon(Icons.copy_outlined, size: 16),
          label: const Text('Export All Reports to Clipboard'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.inputBg,
            foregroundColor: AppColors.white,
            minimumSize: const Size(double.infinity, 44),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            elevation: 0,
          ),
        ),
      ],
    );
  }

  Widget _scoreBadge(int score) {
    final color = score >= 80
        ? const Color(0xFF4CAF50)
        : score >= 50
            ? const Color(0xFFFFA726)
            : const Color(0xFFF44336);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text('$score pts',
          style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: 'Roboto')),
    );
  }

  Widget _miniStat(String label, String val, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(val,
            style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                fontFamily: 'Roboto')),
        Text(label,
            style: TextStyle(
                color: AppColors.grey.withValues(alpha: 0.6),
                fontSize: 10,
                fontFamily: 'Roboto')),
      ],
    );
  }

  // ── Tab 2: Session Log ───────────────────────────────────────────────────

  Widget _buildSessionLogTab() {
    if (_allSessions.isEmpty) {
      return _emptyState('No sessions logged',
          'Save a result from the karaoke screen to see it here',
          Icons.history_outlined);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _allSessions.length,
      itemBuilder: (context, i) {
        final s = _allSessions[i];
        final date = s.completedAt;
        final dateStr =
            '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} '
            '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.songTitle,
                        style: const TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            fontFamily: 'Roboto')),
                    const SizedBox(height: 2),
                    Text(dateStr,
                        style: TextStyle(
                            color:
                                AppColors.grey.withValues(alpha: 0.5),
                            fontSize: 11,
                            fontFamily: 'Roboto')),
                    const SizedBox(height: 4),
                    Text(
                        'Flat: ${s.avgFlatPercent.toStringAsFixed(0)}%  '
                        'Sharp: ${s.avgSharpPercent.toStringAsFixed(0)}%  '
                        'VAD: ${(s.overallVoiceActivity * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                            color:
                                AppColors.grey.withValues(alpha: 0.6),
                            fontSize: 11,
                            fontFamily: 'Roboto')),
                  ],
                ),
              ),
              _scoreBadge(s.score.round()),
            ],
          ),
        );
      },
    );
  }

  // ── Dialogs ──────────────────────────────────────────────────────────────

  final _availableSongs = SongLyrics.allTitles;

  void _showAddClassDialog() {
    final nameCtrl = TextEditingController();
    final studentCtrl = TextEditingController();
    final List<String> students = [];
    final List<String> selectedSongs = [];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppColors.cardBg,
          title: const Text('New Class',
              style: TextStyle(
                  color: AppColors.white, fontFamily: 'Roboto')),
          content: SizedBox(
            width: 320,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: AppColors.white),
                    decoration: InputDecoration(
                      hintText: 'Class name (e.g. Grade 9 - Rizal)',
                      hintStyle: TextStyle(
                          color: AppColors.grey.withValues(alpha: 0.5),
                          fontSize: 13),
                      filled: true,
                      fillColor: AppColors.inputBg,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Students',
                      style: TextStyle(
                          color: AppColors.grey,
                          fontSize: 12,
                          fontFamily: 'Roboto')),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: studentCtrl,
                          style: const TextStyle(
                              color: AppColors.white),
                          decoration: InputDecoration(
                            hintText: 'Student name',
                            hintStyle: TextStyle(
                                color: AppColors.grey
                                    .withValues(alpha: 0.4),
                                fontSize: 12),
                            filled: true,
                            fillColor: AppColors.inputBg,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          final name = studentCtrl.text.trim();
                          if (name.isNotEmpty) {
                            setLocal(() => students.add(name));
                            studentCtrl.clear();
                          }
                        },
                        icon: const Icon(Icons.add_circle,
                            color: AppColors.primaryCyan),
                      ),
                    ],
                  ),
                  ...students.map((s) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.person_outline,
                            color: AppColors.grey, size: 16),
                        title: Text(s,
                            style: const TextStyle(
                                color: AppColors.white,
                                fontSize: 13,
                                fontFamily: 'Roboto')),
                        trailing: IconButton(
                          icon: const Icon(Icons.close,
                              color: AppColors.grey, size: 16),
                          onPressed: () =>
                              setLocal(() => students.remove(s)),
                        ),
                      )),
                  const SizedBox(height: 12),
                  const Text('Assign Songs',
                      style: TextStyle(
                          color: AppColors.grey,
                          fontSize: 12,
                          fontFamily: 'Roboto')),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _availableSongs.map((song) {
                      final selected = selectedSongs.contains(song);
                      return GestureDetector(
                        onTap: () => setLocal(() {
                          if (selected) {
                            selectedSongs.remove(song);
                          } else {
                            selectedSongs.add(song);
                          }
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primaryCyan
                                    .withValues(alpha: 0.2)
                                : AppColors.inputBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: selected
                                    ? AppColors.primaryCyan
                                    : Colors.transparent),
                          ),
                          child: Text(song,
                              style: TextStyle(
                                  color: selected
                                      ? AppColors.primaryCyan
                                      : AppColors.grey,
                                  fontSize: 11,
                                  fontFamily: 'Roboto')),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: TextStyle(
                      color: AppColors.grey.withValues(alpha: 0.8),
                      fontFamily: 'Roboto')),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                await SessionStorageService.addClass({
                  'name': nameCtrl.text.trim(),
                  'students': students,
                  'assignedSongs': selectedSongs,
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryCyan,
                foregroundColor: Colors.black,
                elevation: 0,
              ),
              child: const Text('Create',
                  style: TextStyle(fontFamily: 'Roboto')),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditClassDialog(int index, Map<String, dynamic> cls) {
    final nameCtrl =
        TextEditingController(text: cls['name'] as String? ?? '');
    final studentCtrl = TextEditingController();
    final students =
        List<String>.from(cls['students'] as List<dynamic>? ?? []);
    final selectedSongs =
        List<String>.from(cls['assignedSongs'] as List<dynamic>? ?? []);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppColors.cardBg,
          title: const Text('Edit Class',
              style: TextStyle(
                  color: AppColors.white, fontFamily: 'Roboto')),
          content: SizedBox(
            width: 320,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: AppColors.white),
                    decoration: InputDecoration(
                      hintText: 'Class name',
                      hintStyle: TextStyle(
                          color: AppColors.grey.withValues(alpha: 0.5),
                          fontSize: 13),
                      filled: true,
                      fillColor: AppColors.inputBg,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Students',
                      style: TextStyle(
                          color: AppColors.grey,
                          fontSize: 12,
                          fontFamily: 'Roboto')),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: studentCtrl,
                          style: const TextStyle(
                              color: AppColors.white),
                          decoration: InputDecoration(
                            hintText: 'Add student',
                            hintStyle: TextStyle(
                                color: AppColors.grey
                                    .withValues(alpha: 0.4),
                                fontSize: 12),
                            filled: true,
                            fillColor: AppColors.inputBg,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          final n = studentCtrl.text.trim();
                          if (n.isNotEmpty) {
                            setLocal(() => students.add(n));
                            studentCtrl.clear();
                          }
                        },
                        icon: const Icon(Icons.add_circle,
                            color: AppColors.primaryCyan),
                      ),
                    ],
                  ),
                  ...students.map((s) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.person_outline,
                            color: AppColors.grey, size: 16),
                        title: Text(s,
                            style: const TextStyle(
                                color: AppColors.white,
                                fontSize: 13,
                                fontFamily: 'Roboto')),
                        trailing: IconButton(
                          icon: const Icon(Icons.close,
                              color: AppColors.grey, size: 16),
                          onPressed: () =>
                              setLocal(() => students.remove(s)),
                        ),
                      )),
                  const SizedBox(height: 12),
                  const Text('Assign Songs',
                      style: TextStyle(
                          color: AppColors.grey,
                          fontSize: 12,
                          fontFamily: 'Roboto')),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _availableSongs.map((song) {
                      final sel = selectedSongs.contains(song);
                      return GestureDetector(
                        onTap: () => setLocal(() {
                          if (sel) {
                            selectedSongs.remove(song);
                          } else {
                            selectedSongs.add(song);
                          }
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: sel
                                ? AppColors.primaryCyan
                                    .withValues(alpha: 0.2)
                                : AppColors.inputBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: sel
                                    ? AppColors.primaryCyan
                                    : Colors.transparent),
                          ),
                          child: Text(song,
                              style: TextStyle(
                                  color: sel
                                      ? AppColors.primaryCyan
                                      : AppColors.grey,
                                  fontSize: 11,
                                  fontFamily: 'Roboto')),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: TextStyle(
                      color: AppColors.grey.withValues(alpha: 0.8),
                      fontFamily: 'Roboto')),
            ),
            ElevatedButton(
              onPressed: () async {
                await SessionStorageService.updateClass(index, {
                  'name': nameCtrl.text.trim(),
                  'students': students,
                  'assignedSongs': selectedSongs,
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryCyan,
                foregroundColor: Colors.black,
                elevation: 0,
              ),
              child: const Text('Save',
                  style: TextStyle(fontFamily: 'Roboto')),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteClass(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text('Delete Class',
            style: TextStyle(
                color: AppColors.white, fontFamily: 'Roboto')),
        content: const Text(
            'Are you sure you want to delete this class?',
            style: TextStyle(
                color: AppColors.grey, fontFamily: 'Roboto')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(
                    color: AppColors.grey.withValues(alpha: 0.8),
                    fontFamily: 'Roboto')),
          ),
          TextButton(
            onPressed: () async {
              await SessionStorageService.deleteClass(index);
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
            },
            child: const Text('Delete',
                style: TextStyle(
                    color: Color(0xFFF44336),
                    fontFamily: 'Roboto')),
          ),
        ],
      ),
    );
  }

  // ── Export helpers ────────────────────────────────────────────────────────

  void _exportRubric(
      String className, List<String> students, List<String> songs) {
    final buf = StringBuffer();
    buf.writeln('=== HUNI RUBRIC EXPORT ===');
    buf.writeln('Class: $className');
    buf.writeln('Date: ${DateTime.now()}');
    buf.writeln('');
    buf.writeln('Students (${students.length}):');
    for (final s in students) {
      buf.writeln('  - $s');
    }
    buf.writeln('');
    buf.writeln('Assigned Songs:');
    for (final song in songs) {
      buf.writeln('  - $song');
    }
    buf.writeln('');
    buf.writeln('Rubric Criteria:');
    buf.writeln('  5 stars (95-100): Excellent pitch accuracy');
    buf.writeln('  4 stars (80-94) : Good with minor deviations');
    buf.writeln('  3 stars (65-79) : Average, needs improvement');
    buf.writeln('  2 stars (50-64) : Below average');
    buf.writeln('  1 star  (0-49)  : Needs significant practice');

    Clipboard.setData(ClipboardData(text: buf.toString()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Rubric copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ));
    }
  }

  void _exportAllReportsToClipboard() {
    final buf = StringBuffer();
    buf.writeln('=== HUNI BATCH REPORT ===');
    buf.writeln('Generated: ${DateTime.now()}');
    buf.writeln('Total sessions: ${_allSessions.length}');
    buf.writeln('');

    final Map<String, List<SessionResult>> bySong = {};
    for (final s in _allSessions) {
      bySong.putIfAbsent(s.songTitle, () => []).add(s);
    }

    for (final entry in bySong.entries) {
      final sessions = entry.value;
      final avg =
          sessions.map((s) => s.score).reduce((a, b) => a + b) /
              sessions.length;
      final avgFlat =
          sessions.map((s) => s.avgFlatPercent).reduce((a, b) => a + b) /
              sessions.length;
      final avgSharp =
          sessions.map((s) => s.avgSharpPercent).reduce((a, b) => a + b) /
              sessions.length;
      buf.writeln('Song: ${entry.key}');
      buf.writeln('  Attempts: ${sessions.length}');
      buf.writeln('  Avg Score: ${avg.toStringAsFixed(0)} pts');
      buf.writeln('  Avg Flat:  ${avgFlat.toStringAsFixed(0)}%');
      buf.writeln('  Avg Sharp: ${avgSharp.toStringAsFixed(0)}%');
      buf.writeln('');
    }

    Clipboard.setData(ClipboardData(text: buf.toString()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Batch report copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ));
    }
  }

  Widget _emptyState(String title, String subtitle, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.grey.withValues(alpha: 0.4), size: 56),
          const SizedBox(height: 12),
          Text(title,
              style: TextStyle(
                  color: AppColors.grey.withValues(alpha: 0.7),
                  fontSize: 16,
                  fontFamily: 'Roboto')),
          const SizedBox(height: 6),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.grey.withValues(alpha: 0.4),
                  fontSize: 13,
                  fontFamily: 'Roboto')),
        ],
      ),
    );
  }
}
