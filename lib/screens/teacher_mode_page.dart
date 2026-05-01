import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../data/lyrics.dart';
import '../models/session_result.dart';
import '../services/session_storage_service.dart';

/// MAPEH Teacher Mode — Huni dark theme + Figma layout (no Live Pitch).
class TeacherModePage extends StatefulWidget {
  final int initialTab;
  const TeacherModePage({super.key, this.initialTab = 0});

  @override
  State<TeacherModePage> createState() => _TeacherModePageState();
}

class _TeacherModePageState extends State<TeacherModePage> {
  List<Map<String, dynamic>> _classes = [];
  List<SessionResult> _sessions = [];
  bool _loading = true;
  int _tab = 0; // 0=Overview 1=Students 2=Assignments 3=Analytics

  String _studentSearch = '';
  String _selectedSection = 'All Sections';

  // ── computed ───────────────────────────────────────────────────────────────
  int get _totalStudents =>
      _classes.fold(0, (s, c) => s + ((c['students'] as List?)?.length ?? 0));
  int get _activeClasses => _classes.length;
  double get _classAvg => _sessions.isEmpty
      ? 0
      : _sessions.map((s) => s.score).reduce((a, b) => a + b) /
            _sessions.length;
  double get _totalHours =>
      _sessions.fold(0.0, (s, r) => s + r.durationSeconds) / 3600;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    _load();
  }

  Future<void> _load() async {
    final cls = await SessionStorageService.loadClasses();
    final sess = await SessionStorageService.loadSessions();
    if (mounted) {
      setState(() {
        _classes = cls;
        _sessions = sess;
        _loading = false;
      });
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Column(
        children: [
          _buildHeader(context),
          _buildTabBar(),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryCyan,
                    ),
                  )
                : _buildTabContent(),
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          // Title row
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: AppColors.white,
                    size: 20,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Teacher Mode',
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Roboto',
                        ),
                      ),
                      Text(
                        'MAPEH Class Management',
                        style: TextStyle(
                          color: AppColors.grey,
                          fontSize: 12,
                          fontFamily: 'Roboto',
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.refresh_rounded,
                    color: AppColors.grey.withValues(alpha: 0.6),
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() => _loading = true);
                    _load();
                  },
                  tooltip: 'Refresh',
                ),
                IconButton(
                  icon: const Icon(
                    Icons.file_download_outlined,
                    color: AppColors.grey,
                    size: 22,
                  ),
                  onPressed: _exportAllReports,
                  tooltip: 'Export reports',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Stat cards row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                _statCard(Icons.people_outline, '$_totalStudents', 'Students'),
                const SizedBox(width: 10),
                _statCard(Icons.class_outlined, '$_activeClasses', 'Classes'),
                const SizedBox(width: 10),
                _statCard(
                  Icons.star_outline,
                  '${_classAvg.toStringAsFixed(0)}%',
                  'Class Avg',
                ),
                const SizedBox(width: 10),
                _statCard(
                  Icons.access_time_rounded,
                  '${_totalHours.toStringAsFixed(0)}h',
                  'Total Time',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(IconData icon, String value, String label) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primaryCyan.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primaryCyan, size: 18),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'Roboto',
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: AppColors.grey.withValues(alpha: 0.7),
              fontSize: 9,
              fontFamily: 'Roboto',
            ),
          ),
        ],
      ),
    ),
  );

  // ── Tab Bar ───────────────────────────────────────────────────────────────
  static const _tabLabels = [
    'Overview',
    'Students',
    'Assignments',
    'Analytics',
  ];
  static const _tabIcons = [
    Icons.dashboard_outlined,
    Icons.people_outline,
    Icons.queue_music_outlined,
    Icons.bar_chart_rounded,
  ];

  Widget _buildTabBar() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    child: Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.inputBg),
      ),
      child: Row(
        children: List.generate(4, (i) {
          final sel = _tab == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tab = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: sel
                      ? AppColors.primaryCyan.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: sel
                      ? Border.all(
                          color: AppColors.primaryCyan.withValues(alpha: 0.4),
                        )
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _tabIcons[i],
                      color: sel
                          ? AppColors.primaryCyan
                          : AppColors.grey.withValues(alpha: 0.5),
                      size: 16,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _tabLabels[i],
                      style: TextStyle(
                        color: sel
                            ? AppColors.primaryCyan
                            : AppColors.grey.withValues(alpha: 0.5),
                        fontSize: 9,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                        fontFamily: 'Roboto',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    ),
  );

  Widget _buildTabContent() {
    switch (_tab) {
      case 0:
        return _buildOverviewTab();
      case 1:
        return _buildStudentsTab();
      case 2:
        return _buildAssignmentsTab();
      case 3:
        return _buildAnalyticsTab();
      default:
        return const SizedBox();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 0 — OVERVIEW
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildOverviewTab() {
    final sorted = List<SessionResult>.from(_sessions)
      ..sort((a, b) => b.score.compareTo(a.score));
    final top3 = sorted.take(3).toList();
    final recent = _sessions.reversed.take(5).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Quick-action cards
        Row(
          children: [
            Expanded(
              child: _actionCard(
                icon: Icons.add_rounded,
                label: 'New Assignment',
                sub: 'Create & assign',
                color: AppColors.primaryCyan,
                onTap: () => setState(() => _tab = 2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _actionCard(
                icon: Icons.bar_chart_rounded,
                label: 'Analytics',
                sub: 'View insights',
                color: const Color(0xFF9C6FFF),
                onTap: () => setState(() => _tab = 3),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),

        // Top performers
        _sectionHeader(
          'Top Performers',
          Icons.star_rounded,
          onViewAll: () => setState(() => _tab = 1),
        ),
        const SizedBox(height: 10),
        if (top3.isEmpty)
          _emptyCard('No sessions recorded yet', Icons.star_outline)
        else
          ...top3.asMap().entries.map((e) => _topRow(e.key + 1, e.value)),

        const SizedBox(height: 22),

        // My Classes
        if (_classes.isNotEmpty) ...[
          _sectionHeader(
            'My Classes',
            Icons.class_outlined,
            onViewAll: () => setState(() => _tab = 2),
          ),
          const SizedBox(height: 10),
          ..._classes.asMap().entries.map(
            (e) => _quickClassRow(e.key, e.value),
          ),
          const SizedBox(height: 22),
        ],

        // Recent activity
        _sectionHeader('Recent Activity', Icons.history_rounded),
        const SizedBox(height: 10),
        if (recent.isEmpty)
          _emptyCard('No recent activity', Icons.history_outlined)
        else
          ...recent.map((s) => _activityRow(s)),
      ],
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String label,
    required String sub,
    required Color color,
    required VoidCallback onTap,
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 110,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const Spacer(),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              fontFamily: 'Roboto',
            ),
          ),
          Text(
            sub,
            style: TextStyle(
              color: color.withValues(alpha: 0.65),
              fontSize: 10,
              fontFamily: 'Roboto',
            ),
          ),
        ],
      ),
    ),
  );

  Widget _sectionHeader(
    String title,
    IconData icon, {
    VoidCallback? onViewAll,
  }) => Row(
    children: [
      Icon(icon, color: AppColors.primaryCyan, size: 16),
      const SizedBox(width: 7),
      Text(
        title,
        style: const TextStyle(
          color: AppColors.white,
          fontSize: 15,
          fontWeight: FontWeight.bold,
          fontFamily: 'Roboto',
        ),
      ),
      const Spacer(),
      if (onViewAll != null)
        GestureDetector(
          onTap: onViewAll,
          child: const Text(
            'View All',
            style: TextStyle(
              color: AppColors.primaryCyan,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: 'Roboto',
            ),
          ),
        ),
    ],
  );

  static const _rankColors = [
    Color(0xFFFFA726),
    AppColors.primaryCyan,
    Color(0xFF9C6FFF),
  ];

  Widget _topRow(int rank, SessionResult s) {
    final color = _rankColors[(rank - 1).clamp(0, 2)];
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(13),
      decoration: _card(),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            alignment: Alignment.center,
            child: Text(
              '$rank',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                fontFamily: 'Roboto',
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.songTitle,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Roboto',
                  ),
                ),
                Text(
                  s.songArtist,
                  style: const TextStyle(
                    color: AppColors.grey,
                    fontSize: 11,
                    fontFamily: 'Roboto',
                  ),
                ),
              ],
            ),
          ),
          _scoreBadge(s.score.round()),
        ],
      ),
    );
  }

  Widget _quickClassRow(int index, Map<String, dynamic> cls) {
    final name = cls['name'] as String? ?? '';
    final st = (cls['students'] as List<dynamic>? ?? []).length;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: _card(),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primaryCyan.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            alignment: Alignment.center,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: AppColors.primaryCyan,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                fontFamily: 'Roboto',
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Roboto',
                  ),
                ),
                Text(
                  '$st students',
                  style: const TextStyle(
                    color: AppColors.grey,
                    fontSize: 11,
                    fontFamily: 'Roboto',
                  ),
                ),
              ],
            ),
          ),
          _iconBtn(
            Icons.edit_outlined,
            AppColors.grey,
            () => _showEditClassDialog(index, cls),
          ),
          _iconBtn(
            Icons.delete_outline,
            AppColors.errorRed,
            () => _confirmDeleteClass(index),
          ),
        ],
      ),
    );
  }

  Widget _activityRow(SessionResult s) {
    final diff = DateTime.now().difference(s.completedAt);
    final ago = diff.inHours < 1
        ? '${diff.inMinutes}m ago'
        : diff.inHours < 24
        ? '${diff.inHours}h ago'
        : '${diff.inDays}d ago';
    final score = s.score.round();
    final color = score >= 80
        ? const Color(0xFF4CAF50)
        : score >= 60
        ? const Color(0xFFFFA726)
        : AppColors.errorRed;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(
            score >= 80
                ? Icons.check_circle_outline
                : score >= 60
                ? Icons.info_outline
                : Icons.warning_amber_outlined,
            color: color,
            size: 17,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Completed "${s.songTitle}"',
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Roboto',
                  ),
                ),
                Text(
                  '$score% accuracy · $ago',
                  style: const TextStyle(
                    color: AppColors.grey,
                    fontSize: 11,
                    fontFamily: 'Roboto',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard(String text, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(vertical: 24),
    decoration: _card(),
    child: Column(
      children: [
        Icon(icon, color: AppColors.grey.withValues(alpha: 0.3), size: 36),
        const SizedBox(height: 8),
        Text(
          text,
          style: TextStyle(
            color: AppColors.grey.withValues(alpha: 0.55),
            fontSize: 13,
            fontFamily: 'Roboto',
          ),
        ),
      ],
    ),
  );

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 1 — STUDENTS
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildStudentsTab() {
    final all = <Map<String, String>>[];
    for (final cls in _classes) {
      final n = cls['name'] as String? ?? '';
      for (final s
          in (cls['students'] as List<dynamic>? ?? []).cast<String>()) {
        all.add({'name': s, 'class': n});
      }
    }
    final sections = [
      'All Sections',
      ..._classes.map((c) => c['name'] as String? ?? ''),
    ];
    final filtered = all.where((s) {
      final okSec =
          _selectedSection == 'All Sections' || s['class'] == _selectedSection;
      final okSrch =
          _studentSearch.isEmpty ||
          s['name']!.toLowerCase().contains(_studentSearch.toLowerCase());
      return okSec && okSrch;
    }).toList();

    return Column(
      children: [
        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => _studentSearch = v),
            style: const TextStyle(color: AppColors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search students...',
              hintStyle: TextStyle(
                color: AppColors.grey.withValues(alpha: 0.5),
                fontSize: 13,
              ),
              prefixIcon: Icon(
                Icons.search,
                color: AppColors.grey.withValues(alpha: 0.5),
                size: 20,
              ),
              filled: true,
              fillColor: AppColors.inputBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.primaryCyan,
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
          ),
        ),
        // Section chips
        SizedBox(
          height: 38,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: sections.length,
            itemBuilder: (_, i) {
              final sec = sections[i];
              final sel = _selectedSection == sec;
              return GestureDetector(
                onTap: () => setState(() => _selectedSection = sec),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: sel
                        ? AppColors.primaryCyan.withValues(alpha: 0.15)
                        : AppColors.inputBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: sel
                          ? AppColors.primaryCyan.withValues(alpha: 0.5)
                          : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    sec,
                    style: TextStyle(
                      color: sel ? AppColors.primaryCyan : AppColors.grey,
                      fontSize: 12,
                      fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    all.isEmpty
                        ? 'Add classes and students first'
                        : 'No students match your search',
                    style: TextStyle(
                      color: AppColors.grey.withValues(alpha: 0.55),
                      fontSize: 13,
                      fontFamily: 'Roboto',
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _buildStudentCard(filtered[i], i),
                ),
        ),
      ],
    );
  }

  static const _avatarColors = [
    AppColors.primaryCyan,
    Color(0xFF9C6FFF),
    Color(0xFFFFA726),
    Color(0xFF4CAF50),
    Color(0xFFEF5350),
  ];

  Widget _buildStudentCard(Map<String, String> student, int index) {
    final name = student['name']!;
    final cls = student['class']!;
    final color = _avatarColors[index % _avatarColors.length];
    final avg = _classAvg;
    final flat = _sessions.isEmpty
        ? 0.0
        : _sessions.map((s) => s.avgFlatPercent).reduce((a, b) => a + b) /
              _sessions.length;
    final sharp = _sessions.isEmpty
        ? 0.0
        : _sessions.map((s) => s.avgSharpPercent).reduce((a, b) => a + b) /
              _sessions.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: _card(),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                alignment: Alignment.center,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: color,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Roboto',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Roboto',
                      ),
                    ),
                    Text(
                      cls,
                      style: const TextStyle(
                        color: AppColors.grey,
                        fontSize: 11,
                        fontFamily: 'Roboto',
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${avg.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: Color(0xFF4CAF50),
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Roboto',
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.trending_up,
                        color: Color(0xFF4CAF50),
                        size: 11,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'Improving',
                        style: TextStyle(
                          color: const Color(
                            0xFF4CAF50,
                          ).withValues(alpha: 0.85),
                          fontSize: 10,
                          fontFamily: 'Roboto',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _miniStat(
                  '${_sessions.length}',
                  'Songs',
                  AppColors.primaryCyan,
                ),
              ),
              Container(width: 1, height: 28, color: AppColors.inputBg),
              Expanded(
                child: _miniStat(
                  '${flat.toStringAsFixed(0)}%',
                  'Flat',
                  const Color(0xFFFFA726),
                ),
              ),
              Container(width: 1, height: 28, color: AppColors.inputBg),
              Expanded(
                child: _miniStat(
                  '${sharp.toStringAsFixed(0)}%',
                  'Sharp',
                  const Color(0xFFEF5350),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (avg / 100).clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: AppColors.inputBg,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primaryCyan,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String val, String label, Color color) => Column(
    children: [
      Text(
        val,
        style: TextStyle(
          color: color,
          fontSize: 15,
          fontWeight: FontWeight.bold,
          fontFamily: 'Roboto',
        ),
      ),
      Text(
        label,
        style: const TextStyle(
          color: AppColors.grey,
          fontSize: 10,
          fontFamily: 'Roboto',
        ),
      ),
    ],
  );

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 2 — ASSIGNMENTS
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildAssignmentsTab() {
    final assignments = <Map<String, dynamic>>[];
    for (final cls in _classes) {
      final cName = cls['name'] as String? ?? '';
      final students = (cls['students'] as List<dynamic>? ?? []).length;
      for (final song
          in (cls['assignedSongs'] as List<dynamic>? ?? []).cast<String>()) {
        final ss = _sessions.where((s) => s.songTitle == song).toList();
        assignments.add({
          'song': song,
          'class': cName,
          'students': students,
          'completed': ss.length.clamp(0, students),
          'avgScore': ss.isEmpty
              ? 0.0
              : ss.map((s) => s.score).reduce((a, b) => a + b) / ss.length,
        });
      }
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: GestureDetector(
            onTap: _showAddClassDialog,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: AppColors.primaryCyan,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryCyan.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.add_rounded, color: Colors.black, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Create New Assignment',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: assignments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.queue_music_rounded,
                        color: AppColors.grey.withValues(alpha: 0.3),
                        size: 56,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No assignments yet',
                        style: TextStyle(
                          color: AppColors.grey.withValues(alpha: 0.6),
                          fontSize: 15,
                          fontFamily: 'Roboto',
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Add songs to a class to get started',
                        style: TextStyle(
                          color: AppColors.grey.withValues(alpha: 0.4),
                          fontSize: 12,
                          fontFamily: 'Roboto',
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: assignments.length,
                  itemBuilder: (_, i) => _buildAssignmentCard(assignments[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildAssignmentCard(Map<String, dynamic> a) {
    final song = a['song'] as String;
    final cls = a['class'] as String;
    final students = a['students'] as int;
    final completed = a['completed'] as int;
    final avgScore = a['avgScore'] as double;
    final pct = students == 0 ? 0.0 : (completed / students).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: _card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primaryCyan.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.music_note_rounded,
                  color: AppColors.primaryCyan,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Roboto',
                      ),
                    ),
                    Text(
                      cls,
                      style: const TextStyle(
                        color: AppColors.grey,
                        fontSize: 11,
                        fontFamily: 'Roboto',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _chip('MAPEH', AppColors.primaryCyan),
                        const SizedBox(width: 6),
                        _chip('📅 Due soon', const Color(0xFFFFA726)),
                      ],
                    ),
                  ],
                ),
              ),
              _scoreBadge(avgScore.round()),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Completion Rate',
                style: TextStyle(
                  color: AppColors.grey,
                  fontSize: 12,
                  fontFamily: 'Roboto',
                ),
              ),
              Text(
                '$completed/$students (${(pct * 100).round()}%)',
                style: const TextStyle(
                  color: AppColors.grey,
                  fontSize: 12,
                  fontFamily: 'Roboto',
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 5,
              backgroundColor: AppColors.inputBg,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primaryCyan,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _outlineBtn('View', Icons.visibility_outlined),
              const SizedBox(width: 8),
              _outlineBtn('Export', Icons.copy_outlined),
              const SizedBox(width: 8),
              _outlineBtn('Stats', Icons.bar_chart_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 10, fontFamily: 'Roboto'),
    ),
  );

  Widget _outlineBtn(String label, IconData icon) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primaryCyan.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primaryCyan.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.primaryCyan, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.primaryCyan,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              fontFamily: 'Roboto',
            ),
          ),
        ],
      ),
    ),
  );

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 3 — ANALYTICS
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildAnalyticsTab() {
    final avgFlat = _sessions.isEmpty
        ? 0.0
        : _sessions.map((s) => s.avgFlatPercent).reduce((a, b) => a + b) /
              _sessions.length;
    final avgSharp = _sessions.isEmpty
        ? 0.0
        : _sessions.map((s) => s.avgSharpPercent).reduce((a, b) => a + b) /
              _sessions.length;
    final avgSilent = _sessions.isEmpty
        ? 0.0
        : _sessions
                  .map((s) => (1 - s.overallVoiceActivity) * 100)
                  .reduce((a, b) => a + b) /
              _sessions.length;
    final weekly = _weeklyScores();

    final tagPct = _sessions.isEmpty
        ? 62
        : (_sessions.where((s) => _isTagalog(s.songTitle)).length /
                  _sessions.length *
                  100)
              .round();
    final bisPct = _sessions.isEmpty
        ? 10
        : (_sessions.where((s) => _isBisaya(s.songTitle)).length /
                  _sessions.length *
                  100)
              .round();
    final engPct = (100 - tagPct - bisPct).clamp(0, 100);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Performance trend
        _analyticsCard(
          title: 'Class Performance Trend',
          icon: Icons.show_chart_rounded,
          child: Column(
            children: [
              SizedBox(
                height: 160,
                child: CustomPaint(
                  painter: _TrendPainter(weekly),
                  child: const SizedBox.expand(),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  weekly.length,
                  (i) => Text(
                    'W${i + 1}',
                    style: TextStyle(
                      color: AppColors.grey.withValues(alpha: 0.5),
                      fontSize: 9,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Average accuracy over ${weekly.length} weeks',
                style: TextStyle(
                  color: AppColors.grey.withValues(alpha: 0.45),
                  fontSize: 10,
                  fontFamily: 'Roboto',
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Common Issues
        _analyticsCard(
          title: 'Common Issues',
          icon: Icons.warning_amber_rounded,
          child: Column(
            children: [
              _issueBar(
                'Flat Notes (High Range)',
                avgFlat,
                const Color(0xFFFFA726),
              ),
              const SizedBox(height: 12),
              _issueBar(
                'Sharp Notes (Sustained)',
                avgSharp,
                AppColors.primaryCyan,
              ),
              const SizedBox(height: 12),
              _issueBar('Breath Control', avgSilent, const Color(0xFF9C6FFF)),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Song Language Preference
        _analyticsCard(
          title: 'Song Language Preference',
          icon: Icons.language_rounded,
          child: Row(
            children: [
              _langBox('$tagPct%', 'Tagalog', AppColors.primaryCyan),
              const SizedBox(width: 10),
              _langBox('$engPct%', 'English', const Color(0xFF9C6FFF)),
              const SizedBox(width: 10),
              _langBox('$bisPct%', 'Bisaya', const Color(0xFFFFA726)),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Class Recommendations
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primaryCyan.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.primaryCyan.withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    color: AppColors.primaryCyan,
                    size: 16,
                  ),
                  SizedBox(width: 7),
                  Text(
                    'Class Recommendations',
                    style: TextStyle(
                      color: AppColors.primaryCyan,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ..._buildRecommendations(
                avgFlat,
                avgSharp,
                avgSilent,
              ).map((r) => _recRow(r)),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Batch report by song
        if (_sessions.isNotEmpty)
          _analyticsCard(
            title: 'Batch Report by Song',
            icon: Icons.music_note_outlined,
            child: Column(
              children: [
                ..._bySong().entries.map((e) {
                  final avg =
                      e.value.map((s) => s.score).reduce((a, b) => a + b) /
                      e.value.length;
                  final flat =
                      e.value
                          .map((s) => s.avgFlatPercent)
                          .reduce((a, b) => a + b) /
                      e.value.length;
                  final shp =
                      e.value
                          .map((s) => s.avgSharpPercent)
                          .reduce((a, b) => a + b) /
                      e.value.length;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                e.key,
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Roboto',
                                ),
                              ),
                            ),
                            _scoreBadge(avg.round()),
                          ],
                        ),
                        const SizedBox(height: 6),
                        _issueBar('Flat', flat, const Color(0xFFFFA726)),
                        const SizedBox(height: 4),
                        _issueBar('Sharp', shp, AppColors.primaryCyan),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),

        const SizedBox(height: 14),

        // Export
        GestureDetector(
          onTap: _exportAllReports,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.inputBg),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.copy_outlined,
                  color: AppColors.primaryCyan,
                  size: 16,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Export All Reports to Clipboard',
                    style: TextStyle(
                      color: AppColors.primaryCyan,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: AppColors.primaryCyan.withValues(alpha: 0.5),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _analyticsCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) => Container(
    padding: const EdgeInsets.all(16),
    decoration: _card(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.primaryCyan, size: 15),
            const SizedBox(width: 7),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                fontFamily: 'Roboto',
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        child,
      ],
    ),
  );

  Widget _issueBar(String label, double pct, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 12,
                fontFamily: 'Roboto',
              ),
            ),
          ),
          Text(
            '${pct.toStringAsFixed(0)}%',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: 'Roboto',
            ),
          ),
        ],
      ),
      const SizedBox(height: 5),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: (pct / 100).clamp(0.0, 1.0),
          minHeight: 6,
          backgroundColor: color.withValues(alpha: 0.1),
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ),
    ],
  );

  Widget _langBox(String pct, String label, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            pct,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Roboto',
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.grey,
              fontSize: 10,
              fontFamily: 'Roboto',
            ),
          ),
        ],
      ),
    ),
  );

  Widget _recRow(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.check_circle_rounded,
          color: AppColors.primaryCyan,
          size: 14,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: AppColors.white.withValues(alpha: 0.85),
              fontSize: 12,
              fontFamily: 'Roboto',
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );

  List<String> _buildRecommendations(double flat, double sharp, double silent) {
    final r = <String>[];
    if (flat > 20) r.add('Focus on high note drills for students singing flat');
    if (sharp > 15) {
      r.add('Practice slow, sustained phrases to reduce sharpness');
    }
    if (silent > 30) {
      r.add('Schedule breath control workshops to improve voice activity');
    }
    r.add('Introduce more Filipino songs to diversify repertoire');
    if (r.length < 3) r.add('Group practice sessions encourage peer learning');
    return r.take(4).toList();
  }

  bool _isTagalog(String t) => [
    'dadalhin',
    'tala',
    'buwan',
    'ikaw',
    'ako',
    'ang',
    'ng',
    'sa',
    'mahal',
    'puso',
  ].any((w) => t.toLowerCase().contains(w));
  bool _isBisaya(String t) => [
    'gugma',
    'palangga',
    'bisaya',
    'cebuano',
    'cebu',
  ].any((w) => t.toLowerCase().contains(w));

  Map<String, List<SessionResult>> _bySong() {
    final m = <String, List<SessionResult>>{};
    for (final s in _sessions) {
      m.putIfAbsent(s.songTitle, () => []).add(s);
    }
    return m;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DIALOGS
  // ─────────────────────────────────────────────────────────────────────────
  final _availableSongs = SongLyrics.allTitles;

  void _showAddClassDialog() {
    final nameCtrl = TextEditingController();
    final stuCtrl = TextEditingController();
    final students = <String>[];
    final selSongs = <String>[];
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setL) => _dialog(
          ctx: ctx,
          title: 'New Class',
          content: _classForm(nameCtrl, stuCtrl, students, selSongs, setL),
          onSave: () async {
            if (nameCtrl.text.trim().isEmpty) return;
            await SessionStorageService.addClass({
              'name': nameCtrl.text.trim(),
              'students': students,
              'assignedSongs': selSongs,
            });
            if (ctx.mounted) Navigator.pop(ctx);
            _load();
          },
          saveLabel: 'Create Class',
        ),
      ),
    );
  }

  void _showEditClassDialog(int index, Map<String, dynamic> cls) {
    final nameCtrl = TextEditingController(text: cls['name'] as String? ?? '');
    final stuCtrl = TextEditingController();
    final students = List<String>.from(cls['students'] as List<dynamic>? ?? []);
    final selSongs = List<String>.from(
      cls['assignedSongs'] as List<dynamic>? ?? [],
    );
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setL) => _dialog(
          ctx: ctx,
          title: 'Edit Class',
          content: _classForm(nameCtrl, stuCtrl, students, selSongs, setL),
          onSave: () async {
            await SessionStorageService.updateClass(index, {
              'name': nameCtrl.text.trim(),
              'students': students,
              'assignedSongs': selSongs,
            });
            if (ctx.mounted) Navigator.pop(ctx);
            _load();
          },
          saveLabel: 'Save Changes',
        ),
      ),
    );
  }

  Widget _dialog({
    required BuildContext ctx,
    required String title,
    required Widget content,
    required VoidCallback onSave,
    required String saveLabel,
  }) => AlertDialog(
    backgroundColor: AppColors.cardBg,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    titlePadding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
    contentPadding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
    title: Text(
      title,
      style: const TextStyle(
        color: AppColors.white,
        fontSize: 16,
        fontWeight: FontWeight.bold,
        fontFamily: 'Roboto',
      ),
    ),
    content: SizedBox(width: 340, child: content),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(ctx),
        child: Text(
          'Cancel',
          style: TextStyle(
            color: AppColors.grey.withValues(alpha: 0.8),
            fontFamily: 'Roboto',
          ),
        ),
      ),
      ElevatedButton(
        onPressed: onSave,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryCyan,
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
        child: Text(
          saveLabel,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontFamily: 'Roboto',
          ),
        ),
      ),
    ],
  );

  Widget _classForm(
    TextEditingController nameCtrl,
    TextEditingController stuCtrl,
    List<String> students,
    List<String> selSongs,
    StateSetter setL,
  ) => SingleChildScrollView(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fLabel('Class Name'),
        const SizedBox(height: 6),
        _fField(nameCtrl, 'e.g. Grade 9 — Rizal'),
        const SizedBox(height: 14),
        _fLabel('Students'),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: _fField(stuCtrl, 'Student name')),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                final n = stuCtrl.text.trim();
                if (n.isNotEmpty) {
                  setL(() => students.add(n));
                  stuCtrl.clear();
                }
              },
              child: Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: AppColors.primaryCyan,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.black,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
        if (students.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: students
                .map(
                  (s) => GestureDetector(
                    onTap: () => setL(() => students.remove(s)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryCyan.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.primaryCyan.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            s,
                            style: const TextStyle(
                              color: AppColors.primaryCyan,
                              fontSize: 12,
                              fontFamily: 'Roboto',
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Icon(
                            Icons.close,
                            color: AppColors.primaryCyan,
                            size: 12,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
        const SizedBox(height: 14),
        _fLabel('Assign Songs'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _availableSongs.map((song) {
            final sel = selSongs.contains(song);
            return GestureDetector(
              onTap: () => setL(() {
                if (sel) {
                  selSongs.remove(song);
                } else {
                  selSongs.add(song);
                }
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: sel
                      ? AppColors.primaryCyan.withValues(alpha: 0.15)
                      : AppColors.inputBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: sel ? AppColors.primaryCyan : Colors.transparent,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (sel)
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(
                          Icons.check_rounded,
                          color: AppColors.primaryCyan,
                          size: 12,
                        ),
                      ),
                    Text(
                      song,
                      style: TextStyle(
                        color: sel ? AppColors.primaryCyan : AppColors.grey,
                        fontSize: 12,
                        fontFamily: 'Roboto',
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    ),
  );

  Widget _fLabel(String t) => Text(
    t,
    style: TextStyle(
      color: AppColors.grey.withValues(alpha: 0.8),
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.4,
      fontFamily: 'Roboto',
    ),
  );

  Widget _fField(TextEditingController c, String hint) => TextField(
    controller: c,
    style: const TextStyle(color: AppColors.white, fontSize: 13),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: AppColors.grey.withValues(alpha: 0.4),
        fontSize: 12,
      ),
      filled: true,
      fillColor: AppColors.inputBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primaryCyan, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    ),
  );

  void _confirmDeleteClass(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(
              Icons.warning_amber_rounded,
              color: AppColors.errorRed,
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              'Delete Class',
              style: TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.bold,
                fontFamily: 'Roboto',
              ),
            ),
          ],
        ),
        content: const Text(
          'This will permanently remove the class and all its data.',
          style: TextStyle(
            color: AppColors.grey,
            fontFamily: 'Roboto',
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.grey, fontFamily: 'Roboto'),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await SessionStorageService.deleteClass(index);
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
            ),
            child: const Text('Delete', style: TextStyle(fontFamily: 'Roboto')),
          ),
        ],
      ),
    );
  }

  // ── Export ────────────────────────────────────────────────────────────────
  void _exportAllReports() {
    final buf = StringBuffer();
    buf.writeln('=== HUNI BATCH REPORT ===');
    buf.writeln('Generated: ${DateTime.now()}');
    buf.writeln('Total sessions: ${_sessions.length}\n');
    for (final e in _bySong().entries) {
      final avg =
          e.value.map((s) => s.score).reduce((a, b) => a + b) / e.value.length;
      final flat =
          e.value.map((s) => s.avgFlatPercent).reduce((a, b) => a + b) /
          e.value.length;
      final shp =
          e.value.map((s) => s.avgSharpPercent).reduce((a, b) => a + b) /
          e.value.length;
      buf.writeln('Song: ${e.key}');
      buf.writeln('  Attempts  : ${e.value.length}');
      buf.writeln('  Avg Score : ${avg.toStringAsFixed(0)} pts');
      buf.writeln('  Avg Flat  : ${flat.toStringAsFixed(0)}%');
      buf.writeln('  Avg Sharp : ${shp.toStringAsFixed(0)}%\n');
    }
    Clipboard.setData(ClipboardData(text: buf.toString()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Batch report copied to clipboard ✓'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // ── Shared helpers ────────────────────────────────────────────────────────
  BoxDecoration _card() => BoxDecoration(
    color: AppColors.cardBg,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: AppColors.inputBg),
  );

  Widget _scoreBadge(int score) {
    final color = score >= 80
        ? const Color(0xFF4CAF50)
        : score >= 50
        ? const Color(0xFFFFA726)
        : AppColors.errorRed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$score%',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          fontFamily: 'Roboto',
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: color, size: 16),
        ),
      );

  List<double> _weeklyScores() {
    final now = DateTime.now();
    return List.generate(8, (i) {
      final wS = now.subtract(Duration(days: (7 - i) * 7));
      final wE = now.subtract(Duration(days: (6 - i) * 7));
      final ws = _sessions
          .where((s) => s.completedAt.isAfter(wS) && s.completedAt.isBefore(wE))
          .toList();
      return ws.isEmpty
          ? 0.0
          : ws.map((s) => s.score).reduce((a, b) => a + b) / ws.length;
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TREND CHART PAINTER
// ─────────────────────────────────────────────────────────────────────────────
class _TrendPainter extends CustomPainter {
  final List<double> data;
  _TrendPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final w = size.width;
    final h = size.height;

    // Grid lines
    final gridP = Paint()
      ..color = AppColors.inputBg
      ..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final y = h - (i / 4) * h;
      canvas.drawLine(Offset(0, y), Offset(w, y), gridP);
      final tp = TextPainter(
        text: TextSpan(
          text: '${i * 25}%',
          style: TextStyle(
            color: AppColors.grey.withValues(alpha: 0.4),
            fontSize: 8,
            fontFamily: 'Roboto',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(2, y - 11));
    }

    final pts = <Offset>[];
    for (int i = 0; i < data.length; i++) {
      final x = data.length == 1 ? w / 2 : (i / (data.length - 1)) * w;
      final y = h - (data[i] / 100).clamp(0.0, 1.0) * h;
      pts.add(Offset(x, y));
    }
    if (pts.length < 2) return;

    // Fill
    final fill = Path()..moveTo(pts.first.dx, h);
    for (final p in pts) {
      fill.lineTo(p.dx, p.dy);
    }
    fill.lineTo(pts.last.dx, h);
    fill.close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          colors: [
            AppColors.primaryCyan.withValues(alpha: 0.25),
            AppColors.primaryCyan.withValues(alpha: 0.0),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Line
    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      line.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = AppColors.primaryCyan
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Dots
    for (final p in pts) {
      if (p.dy < h) {
        canvas.drawCircle(p, 4, Paint()..color = AppColors.cardBg);
        canvas.drawCircle(p, 3, Paint()..color = AppColors.primaryCyan);
      }
    }
  }

  @override
  bool shouldRepaint(_TrendPainter o) => o.data != data;
}
