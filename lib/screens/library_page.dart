import 'package:final_thesis_ui/screens/education_mode_page.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/session_result.dart';
import '../services/session_storage_service.dart';
import '../widgets/bottom_nav_bar.dart';
import 'home_page.dart';
import 'record_selection_page.dart';
import 'results_page.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  List<SessionResult> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final sessions = await SessionStorageService.loadSessions();
    if (mounted) {
      setState(() {
        _sessions = sessions;
        _loading = false;
      });
    }
  }

  Future<void> _deleteSession(int index) async {
    await SessionStorageService.deleteSession(index);
    await _loadSessions();
  }

  void _onItemTapped(int index) {
    if (index == 0) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
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
                    onPressed: _loadSessions,
                  ),
                ],
              ),
            ),

            // Subtitle
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Row(
                children: [
                  Text(
                    'Your Recordings',
                    style: TextStyle(
                      color: AppColors.grey.withValues(alpha: 0.7),
                      fontSize: 13,
                      fontFamily: 'Roboto',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryCyan.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_sessions.length}',
                      style: const TextStyle(
                        color: AppColors.primaryCyan,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Roboto',
                      ),
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
                  : _sessions.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _sessions.length,
                      itemBuilder: (context, index) {
                        return _buildSessionItem(_sessions[index], index);
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(currentIndex: 1, onTap: _onItemTapped),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.library_music_outlined,
            color: AppColors.grey.withValues(alpha: 0.4),
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            'No recordings yet',
            style: TextStyle(
              color: AppColors.grey.withValues(alpha: 0.6),
              fontSize: 16,
              fontFamily: 'Roboto',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sing a song and save your results!',
            style: TextStyle(
              color: AppColors.grey.withValues(alpha: 0.4),
              fontSize: 13,
              fontFamily: 'Roboto',
            ),
          ),
        ],
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
