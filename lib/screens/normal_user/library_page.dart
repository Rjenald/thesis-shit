import 'package:final_thesis_ui/screens/normal_user/education_mode_page.dart';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../widgets/song_cover_art.dart';
import '../../models/freestyle_summary.dart';
import '../../models/session_result.dart';
import '../../services/freestyle_storage_service.dart';
import '../../services/session_storage_service.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/result_share_sheet.dart';
import '../../widgets/shareable_result_card.dart';
import 'home_page.dart';
import 'record_selection_page.dart';
import 'results_page.dart';
import 'freestyle_results_page.dart';

/// One section per singing mode, because they are different things to look
/// back on: a Karaoke take has a score, a Search & Sing take has a song but
/// no score, and a Freestyle take has neither. Mixing the last two — which
/// is what happened before, since both are stored as [FreestyleSummary] —
/// made a saved song look like an untitled recording.
enum _LibraryTab { karaoke, searchAndSing, freestyle }

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  _LibraryTab _tab = _LibraryTab.karaoke;

  List<SessionResult> _sessions = [];
  List<FreestyleSummary> _freeSings = [];
  bool _loading = true;

  /// The two reference-free modes share one store, so they are split here
  /// on whether a song was recorded against the take.
  List<FreestyleSummary> get _searchAndSings =>
      _freeSings.where((s) => s.isSearchAndSing).toList();

  List<FreestyleSummary> get _freestyles =>
      _freeSings.where((s) => !s.isSearchAndSing).toList();

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final sessions = await SessionStorageService.loadSessions();
    final freeSings = await FreestyleStorageService.loadSummaries();
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

  Future<void> _deleteFreeSing(FreestyleSummary summary) async {
    await FreestyleStorageService.deleteSummary(summary.id);
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

            // Tab switcher. Three labels don't fit side by side on a narrow
            // phone, so it scrolls rather than squeezing or eliding them.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Row(
                children: [
                  _tabButton(
                    label: 'Karaoke',
                    count: _sessions.length,
                    selected: _tab == _LibraryTab.karaoke,
                    onTap: () => setState(() => _tab = _LibraryTab.karaoke),
                  ),
                  const SizedBox(width: 10),
                  _tabButton(
                    label: 'Search & Sing',
                    count: _searchAndSings.length,
                    selected: _tab == _LibraryTab.searchAndSing,
                    onTap: () =>
                        setState(() => _tab = _LibraryTab.searchAndSing),
                  ),
                  const SizedBox(width: 10),
                  _tabButton(
                    label: 'Freestyle',
                    count: _freestyles.length,
                    selected: _tab == _LibraryTab.freestyle,
                    onTap: () => setState(() => _tab = _LibraryTab.freestyle),
                  ),
                ],
              ),
            ),

            Expanded(child: _buildBody()),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(currentIndex: 1, onTap: _onItemTapped),
    );
  }

  /// One list per tab. A switch rather than nested ternaries, so adding a
  /// mode is one more case instead of another level of nesting.
  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryCyan),
      );
    }

    switch (_tab) {
      case _LibraryTab.karaoke:
        if (_sessions.isEmpty) {
          return _buildEmptyState(
            icon: Icons.library_music_outlined,
            title: 'No karaoke sessions yet',
            subtitle: 'Sing a song and save your results!',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _sessions.length,
          itemBuilder: (context, index) =>
              _buildSessionItem(_sessions[index], index),
        );

      case _LibraryTab.searchAndSing:
        final items = _searchAndSings;
        if (items.isEmpty) {
          return _buildEmptyState(
            icon: Icons.search,
            title: 'No Search & Sing takes yet',
            subtitle: 'Find a song online, sing it, and your word and note '
                'breakdown will appear here.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: items.length,
          itemBuilder: (context, index) => _buildFreeSingItem(items[index]),
        );

      case _LibraryTab.freestyle:
        final items = _freestyles;
        if (items.isEmpty) {
          return _buildEmptyState(
            icon: Icons.mic_none_outlined,
            title: 'No freestyle recordings yet',
            subtitle: 'Record a freestyle take and your word/note summary '
                'will appear here!',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: items.length,
          itemBuilder: (context, index) => _buildFreeSingItem(items[index]),
        );
    }
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
        // Horizontal padding now that these size to their label rather
        // than being stretched by an Expanded.
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
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
            SongCoverArt(image: session.songImage, size: 56),
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
                    // An artist name comes from the catalog or from an
                    // online search, so its length is not something this
                    // screen controls.
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.grey.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontFamily: 'Roboto',
                    ),
                  ),
                  const SizedBox(height: 4),
                  SessionMetaLine(
                    dateText: '$dateStr  $timeStr',
                    flat: session.avgFlatPercent > 35,
                    sharp: session.avgSharpPercent > 35,
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
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Share result',
              icon: Icon(
                Icons.share_outlined,
                color: AppColors.grey.withValues(alpha: 0.6),
                size: 19,
              ),
              onPressed: () => _shareSession(session),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 10),
            IconButton(
              tooltip: 'Delete',
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

  /// Shares a past karaoke result straight from the library, so a take
  /// doesn't have to be shared in the moment or not at all.
  void _shareSession(SessionResult s) {
    final scoreInt = s.score.round();
    final label = _feedbackLabel(scoreInt);
    ResultShareSheet.show(
      context,
      baseName: s.songTitle,
      shareText: 'I sang "${s.songTitle}" by ${s.songArtist} on Huni — '
          '$scoreInt% ($label)',
      card: ShareableResultCard(
        songTitle: s.songTitle,
        songArtist: s.songArtist,
        completedAt: s.completedAt,
        score: s.score,
        scoreLabel: label,
        stats: [
          ShareStat('On pitch', '${s.correctLines}/${s.totalLines}'),
          ShareStat('Off pitch', '${s.flatLines + s.sharpLines}'),
          ShareStat('Duration', _formatClipDuration(s.durationSeconds)),
        ],
      ),
    );
  }

  /// Shares a past Search & Sing or Freestyle take. No score is passed —
  /// neither mode has a reference melody to score against, and the card's
  /// unscored layout leads with what was detected instead.
  void _shareFreeSing(FreestyleSummary summary) {
    final words = summary.words
        .map((w) => w.word.trim())
        .where((w) => w.isNotEmpty)
        .toList();
    final notes = summary.words
        .expand((w) => w.syllableNotes)
        .whereType<String>()
        .toSet()
        .length;
    final excerpt = words.isEmpty
        ? null
        : (words.length > 12
            ? '${words.take(12).join(' ')}…'
            : words.join(' '));

    ResultShareSheet.show(
      context,
      baseName: summary.displayTitle,
      shareText: summary.isSearchAndSing
          ? 'I sang "${summary.songTitle}" on Huni'
          : 'A freestyle take on Huni — ${words.length} words, '
              '$notes distinct notes',
      card: ShareableResultCard(
        songTitle: summary.displayTitle,
        songArtist: summary.songArtist ?? '',
        completedAt: summary.createdAt,
        excerpt: excerpt,
        stats: [
          ShareStat('Words', '${words.length}'),
          ShareStat('Notes', '$notes'),
          ShareStat(
              'Duration', _formatClipDuration(summary.durationSeconds)),
        ],
      ),
    );
  }

  static String _formatClipDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// Same thresholds the results screen uses, so a card shared from the
  /// library carries the same label the user saw when they finished.
  static String _feedbackLabel(int scoreInt) {
    if (scoreInt >= 80) return 'Good';
    if (scoreInt >= 60) return 'Fair';
    return 'Needs work';
  }



  Widget _buildFreeSingItem(FreestyleSummary summary) {
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
            builder: (_) => FreestyleResultsPage(summary: summary),
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
                child: Icon(
                  summary.isSearchAndSing ? Icons.search : Icons.mic,
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
                    // Name the song when there is one, rather than listing
                    // every reference-free take as "Freestyle".
                    summary.isSearchAndSing
                        ? '${summary.songTitle}  •  $m:$s'
                        : 'Freestyle  •  $m:$s',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      fontFamily: 'Roboto',
                    ),
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
              tooltip: 'Share result',
              icon: Icon(
                Icons.share_outlined,
                color: AppColors.grey.withValues(alpha: 0.6),
                size: 19,
              ),
              onPressed: () => _shareFreeSing(summary),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 10),
            IconButton(
              tooltip: 'Delete',
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

  void _confirmDeleteFreeSing(FreestyleSummary summary) {
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

/// The second line of a karaoke card: when it was sung, and whether the
/// take ran flat or sharp.
///
/// Its own widget because it is the part that broke. It was a [Row] of a
/// date and up to two badges, none of which could yield any space, so a
/// take that was *both* flat and sharp overflowed the card by 41 logical
/// pixels and painted the striped overflow banner across the list — the
/// screenshot showed it running straight through two rows.
///
/// A [Wrap] cannot overflow: when the badges do not fit beside the date
/// they move to a second line. That is also why this is not solved by
/// shortening the date or ellipsising it — the number of badges, the
/// locale's date format and the user's text scale all vary, and a layout
/// that depends on all three staying small is a layout that breaks
/// again.
class SessionMetaLine extends StatelessWidget {
  const SessionMetaLine({
    super.key,
    required this.dateText,
    required this.flat,
    required this.sharp,
  });

  final String dateText;

  /// Set when the take averaged more than 35% flat phrases.
  final bool flat;

  /// Set when it averaged more than 35% sharp ones. Both can be true at
  /// once — a singer who drifts either side of the note across a song —
  /// which is exactly the case that used to overflow.
  final bool sharp;

  static const flatColor = Color(0xFFFFA726);
  static const sharpColor = Color(0xFFF44336);

  static Widget badge(String label, Color color) => Container(
        // No margin: the Wrap owns the spacing, and a margin here would
        // be added to it.
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

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          dateText,
          style: TextStyle(
            color: AppColors.grey.withValues(alpha: 0.5),
            fontSize: 11,
            fontFamily: 'Roboto',
          ),
        ),
        if (flat) badge('Flat', flatColor),
        if (sharp) badge('Sharp', sharpColor),
      ],
    );
  }
}
