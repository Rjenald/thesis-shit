import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/class_notification.dart';
import '../../services/class_notifications_service.dart';
import '../../services/session_storage_service.dart';

class TaskPerformanceAssignPage extends StatefulWidget {
  final Map<String, dynamic> classData;
  final String lessonTitle;

  const TaskPerformanceAssignPage({
    super.key,
    required this.classData,
    required this.lessonTitle,
  });

  @override
  State<TaskPerformanceAssignPage> createState() =>
      _TaskPerformanceAssignPageState();
}

class _TaskPerformanceAssignPageState extends State<TaskPerformanceAssignPage> {
  final _titleCtrl = TextEditingController(text: 'Task Performance 1');
  final _instructionCtrl = TextEditingController(
    text: 'Sing the assigned solfege sequence accurately',
  );

  static const _allNotes = ['Do', 'Re', 'Mi', 'Fa', 'Sol', 'La', 'Ti'];
  static const _noteColors = {
    'Do': Color(0xFFE53935),
    'Re': Color(0xFFFF7043),
    'Mi': Color(0xFFFDD835),
    'Fa': Color(0xFF43A047),
    'Sol': Color(0xFF1E88E5),
    'La': Color(0xFF8E24AA),
    'Ti': Color(0xFF00ACC1),
  };

  final List<String> _selectedNotes = [];
  DateTime? _dueDate;
  bool _allowLate = false;
  int _maxScore = 100;
  bool _assigning = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _instructionCtrl.dispose();
    super.dispose();
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

  void _toggleNote(String note) {
    setState(() {
      if (_selectedNotes.contains(note)) {
        _selectedNotes.remove(note);
      } else {
        _selectedNotes.add(note);
      }
    });
  }

  Future<void> _giveToStudents() async {
    if (_selectedNotes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one note first'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _assigning = true);

    final className = widget.classData['name'] as String? ?? '';
    final title = _titleCtrl.text.trim().isNotEmpty
        ? _titleCtrl.text.trim()
        : 'Task Performance';

    final fullDeadline = _dueDate ?? DateTime.now().add(const Duration(days: 7));

    await ClassNotificationsService().addNotification(
      ClassNotification(
        id: '${DateTime.now().millisecondsSinceEpoch}',
        teacherName: await SessionStorageService.loadUsername() ?? 'Teacher',
        className: className,
        message: 'Task Performance: $title — Notes: ${_selectedNotes.join(', ')}',
        timestamp: DateTime.now(),
        type: NotificationType.activityAssignment,
        activityName: title,
        deadline: fullDeadline,
        maxScore: _maxScore,
      ),
    );

    setState(() => _assigning = false);

    if (!mounted) return;

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
            Expanded(
              child: Text(
                'Task Performance Assigned',
                style: TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Roboto',
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          '"$title" with notes ${_selectedNotes.join(', ')} has been sent to '
          '$className.\n\nStudents must sing the sequence and achieve the target score.',
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
          // Teal header
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
                    '${widget.lessonTitle}  /  Task Performance',
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

          // Scrollable body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title field
                  const Text(
                    'Activity Title',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Roboto',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleCtrl,
                    style: const TextStyle(color: AppColors.white, fontSize: 14),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.inputBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Instructions field
                  const Text(
                    'Instructions',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Roboto',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _instructionCtrl,
                    maxLines: 2,
                    style: const TextStyle(color: AppColors.white, fontSize: 13),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.inputBg,
                      hintText: 'Instructions for students...',
                      hintStyle: TextStyle(
                        color: AppColors.grey.withValues(alpha: 0.6),
                        fontFamily: 'Roboto',
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Solfege note selection
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Select Solfege Notes',
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Roboto',
                        ),
                      ),
                      Text(
                        '${_selectedNotes.length} selected',
                        style: const TextStyle(
                          color: AppColors.primaryCyan,
                          fontSize: 12,
                          fontFamily: 'Roboto',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _allNotes.map((note) {
                      final isSelected = _selectedNotes.contains(note);
                      final noteColor =
                          _noteColors[note] ?? AppColors.primaryCyan;
                      return GestureDetector(
                        onTap: () => _toggleNote(note),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? noteColor
                                : AppColors.inputBg,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? noteColor
                                  : AppColors.grey.withValues(alpha: 0.3),
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: noteColor.withValues(alpha: 0.4),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : [],
                          ),
                          child: Center(
                            child: Text(
                              note,
                              style: TextStyle(
                                color: isSelected ? Colors.white : AppColors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Roboto',
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Sequence preview
                  if (_selectedNotes.isNotEmpty) ...[
                    const Text(
                      'Performance Sequence',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Roboto',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.inputBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _selectedNotes.join('  →  '),
                        style: const TextStyle(
                          color: AppColors.primaryCyan,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Roboto',
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Max Score
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Max Score',
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Roboto',
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() {
                          if (_maxScore > 10) _maxScore -= 10;
                        }),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.inputBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.remove, color: AppColors.grey, size: 18),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.inputBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$_maxScore',
                          style: const TextStyle(
                            color: AppColors.primaryCyan,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Roboto',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => setState(() {
                          if (_maxScore < 200) _maxScore += 10;
                        }),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.inputBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.add, color: AppColors.grey, size: 18),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Due date + Allow late
                  Row(
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
                                Expanded(
                                  child: Text(
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
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Row(
                        children: [
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
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Give to students button
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: GestureDetector(
              onTap: _assigning ? null : _giveToStudents,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: _assigning
                      ? AppColors.inputBg
                      : const Color(0xFF1C1C1C),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primaryCyan.withValues(alpha: 0.4),
                  ),
                ),
                alignment: Alignment.center,
                child: _assigning
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primaryCyan,
                        ),
                      )
                    : const Text(
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
    );
  }

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
          const SizedBox(width: 8),
        ],
      ),
    );
  }

}
