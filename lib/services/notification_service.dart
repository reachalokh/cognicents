import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;

/// Service for managing local notifications using flutter_local_notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Initialize the notification service
  /// Must be called before showing any notifications
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Android initialization settings
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _isInitialized = true;
    debugPrint('✅ NotificationService initialized');
  }

  /// Callback when a notification is tapped
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('🔔 Notification tapped: ${response.payload}');
    // Handle notification tap here
    // You can navigate to specific screens based on payload
  }

  /// Request notification permissions (required for iOS)
  Future<bool> requestPermissions() async {
    final iOS = _notificationsPlugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();

    if (iOS != null) {
      final granted = await iOS.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    return true; // Android doesn't need explicit permission for basic notifications
  }

  /// Show a simple notification
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) await initialize();

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'cognicents_channel',
      'CogniCents Notifications',
      channelDescription: 'Notifications from CogniCents app',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );

    debugPrint('🔔 Notification shown: $title');
  }

  /// Show a payment reminder notification
  Future<void> showPaymentReminder({
    required String debtName,
    required double amount,
    required DateTime dueDate,
  }) async {
    final daysUntilDue = dueDate.difference(DateTime.now()).inDays;
    String message;

    if (daysUntilDue <= 0) {
      message =
          'Payment of \$${amount.toStringAsFixed(2)} for $debtName is due today!';
    } else if (daysUntilDue == 1) {
      message =
          'Payment of \$${amount.toStringAsFixed(2)} for $debtName is due tomorrow!';
    } else {
      message =
          'Payment of \$${amount.toStringAsFixed(2)} for $debtName is due in $daysUntilDue days.';
    }

    await showNotification(
      id: debtName.hashCode,
      title: '💰 Payment Reminder',
      body: message,
      payload: 'payment_reminder:$debtName',
    );
  }

  /// Show a milestone achievement notification
  Future<void> showMilestoneNotification({
    required String title,
    required String achievement,
  }) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '🎉 $title',
      body: achievement,
      payload: 'milestone',
    );
  }

  /// Schedule a notification for a future time
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    if (!_isInitialized) await initialize();

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'cognicents_scheduled_channel',
      'CogniCents Scheduled Notifications',
      channelDescription: 'Scheduled notifications from CogniCents app',
      importance: Importance.high,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      _convertToTZDateTime(scheduledDate),
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );

    debugPrint('🔔 Notification scheduled for: $scheduledDate');
  }

  /// Convert DateTime to TZDateTime for scheduling
  /// Note: For production, you should use the timezone package properly
  tz.TZDateTime _convertToTZDateTime(DateTime dateTime) {
    return tz.TZDateTime.from(dateTime, tz.local);
  }

  /// Cancel a specific notification
  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
    debugPrint('🔔 Notification cancelled: $id');
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
    debugPrint('🔔 All notifications cancelled');
  }
}
