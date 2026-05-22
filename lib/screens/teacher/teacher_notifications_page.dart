import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../services/enrollment_service.dart';
import '../../services/submission_service.dart';

class TeacherNotificationsPage extends StatelessWidget {
  const TeacherNotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<EnrollmentService, SubmissionService>(
      builder: (context, enrollment, submissionSvc, _) {
        final recentEnrollments = enrollment.enrolledClasses;
        final recentSubmissions = submissionSvc.submissions;

        final hasAny =
            recentEnrollments.isNotEmpty || recentSubmissions.isNotEmpty;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text(
                'Notifications',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Roboto',
                ),
              ),
              const SizedBox(height: 16),
              if (!hasAny)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.notifications_off_outlined,
                          color: Colors.white.withValues(alpha: 0.2),
                          size: 56,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'No notifications yet',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 15,
                            fontFamily: 'Roboto',
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'You\'ll be notified when students enroll or submit',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3),
                            fontSize: 12,
                            fontFamily: 'Roboto',
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView(
                    children: [
                      if (recentSubmissions.isNotEmpty) ...[
                        _sectionLabel('Recent Submissions'),
                        ...recentSubmissions.take(20).map(
                          (s) => _notifTile(
                            icon: Icons.assignment_turned_in,
                            iconColor: Colors.green,
                            title: '${s.studentName} submitted',
                            subtitle:
                                '${s.activityName} • Score: ${s.score.round()}%',
                            time: _timeAgo(s.submittedAt),
                          ),
                        ),
                      ],
                      if (recentEnrollments.isNotEmpty) ...[
                        _sectionLabel('Enrollments'),
                        ...recentEnrollments.map(
                          (className) => _notifTile(
                            icon: Icons.person_add,
                            iconColor: AppColors.primaryCyan,
                            title: 'Student enrolled',
                            subtitle: className,
                            time: '',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 8),
    child: Text(
      text,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.5),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
        fontFamily: 'Roboto',
      ),
    ),
  );

  Widget _notifTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String time,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Roboto',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                    fontFamily: 'Roboto',
                  ),
                ),
              ],
            ),
          ),
          if (time.isNotEmpty)
            Text(
              time,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 11,
                fontFamily: 'Roboto',
              ),
            ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
