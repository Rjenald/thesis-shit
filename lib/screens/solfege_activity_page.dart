import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../widgets/piano_keyboard_widget.dart';

/// Solfege Activity — teacher selects piano notes for students to hit,
/// sets a due date, and gives the assignment to the class.
class SolfegeActivityPage extends StatefulWidget {
  final Map<String, dynamic> classData;
  final String lessonTitle;

  const SolfegeActivityPage({
    super.key,
    required this.classData,
    required this.lessonTitle,
  });

  @override
  State<SolfegeActivityPage> createState() => _SolfegeActivityPageState();
}

class _SolfegeActivityPageState extends State<SolfegeActivityPage> {
  static const _allNotes = ['Do', 'Re', 'Mi', 'Fa', 'So', 'La', 'Ti'];
  static const _noteColors = {
    'Do': Color(0xFFE53935),
    'Re': Color(0xFFFF7043),
    'Mi': Color(0xFFFDD835),
    'Fa': Color(0xFF43A047),
    'So': Color(0xFF1E88E5),
    'La': Color(0xFF8E24AA),
    'Ti': Color(0xFF00ACC1),
  };

  final Set<String> _selected = {};
  final _instructionCtrl = TextEditingController(
    text: 'Students must hit the notes',
  );
  DateTime? _dueDate;
  bool _allowLate = false;

  @override
  void dispose() {
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

  void _giveToStudents() {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one note first'),
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
              'Activity Assigned',
              style: TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.bold,
                fontFamily: 'Roboto',
              ),
            ),
          ],
        ),
        content: Text(
          '"Solfege Activity" with notes ${_selected.join(', ')} has been sent to '
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
                    '${widget.lessonTitle}  /  Solfege Activity',
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

          // ── Scrollable body ────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Piano keyboard — live, with sound
                  const Text(
                    'Tap the keys to hear the notes',
                    style: TextStyle(
                      color: AppColors.grey,
                      fontSize: 12,
                      fontFamily: 'Roboto',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 140,
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: const PianoKeyboardWidget(
                      keyHeight: 140,
                      whiteKeyWidth: 46,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Instruction label
                  const Text(
                    'Select notes from Piano for the student to hit',
                    style: TextStyle(
                      color: AppColors.grey,
                      fontSize: 13,
                      fontFamily: 'Roboto',
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Instruction text field
                  TextField(
                    controller: _instructionCtrl,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
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
                        borderSide: const BorderSide(
                          color: AppColors.primaryCyan,
                          width: 1.5,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Note grid (2-column)
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 3.2,
                        ),
                    itemCount: _allNotes.length,
                    itemBuilder: (_, i) {
                      final note = _allNotes[i];
                      final isSelected = _selected.contains(note);
                      final noteColor =
                          _noteColors[note] ?? AppColors.primaryCyan;
                      return GestureDetector(
                        onTap: () => setState(() {
                          if (isSelected) {
                            _selected.remove(note);
                          } else {
                            _selected.add(note);
                          }
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? noteColor.withValues(alpha: 0.2)
                                : AppColors.inputBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? noteColor
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            note,
                            style: TextStyle(
                              color: isSelected ? noteColor : AppColors.grey,
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontFamily: 'Roboto',
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Due date + Allow late row
                  Row(
                    children: [
                      // Due Date
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
                      // Allow Late
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

          // ── Give to students button ────────────────────────────────────
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
