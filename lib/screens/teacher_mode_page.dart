<<<<<<< HEAD
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../core/audio_service.dart';
import '../core/note_utils.dart';
import '../core/pitch_server_config.dart';
=======
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f
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
<<<<<<< HEAD
  int _tab = 0; // 0 = Classes, 1 = Reports, 2 = Session Log, 3 = Live Pitch

  // ── Live Pitch (CREPE) state ─────────────────────────────────────────────────
  final _audioService = AudioService();
  StreamSubscription<NoteResult?>? _audioSub;
  final List<double> _pitchHistory = [];
  bool _pitchWorking = false;
  bool _isListening = false;
  NoteResult? _currentNote;
=======
  int _tab = 0; // 0 = Classes, 1 = Reports, 2 = Session Log
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f

  @override
  void initState() {
    super.initState();
    _load();
<<<<<<< HEAD
    _audioService.initialize();
  }

  @override
  void dispose() {
    _audioSub?.cancel();
    _audioService.dispose();
    super.dispose();
=======
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f
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
<<<<<<< HEAD
    final tabs = ['Classes', 'Reports', 'Log', 'Live Pitch'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: List.generate(4, (i) {
          final selected = _tab == i;
          final isLive = i == 3;
=======
    final tabs = ['Classes', 'Reports', 'Session Log'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: List.generate(3, (i) {
          final selected = _tab == i;
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tab = i),
              child: Container(
<<<<<<< HEAD
                margin: EdgeInsets.only(right: i < 3 ? 8 : 0),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primaryCyan : AppColors.inputBg,
                  borderRadius: BorderRadius.circular(10),
                  border: !selected && isLive
                      ? Border.all(
                          color: AppColors.primaryCyan.withValues(alpha: 0.3),
                          width: 1)
                      : null,
=======
                margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primaryCyan
                      : AppColors.inputBg,
                  borderRadius: BorderRadius.circular(10),
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f
                ),
                child: Text(tabs[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: selected
                            ? Colors.black
<<<<<<< HEAD
                            : isLive
                                ? AppColors.primaryCyan
                                : AppColors.grey,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
=======
                            : AppColors.grey,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f
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
<<<<<<< HEAD
      case 3:
        return _buildLivePitchTab();
=======
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f
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
<<<<<<< HEAD

  // ── Tab 3: Live Pitch (CREPE) ─────────────────────────────────────────────────

  Future<void> _startListening() async {
    final ok = await _audioService.start();
    if (!ok || !mounted) return;
    setState(() => _isListening = true);
    _audioSub = _audioService.results.listen((result) {
      if (!mounted) return;
      final hz = result?.frequency ?? 0.0;
      setState(() {
        _currentNote = result;
        _pitchHistory.add(hz);
        if (_pitchHistory.length > 200) _pitchHistory.removeAt(0);
        if (hz > 0 && !_pitchWorking) _pitchWorking = true;
      });
    });
  }

  Future<void> _stopListening() async {
    await _audioSub?.cancel();
    _audioSub = null;
    await _audioService.stop();
    if (mounted) {
      setState(() {
        _isListening = false;
        _pitchWorking = false;
        _currentNote = null;
        _pitchHistory.clear();
      });
    }
  }

  Widget _buildLivePitchTab() {
    final note = _currentNote;
    final hz = note?.frequency ?? 0.0;
    final feedback = note?.feedback ?? PitchFeedback.noSignal;
    final cents = note?.cents ?? 0.0;

    String feedbackLabel;
    Color feedbackColor;
    switch (feedback) {
      case PitchFeedback.correct:
        feedbackLabel = 'In Tune ✓';
        feedbackColor = const Color(0xFF4CAF50);
        break;
      case PitchFeedback.tooHigh:
        feedbackLabel = 'Sharp ↑';
        feedbackColor = const Color(0xFFF44336);
        break;
      case PitchFeedback.tooLow:
        feedbackLabel = 'Flat ↓';
        feedbackColor = const Color(0xFFFFA726);
        break;
      case PitchFeedback.noSignal:
        feedbackLabel = _isListening ? 'No Signal' : 'Tap Start';
        feedbackColor = AppColors.grey;
        break;
    }

    final lineColor = switch (feedback) {
      PitchFeedback.correct => const Color(0xFF4CAF50),
      PitchFeedback.tooHigh => const Color(0xFFF44336),
      PitchFeedback.tooLow => const Color(0xFFFFA726),
      PitchFeedback.noSignal => AppColors.primaryCyan,
    };

    final showNoSignal = !_pitchWorking;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ── Connection status ────────────────────────────────────────────────
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _audioService.isUsingServer
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFFFA726),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _audioService.isUsingServer
                        ? 'CREPE Server Connected'
                        : 'On-Device Pitch (YIN Fallback)',
                    style: TextStyle(
                      color: _audioService.isUsingServer
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFFFA726),
                      fontSize: 12,
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (_isListening && _pitchWorking) ...[
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                        color: AppColors.primaryCyan,
                        shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 4),
                  const Text('Live',
                      style: TextStyle(
                          color: AppColors.primaryCyan,
                          fontSize: 11,
                          fontFamily: 'Roboto',
                          fontWeight: FontWeight.w600)),
                ],
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── Current pitch display ────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hz > 0
                    ? feedbackColor.withValues(alpha: 0.3)
                    : Colors.transparent,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      note != null && hz > 0 ? note.fullName : '—',
                      style: TextStyle(
                        color:
                            hz > 0 ? feedbackColor : AppColors.grey,
                        fontSize: 72,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Roboto',
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        hz > 0 ? '${hz.toStringAsFixed(1)} Hz' : '',
                        style: const TextStyle(
                            color: AppColors.grey,
                            fontSize: 13,
                            fontFamily: 'Roboto'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  feedbackLabel,
                  style: TextStyle(
                    color: feedbackColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Roboto',
                  ),
                ),
                if (hz > 0) ...[
                  const SizedBox(height: 12),
                  _buildCentsBar(cents),
                ],
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── Pitch graph ──────────────────────────────────────────────────────
          Container(
            height: 190,
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _TeacherPitchGraphPainter(
                        pitchHistory:
                            List.unmodifiable(_pitchHistory),
                        lineColor: lineColor,
                      ),
                    ),
                  ),
                  if (showNoSignal)
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.mic_off,
                              color: AppColors.grey
                                  .withValues(alpha: 0.4),
                              size: 32),
                          const SizedBox(height: 6),
                          Text(
                            _isListening
                                ? 'Sing or speak loudly'
                                : 'Press Start to begin',
                            style: TextStyle(
                                color: AppColors.grey
                                    .withValues(alpha: 0.5),
                                fontSize: 13,
                                fontFamily: 'Roboto'),
                          ),
                        ],
                      ),
                    ),
                  Positioned(
                    top: 8,
                    left: 12,
                    child: Text('Pitch Graph',
                        style: TextStyle(
                            color:
                                AppColors.grey.withValues(alpha: 0.5),
                            fontSize: 10,
                            fontFamily: 'Roboto')),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Start / Stop button ──────────────────────────────────────────────
          GestureDetector(
            onTap: _isListening ? _stopListening : _startListening,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: _isListening
                    ? const Color(0xFFF44336).withValues(alpha: 0.1)
                    : AppColors.primaryCyan.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _isListening
                      ? const Color(0xFFF44336)
                      : AppColors.primaryCyan,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isListening ? Icons.stop_rounded : Icons.mic,
                    color: _isListening
                        ? const Color(0xFFF44336)
                        : AppColors.primaryCyan,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isListening ? 'Stop Listening' : 'Start Listening',
                    style: TextStyle(
                      color: _isListening
                          ? const Color(0xFFF44336)
                          : AppColors.primaryCyan,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // ── Server info ──────────────────────────────────────────────────────
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    color: AppColors.grey, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'CREPE server: ${PitchServerConfig.wsUrl}\n'
                    'Run crepe_server.py on your PC for highest accuracy.',
                    style: TextStyle(
                        color: AppColors.grey.withValues(alpha: 0.5),
                        fontSize: 10,
                        fontFamily: 'Roboto',
                        height: 1.5),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildCentsBar(double cents) {
    final clamped = cents.clamp(-50.0, 50.0);
    final fraction = (clamped + 50.0) / 100.0;
    final barColor = cents.abs() < 35
        ? const Color(0xFF4CAF50)
        : cents > 0
            ? const Color(0xFFF44336)
            : const Color(0xFFFFA726);

    return Column(
      children: [
        LayoutBuilder(builder: (_, constraints) {
          final w = constraints.maxWidth;
          return Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.inputBg,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Positioned(
                left: (w * fraction - 5).clamp(0.0, w - 10),
                top: 0,
                child: Container(
                  width: 10,
                  height: 8,
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          );
        }),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Flat ↓',
                style: TextStyle(
                    color: AppColors.grey.withValues(alpha: 0.4),
                    fontSize: 9,
                    fontFamily: 'Roboto')),
            Text('${cents.toStringAsFixed(0)} cents',
                style: const TextStyle(
                    color: AppColors.grey,
                    fontSize: 10,
                    fontFamily: 'Roboto')),
            Text('Sharp ↑',
                style: TextStyle(
                    color: AppColors.grey.withValues(alpha: 0.4),
                    fontSize: 9,
                    fontFamily: 'Roboto')),
          ],
        ),
      ],
    );
  }
}

// ── Pitch graph painter ───────────────────────────────────────────────────────

class _TeacherPitchGraphPainter extends CustomPainter {
  final List<double> pitchHistory;
  final Color lineColor;

  const _TeacherPitchGraphPainter({
    required this.pitchHistory,
    required this.lineColor,
  });

  static const double _minHz = 100.0;
  static const double _maxHz = 900.0;
  static const int _windowSize = 80;

  static const _gridNotes = <String, double>{
    'C3': 130.81, 'E3': 164.81, 'G3': 196.00,
    'C4': 261.63, 'E4': 329.63, 'G4': 392.00, 'A4': 440.00,
    'C5': 523.25, 'E5': 659.25, 'G5': 783.99,
  };

  double _hzToY(double hz, double height) {
    final logMin = math.log(_minHz);
    final logMax = math.log(_maxHz);
    final logHz = math.log(hz.clamp(_minHz, _maxHz));
    return height - ((logHz - logMin) / (logMax - logMin)) * height;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = const Color(0xFF1A1A1A),
    );

    // Grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFF2A2A2A)
      ..strokeWidth = 1;
    final labelStyle = const TextStyle(
      color: Color(0xFF444444),
      fontSize: 9,
      fontFamily: 'Roboto',
    );

    for (final entry in _gridNotes.entries) {
      final y = _hzToY(entry.value, h);
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
      final span = TextSpan(text: entry.key, style: labelStyle);
      final tp = TextPainter(
          text: span, textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, Offset(4, y - 9));
    }

    // Pitch line — show last _windowSize samples
    final window = pitchHistory.length > _windowSize
        ? pitchHistory.sublist(pitchHistory.length - _windowSize)
        : pitchHistory;

    if (window.isEmpty) return;

    final xStep = w / _windowSize;
    final linePaint = Paint()
      ..color = lineColor.withValues(alpha: 0.85)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    Offset? prev;
    for (int i = 0; i < window.length; i++) {
      final hz = window[i];
      if (hz <= 0) {
        prev = null;
        continue;
      }
      final x = i * xStep;
      final y = _hzToY(hz, h);
      final pt = Offset(x, y);
      if (prev != null) {
        canvas.drawLine(prev, pt, linePaint);
      }
      prev = pt;
    }

    // Current pitch dot (last non-zero)
    double? lastHz;
    for (final hz in window.reversed) {
      if (hz > 0) { lastHz = hz; break; }
    }
    if (lastHz != null) {
      final dotX = (window.length - 1) * xStep;
      final dotY = _hzToY(lastHz, h);
      canvas.drawCircle(
          Offset(dotX, dotY), 5,
          Paint()..color = lineColor.withValues(alpha: 0.9));
      canvas.drawCircle(
          Offset(dotX, dotY), 3,
          Paint()..color = const Color(0xFFFFFFFF));
    }

    // Right-edge cursor line
    canvas.drawLine(
      Offset(w - 1, 0),
      Offset(w - 1, h),
      Paint()
        ..color = const Color(0xFF333333)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_TeacherPitchGraphPainter old) =>
      old.pitchHistory != pitchHistory || old.lineColor != lineColor;
=======
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f
}
