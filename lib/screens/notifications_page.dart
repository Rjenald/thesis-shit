import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../models/class_notification.dart';
import '../services/class_notifications_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _seedSampleNotifications();
  }

  Future<void> _loadNotifications() async {
    final service = ClassNotificationsService();
    await service.initialize();
  }

  Future<void> _seedSampleNotifications() async {
    final service = ClassNotificationsService();
    await service.initialize();
    if (service.notifications.isEmpty) {
      final today = DateTime.now();
      final tuesday = today.subtract(Duration(days: today.weekday - 2));
      await service.addNotification(
        ClassNotification(
          id: '1',
          teacherName: 'Bago, Kian Francis',
          className: 'Grade 11 - Sampaquita',
          message: 'Add to Grade 11 - Sampaquita',
          timestamp: today,
          type: NotificationType.enrollmentRequest,
        ),
      );
      await service.addNotification(
        ClassNotification(
          id: '2',
          teacherName: 'Bago, Kian Francis',
          className: 'Grade 11 - Sampaquita',
          message: 'Added Activity / Solfege',
          timestamp: today,
          type: NotificationType.activityAssignment,
          activityName: 'Activity 1',
          deadline: tuesday,
        ),
      );
      await service.addNotification(
        ClassNotification(
          id: '3',
          teacherName: 'Bago, Kian Francis',
          className: 'Grade 11 - Sampaquita',
          message: 'Added Activity / Practice Exercise',
          timestamp: today,
          type: NotificationType.activityAssignment,
          activityName: 'Practice Exercise 1',
          deadline: tuesday,
        ),
      );
      await service.addNotification(
        ClassNotification(
          id: '4',
          teacherName: 'Bago, Kian Francis',
          className: 'Grade 11 - Sampaquita',
          message: 'Added Activity / Task Performance',
          timestamp: today,
          type: NotificationType.activityAssignment,
          activityName: 'Task Performance 1 - ARG',
          deadline: tuesday,
        ),
      );
      await service.addNotification(
        ClassNotification(
          id: '5',
          teacherName: 'Bago, Kian Francis',
          className: 'Grade 11 - Sampaquita',
          message: 'Added Activity / Task Performance',
          timestamp: today,
          type: NotificationType.activityAssignment,
          activityName: 'Task Performance 1 - ARG',
          deadline: tuesday.add(const Duration(days: 1)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
              decoration: const BoxDecoration(color: Colors.black),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          color: AppColors.white,
                          size: 20,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Notification',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ],
              ),
            ),

            // Notifications List
            Expanded(
              child: Consumer<ClassNotificationsService>(
                builder: (context, notificationService, child) {
                  final notifications = notificationService.notifications;

                  if (notifications.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_off,
                            color: AppColors.grey.withValues(alpha: 0.5),
                            size: 64,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No notifications yet',
                            style: TextStyle(
                              color: AppColors.grey.withValues(alpha: 0.6),
                              fontFamily: 'Roboto',
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: notifications.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.inputBg.withValues(alpha: 0.3),
                    ),
                    itemBuilder: (context, index) => _buildNotificationRow(
                      context,
                      notifications[index],
                      notificationService,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationRow(
    BuildContext context,
    ClassNotification notification,
    ClassNotificationsService service,
  ) {
    final isEnrollment =
        notification.type == NotificationType.enrollmentRequest;
    final isPending = !notification.isAccepted && !notification.isDeclined;

    return Container(
      color: AppColors.bgDark,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Row(
        children: [
          // Person icon
          Icon(Icons.person_outline, color: AppColors.white, size: 28),
          const SizedBox(width: 12),

          // Name
          Expanded(
            flex: 3,
            child: Text(
              notification.teacherName,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                fontFamily: 'Roboto',
              ),
            ),
          ),

          // Action / Activity
          Expanded(
            flex: 4,
            child: Text(
              isEnrollment
                  ? 'Add to ${notification.className}'
                  : 'Added Activity / ${notification.activityName ?? ''}',
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                fontFamily: 'Roboto',
              ),
            ),
          ),

          // Deadline (activity only)
          if (!isEnrollment && notification.deadline != null) ...[
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  const Text(
                    'Deadline:',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Roboto',
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatDeadline(notification.deadline!),
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 13,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Confirm button (enrollment only, when pending)
          if (isEnrollment && isPending) ...[
            TextButton(
              onPressed: () async {
                await service.acceptNotification(notification.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enrollment confirmed!')),
                  );
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryCyan,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Confirm',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Roboto',
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Delete button
          TextButton(
            onPressed: () async {
              await service.removeNotification(notification.id);
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.errorRed,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Delete',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                fontFamily: 'Roboto',
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDeadline(DateTime dt) {
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    final yy = (dt.year % 100).toString().padLeft(2, '0');
    return '$mm.$dd.$yy';
  }
}
