import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/class_notification.dart';
import 'session_storage_service.dart';

class ClassNotificationsService with ChangeNotifier {
  static final ClassNotificationsService _instance =
      ClassNotificationsService._internal();
  static const _storageKey = 'class_notifications';

  List<ClassNotification> _notifications = [];

  ClassNotificationsService._internal();

  factory ClassNotificationsService() {
    return _instance;
  }

  List<ClassNotification> get notifications => _notifications;

  List<ClassNotification> get pendingNotifications =>
      _notifications.where((n) => !n.isAccepted && !n.isDeclined).toList();

  Future<void> initialize() async {
    await _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final stored =
        await SessionStorageService.loadFromStorage(_storageKey);
    if (stored != null) {
      try {
        final List<dynamic> decoded = jsonDecode(stored);
        _notifications = decoded
            .map((item) =>
                ClassNotification.fromJson(item as Map<String, dynamic>))
            .toList();
        notifyListeners();
      } catch (e) {
        if (kDebugMode) print('Error loading notifications: $e');
      }
    }
  }

  Future<void> _saveNotifications() async {
    final json = _notifications.map((n) => n.toJson()).toList();
    await SessionStorageService.saveToStorage(
        _storageKey, jsonEncode(json));
    notifyListeners();
  }

  Future<void> addNotification(ClassNotification notification) async {
    _notifications.add(notification);
    await _saveNotifications();
  }

  Future<void> acceptNotification(String notificationId) async {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(
        isAccepted: true,
        isDeclined: false,
      );
      await _saveNotifications();
    }
  }

  Future<void> declineNotification(String notificationId) async {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(
        isAccepted: false,
        isDeclined: true,
      );
      await _saveNotifications();
    }
  }

  Future<void> removeNotification(String notificationId) async {
    _notifications.removeWhere((n) => n.id == notificationId);
    await _saveNotifications();
  }

  int get unreadCount => pendingNotifications.length;
}
