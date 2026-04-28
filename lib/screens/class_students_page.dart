import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/session_storage_service.dart';

/// Students management page for a specific class.
/// Teal header + student list with avatar, name, phone placeholder, Remove.
class ClassStudentsPage extends StatefulWidget {
  final Map<String, dynamic> classData;
  final int classIndex;
  final VoidCallback onStudentsUpdated;

  const ClassStudentsPage({
    super.key,
    required this.classData,
    required this.classIndex,
    required this.onStudentsUpdated,
  });

  @override
  State<ClassStudentsPage> createState() => _ClassStudentsPageState();
}

class _ClassStudentsPageState extends State<ClassStudentsPage> {
  late List<String> _students;
  late String _className;

  static const _avatarColors = [
    AppColors.primaryCyan,
    Color(0xFF9C6FFF),
    Color(0xFFFFA726),
    Color(0xFF4CAF50),
    Color(0xFFEF5350),
  ];

  @override
  void initState() {
    super.initState();
    _className = widget.classData['name'] as String? ?? '';
    _students = List<String>.from(
        widget.classData['students'] as List<dynamic>? ?? []);
  }

  Future<void> _persist() async {
    final updated = Map<String, dynamic>.from(widget.classData);
    updated['students'] = List<String>.from(_students);
    await SessionStorageService.updateClass(widget.classIndex, updated);
    widget.onStudentsUpdated();
  }

  void _addStudentDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Add Student',
          style: TextStyle(
              color: AppColors.white,
              fontWeight: FontWeight.bold,
              fontFamily: 'Roboto'),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: AppColors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Student name or ID',
            hintStyle: TextStyle(
                color: AppColors.grey.withValues(alpha: 0.4), fontSize: 12),
            filled: true,
            fillColor: AppColors.inputBg,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: AppColors.primaryCyan, width: 1.5),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(
                  color: AppColors.grey.withValues(alpha: 0.8),
                  fontFamily: 'Roboto'),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isNotEmpty && !_students.contains(name)) {
                setState(() => _students.add(name));
                await _persist();
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryCyan,
              foregroundColor: Colors.black,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9)),
            ),
            child: const Text('Add',
                style: TextStyle(
                    fontWeight: FontWeight.w700, fontFamily: 'Roboto')),
          ),
        ],
      ),
    );
  }

  void _confirmRemove(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Remove Student',
          style: TextStyle(
              color: AppColors.white,
              fontWeight: FontWeight.bold,
              fontFamily: 'Roboto'),
        ),
        content: Text(
          'Remove "${_students[index]}" from this class?',
          style: const TextStyle(
              color: AppColors.grey,
              fontFamily: 'Roboto',
              fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style:
                    TextStyle(color: AppColors.grey, fontFamily: 'Roboto')),
          ),
          ElevatedButton(
            onPressed: () async {
              setState(() => _students.removeAt(index));
              await _persist();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9)),
            ),
            child: const Text('Remove',
                style: TextStyle(fontFamily: 'Roboto')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back_ios_new,
                      color: Colors.black, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    _className.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Roboto',
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Body ──────────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row always visible
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: _buildHeader(),
                ),
                // List or empty state
                Expanded(
                  child: _students.isEmpty
                      ? Center(
                          child: Text(
                            'No students yet\nTap "Add Student" to add one',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.grey.withValues(alpha: 0.5),
                              fontFamily: 'Roboto',
                              height: 1.6,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                          itemCount: _students.length,
                          itemBuilder: (_, i) =>
                              _buildStudentRow(i, _students[i]),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Students (${_students.length})',
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              fontFamily: 'Roboto',
            ),
          ),
          GestureDetector(
            onTap: _addStudentDialog,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primaryCyan.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppColors.primaryCyan.withValues(alpha: 0.4)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add,
                      color: AppColors.primaryCyan, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Add Student',
                    style: TextStyle(
                      color: AppColors.primaryCyan,
                      fontWeight: FontWeight.w600,
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
    );
  }

  Widget _buildStudentRow(int index, String name) {
    final color = _avatarColors[index % _avatarColors.length];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Avatar circle
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Roboto',
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Name + phone placeholder
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
                const SizedBox(height: 3),
                Text(
                  '09XX-XXX-XXXX',
                  style: TextStyle(
                    color: AppColors.grey.withValues(alpha: 0.55),
                    fontSize: 12,
                    fontFamily: 'Roboto',
                  ),
                ),
              ],
            ),
          ),
          // Remove button
          GestureDetector(
            onTap: () => _confirmRemove(index),
            child: const Text(
              'Remove',
              style: TextStyle(
                color: AppColors.errorRed,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFamily: 'Roboto',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom nav ─────────────────────────────────────────────────────────
  Widget _buildBottomNav(BuildContext context) {
    return Container(
      height: 70,
      color: AppColors.bottomNavBg,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navIcon(Icons.notifications_outlined),
          _navIcon(Icons.home_outlined,
              onTap: () => Navigator.of(context).pop()),
          _navIcon(Icons.person_outline),
        ],
      ),
    );
  }

  Widget _navIcon(IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Icon(icon,
            color: AppColors.grey.withValues(alpha: 0.5), size: 26),
      ),
    );
  }
}
