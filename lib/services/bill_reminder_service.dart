import 'dart:async';
import 'package:flutter/foundation.dart';
import '../shared_preferences_stub.dart';
import '../main.dart';
import 'nudge_manager.dart';
import 'notification_service.dart';

/// Service that monitors calendar state for upcoming bills and sends
/// nudge notifications for bills due tomorrow.
class BillReminderService {
  static final BillReminderService _instance = BillReminderService._internal();
  factory BillReminderService() => _instance;
  BillReminderService._internal();

  final NudgeManager _nudgeManager = NudgeManager();
  final NotificationService _notificationService = NotificationService();

  bool _isInitialized = false;
  Timer? _checkTimer;
  DateTime? _lastCheckTime;

  // Cooldown to avoid duplicate notifications (12 hours)
  static const Duration _checkCooldown = Duration(hours: 12);

  /// Initialize the bill reminder service
  Future<void> init() async {
    if (_isInitialized) return;

    await _nudgeManager.init();
    await _loadLastCheckTime();

    _isInitialized = true;
    debugPrint('✅ BillReminderService initialized');

    // Run initial check
    await checkBillsDueTomorrow();

    // Set up periodic check every hour
    _checkTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      checkBillsDueTomorrow();
    });
  }

  /// Load last check time from storage
  Future<void> _loadLastCheckTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timeStr = prefs.getString('bill_reminder_last_check');
    if (timeStr != null) {
      _lastCheckTime = DateTime.parse(timeStr);
    }
  }

  /// Save last check time to storage
  Future<void> _saveLastCheckTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'bill_reminder_last_check', DateTime.now().toIso8601String());
    _lastCheckTime = DateTime.now();
  }

  /// Check if enough time has passed since last check
  bool _canCheck() {
    if (_lastCheckTime == null) return true;
    return DateTime.now().difference(_lastCheckTime!) > _checkCooldown;
  }

  /// Check for bills due tomorrow and send nudge notifications
  Future<void> checkBillsDueTomorrow() async {
    if (!_isInitialized) await init();

    // Respect cooldown to avoid spamming
    if (!_canCheck()) {
      debugPrint(
          '🔄 BillReminderService: Skipping check - within cooldown period');
      return;
    }

    debugPrint('🔍 BillReminderService: Checking for bills due tomorrow...');

    try {
      final debts = await DataService.getDebts();
      final now = DateTime.now();
      final tomorrow = DateTime(now.year, now.month, now.day + 1);

      // Find debts due tomorrow
      final billsDueTomorrow = <Debt>[];

      for (final debt in debts) {
        if (debt.dueDate != null) {
          // Check if the due date day matches tomorrow's day in the current month
          final dueDay = debt.dueDate!.day;
          final dueDateThisMonth = DateTime(now.year, now.month, dueDay);

          // Check if valid date and if it's tomorrow
          if (dueDateThisMonth.month == now.month &&
              dueDateThisMonth.year == now.year &&
              dueDateThisMonth.day == tomorrow.day) {
            billsDueTomorrow.add(debt);
          }
        }
      }

      if (billsDueTomorrow.isEmpty) {
        debugPrint('✅ BillReminderService: No bills due tomorrow');
        return;
      }

      debugPrint(
          '⚠️ BillReminderService: Found ${billsDueTomorrow.length} bill(s) due tomorrow');

      // Send nudge for each bill due tomorrow
      for (final debt in billsDueTomorrow) {
        await _sendBillDueTomorrowNudge(debt);
      }

      // Update last check time
      await _saveLastCheckTime();
    } catch (e) {
      debugPrint('❌ BillReminderService: Error checking bills: $e');
    }
  }

  /// Send a nudge notification for a bill due tomorrow
  Future<void> _sendBillDueTomorrowNudge(Debt debt) async {
    const title = '📅 Payment Due Tomorrow';
    final message =
        '${debt.name} payment of \$${debt.minimumPayment.toStringAsFixed(2)} '
        'is due tomorrow. Don\'t miss it!';

    await _notificationService.showNotification(
      id: 'bill_tomorrow_${debt.id}'.hashCode,
      title: title,
      body: message,
      payload: 'bill_reminder:${debt.id}',
    );

    debugPrint('🔔 BillReminderService: Sent reminder for ${debt.name}');
  }

  /// Force check bills (for testing purposes - ignores cooldown)
  Future<List<Debt>> forceCheckBillsDueTomorrow() async {
    if (!_isInitialized) await init();

    debugPrint(
        '🔍 BillReminderService: Force checking for bills due tomorrow...');

    final debts = await DataService.getDebts();
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);

    final billsDueTomorrow = <Debt>[];

    for (final debt in debts) {
      if (debt.dueDate != null) {
        final dueDay = debt.dueDate!.day;
        final dueDateThisMonth = DateTime(now.year, now.month, dueDay);

        if (dueDateThisMonth.month == now.month &&
            dueDateThisMonth.year == now.year &&
            dueDateThisMonth.day == tomorrow.day) {
          billsDueTomorrow.add(debt);
        }
      }
    }

    // Send nudges for all found bills
    for (final debt in billsDueTomorrow) {
      await _sendBillDueTomorrowNudge(debt);
    }

    return billsDueTomorrow;
  }

  /// Dispose of the service
  void dispose() {
    _checkTimer?.cancel();
    _checkTimer = null;
    debugPrint('🛑 BillReminderService disposed');
  }
}
