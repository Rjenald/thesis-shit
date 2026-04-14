import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/session_storage_service.dart';
import 'results_page.dart';

class RecentlyDeletedPage extends StatefulWidget {
  const RecentlyDeletedPage({super.key});

  @override
  State<RecentlyDeletedPage> createState() => _RecentlyDeletedPageState();
}

class _RecentlyDeletedPageState extends State<RecentlyDeletedPage> {
  List<TrashEntry> _trash = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final trash = await SessionStorageService.loadTrash();
    if (mounted) {
      setState(() {
        _trash = trash;
        _loading = false;
      });
    }
  }

  Future<void> _restore(int index) async {
    await SessionStorageService.restoreFromTrash(index);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(children: [
          Icon(Icons.restore, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Text('Session restored to Library',
              style: TextStyle(color: Colors.white, fontFamily: 'Roboto')),
        ]),
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
    await _load();
  }

  Future<void> _permanentDelete(int index) async {
    final entry = _trash[index];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text('Delete Forever',
            style: TextStyle(color: AppColors.white, fontFamily: 'Roboto')),
        content: Text(
          '"${entry.session.songTitle}" will be permanently deleted and cannot be recovered.',
          style: const TextStyle(color: AppColors.grey, fontFamily: 'Roboto'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(
                    color: AppColors.grey.withValues(alpha: 0.8),
                    fontFamily: 'Roboto')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Forever',
                style: TextStyle(
                    color: Color(0xFFF44336), fontFamily: 'Roboto')),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await SessionStorageService.permanentlyDeleteFromTrash(index);
      await _load();
    }
  }

  Future<void> _emptyTrash() async {
    if (_trash.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text('Empty Trash',
            style: TextStyle(color: AppColors.white, fontFamily: 'Roboto')),
        content: Text(
          'All ${_trash.length} deleted session${_trash.length == 1 ? '' : 's'} will be permanently removed.',
          style: const TextStyle(color: AppColors.grey, fontFamily: 'Roboto'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(
                    color: AppColors.grey.withValues(alpha: 0.8),
                    fontFamily: 'Roboto')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Empty Trash',
                style: TextStyle(
                    color: Color(0xFFF44336), fontFamily: 'Roboto')),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await SessionStorageService.emptyTrash();
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            if (!_loading && _trash.isNotEmpty) _buildInfoBanner(),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primaryCyan))
                  : _trash.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          itemCount: _trash.length,
                          itemBuilder: (context, index) {
                            return _buildTrashItem(_trash[index], index);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back,
                color: AppColors.white, size: 26),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text('Recently Deleted',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                    fontFamily: 'Roboto')),
          ),
          if (_trash.isNotEmpty)
            TextButton(
              onPressed: _emptyTrash,
              child: const Text('Empty',
                  style: TextStyle(
                      color: Color(0xFFF44336),
                      fontSize: 13,
                      fontFamily: 'Roboto')),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.amber, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Items are permanently deleted after 30 days.',
              style: TextStyle(
                  color: Colors.amber.withValues(alpha: 0.9),
                  fontSize: 12,
                  fontFamily: 'Roboto'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.delete_outline,
              color: AppColors.grey.withValues(alpha: 0.3), size: 72),
          const SizedBox(height: 16),
          Text('Trash is Empty',
              style: TextStyle(
                  color: AppColors.grey.withValues(alpha: 0.6),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Roboto')),
          const SizedBox(height: 8),
          Text('Deleted sessions will appear here\nfor 30 days.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.grey.withValues(alpha: 0.4),
                  fontSize: 13,
                  fontFamily: 'Roboto',
                  height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildTrashItem(TrashEntry entry, int index) {
    final session = entry.session;
    final score = session.score.round();
    final scoreColor = score >= 80
        ? const Color(0xFF4CAF50)
        : score >= 50
            ? const Color(0xFFFFA726)
            : const Color(0xFFF44336);

    final deletedDate = entry.deletedAt;
    final dateStr =
        '${deletedDate.month.toString().padLeft(2, '0')}-${deletedDate.day.toString().padLeft(2, '0')}-${deletedDate.year}';

    final days = entry.daysRemaining;
    final daysLabel = days == 0
        ? 'Expires today'
        : days == 1
            ? '1 day left'
            : '$days days left';
    final daysColor = days <= 3
        ? const Color(0xFFF44336)
        : days <= 7
            ? const Color(0xFFFFA726)
            : AppColors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: AppColors.inputBg.withValues(alpha: 0.5))),
      child: Column(
        children: [
          // Main row — tappable to view results
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ResultsPage(session: session),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Album art
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: session.songImage.isNotEmpty
                        ? Image.network(session.songImage,
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, e, st) => _iconBox())
                        : _iconBox(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(session.songTitle,
                            style: const TextStyle(
                                color: AppColors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                fontFamily: 'Roboto'),
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(session.songArtist,
                            style: TextStyle(
                                color: AppColors.grey.withValues(alpha: 0.7),
                                fontSize: 12,
                                fontFamily: 'Roboto')),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.delete_outline,
                                size: 11,
                                color: AppColors.grey.withValues(alpha: 0.5)),
                            const SizedBox(width: 3),
                            Text('Deleted $dateStr',
                                style: TextStyle(
                                    color: AppColors.grey.withValues(alpha: 0.5),
                                    fontSize: 11,
                                    fontFamily: 'Roboto')),
                            const SizedBox(width: 8),
                            Text('·',
                                style: TextStyle(
                                    color: AppColors.grey.withValues(alpha: 0.4),
                                    fontSize: 11)),
                            const SizedBox(width: 8),
                            Text(daysLabel,
                                style: TextStyle(
                                    color: daysColor,
                                    fontSize: 11,
                                    fontFamily: 'Roboto',
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Score badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: scoreColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: scoreColor.withValues(alpha: 0.3)),
                    ),
                    child: Text('$score',
                        style: TextStyle(
                            color: scoreColor,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Roboto')),
                  ),
                ],
              ),
            ),
          ),

          // Action buttons
          Container(
            decoration: BoxDecoration(
              border: Border(
                  top: BorderSide(
                      color: AppColors.inputBg.withValues(alpha: 0.8))),
            ),
            child: Row(
              children: [
                // Restore
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _restore(index),
                    icon: const Icon(Icons.restore,
                        size: 15, color: AppColors.primaryCyan),
                    label: const Text('Restore',
                        style: TextStyle(
                            color: AppColors.primaryCyan,
                            fontSize: 12,
                            fontFamily: 'Roboto')),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(14))),
                    ),
                  ),
                ),
                Container(
                    width: 1,
                    height: 28,
                    color: AppColors.inputBg.withValues(alpha: 0.8)),
                // Delete Forever
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _permanentDelete(index),
                    icon: const Icon(Icons.delete_forever,
                        size: 15, color: Color(0xFFF44336)),
                    label: const Text('Delete Forever',
                        style: TextStyle(
                            color: Color(0xFFF44336),
                            fontSize: 12,
                            fontFamily: 'Roboto')),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                              bottomRight: Radius.circular(14))),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconBox() => Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.inputBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.music_note, color: AppColors.grey, size: 22),
      );
}
