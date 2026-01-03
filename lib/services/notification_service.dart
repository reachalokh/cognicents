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

  /// Schedule a test notification to fire in X seconds (for testing background notifications)
  Future<void> scheduleTestNotification({
    required int secondsFromNow,
    String? customMessage,
  }) async {
    final scheduledTime = DateTime.now().add(Duration(seconds: secondsFromNow));
    await scheduleNotification(
      id: 99999, // Fixed ID for test notifications
      title: '🧪 Test Notification',
      body: customMessage ??
          'This notification was scheduled $secondsFromNow seconds ago. The app can be closed and this still works!',
      scheduledDate: scheduledTime,
      payload: 'test_scheduled',
    );
    debugPrint('🧪 Test notification scheduled for $scheduledTime');
  }

  /// Schedule a daily reminder at a specific time
  /// This will fire every day even when the app is closed
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    required String title,
    required String body,
    int notificationId = 1000,
  }) async {
    if (!_isInitialized) await initialize();

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'cognicents_daily_channel',
      'CogniCents Daily Reminders',
      channelDescription: 'Daily reminder notifications',
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

    // Calculate next occurrence of this time
    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _notificationsPlugin.zonedSchedule(
      notificationId,
      title,
      body,
      _convertToTZDateTime(scheduledDate),
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents:
          DateTimeComponents.time, // This makes it repeat daily!
      payload: 'daily_reminder',
    );

    debugPrint('🔔 Daily reminder scheduled for $hour:$minute');
  }

  /// Schedule the default daily motivational reminder
  Future<void> scheduleDefaultDailyReminder(
      {int hour = 9, int minute = 0}) async {
    await scheduleDailyReminder(
      hour: hour,
      minute: minute,
      title: '💪 Daily Check-in',
      body:
          'Open CogniCents to keep your streak going and stay on track with your financial goals!',
      notificationId: 1001,
    );
  }

  /// Schedule a streak protection reminder (fires in evening if not logged in)
  Future<void> scheduleStreakProtectionReminder() async {
    await scheduleDailyReminder(
      hour: 20, // 8 PM
      minute: 0,
      title: '🔥 Protect Your Streak!',
      body: 'Don\'t forget to check in today to keep your streak alive!',
      notificationId: 1002,
    );
  }

  /// Get list of pending notifications (for debugging)
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notificationsPlugin.pendingNotificationRequests();
  }

  /// Cancel daily reminders
  Future<void> cancelDailyReminders() async {
    await cancelNotification(1001);
    await cancelNotification(1002);
    debugPrint('🔔 Daily reminders cancelled');
  }
}
