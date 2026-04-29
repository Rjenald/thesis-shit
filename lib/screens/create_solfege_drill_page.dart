import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../core/note_utils.dart';
import 'teacher_solfege_drill_page.dart';

class CreateSolfegeDrillPage extends StatefulWidget {
  const CreateSolfegeDrillPage({super.key});

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
                        Text(
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
                            Text(
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
                              style: TextStyle(
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
                              'Do': Color(0xFFE53935),
                              'Re': Color(0xFFFF7043),
                              'Mi': Color(0xFFFDD835),
                              'Fa': Color(0xFF43A047),
                              'Sol': Color(0xFF1E88E5),
                              'La': Color(0xFF8E24AA),
                              'Ti': Color(0xFF00ACC1),
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
                          Text(
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: List.generate(
                                    _selectedNotes.length,
                                    (i) => Expanded(
                                      child: Column(
                                        children: [
                                          Text(
                                            _selectedNotes[i],
                                            style: const TextStyle(
                                              color: AppColors.primaryCyan,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'Roboto',
                                            ),
                                          ),
                                          if (i < _selectedNotes.length - 1)
                                            const Padding(
                                              padding: EdgeInsets.only(top: 4),
                                              child: Icon(
                                                Icons.arrow_downward,
                                                size: 16,
                                                color: AppColors.primaryCyan,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Students will sing in order: ${_selectedNotes.join(" → ")}',
                                  style: TextStyle(
                                    color: AppColors.grey.withValues(
                                      alpha: 0.7,
                                    ),
                                    fontSize: 12,
                                    fontFamily: 'Roboto',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),

            // Bottom buttons
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
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
                        'Start Drill',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Roboto',
                        ),
                      ),
                    ),
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
