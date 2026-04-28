import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Practice Solfege page — teacher demonstrates each solfege syllable,
/// cycles through do→re→mi→fa→so→la→ti, with a recording indicator.
/// "Give to students" sends the activity to the class.
class PracticeSolfegePage extends StatefulWidget {
  final Map<String, dynamic> classData;
  final String lessonTitle;

  const PracticeSolfegePage({
    super.key,
    required this.classData,
    required this.lessonTitle,
  });

  @override
  State<PracticeSolfegePage> createState() => _PracticeSolfegePageState();
}

class _PracticeSolfegePageState extends State<PracticeSolfegePage> {
  static const _syllables = ['do', 're', 'mi', 'fa', 'so', 'la', 'ti'];

  int _index = 0;
  bool _recording = false;
  Timer? _recordTimer;
  String _accuracy = '—';
  String _userRange = '—';

  String get _current => _syllables[_index];

  void _next() {
    setState(() => _index = (_index + 1) % _syllables.length);
  }

  void _prev() {
    setState(() =>
        _index = (_index - 1 + _syllables.length) % _syllables.length);
  }

  void _toggleRecord() {
    if (_recording) {
      _recordTimer?.cancel();
      // Simulate fake result
      setState(() {
        _recording = false;
        _accuracy = '${(78 + _index * 3) % 100}%';
        _userRange = 'C3 – C4';
      });
    } else {
      setState(() {
        _recording = true;
        _accuracy = '—';
        _userRange = '—';
      });
      // Auto-stop after 5 s
      _recordTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() {
            _recording = false;
            _accuracy = '${(78 + _index * 3) % 100}%';
            _userRange = 'C3 – C4';
          });
        }
      });
    }
  }

  void _giveToStudents() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.check_circle_rounded,
              color: Color(0xFF4CAF50), size: 22),
          SizedBox(width: 8),
          Text('Activity Assigned',
              style: TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Roboto')),
        ]),
        content: Text(
          '"Practice Solfege" has been sent to all students in '
          '${widget.classData['name'] ?? 'the class'}.',
          style: const TextStyle(
              color: AppColors.grey, fontFamily: 'Roboto', fontSize: 13),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryCyan,
              foregroundColor: Colors.black,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9)),
            ),
            child: const Text('Done',
                style: TextStyle(
                    fontWeight: FontWeight.w700, fontFamily: 'Roboto')),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    super.dispose();
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
                Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.black, size: 20),
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
                ]),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 36),
                  child: Text(
                    '${widget.lessonTitle}  /  Practice Solfege',
                    style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 12,
                        fontFamily: 'Roboto'),
                  ),
                ),
              ],
            ),
          ),

          // ── Body ──────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                children: [
                  // Syllable display box
                  Container(
                    width: double.infinity,
                    height: 180,
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Syllable text
                        Text(
                          _current,
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 64,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Roboto',
                            letterSpacing: 2,
                          ),
                        ),
                        // Prev/Next arrows
                        Positioned(
                          left: 12,
                          child: GestureDetector(
                            onTap: _prev,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.inputBg,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.chevron_left,
                                  color: AppColors.grey, size: 22),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 12,
                          child: GestureDetector(
                            onTap: _next,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.inputBg,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.chevron_right,
                                  color: AppColors.grey, size: 22),
                            ),
                          ),
                        ),
                        // Step indicator
                        Positioned(
                          bottom: 12,
                          child: Text(
                            '${_index + 1} / ${_syllables.length}',
                            style: TextStyle(
                              color: AppColors.grey.withValues(alpha: 0.5),
                              fontSize: 11,
                              fontFamily: 'Roboto',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Recording button
                  GestureDetector(
                    onTap: _toggleRecord,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: _recording
                            ? const Color(0xFFE53935)
                            : const Color(0xFFE53935).withValues(alpha: 0.7),
                        shape: BoxShape.circle,
                        boxShadow: _recording
                            ? [
                                BoxShadow(
                                  color: const Color(0xFFE53935)
                                      .withValues(alpha: 0.4),
                                  blurRadius: 16,
                                  spreadRadius: 4,
                                )
                              ]
                            : [],
                      ),
                      child: Icon(
                        _recording ? Icons.stop_rounded : Icons.mic_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _recording ? 'Recording… tap to stop' : 'Tap to record',
                    style: TextStyle(
                      color: AppColors.grey.withValues(alpha: 0.6),
                      fontSize: 12,
                      fontFamily: 'Roboto',
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Details card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Details',
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Roboto',
                          ),
                        ),
                        const SizedBox(height: 12),
                        _detailRow('Accuracy:', _accuracy),
                        const SizedBox(height: 8),
                        _detailRow('User Range:', _userRange),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Syllable chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _syllables.asMap().entries.map((e) {
                      final isActive = e.key == _index;
                      return GestureDetector(
                        onTap: () => setState(() => _index = e.key),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppColors.primaryCyan
                                : AppColors.inputBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            e.value,
                            style: TextStyle(
                              color: isActive
                                  ? Colors.black
                                  : AppColors.grey,
                              fontWeight: isActive
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontFamily: 'Roboto',
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
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
                      color: AppColors.primaryCyan.withValues(alpha: 0.4)),
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

  Widget _detailRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.inputBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppColors.grey,
                  fontSize: 13,
                  fontFamily: 'Roboto')),
          const SizedBox(width: 12),
          Text(value,
              style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Roboto')),
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
          _navIcon(Icons.home_outlined,
              onTap: () => Navigator.pop(context)),
          _navIcon(Icons.person_outline),
        ],
      ),
    );
  }

  Widget _navIcon(IconData icon, {VoidCallback? onTap}) => GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon,
              color: AppColors.grey.withValues(alpha: 0.5), size: 26),
        ),
      );
}
