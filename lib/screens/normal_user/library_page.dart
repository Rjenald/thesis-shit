import 'package:final_thesis_ui/screens/normal_user/education_mode_page.dart';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/free_sing_summary.dart';
import '../../models/session_result.dart';
import '../../services/free_sing_storage_service.dart';
import '../../services/session_storage_service.dart';
import '../../widgets/bottom_nav_bar.dart';
import 'home_page.dart';
import 'record_selection_page.dart';
import 'results_page.dart';
import 'without_karaoke_results_page.dart';

enum _LibraryTab { karaoke, freeSing }

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  _LibraryTab _tab = _LibraryTab.karaoke;

  List<SessionResult> _sessions = [];
  List<FreeSingSummary> _freeSings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final sessions = await SessionStorageService.loadSessions();
    final freeSings = await FreeSingStorageService.loadSummaries();
    if (mounted) {
      setState(() {
        _sessions = sessions;
        _freeSings = freeSings;
        _loading = false;
      });
    }
  }

  Future<void> _deleteSession(int index) async {
    await SessionStorageService.deleteSession(index);
    await _loadAll();
  }

  Future<void> _deleteFreeSing(FreeSingSummary summary) async {
    await FreeSingStorageService.deleteSummary(summary.id);
    await _loadAll();
  }

  void _onItemTapped(int index) {
    if (index == 0) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const HomePage(),
        ),
        (route) => false,
      );
    } else if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const RecordSelectionPage()),
      );
    } else if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const EducationModePage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: AppColors.white,
                      size: 26,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      'Library',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.white,
                        fontFamily: 'Roboto',
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.refresh,
                      color: AppColors.white,
                      size: 24,
                    ),
                    onPressed: _loadAll,
                  ),
                ],
              ),
            ),

            // Tab switcher
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: _tabButton(
                      label: 'Karaoke',
                      count: _sessions.length,
                      selected: _tab == _LibraryTab.karaoke,
                      onTap: () => setState(() => _tab = _LibraryTab.karaoke),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _tabButton(
                      label: 'Free Sing',
                      count: _freeSings.length,
                      selected: _tab == _LibraryTab.freeSing,
                      onTap: () => setState(() => _tab = _LibraryTab.freeSing),
                    ),
                  ),
                ],
              ),
            ),

            // List
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryCyan,
                      ),
                    )
                  : _tab == _LibraryTab.karaoke
                  ? (_sessions.isEmpty
                        ? _buildEmptyState(
                            icon: Icons.library_music_outlined,
                            title: 'No karaoke sessions yet',
                            subtitle: 'Sing a song and save your results!',
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                            itemCount: _sessions.length,
                            itemBuilder: (context, index) {
                              return _buildSessionItem(
                                _sessions[index],
                                index,
                              );
                            },
                          ))
                  : (_freeSings.isEmpty
                        ? _buildEmptyState(
                            icon: Icons.mic_none_outlined,
                            title: 'No free sing recordings yet',
                            subtitle:
                                'Record without karaoke and your word/note summary will appear here!',
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                            itemCount: _freeSings.length,
                            itemBuilder: (context, index) {
                              return _buildFreeSingItem(_freeSings[index]);
                            },
                          )),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(currentIndex: 1, onTap: _onItemTapped),
    );
  }

  Widget _tabButton({
    required String label,
    required int count,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryCyan.withValues(alpha: 0.12)
              : AppColors.cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? AppColors.primaryCyan.withValues(alpha: 0.5)
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.primaryCyan : AppColors.grey,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFamily: 'Roboto',
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: TextStyle(
                color: selected
                    ? AppColors.primaryCyan.withValues(alpha: 0.7)
                    : AppColors.grey.withValues(alpha: 0.6),
                fontSize: 12,
                fontFamily: 'Roboto',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: AppColors.grey.withValues(alpha: 0.4),
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.grey.withValues(alpha: 0.6),
                fontSize: 16,
                fontFamily: 'Roboto',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.grey.withValues(alpha: 0.4),
                fontSize: 13,
                fontFamily: 'Roboto',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionItem(SessionResult session, int index) {
    final score = session.score.round();
    final scoreColor = score >= 90
        ? AppColors.primaryCyan
        : score >= 75
        ? const Color(0xFF4CAF50)
        : const Color(0xFFFFA726);

    final date = session.completedAt;
    final dateStr =
        '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}-${date.year}';
    final timeStr =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ResultsPage(session: session)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            // Album art or icon
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: session.songImage.isNotEmpty
                  ? Image.network(
                      session.songImage,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, e, st) => _iconBox(),
                    )
                  : _iconBox(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.songTitle,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      fontFamily: 'Roboto',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    session.songArtist,
                    style: TextStyle(
                      color: AppColors.grey.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontFamily: 'Roboto',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '$dateStr  $timeStr',
                        style: TextStyle(
                          color: AppColors.grey.withValues(alpha: 0.5),
                          fontSize: 11,
                          fontFamily: 'Roboto',
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Flat/sharp badge
                      if (session.avgFlatPercent > 35)
                        _badge('Flat', _flatBadgeColor),
                      if (session.avgSharpPercent > 35)
                        _badge('Sharp', _sharpBadgeColor),
                    ],
                  ),
                ],
              ),
            ),
            // Score
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: scoreColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: scoreColor.withValues(alpha: 0.35)),
              ),
              child: Text(
                '$score',
                style: TextStyle(
                  color: scoreColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Roboto',
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                color: AppColors.grey.withValues(alpha: 0.6),
                size: 20,
              ),
              onPressed: () => _confirmDelete(index),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  static const _flatBadgeColor = Color(0xFFFFA726);
  static const _sharpBadgeColor = Color(0xFFF44336);

  Widget _badge(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w600,
          fontFamily: 'Roboto',
        ),
      ),
    );
  }

  Widget _iconBox() => Container(
    width: 56,
    height: 56,
    color: AppColors.inputBg,
    child: const Icon(Icons.music_note, color: AppColors.grey, size: 24),
  );

  Widget _buildFreeSingItem(FreeSingSummary summary) {
    final date = summary.createdAt;
    final dateStr =
        '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}-${date.year}';
    final timeStr =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    final m = (summary.durationSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (summary.durationSeconds % 60).toString().padLeft(2, '0');

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WithoutKaraokeResultsPage(summary: summary),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 56,
                height: 56,
                color: AppColors.inputBg,
                child: const Icon(
                  Icons.mic,
                  color: AppColors.primaryCyan,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Free Sing  •  $m:$s',
                    style: const TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      fontFamily: 'Roboto',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${summary.words.length} word'
                    '${summary.words.length == 1 ? '' : 's'} detected',
                    style: TextStyle(
                      color: AppColors.grey.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontFamily: 'Roboto',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$dateStr  $timeStr',
                    style: TextStyle(
                      color: AppColors.grey.withValues(alpha: 0.5),
                      fontSize: 11,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                color: AppColors.grey.withValues(alpha: 0.6),
                size: 20,
              ),
              onPressed: () => _confirmDeleteFreeSing(summary),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteFreeSing(FreeSingSummary summary) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text(
          'Delete Recording',
          style: TextStyle(color: AppColors.white, fontFamily: 'Roboto'),
        ),
        content: const Text(
          'This free sing summary will be permanently deleted.',
          style: TextStyle(color: AppColors.grey, fontFamily: 'Roboto'),
        ),
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
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteFreeSing(summary);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Color(0xFFF44336), fontFamily: 'Roboto'),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text(
          'Move to Trash',
          style: TextStyle(color: AppColors.white, fontFamily: 'Roboto'),
        ),
        content: const Text(
          'This session will be moved to Recently Deleted.\nYou can restore it within 30 days.',
          style: TextStyle(color: AppColors.grey, fontFamily: 'Roboto'),
        ),
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
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteSession(index);
            },
            child: const Text(
              'Move to Trash',
              style: TextStyle(color: Color(0xFFF44336), fontFamily: 'Roboto'),
            ),
          ),
        ],
      ),
    );
  }
}
