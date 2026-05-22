import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/class_notification.dart';
import '../../services/class_notifications_service.dart';
import '../../services/session_storage_service.dart';
import 'teacher_solfege_drill_page.dart';

class CreateSolfegeDrillPage extends StatefulWidget {
  final Map<String, dynamic>? classData;

  const CreateSolfegeDrillPage({super.key, this.classData});

  @override
  State<CreateSolfegeDrillPage> createState() => _CreateSolfegeDrillPageState();
}

class _CreateSolfegeDrillPageState extends State<CreateSolfegeDrillPage> {
  final List<String> _selectedNotes = [];
  final TextEditingController _titleController = TextEditingController();
  final List<String> _availableNotes = [
    'Do',
    'Re',
    'Mi',
    'Fa',
    'Sol',
    'La',
    'Ti',
  ];

  DateTime? _dueDate;
  int _maxScore = 100;
  bool _assigning = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
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

  void _startDrill() {
    if (_selectedNotes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one note')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TeacherSolfegeDrill(
          sequence: _selectedNotes,
          lessonTitle: _titleController.text.isNotEmpty
              ? _titleController.text
              : 'Solfege Drill',
        ),
      ),
    );
  }

  void _addRandomSequence() {
    setState(() {
      _selectedNotes.clear();
      final random = List.generate(4, (index) {
        return _availableNotes[(DateTime.now().millisecondsSinceEpoch ~/
                (index + 1)) %
            7];
      });
      _selectedNotes.addAll(random);
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

    final className = widget.classData?['name'] as String? ?? 'Class';
    final title = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : 'Solfege Drill';
    final fullDeadline = _dueDate ?? DateTime.now().add(const Duration(days: 7));

    await ClassNotificationsService().addNotification(
      ClassNotification(
        id: '${DateTime.now().millisecondsSinceEpoch}',
        teacherName: await SessionStorageService.loadUsername() ?? 'Teacher',
        className: className,
        message: 'Solfege Drill: $title — Notes: ${_selectedNotes.join(', ')}',
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
            Icon(Icons.check_circle_rounded, color: Color(0xFF4CAF50), size: 22),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Solfege Drill Assigned',
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
          '$className.\n\nMax Score: $_maxScore',
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
              style: TextStyle(fontWeight: FontWeight.w700, fontFamily: 'Roboto'),
            ),
          ),
        ],
      ),
    );
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
              padding: const EdgeInsets.fromLTRB(4, 10, 16, 20),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      color: AppColors.white,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create Solfege Drill',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.white,
                            fontFamily: 'Roboto',
                          ),
                        ),
                        Text(
                          'Define a sequence for your students',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.primaryCyan,
                            fontFamily: 'Roboto',
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ListView(
                  children: [
                    // Lesson title
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Lesson Title',
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Roboto',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.inputBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextField(
                            controller: _titleController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText:
                                  'e.g., Scale Practice, Grade 11 Lesson...',
                              hintStyle: TextStyle(
                                color: AppColors.grey.withValues(alpha: 0.6),
                                fontFamily: 'Roboto',
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Note selection
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Select Notes',
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
                          spacing: 8,
                          runSpacing: 8,
                          children: _availableNotes.map((note) {
                            final isSelected = _selectedNotes.contains(note);
                            final colorMap = {
                              'Do': const Color(0xFFE53935),
                              'Re': const Color(0xFFFF7043),
                              'Mi': const Color(0xFFFDD835),
                              'Fa': const Color(0xFF43A047),
                              'Sol': const Color(0xFF1E88E5),
                              'La': const Color(0xFF8E24AA),
                              'Ti': const Color(0xFF00ACC1),
                            };

                            return GestureDetector(
                              onTap: () => _toggleNote(note),
                              child: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? colorMap[note]
                                      : AppColors.inputBg,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? colorMap[note]!
                                        : AppColors.grey.withValues(alpha: 0.3),
                                    width: isSelected ? 2 : 1,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: colorMap[note]!.withValues(
                                              alpha: 0.4,
                                            ),
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
                                      color: isSelected
                                          ? Colors.white
                                          : AppColors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Roboto',
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Preview sequence
                    if (_selectedNotes.isNotEmpty) ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Preview Sequence',
                            style: TextStyle(
                              color: AppColors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Roboto',
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.inputBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.all(16),
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
                        ],
                      ),
                      const SizedBox(height: 24),
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

                    // Due Date
                    GestureDetector(
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
                                    ? 'Set Deadline'
                                    : 'Deadline: ${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}',
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

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            // Bottom buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                children: [
                  // Give to students button
                  GestureDetector(
                    onTap: _assigning ? null : _giveToStudents,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
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
                              'Give to Students',
                              style: TextStyle(
                                color: AppColors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Roboto',
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _addRandomSequence,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryCyan,
                            side: const BorderSide(color: AppColors.primaryCyan),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text(
                            'Random',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Roboto',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _startDrill,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryCyan,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text(
                            'Preview Drill',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Roboto',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
