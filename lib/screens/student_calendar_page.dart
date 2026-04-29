import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../models/class_notification.dart';
import '../services/class_notifications_service.dart';
import '../widgets/bottom_nav_bar.dart';
import 'full_calendar_page.dart';

class StudentCalendarPage extends StatefulWidget {
  const StudentCalendarPage({super.key});

  @override
  State<StudentCalendarPage> createState() => _StudentCalendarPageState();
}

class _StudentCalendarPageState extends State<StudentCalendarPage> {
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool _calendarVisible = true;
  final List<_TodoItem> _todos = [_TodoItem(id: '1', text: 'comsciii!!!!!!!')];

  void _prevMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
  }

  Set<int> _dueDaysInMonth(ClassNotificationsService service) {
    return service.notifications
        .where(
          (n) =>
              n.type == NotificationType.activityAssignment &&
              n.deadline != null,
        )
        .where(
          (n) =>
              n.deadline!.year == _currentMonth.year &&
              n.deadline!.month == _currentMonth.month,
        )
        .map((n) => n.deadline!.day)
        .toSet();
  }

  int _totalAssignmentsDue(ClassNotificationsService service) {
    final now = DateTime.now();
    return service.notifications
        .where(
          (n) =>
              n.type == NotificationType.activityAssignment &&
              n.deadline != null &&
              n.deadline!.isAfter(now.subtract(const Duration(days: 1))),
        )
        .length;
  }

  void _addTodo() {
    showDialog(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          backgroundColor: AppColors.cardBg,
          title: const Text('Add To-do', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'What do you need to do?',
              hintStyle: TextStyle(
                color: AppColors.grey.withValues(alpha: 0.6),
              ),
              filled: true,
              fillColor: AppColors.inputBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  setState(() {
                    _todos.add(
                      _TodoItem(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        text: text,
                      ),
                    );
                  });
                }
                Navigator.pop(ctx);
              },
              child: const Text(
                'Add',
                style: TextStyle(color: AppColors.primaryCyan),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Consumer<ClassNotificationsService>(
          builder: (context, service, _) {
            final dueDays = _dueDaysInMonth(service);
            final assignmentsDue = _totalAssignmentsDue(service);
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Calendar card
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        // Header
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                color: AppColors.primaryCyan,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Calendar',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontFamily: 'Roboto',
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (_calendarVisible) ...[
                          // Month nav
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.chevron_left,
                                    color: Colors.white,
                                  ),
                                  onPressed: _prevMonth,
                                ),
                                Text(
                                  _formatMonthYear(_currentMonth),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontFamily: 'Roboto',
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.chevron_right,
                                    color: Colors.white,
                                  ),
                                  onPressed: _nextMonth,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Weekday headers
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children:
                                  const ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                                      .map(
                                        (d) => Expanded(
                                          child: Center(
                                            child: Text(
                                              d,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                fontFamily: 'Roboto',
                                              ),
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Days grid
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: _buildMonthGrid(dueDays),
                          ),
                          const SizedBox(height: 8),
                        ],

                        // Footer links
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const FullCalendarPage(),
                                    ),
                                  );
                                },
                                child: const Text(
                                  'full calendar',
                                  style: TextStyle(
                                    color: AppColors.primaryCyan,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Roboto',
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => setState(
                                  () => _calendarVisible = !_calendarVisible,
                                ),
                                child: Text(
                                  _calendarVisible ? 'hide' : 'show',
                                  style: const TextStyle(
                                    color: AppColors.primaryCyan,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Roboto',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // To-do card
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                color: AppColors.primaryCyan,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'To-do',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontFamily: 'Roboto',
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: _addTodo,
                                icon: const Icon(
                                  Icons.add,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Icon(
                                Icons.assignment_outlined,
                                color: AppColors.primaryCyan,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const FullCalendarPage(),
                                    ),
                                  );
                                },
                                child: Text(
                                  '$assignmentsDue assignments due',
                                  style: const TextStyle(
                                    color: AppColors.primaryCyan,
                                    fontFamily: 'Roboto',
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._todos.map(
                          (todo) => Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.push_pin,
                                  color: AppColors.grey.withValues(alpha: 0.7),
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    todo.text,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'Roboto',
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.delete_outline,
                                    color: AppColors.grey.withValues(
                                      alpha: 0.7,
                                    ),
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    setState(() => _todos.remove(todo));
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: const BottomNavBar(
        currentIndex: 1,
        onTap: _noopCalendar,
        isStudent: true,
      ),
    );
  }

  Widget _buildMonthGrid(Set<int> dueDays) {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final daysInMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month + 1,
      0,
    ).day;
    final daysInPrevMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month,
      0,
    ).day;
    final firstWeekday = firstDay.weekday % 7; // 0=Sun

    final today = DateTime.now();
    final isCurrentMonth =
        today.year == _currentMonth.year && today.month == _currentMonth.month;

    final cells = <Widget>[];

    // Leading days from previous month
    for (var i = firstWeekday - 1; i >= 0; i--) {
      final day = daysInPrevMonth - i;
      cells.add(_dayCell(day, isOtherMonth: true));
    }

    // Current month days
    for (var d = 1; d <= daysInMonth; d++) {
      final isToday = isCurrentMonth && d == today.day;
      final hasDue = dueDays.contains(d);
      cells.add(_dayCell(d, isToday: isToday, hasDue: hasDue));
    }

    // Trailing days
    while (cells.length % 7 != 0) {
      cells.add(
        _dayCell(
          cells.length - daysInMonth - firstWeekday + 1,
          isOtherMonth: true,
        ),
      );
    }

    final rows = <Widget>[];
    for (var i = 0; i < cells.length; i += 7) {
      rows.add(
        Row(
          children: cells
              .sublist(i, i + 7)
              .map((c) => Expanded(child: c))
              .toList(),
        ),
      );
    }

    return Column(children: rows);
  }

  Widget _dayCell(
    int day, {
    bool isOtherMonth = false,
    bool isToday = false,
    bool hasDue = false,
  }) {
    Color textColor;
    if (isOtherMonth) {
      textColor = AppColors.grey.withValues(alpha: 0.3);
    } else if (isToday) {
      textColor = Colors.white;
    } else {
      textColor = Colors.white;
    }

    return AspectRatio(
      aspectRatio: 1,
      child: Center(
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isToday ? AppColors.primaryCyan : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$day',
              style: TextStyle(
                color: isToday ? Colors.black : textColor,
                fontWeight: hasDue || isToday
                    ? FontWeight.bold
                    : FontWeight.normal,
                fontSize: 13,
                fontFamily: 'Roboto',
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatMonthYear(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }
}

void _noopCalendar(int _) {}

class _TodoItem {
  final String id;
  final String text;
  _TodoItem({required this.id, required this.text});
}
