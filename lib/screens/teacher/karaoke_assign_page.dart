import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/class_notification.dart';
import '../../services/class_notifications_service.dart';
import '../../services/session_storage_service.dart';
import '../../services/songs_service.dart';

/// Teacher page — search for a karaoke song, add an instruction, set a
/// due-date, toggle late submissions, then give the assignment to students.
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
  // ── Data ──────────────────────────────────────────────────────────────────
  List<Map<String, String>> _allSongs = [];
  List<Map<String, String>> _filtered = [];
  String _search = '';
  String? _selectedSongTitle;
  DateTime? _dueDate;
  bool _allowLate = false;
  bool _loading = true;
  bool _assigning = false;

  final _instructionCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSongs();
  }

  @override
  void dispose() {
    _instructionCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
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
      _filtered = q.isEmpty
          ? _allSongs
          : _allSongs.where((s) {
              final lower = q.toLowerCase();
              return (s['title'] ?? '').toLowerCase().contains(lower) ||
                  (s['artist'] ?? '').toLowerCase().contains(lower);
            }).toList();
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

  Future<void> _giveToStudents() async {
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

    setState(() => _assigning = true);

    final className = widget.classData['name'] as String? ?? '';
    final students = List<String>.from(
      widget.classData['students'] as List? ?? [],
    );
    final teacherName = await SessionStorageService.loadUsername() ?? 'Teacher';

    // 1 — push notification so students see it in their inbox
    final notifService = ClassNotificationsService();
    await notifService.addNotification(
      ClassNotification(
        id: '${DateTime.now().millisecondsSinceEpoch}',
        teacherName: teacherName,
        className: className,
        message: 'Added Activity / Karaoke – $_selectedSongTitle',
        timestamp: DateTime.now(),
        type: NotificationType.activityAssignment,
        activityName: _selectedSongTitle,
        deadline: _dueDate,
      ),
    );

    // 2 — store assigned song in class data
    final classes = await SessionStorageService.loadClasses();
    final idx = classes.indexWhere(
      (c) =>
          (c['name'] as String? ?? '').toLowerCase() == className.toLowerCase(),
    );
    if (idx != -1) {
      final songs = List<String>.from(
        classes[idx]['assignedSongs'] as List? ?? [],
      );
      if (!songs.contains(_selectedSongTitle)) {
        songs.add(_selectedSongTitle!);
      }
      classes[idx] = {...classes[idx], 'assignedSongs': songs};
      await SessionStorageService.saveClasses(classes);
    }

    if (!mounted) return;
    setState(() => _assigning = false);

    // 3 — confirmation dialog
    final studentCount = students.length;
    final studentWord = studentCount == 1 ? 'student' : 'students';

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
          '"$_selectedSongTitle" has been sent to '
          '${studentCount > 0 ? '$studentCount $studentWord' : 'all students'} '
          'in $className.'
          '${_dueDate != null ? '\n\nDue: ${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}' : ''}',
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
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.inputBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(color: AppColors.white, fontSize: 14),
                onChanged: _onSearch,
                decoration: InputDecoration(
                  hintText: 'search karaoke to assign',
                  hintStyle: TextStyle(
                    color: AppColors.grey.withValues(alpha: 0.5),
                    fontFamily: 'Roboto',
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.grey,
                    size: 20,
                  ),
                  suffixIcon: _search.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear,
                            color: AppColors.grey,
                            size: 18,
                          ),
                          onPressed: () {
                            _searchCtrl.clear();
                            _onSearch('');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 13,
                  ),
                ),
              ),
            ),
          ),

          // ── Scrollable body: song list + instruction ────────────────────
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryCyan,
                      strokeWidth: 2,
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    children: [
                      if (_filtered.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              _search.isNotEmpty
                                  ? 'No songs match "$_search"'
                                  : 'No songs available',
                              style: TextStyle(
                                color: AppColors.grey.withValues(alpha: 0.5),
                                fontFamily: 'Roboto',
                              ),
                            ),
                          ),
                        )
                      else
                        ..._filtered.map(_buildSongRow),

                      const SizedBox(height: 12),

                      // ── Instruction text area ────────────────────────────
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF5A5A5A),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: TextField(
                          controller: _instructionCtrl,
                          style: const TextStyle(
                            color: AppColors.white,
                            fontFamily: 'Roboto',
                            fontSize: 13,
                          ),
                          maxLines: 4,
                          decoration: const InputDecoration(
                            hintText: 'Instruction:',
                            hintStyle: TextStyle(
                              color: Colors.white54,
                              fontFamily: 'Roboto',
                              fontSize: 13,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(14),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),

          // ── Due date + Allow late ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.inputBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            color: AppColors.grey,
                            size: 15,
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
                const SizedBox(width: 6),
                _radioBtn('Yes', true),
                _radioBtn('No', false),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ── Give to students ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _assigning ? null : _giveToStudents,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryCyan,
                  disabledBackgroundColor: AppColors.primaryCyan.withValues(
                    alpha: 0.4,
                  ),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _assigning
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Give to students',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
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

  // ── Song row — Figma style: title | artist | Select button ────────────────

  Widget _buildSongRow(Map<String, String> song) {
    final title = song['title'] ?? '';
    final artist = song['artist'] ?? '';
    final selected = _selectedSongTitle == title;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.primaryCyan.withValues(alpha: 0.12)
            : AppColors.cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected
              ? AppColors.primaryCyan.withValues(alpha: 0.5)
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          // Title + artist
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

          // Select / Selected button
          GestureDetector(
            onTap: () => setState(() {
              _selectedSongTitle = selected ? null : title;
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? AppColors.primaryCyan : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: selected
                      ? AppColors.primaryCyan
                      : AppColors.grey.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                selected ? 'Selected' : 'Select',
                style: TextStyle(
                  color: selected ? Colors.black : AppColors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Roboto',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Radio button ───────────────────────────────────────────────────────────

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

  // ── Bottom nav ─────────────────────────────────────────────────────────────

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
