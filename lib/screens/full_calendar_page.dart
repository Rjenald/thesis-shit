import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../models/class_notification.dart';
import '../services/class_notifications_service.dart';

enum _CalendarView { week, month, agenda }

class FullCalendarPage extends StatefulWidget {
  const FullCalendarPage({super.key});

  @override
  State<FullCalendarPage> createState() => _FullCalendarPageState();
}

class _FullCalendarPageState extends State<FullCalendarPage> {
  _CalendarView _view = _CalendarView.week;
  late DateTime _anchor;

  @override
  void initState() {
    super.initState();
    _anchor = DateTime.now();
  }

  void _today() {
    setState(() => _anchor = DateTime.now());
  }

  void _prev() {
    setState(() {
      switch (_view) {
        case _CalendarView.week:
          _anchor = _anchor.subtract(const Duration(days: 7));
          break;
        case _CalendarView.month:
          _anchor = DateTime(_anchor.year, _anchor.month - 1, _anchor.day);
          break;
        case _CalendarView.agenda:
          _anchor = _anchor.subtract(const Duration(days: 7));
          break;
      }
    });
  }

  void _next() {
    setState(() {
      switch (_view) {
        case _CalendarView.week:
          _anchor = _anchor.add(const Duration(days: 7));
          break;
        case _CalendarView.month:
          _anchor = DateTime(_anchor.year, _anchor.month + 1, _anchor.day);
          break;
        case _CalendarView.agenda:
          _anchor = _anchor.add(const Duration(days: 7));
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildToolbar(),
            Expanded(
              child: Consumer<ClassNotificationsService>(
                builder: (context, service, _) {
                  switch (_view) {
                    case _CalendarView.week:
                      return _WeekView(anchor: _anchor, service: service);
                    case _CalendarView.month:
                      return _MonthView(anchor: _anchor, service: service);
                    case _CalendarView.agenda:
                      return _AgendaView(service: service);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgDark,
        border: Border(
          bottom: BorderSide(color: AppColors.inputBg.withValues(alpha: 0.4)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          OutlinedButton(
            onPressed: _today,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: AppColors.grey.withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text('Today'),
          ),
          const SizedBox(width: 8),
          _circleIconButton(Icons.chevron_left, _prev),
          const SizedBox(width: 4),
          _circleIconButton(Icons.chevron_right, _next),
          const Spacer(),
          _viewButton('Week', _CalendarView.week, Icons.calendar_view_week),
          const SizedBox(width: 6),
          _viewButton('Month', _CalendarView.month, Icons.calendar_month),
          const SizedBox(width: 6),
          _viewButton('Agenda', _CalendarView.agenda, Icons.list_alt),
        ],
      ),
    );
  }

  Widget _circleIconButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.grey.withValues(alpha: 0.4)),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _viewButton(String label, _CalendarView view, IconData icon) {
    final selected = _view == view;
    return OutlinedButton.icon(
      onPressed: () => setState(() => _view = view),
      icon: Icon(
        icon,
        size: 16,
        color: selected ? AppColors.primaryCyan : Colors.white,
      ),
      label: Text(
        label,
        style: TextStyle(
          color: selected ? AppColors.primaryCyan : Colors.white,
        ),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(
          color: selected
              ? AppColors.primaryCyan
              : AppColors.grey.withValues(alpha: 0.4),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Week view
// ─────────────────────────────────────────────────────────────────
class _WeekView extends StatelessWidget {
  final DateTime anchor;
  final ClassNotificationsService service;

  const _WeekView({required this.anchor, required this.service});

  List<DateTime> get _weekDays {
    final start = anchor.subtract(Duration(days: anchor.weekday % 7));
    return List.generate(
      7,
      (i) => DateTime(start.year, start.month, start.day + i),
    );
  }

  List<ClassNotification> _eventsForDay(DateTime day) {
    return service.notifications
        .where(
          (n) =>
              n.type == NotificationType.activityAssignment &&
              n.deadline != null &&
              n.deadline!.year == day.year &&
              n.deadline!.month == day.month &&
              n.deadline!.day == day.day,
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final days = _weekDays;
    final today = DateTime.now();

    return SingleChildScrollView(
      child: Column(
        children: [
          // Day headers
          Row(
            children: days.map((d) {
              final isToday =
                  d.year == today.year &&
                  d.month == today.month &&
                  d.day == today.day;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    children: [
                      Text(
                        _shortDay(d.weekday),
                        style: TextStyle(
                          color: AppColors.grey.withValues(alpha: 0.8),
                          fontSize: 13,
                          fontFamily: 'Roboto',
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isToday
                              ? AppColors.primaryCyan
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${d.day}',
                            style: TextStyle(
                              color: isToday ? Colors.black : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              fontFamily: 'Roboto',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          Divider(color: AppColors.inputBg.withValues(alpha: 0.5), height: 1),
          // All-day events row
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 60,
                  alignment: Alignment.topCenter,
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'All day',
                    style: TextStyle(
                      color: AppColors.grey.withValues(alpha: 0.7),
                      fontSize: 12,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ),
                ...days.map((d) {
                  final events = _eventsForDay(d);
                  return Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: AppColors.inputBg.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: events.map((e) => _eventChip(e)).toList(),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          Divider(color: AppColors.inputBg.withValues(alpha: 0.5), height: 1),
          // Hour grid
          ...List.generate(12, (i) {
            final hour = i + 12; // 12pm to 11pm
            return _hourRow(hour, days);
          }),
        ],
      ),
    );
  }

  Widget _eventChip(ClassNotification e) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(4),
        border: Border(
          left: BorderSide(color: const Color(0xFF8E24AA), width: 3),
        ),
      ),
      child: Text(
        'Due: ${e.deadline!.day.toString().padLeft(2, '0')} '
        '${e.activityName ?? 'Activity'}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          fontFamily: 'Roboto',
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _hourRow(int hour, List<DateTime> days) {
    return SizedBox(
      height: 50,
      child: Row(
        children: [
          Container(
            width: 60,
            alignment: Alignment.topCenter,
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _hourLabel(hour),
              style: TextStyle(
                color: AppColors.grey.withValues(alpha: 0.7),
                fontSize: 11,
                fontFamily: 'Roboto',
              ),
            ),
          ),
          ...days.map(
            (d) => Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: AppColors.inputBg.withValues(alpha: 0.3),
                    ),
                    bottom: BorderSide(
                      color: AppColors.inputBg.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _shortDay(int weekday) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[weekday - 1];
  }

  String _hourLabel(int hour) {
    if (hour == 0) return '12am';
    if (hour < 12) return '${hour}am';
    if (hour == 12) return '12pm';
    return '${hour - 12}pm';
  }
}

// ─────────────────────────────────────────────────────────────────
// Month view
// ─────────────────────────────────────────────────────────────────
class _MonthView extends StatelessWidget {
  final DateTime anchor;
  final ClassNotificationsService service;

  const _MonthView({required this.anchor, required this.service});

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(anchor.year, anchor.month, 1);
    final daysInMonth = DateTime(anchor.year, anchor.month + 1, 0).day;
    final firstWeekday = firstDay.weekday % 7;
    final today = DateTime.now();

    final cells = <Widget>[];
    for (var i = 0; i < firstWeekday; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var d = 1; d <= daysInMonth; d++) {
      final date = DateTime(anchor.year, anchor.month, d);
      final isToday =
          date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;
      final dayEvents = service.notifications.where(
        (n) =>
            n.type == NotificationType.activityAssignment &&
            n.deadline != null &&
            n.deadline!.year == date.year &&
            n.deadline!.month == date.month &&
            n.deadline!.day == date.day,
      );
      cells.add(_buildCell(d, isToday, dayEvents.length));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Text(
            _formatMonthYear(anchor),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Roboto',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                .map(
                  (d) => Expanded(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          d,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 7,
            childAspectRatio: 1,
            children: cells,
          ),
        ],
      ),
    );
  }

  Widget _buildCell(int day, bool isToday, int eventCount) {
    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isToday
            ? AppColors.primaryCyan.withValues(alpha: 0.2)
            : AppColors.cardBg,
        borderRadius: BorderRadius.circular(6),
        border: isToday
            ? Border.all(color: AppColors.primaryCyan, width: 2)
            : null,
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(4),
            child: Text(
              '$day',
              style: TextStyle(
                color: isToday ? AppColors.primaryCyan : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          if (eventCount > 0)
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF8E24AA),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$eventCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatMonthYear(DateTime dt) {
    const months = [
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
    return '${months[dt.month - 1]} ${dt.year}';
  }
}

// ─────────────────────────────────────────────────────────────────
// Agenda view
// ─────────────────────────────────────────────────────────────────
class _AgendaView extends StatelessWidget {
  final ClassNotificationsService service;

  const _AgendaView({required this.service});

  @override
  Widget build(BuildContext context) {
    final upcoming =
        service.notifications
            .where(
              (n) =>
                  n.type == NotificationType.activityAssignment &&
                  n.deadline != null,
            )
            .toList()
          ..sort((a, b) => a.deadline!.compareTo(b.deadline!));

    if (upcoming.isEmpty) {
      return Center(
        child: Text(
          'No upcoming assignments',
          style: TextStyle(
            color: AppColors.grey.withValues(alpha: 0.7),
            fontSize: 14,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: upcoming.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final n = upcoming[i];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(8),
            border: const Border(
              left: BorderSide(color: Color(0xFF8E24AA), width: 4),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Due: ${n.activityName ?? 'Activity'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${n.className} · ${_formatDate(n.deadline!)}',
                      style: TextStyle(
                        color: AppColors.grey.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime dt) {
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
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}
