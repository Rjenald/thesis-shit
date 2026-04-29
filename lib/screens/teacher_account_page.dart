import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/session_storage_service.dart';
import 'class_detail_page.dart';
import 'start_page.dart';

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
  int _navIndex = 1;

  @override
  void initState() {
    super.initState();
    _loadData();
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
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── "Classroom" title ──────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Text(
                'Classroom',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Roboto',
                ),
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
      height: 70,
      color: AppColors.bottomNavBg,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.notifications_outlined, 0),
          _navItem(Icons.home_outlined, 1),
          _navItem(Icons.person_outline, 2),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, int index) {
    final selected = _navIndex == index;
    return GestureDetector(
      onTap: () {
        if (index == 2) {
          _showProfileSheet();
          return;
        }
        setState(() => _navIndex = index);
      },
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Icon(
          icon,
          color: selected
              ? AppColors.primaryCyan
              : AppColors.grey.withValues(alpha: 0.5),
          size: 26,
        ),
      ),
    );
  }

  // ── Profile bottom sheet ──────────────────────────────────────────────────
  void _showProfileSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: AppColors.primaryCyan.withValues(alpha: 0.15),
              child: Text(
                _username.isNotEmpty ? _username[0].toUpperCase() : 'T',
                style: const TextStyle(
                  color: AppColors.primaryCyan,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Roboto',
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _username,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Roboto',
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryCyan.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.school, size: 11, color: AppColors.primaryCyan),
                  SizedBox(width: 4),
                  Text(
                    'Teacher Account',
                    style: TextStyle(
                      color: AppColors.primaryCyan,
                      fontSize: 11,
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Divider(color: AppColors.inputBg),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.errorRed),
              title: const Text(
                'Logout',
                style: TextStyle(
                  color: AppColors.errorRed,
                  fontFamily: 'Roboto',
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _logout();
              },
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
