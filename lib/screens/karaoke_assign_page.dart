import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/songs_service.dart';

/// Karaoke (or Piano-Voice) assignment page.
/// Teacher searches for a karaoke song, sets a due date, and gives it
/// to students in the class.
class KaraokeAssignPage extends StatefulWidget {
  final Map<String, dynamic> classData;
  final String lessonTitle;
  final String subLessonTitle;

  const KaraokeAssignPage({
    super.key,
    required this.classData,
    required this.lessonTitle,
    required this.subLessonTitle,
  });

  @override
  State<KaraokeAssignPage> createState() => _KaraokeAssignPageState();
}

class _KaraokeAssignPageState extends State<KaraokeAssignPage> {
  List<Map<String, String>> _allSongs = [];
  List<Map<String, String>> _filtered = [];
  String _search = '';
  String? _selectedSongTitle;
  DateTime? _dueDate;
  bool _allowLate = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSongs();
  }

  Future<void> _loadSongs() async {
    final songs = await SongsService.fetchSongs();
    if (mounted) {
      setState(() {
        _allSongs = songs;
        _filtered = songs;
        _loading = false;
      });
    }
  }

  void _onSearch(String q) {
    setState(() {
      _search = q;
      if (q.isEmpty) {
        _filtered = _allSongs;
      } else {
        final lower = q.toLowerCase();
        _filtered = _allSongs
            .where(
              (s) =>
                  (s['title'] ?? '').toLowerCase().contains(lower) ||
                  (s['artist'] ?? '').toLowerCase().contains(lower),
            )
            .toList();
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primaryCyan,
            onPrimary: Colors.black,
            surface: AppColors.cardBg,
            onSurface: AppColors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  void _giveToStudents() {
    if (_selectedSongTitle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a song to assign first'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF4CAF50),
              size: 22,
            ),
            SizedBox(width: 8),
            Text(
              'Song Assigned',
              style: TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.bold,
                fontFamily: 'Roboto',
              ),
            ),
          ],
        ),
        content: Text(
          '"$_selectedSongTitle" has been sent to all students in '
          '${widget.classData['name'] ?? 'the class'}.',
          style: const TextStyle(
            color: AppColors.grey,
            fontFamily: 'Roboto',
            fontSize: 13,
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryCyan,
              foregroundColor: Colors.black,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
            ),
            child: const Text(
              'Done',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontFamily: 'Roboto',
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final className = widget.classData['name'] as String? ?? '';

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Column(
        children: [
          // ── Teal header ────────────────────────────────────────────────
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
                    '${widget.lessonTitle}  /  ${widget.subLessonTitle}',
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

          // ── Search bar ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.inputBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                style: const TextStyle(color: AppColors.white),
                onChanged: _onSearch,
                decoration: InputDecoration(
                  hintText: 'search karaoke to assign',
                  hintStyle: TextStyle(
                    color: AppColors.grey.withValues(alpha: 0.5),
                    fontFamily: 'Roboto',
                  ),
                  prefixIcon: const Icon(Icons.search, color: AppColors.grey),
                  suffixIcon: _search.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear,
                            color: AppColors.grey,
                            size: 18,
                          ),
                          onPressed: () {
                            _onSearch('');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),

          // ── Song list ──────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryCyan,
                      strokeWidth: 2,
                    ),
                  )
                : _filtered.isEmpty
                ? Center(
                    child: Text(
                      _search.isNotEmpty
                          ? 'No songs match "$_search"'
                          : 'No songs available',
                      style: TextStyle(
                        color: AppColors.grey.withValues(alpha: 0.5),
                        fontFamily: 'Roboto',
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) => _buildSongRow(_filtered[i]),
                  ),
          ),

          // ── Due date + Allow late ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.inputBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            color: AppColors.grey,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _dueDate == null
                                ? 'Due Date'
                                : '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}',
                            style: TextStyle(
                              color: _dueDate == null
                                  ? AppColors.grey
                                  : AppColors.white,
                              fontSize: 13,
                              fontFamily: 'Roboto',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Allow Late:',
                  style: TextStyle(
                    color: AppColors.grey,
                    fontSize: 12,
                    fontFamily: 'Roboto',
                  ),
                ),
                const SizedBox(width: 4),
                _radioBtn('Yes', true),
                _radioBtn('No', false),
              ],
            ),
          ),

          // ── Give to students ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: GestureDetector(
              onTap: _giveToStudents,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1C),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primaryCyan.withValues(alpha: 0.4),
                  ),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Give to students',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Roboto',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildSongRow(Map<String, String> song) {
    final title = song['title'] ?? '';
    final artist = song['artist'] ?? '';
    final isSelected = _selectedSongTitle == title;

    return GestureDetector(
      onTap: () =>
          setState(() => _selectedSongTitle = isSelected ? null : title),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryCyan.withValues(alpha: 0.12)
              : AppColors.cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryCyan.withValues(alpha: 0.5)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            // Thumbnail / placeholder
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: song['image'] != null && song['image']!.isNotEmpty
                  ? Image.network(
                      song['image']!,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, e, st) => _imgFallback(),
                    )
                  : _imgFallback(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Roboto',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    artist,
                    style: TextStyle(
                      color: AppColors.grey.withValues(alpha: 0.7),
                      fontSize: 12,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.primaryCyan,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _imgFallback() => Container(
    width: 44,
    height: 44,
    color: AppColors.inputBg,
    child: const Icon(Icons.music_note, color: AppColors.grey, size: 20),
  );

  Widget _radioBtn(String label, bool value) {
    final isSelected = _allowLate == value;
    return GestureDetector(
      onTap: () => setState(() => _allowLate = value),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? AppColors.primaryCyan
                    : AppColors.grey.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
            child: isSelected
                ? Center(
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryCyan,
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.grey,
              fontSize: 12,
              fontFamily: 'Roboto',
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      height: 70,
      color: AppColors.bottomNavBg,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navIcon(Icons.notifications_outlined),
          _navIcon(Icons.home_outlined, onTap: () => Navigator.pop(context)),
          _navIcon(Icons.person_outline),
        ],
      ),
    );
  }

  Widget _navIcon(IconData icon, {VoidCallback? onTap}) => GestureDetector(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Icon(icon, color: AppColors.grey.withValues(alpha: 0.5), size: 26),
    ),
  );
}
