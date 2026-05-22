import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../models/class_notification.dart';
import '../../services/class_notifications_service.dart';
import '../../services/enrollment_service.dart';
import '../../services/session_storage_service.dart';
import '../../widgets/profile_avatar.dart';
import 'class_detail_page.dart';
import '../normal_user/home_page.dart';
import '../shared/start_page.dart';
import 'submissions_page.dart';
import 'teacher_notifications_page.dart';

/// Teacher main page — Classroom view matching Figma design.
class TeacherAccountPage extends StatefulWidget {
  const TeacherAccountPage({super.key});

  @override
  State<TeacherAccountPage> createState() => _TeacherAccountPageState();
}

class _TeacherAccountPageState extends State<TeacherAccountPage> {
  List<Map<String, dynamic>> _classes = [];
  bool _loading = true;
  String _searchQuery = '';
  String _username = 'Teacher';
  int _navIndex =
      2; // 0=Notification 1=Submissions 2=Home 3=CreateStudent 4=Message

  // Keep a reference so we can remove the listener in dispose().
  EnrollmentService? _enrollmentService;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Called once the Provider tree is available (first frame + on dep changes).
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-register listener each time dependencies rebuild (safe — remove first).
    _enrollmentService?.removeListener(_onEnrollmentChanged);
    _enrollmentService = context.read<EnrollmentService>();
    _enrollmentService!.addListener(_onEnrollmentChanged);
  }

  /// Reloads class data from SharedPreferences whenever a student accepts an
  /// enrollment invite so the teacher's student count updates in real time.
  void _onEnrollmentChanged() => _loadData();

  @override
  void dispose() {
    _enrollmentService?.removeListener(_onEnrollmentChanged);
    super.dispose();
  }

  Future<void> _loadData() async {
    final cls = await SessionStorageService.loadClasses();
    final name = await SessionStorageService.loadUsername();
    if (mounted) {
      setState(() {
        _classes = cls;
        _loading = false;
        if (name != null && name.isNotEmpty) _username = name;
      });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_searchQuery.isEmpty) return _classes;
    final q = _searchQuery.toLowerCase();
    return _classes
        .where((c) => (c['name'] as String? ?? '').toLowerCase().contains(q))
        .toList();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // ── Non-classroom tabs ─────────────────────────────────────────────────
    if (_navIndex != 2) {
      Widget tabBody;
      Color bgColor = AppColors.bgDark;

      switch (_navIndex) {
        case 0: // Notification
          tabBody = const TeacherNotificationsPage();
          break;
        case 1: // Submissions
          tabBody = const SubmissionsPage();
          break;
        case 3: // Create Student Account
          tabBody = const CreateStudentAccountPage();
          break;
        case 4: // Profile
          tabBody = _buildProfileTab();
          break;
        default:
          tabBody = const SizedBox.shrink();
      }

      return Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(child: tabBody),
        bottomNavigationBar: _buildBottomNav(),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── "Classroom" title + logout ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios,
                          color: Colors.white,
                          size: 22,
                        ),
                        tooltip: 'Back to Normal User',
                        onPressed: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const HomePage(),
                            ),
                            (route) => false,
                          );
                        },
                      ),
                      const Text(
                        'Classroom',
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Roboto',
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.logout,
                      color: AppColors.errorRed,
                      size: 22,
                    ),
                    tooltip: 'Logout',
                    onPressed: _logout,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Classes label + Add button ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Classes',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Roboto',
                    ),
                  ),
                  GestureDetector(
                    onTap: _showAddClassDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryCyan,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, color: Colors.black, size: 18),
                          SizedBox(width: 4),
                          Text(
                            'Add New Class',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              fontFamily: 'Roboto',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Search bar ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.inputBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  style: const TextStyle(color: AppColors.white),
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Search class...',
                    hintStyle: TextStyle(
                      color: AppColors.grey.withValues(alpha: 0.5),
                      fontFamily: 'Roboto',
                    ),
                    prefixIcon: const Icon(Icons.search, color: AppColors.grey),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear,
                              color: AppColors.grey,
                              size: 18,
                            ),
                            onPressed: () => setState(() => _searchQuery = ''),
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
            const SizedBox(height: 16),

            // ── Class list ────────────────────────────────────────────────
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
                        _searchQuery.isNotEmpty
                            ? 'No classes match "$_searchQuery"'
                            : 'No classes yet\nTap "+ Add New Class" to get started',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.grey.withValues(alpha: 0.5),
                          fontFamily: 'Roboto',
                          height: 1.6,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) => _buildClassCard(_filtered[i]),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── Class card ────────────────────────────────────────────────────────────
  Widget _buildClassCard(Map<String, dynamic> cls) {
    final name = cls['name'] as String? ?? '';
    final studentCount = (cls['students'] as List<dynamic>? ?? []).length;
    final realIndex = _classes.indexOf(cls);

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ClassDetailPage(
              classData: cls,
              classIndex: realIndex,
              onClassUpdated: _loadData,
            ),
          ),
        );
        _loadData();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Roboto',
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$studentCount student${studentCount == 1 ? '' : 's'}',
                    style: TextStyle(
                      color: AppColors.grey.withValues(alpha: 0.7),
                      fontSize: 13,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ],
              ),
            ),
            // Add Student
            GestureDetector(
              onTap: () => _showAddStudentDialog(name),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.person_add_outlined,
                  color: AppColors.primaryCyan,
                  size: 20,
                ),
              ),
            ),
            // Assign Activity
            GestureDetector(
              onTap: () => _showAssignActivityDialog(name),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.assignment_outlined,
                  color: AppColors.primaryCyan,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 2),
            // Edit
            GestureDetector(
              onTap: () => _showEditClassDialog(realIndex, cls),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.edit_outlined,
                  color: AppColors.grey.withValues(alpha: 0.6),
                  size: 18,
                ),
              ),
            ),
            // Delete
            GestureDetector(
              onTap: () => _confirmDeleteClass(realIndex),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(
                  Icons.delete_outline,
                  color: AppColors.errorRed,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bottom nav ────────────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bottomNavBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(Icons.notifications_outlined, 0, 'Notification'),
              _navItem(Icons.play_circle_outline, 1, 'Submissions'),
              _navItem(Icons.home_outlined, 2, 'Home'),
              _navItem(Icons.add_circle_outline, 3, 'Create\nStudent Account'),
              _navItem(Icons.person_outline, 4, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, int index, String label) {
    final selected = _navIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _navIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: selected
                ? AppColors.primaryCyan
                : Colors.white.withValues(alpha: 0.7),
            size: 26,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected
                  ? AppColors.primaryCyan
                  : Colors.white.withValues(alpha: 0.7),
              fontSize: 10,
              fontFamily: 'Roboto',
            ),
          ),
        ],
      ),
    );
  }

  // ── Profile tab ───────────────────────────────────────────────────────────
  Widget _buildProfileTab() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ProfileAvatar(
              username: _username,
              radius: 48,
              editable: true,
              accentColor: AppColors.primaryCyan,
            ),
            const SizedBox(height: 16),
            Text(
              _username,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                fontFamily: 'Roboto',
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primaryCyan.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.school, size: 13, color: AppColors.primaryCyan),
                  SizedBox(width: 6),
                  Text(
                    'Teacher Account',
                    style: TextStyle(
                      color: AppColors.primaryCyan,
                      fontSize: 13,
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),
            const Divider(color: AppColors.inputBg),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout, size: 18),
                label: const Text(
                  'Logout',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Roboto',
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.errorRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Future<void> _logout() async {
    await SessionStorageService.saveUsername('');
    await SessionStorageService.saveRole('');
    if (!mounted) return;
    // ignore: use_build_context_synchronously
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const StartPage()),
      (route) => false,
    );
  }

  // ── Add Student dialog ───────────────────────────────────────────────────
  /// Opens a dialog where the teacher types a student name/ID and sends an
  /// enrollment invitation. The invitation appears in the student's
  /// Notification screen where they can Accept or Delete it.
  void _showAddStudentDialog(String className) {
    final ctrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryCyan.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.person_add_outlined,
                color: AppColors.primaryCyan,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Add Student',
              style: TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.bold,
                fontSize: 17,
                fontFamily: 'Roboto',
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Class badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primaryCyan.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primaryCyan.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.class_outlined,
                    size: 12,
                    color: AppColors.primaryCyan,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    className,
                    style: const TextStyle(
                      color: AppColors.primaryCyan,
                      fontSize: 12,
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _fLabel('Student Name or ID'),
            const SizedBox(height: 6),
            _fField(ctrl, 'e.g. Juan Dela Cruz'),
            const SizedBox(height: 6),
            Text(
              'An enrollment notification will be sent to the student.',
              style: TextStyle(
                color: AppColors.grey.withValues(alpha: 0.55),
                fontSize: 11,
                fontFamily: 'Roboto',
              ),
            ),
          ],
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
          ElevatedButton.icon(
            onPressed: () {
              final studentName = ctrl.text.trim();
              if (studentName.isEmpty) return;

              // Send via shared EnrollmentService
              context.read<EnrollmentService>().sendInvite(
                teacherName: _username,
                className: className,
                studentName: studentName,
              );

              Navigator.pop(ctx);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Enrollment invite sent to $studentName',
                    style: const TextStyle(fontFamily: 'Roboto'),
                  ),
                  backgroundColor: AppColors.primaryCyan,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.send_outlined, size: 16),
            label: const Text(
              'Send Invite',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontFamily: 'Roboto',
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryCyan,
              foregroundColor: Colors.black,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Assign Activity dialog (Outlook-style) ────────────────────────────────
  /// Teacher selects an activity type, sets a title, optional description,
  /// and a deadline. On confirm, a [ClassNotification] of type
  /// [activityAssignment] is pushed to [ClassNotificationsService] so the
  /// student sees it in their Notification and Calendar screens.
  void _showAssignActivityDialog(String className) {
    const types = [
      'Solfege Drill',
      'Practice Exercise',
      'Task Performance',
      'Karaoke',
    ];
    String selectedType = types[0];
    final titleCtrl = TextEditingController(text: 'Activity 1');
    final descCtrl = TextEditingController();
    DateTime deadline = DateTime.now().add(const Duration(days: 7));
    TimeOfDay deadlineTime = const TimeOfDay(hour: 23, minute: 59);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          return AlertDialog(
            backgroundColor: AppColors.cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryCyan.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.assignment_outlined,
                    color: AppColors.primaryCyan,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Assign Activity',
                  style: TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    fontFamily: 'Roboto',
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Class badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryCyan.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primaryCyan.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.class_outlined,
                          size: 12,
                          color: AppColors.primaryCyan,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          className,
                          style: const TextStyle(
                            color: AppColors.primaryCyan,
                            fontSize: 12,
                            fontFamily: 'Roboto',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Activity type chips
                  _fLabel('Activity Type'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: types.map((t) {
                      final active = t == selectedType;
                      return GestureDetector(
                        onTap: () {
                          setS(() {
                            selectedType = t;
                            titleCtrl.text = 'Activity 1 — $t';
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: active
                                ? AppColors.primaryCyan
                                : AppColors.inputBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: active
                                  ? AppColors.primaryCyan
                                  : AppColors.grey.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            t,
                            style: TextStyle(
                              color: active ? Colors.black : AppColors.grey,
                              fontSize: 12,
                              fontFamily: 'Roboto',
                              fontWeight: active
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // Title
                  _fLabel('Title'),
                  const SizedBox(height: 6),
                  _fField(titleCtrl, 'e.g. Activity 1 — Solfege Drill'),
                  const SizedBox(height: 12),

                  // Description
                  _fLabel('Description (optional)'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 14,
                      fontFamily: 'Roboto',
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.inputBg,
                      hintText: 'Instructions or notes…',
                      hintStyle: TextStyle(
                        color: AppColors.grey.withValues(alpha: 0.5),
                        fontFamily: 'Roboto',
                        fontSize: 13,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Deadline picker (Outlook-style row)
                  _fLabel('Deadline'),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: deadline,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        builder: (ctx2, child) => Theme(
                          data: ThemeData.dark().copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: AppColors.primaryCyan,
                              surface: Color(0xFF2A2A2A),
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) setS(() => deadline = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.inputBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.primaryCyan.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_month_outlined,
                            color: AppColors.primaryCyan,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${_monthName(deadline.month)} ${deadline.day}, ${deadline.year}',
                            style: const TextStyle(
                              color: AppColors.white,
                              fontFamily: 'Roboto',
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.arrow_drop_down,
                            color: AppColors.grey.withValues(alpha: 0.6),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Time picker
                  GestureDetector(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: ctx,
                        initialTime: deadlineTime,
                        builder: (ctx2, child) => Theme(
                          data: ThemeData.dark().copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: AppColors.primaryCyan,
                              surface: Color(0xFF2A2A2A),
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) setS(() => deadlineTime = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.inputBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.primaryCyan.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.access_time_outlined,
                            color: AppColors.primaryCyan,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            deadlineTime.format(ctx),
                            style: const TextStyle(
                              color: AppColors.white,
                              fontFamily: 'Roboto',
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.arrow_drop_down,
                            color: AppColors.grey.withValues(alpha: 0.6),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Students will be notified immediately.',
                    style: TextStyle(
                      color: AppColors.grey.withValues(alpha: 0.55),
                      fontSize: 11,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ],
              ),
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
              ElevatedButton.icon(
                onPressed: () {
                  final title = titleCtrl.text.trim();
                  if (title.isEmpty) return;

                  // Merge date + time into a single DateTime
                  final fullDeadline = DateTime(
                    deadline.year,
                    deadline.month,
                    deadline.day,
                    deadlineTime.hour,
                    deadlineTime.minute,
                  );

                  ClassNotificationsService().addNotification(
                    ClassNotification(
                      id: '${DateTime.now().millisecondsSinceEpoch}',
                      teacherName: _username,
                      className: className,
                      message: 'Added Activity / $selectedType',
                      timestamp: DateTime.now(),
                      type: NotificationType.activityAssignment,
                      activityName: title,
                      deadline: fullDeadline,
                    ),
                  );

                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Activity "$title" assigned to $className',
                        style: const TextStyle(fontFamily: 'Roboto'),
                      ),
                      backgroundColor: AppColors.primaryCyan,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.send_outlined, size: 16),
                label: const Text(
                  'Assign',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Roboto',
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryCyan,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _monthName(int month) {
    const names = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return names[month];
  }

  // ── Add class dialog ──────────────────────────────────────────────────────
  void _showAddClassDialog() {
    final nameCtrl = TextEditingController();
    final stuCtrl = TextEditingController();
    final students = <String>[];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setL) => AlertDialog(
          backgroundColor: AppColors.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          titlePadding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
          contentPadding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
          title: const Text(
            'New Class',
            style: TextStyle(
              color: AppColors.white,
              fontWeight: FontWeight.bold,
              fontFamily: 'Roboto',
            ),
          ),
          content: SizedBox(
            width: 340,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fLabel('Class Name'),
                  const SizedBox(height: 6),
                  _fField(nameCtrl, 'e.g. GRADE 11 – SAMPAGUITA'),
                  const SizedBox(height: 16),
                  _fLabel('Search Student Name / ID'),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(child: _fField(stuCtrl, 'Student name or ID')),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          final n = stuCtrl.text.trim();
                          if (n.isNotEmpty && !students.contains(n)) {
                            setL(() => students.add(n));
                            stuCtrl.clear();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primaryCyan,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.add,
                            color: Colors.black,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (students.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ...students.asMap().entries.map(
                      (e) => Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.inputBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.person_outline,
                              color: AppColors.grey,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                e.value,
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 13,
                                  fontFamily: 'Roboto',
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setL(() => students.removeAt(e.key)),
                              child: const Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF4CAF50),
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
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
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                await SessionStorageService.addClass({
                  'name': nameCtrl.text.trim(),
                  'students': List<String>.from(students),
                  'assignedSongs': <String>[],
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _loadData();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryCyan,
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              child: const Text(
                'Create',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Roboto',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Edit class dialog ─────────────────────────────────────────────────────
  void _showEditClassDialog(int index, Map<String, dynamic> cls) {
    final nameCtrl = TextEditingController(text: cls['name'] as String? ?? '');
    final stuCtrl = TextEditingController();
    final students = List<String>.from(cls['students'] as List<dynamic>? ?? []);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setL) => AlertDialog(
          backgroundColor: AppColors.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          titlePadding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
          contentPadding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
          title: const Text(
            'Edit Class',
            style: TextStyle(
              color: AppColors.white,
              fontWeight: FontWeight.bold,
              fontFamily: 'Roboto',
            ),
          ),
          content: SizedBox(
            width: 340,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fLabel('Class Name'),
                  const SizedBox(height: 6),
                  _fField(nameCtrl, 'e.g. GRADE 11 – SAMPAGUITA'),
                  const SizedBox(height: 16),
                  _fLabel('Add Student'),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(child: _fField(stuCtrl, 'Student name or ID')),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          final n = stuCtrl.text.trim();
                          if (n.isNotEmpty && !students.contains(n)) {
                            setL(() => students.add(n));
                            stuCtrl.clear();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primaryCyan,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.add,
                            color: Colors.black,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (students.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ...students.asMap().entries.map(
                      (e) => Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.inputBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.person_outline,
                              color: AppColors.grey,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                e.value,
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 13,
                                  fontFamily: 'Roboto',
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setL(() => students.removeAt(e.key)),
                              child: const Icon(
                                Icons.close,
                                color: AppColors.errorRed,
                                size: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
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
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                final updated = Map<String, dynamic>.from(cls);
                updated['name'] = nameCtrl.text.trim();
                updated['students'] = List<String>.from(students);
                await SessionStorageService.updateClass(index, updated);
                if (ctx.mounted) Navigator.pop(ctx);
                _loadData();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryCyan,
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              child: const Text(
                'Save',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Roboto',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Delete confirm ────────────────────────────────────────────────────────
  void _confirmDeleteClass(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
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
              _loadData();
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

  // ── Helpers ───────────────────────────────────────────────────────────────
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
}

// ═══════════════════════════════════════════════════════════════════════════
// CREATE STUDENT ACCOUNT PAGE — Full-page form matching your screenshot
// ═══════════════════════════════════════════════════════════════════════════

class CreateStudentAccountPage extends StatefulWidget {
  const CreateStudentAccountPage({super.key});

  @override
  State<CreateStudentAccountPage> createState() =>
      _CreateStudentAccountPageState();
}

class _CreateStudentAccountPageState extends State<CreateStudentAccountPage> {
  final _lastNameCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  String? _lastNameError;
  String? _firstNameError;
  String? _usernameError;
  String? _passwordError;
  String? _confirmPasswordError;

  Future<void> _createAccount() async {
    // Clear previous errors
    setState(() {
      _lastNameError = null;
      _firstNameError = null;
      _usernameError = null;
      _passwordError = null;
      _confirmPasswordError = null;
    });

    // Validate
    bool hasError = false;
    if (_lastNameCtrl.text.trim().isEmpty) {
      _lastNameError = 'Last name is required';
      hasError = true;
    }
    if (_firstNameCtrl.text.trim().isEmpty) {
      _firstNameError = 'First name is required';
      hasError = true;
    }
    if (_usernameCtrl.text.trim().isEmpty) {
      _usernameError = 'Username is required';
      hasError = true;
    }
    if (_passwordCtrl.text.isEmpty) {
      _passwordError = 'Password is required';
      hasError = true;
    }
    if (_confirmPasswordCtrl.text.isEmpty) {
      _confirmPasswordError = 'Please re-type your password';
      hasError = true;
    } else if (_passwordCtrl.text != _confirmPasswordCtrl.text) {
      _confirmPasswordError = 'Passwords do not match';
      hasError = true;
    }

    if (hasError) {
      setState(() {});
      return;
    }

    setState(() => _isLoading = true);

    final lastName = _lastNameCtrl.text.trim();
    final firstName = _firstNameCtrl.text.trim();
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text;

    // Save student account
    await SessionStorageService.saveStudentAccount({
      'username': username,
      'password': password,
      'lastName': lastName,
      'firstName': firstName,
      'fullName': '$firstName $lastName',
    });

    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Account created for $firstName $lastName',
            style: const TextStyle(fontFamily: 'Roboto'),
          ),
          backgroundColor: AppColors.primaryCyan,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );

      // Clear fields after success
      _lastNameCtrl.clear();
      _firstNameCtrl.clear();
      _usernameCtrl.clear();
      _passwordCtrl.clear();
      _confirmPasswordCtrl.clear();
    }
  }

  @override
  void dispose() {
    _lastNameCtrl.dispose();
    _firstNameCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          const Text(
            'Create Student Account',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              fontFamily: 'Roboto',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Fill in the student\'s details below.',
            style: TextStyle(
              color: AppColors.grey.withValues(alpha: 0.6),
              fontSize: 14,
              fontFamily: 'Roboto',
            ),
          ),
          const SizedBox(height: 32),

          // ── Personal Information Section ────────────────────────────────
          const Text(
            'Personal Information',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Roboto',
            ),
          ),
          const SizedBox(height: 16),

          // Last Name
          _buildTextField(
            controller: _lastNameCtrl,
            hint: 'Last Name',
            errorText: _lastNameError,
          ),
          const SizedBox(height: 12),

          // First Name
          _buildTextField(
            controller: _firstNameCtrl,
            hint: 'First Name',
            errorText: _firstNameError,
          ),
          const SizedBox(height: 32),

          // ── Login Information Section ───────────────────────────────────
          const Text(
            'Login Information',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Roboto',
            ),
          ),
          const SizedBox(height: 16),

          // Username
          _buildTextField(
            controller: _usernameCtrl,
            hint: 'Username',
            errorText: _usernameError,
          ),
          const SizedBox(height: 12),

          // Password
          _buildTextField(
            controller: _passwordCtrl,
            hint: 'Password',
            obscureText: _obscurePassword,
            errorText: _passwordError,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: AppColors.grey,
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          const SizedBox(height: 12),

          // Re-type Password
          _buildTextField(
            controller: _confirmPasswordCtrl,
            hint: 'Re-type Password',
            obscureText: _obscureConfirm,
            errorText: _confirmPasswordError,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                color: AppColors.grey,
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
            ),
          ),
          const SizedBox(height: 40),

          // ── Create Account Button ───────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _createAccount,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryCyan,
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                disabledBackgroundColor: AppColors.primaryCyan.withValues(
                  alpha: 0.4,
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.black,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      'Create Account',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Roboto',
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    bool obscureText = false,
    String? errorText,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(
        color: AppColors.white,
        fontSize: 16,
        fontFamily: 'Roboto',
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: AppColors.grey.withValues(alpha: 0.5),
          fontSize: 16,
          fontFamily: 'Roboto',
        ),
        filled: true,
        fillColor: AppColors.inputBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: AppColors.primaryCyan,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.errorRed, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.errorRed, width: 1.5),
        ),
        errorText: errorText,
        errorStyle: const TextStyle(
          color: AppColors.errorRed,
          fontSize: 12,
          fontFamily: 'Roboto',
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        suffixIcon: suffixIcon,
      ),
    );
  }
}
