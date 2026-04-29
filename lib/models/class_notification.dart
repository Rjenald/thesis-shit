enum NotificationType {
  enrollmentRequest,
  activityAssignment,
}

class ClassNotification {
  final String id;
  final String teacherName;
  final String className;
  final String message;
  final DateTime timestamp;
  final bool isAccepted;
  final bool isDeclined;
  final NotificationType type;
  final String? activityName;
  final DateTime? deadline;

  ClassNotification({
    required this.id,
    required this.teacherName,
    required this.className,
    required this.message,
    required this.timestamp,
    this.isAccepted = false,
    this.isDeclined = false,
    this.type = NotificationType.enrollmentRequest,
    this.activityName,
    this.deadline,
  });

  ClassNotification copyWith({
    String? id,
    String? teacherName,
    String? className,
    String? message,
    DateTime? timestamp,
    bool? isAccepted,
    bool? isDeclined,
    NotificationType? type,
    String? activityName,
    DateTime? deadline,
  }) {
    return ClassNotification(
      id: id ?? this.id,
      teacherName: teacherName ?? this.teacherName,
      className: className ?? this.className,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      isAccepted: isAccepted ?? this.isAccepted,
      isDeclined: isDeclined ?? this.isDeclined,
      type: type ?? this.type,
      activityName: activityName ?? this.activityName,
      deadline: deadline ?? this.deadline,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'teacherName': teacherName,
      'className': className,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'isAccepted': isAccepted,
      'isDeclined': isDeclined,
      'type': type.name,
      'activityName': activityName,
      'deadline': deadline?.toIso8601String(),
    };
  }

  factory ClassNotification.fromJson(Map<String, dynamic> json) {
    return ClassNotification(
      id: json['id'] as String,
      teacherName: json['teacherName'] as String,
      className: json['className'] as String,
      message: json['message'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isAccepted: json['isAccepted'] as bool? ?? false,
      isDeclined: json['isDeclined'] as bool? ?? false,
      type: NotificationType.values.firstWhere(
        (e) => e.name == (json['type'] as String? ?? 'enrollmentRequest'),
        orElse: () => NotificationType.enrollmentRequest,
      ),
      activityName: json['activityName'] as String?,
      deadline: json['deadline'] != null
          ? DateTime.parse(json['deadline'] as String)
          : null,
    );
  }
}
