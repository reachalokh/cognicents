import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../shared_preferences_stub.dart';
import '../main.dart';
import '../gemini_config.dart';
import 'notification_service.dart';

/// Types of nudges in the system
enum NudgeType {
  timeBased, // Triggered at specific times (e.g., weekly summary)
  behaviorBased, // Triggered by user behavior patterns
}

/// Represents a nudge configuration
class NudgeConfig {
  final String id;
  final String name;
  final NudgeType type;
  final Duration? cooldown; // Minimum time between showing this nudge again

  NudgeConfig({
    required this.id,
    required this.name,
    required this.type,
    this.cooldown,
  });
}

/// Dynamic nudge with real-time data
class DynamicNudge {
  final String id;
  final String title;
  final String message;
  final DateTime generatedAt;

  DynamicNudge({
    required this.id,
    required this.title,
    required this.message,
    DateTime? generatedAt,
  }) : generatedAt = generatedAt ?? DateTime.now();
}

/// NudgeManager - Manages dynamic, personalized nudges
class NudgeManager {
  static final NudgeManager _instance = NudgeManager._internal();
  factory NudgeManager() => _instance;
  NudgeManager._internal();

  final NotificationService _notificationService = NotificationService();
  final Map<String, DateTime> _lastShownTimes = {};
  bool _isInitialized = false;

  // Nudge configurations
  final List<NudgeConfig> _nudgeConfigs = [
    NudgeConfig(
      id: 'inactive_payment',
      name: 'Inactive Payment Reminder',
      type: NudgeType.behaviorBased,
      cooldown: const Duration(days: 1),
    ),
    NudgeConfig(
      id: 'streak_celebration',
      name: 'Streak Celebration',
      type: NudgeType.behaviorBased,
      cooldown: const Duration(days: 7),
    ),
    NudgeConfig(
      id: 'debt_progress',
      name: 'Debt Progress Update',
      type: NudgeType.behaviorBased,
      cooldown: const Duration(days: 3),
    ),
    NudgeConfig(
      id: 'upcoming_payment',
      name: 'Upcoming Payment Alert',
      type: NudgeType.timeBased,
      cooldown: const Duration(hours: 12),
    ),
    NudgeConfig(
      id: 'weekly_summary',
      name: 'Weekly Summary',
      type: NudgeType.timeBased,
      cooldown: const Duration(days: 7),
    ),
    NudgeConfig(
      id: 'motivational',
      name: 'Motivational Nudge',
      type: NudgeType.behaviorBased,
      cooldown: const Duration(days: 2),
    ),
  ];

  /// Initialize the nudge manager
  Future<void> init() async {
    if (_isInitialized) return;

    await _notificationService.initialize();
    await _loadLastShownTimes();

    _isInitialized = true;
    debugPrint(
        '✅ NudgeManager initialized with ${_nudgeConfigs.length} nudge types');
  }

  /// Load last shown times from storage
  Future<void> _loadLastShownTimes() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('nudge_last_shown');
    if (jsonStr != null) {
      final Map<String, dynamic> data = jsonDecode(jsonStr);
      for (var entry in data.entries) {
        _lastShownTimes[entry.key] = DateTime.parse(entry.value);
      }
    }
  }

  /// Save last shown times to storage
  Future<void> _saveLastShownTimes() async {
    final prefs = await SharedPreferences.getInstance();
    final data =
        _lastShownTimes.map((k, v) => MapEntry(k, v.toIso8601String()));
    await prefs.setString('nudge_last_shown', jsonEncode(data));
  }

  /// Check if a nudge can be shown (respects cooldown)
  bool _canShowNudge(String nudgeId) {
    final config = _nudgeConfigs.firstWhere(
      (c) => c.id == nudgeId,
      orElse: () =>
          NudgeConfig(id: nudgeId, name: '', type: NudgeType.behaviorBased),
    );

    final lastShown = _lastShownTimes[nudgeId];
    if (lastShown == null) return true;

    if (config.cooldown == null) return true;

    return DateTime.now().difference(lastShown) > config.cooldown!;
  }

  /// Mark a nudge as shown
  Future<void> _markAsShown(String nudgeId) async {
    _lastShownTimes[nudgeId] = DateTime.now();
    await _saveLastShownTimes();
  }

  /// Evaluate all nudges and trigger eligible ones
  Future<void> evaluateNudges() async {
    if (!_isInitialized) await init();

    debugPrint('🔍 Evaluating nudges...');

    // Check behavior-based nudges
    await _checkInactivePayment();
    await _checkStreakCelebration();
    await _checkDebtProgress();
    await _checkUpcomingPayment();

    // Check time-based nudges
    await _checkWeeklySummary();
  }

  // ============================================
  // BEHAVIOR-BASED NUDGE GENERATORS
  // ============================================

  /// Check if user hasn't made a payment recently
  Future<void> _checkInactivePayment() async {
    if (!_canShowNudge('inactive_payment')) return;

    final achievements = await DataService.getAchievements();
    final debts = await DataService.getDebts();

    if (debts.isEmpty) return;

    // Check if last payment was more than 7 days ago
    final lastPayment = achievements.lastPaymentDate;
    if (lastPayment == null) return;

    final daysSincePayment = DateTime.now().difference(lastPayment).inDays;
    if (daysSincePayment < 7) return;

    // Find upcoming debt
    final upcomingDebt = debts.firstWhere(
      (d) => d.dueDate != null && d.dueDate!.isAfter(DateTime.now()),
      orElse: () => debts.first,
    );

    final nudge = await _generateDynamicNudge(
      nudgeId: 'inactive_payment',
      context: '''
User hasn't made a payment in $daysSincePayment days.
Upcoming debt: ${upcomingDebt.name}
Amount due: \$${upcomingDebt.minimumPayment}
Due date: ${upcomingDebt.dueDate?.toString() ?? 'Not set'}
Current streak: ${achievements.currentPaymentStreak} days
''',
    );

    await _showNudge(nudge);
  }

  /// Celebrate payment streaks
  Future<void> _checkStreakCelebration() async {
    if (!_canShowNudge('streak_celebration')) return;

    final achievements = await DataService.getAchievements();
    final streak = achievements.currentPaymentStreak;

    // Only celebrate at milestones: 7, 14, 21, 30, 60, 90, etc.
    final milestones = [7, 14, 21, 30, 60, 90, 180, 365];
    if (!milestones.contains(streak)) return;

    final debts = await DataService.getDebts();
    final totalPaid = achievements.totalAmountPaid;

    final nudge = await _generateDynamicNudge(
      nudgeId: 'streak_celebration',
      context: '''
User hit a $streak-day payment streak milestone!
Total amount paid: \$${totalPaid.toStringAsFixed(0)}
Number of debts: ${debts.length}
''',
    );

    await _showNudge(nudge);
  }

  /// Progress update on debt payoff
  Future<void> _checkDebtProgress() async {
    if (!_canShowNudge('debt_progress')) return;

    final debts = await DataService.getDebts();
    if (debts.isEmpty) return;

    final achievements = await DataService.getAchievements();
    final totalDebt = debts.fold(0.0, (sum, d) => sum + d.currentBalance);
    final totalPaid = achievements.totalAmountPaid;

    if (totalPaid == 0) return;

    final progressPercent = (totalPaid / (totalDebt + totalPaid)) * 100;

    // Only show if significant progress (>10%)
    if (progressPercent < 10) return;

    // Find the debt with most progress
    final debtWithMostProgress = debts.reduce((a, b) {
      final aProgress = a.totalPaid / (a.currentBalance + a.totalPaid);
      final bProgress = b.totalPaid / (b.currentBalance + b.totalPaid);
      return aProgress > bProgress ? a : b;
    });

    final debtProgress = (debtWithMostProgress.totalPaid /
            (debtWithMostProgress.currentBalance +
                debtWithMostProgress.totalPaid)) *
        100;

    final nudge = await _generateDynamicNudge(
      nudgeId: 'debt_progress',
      context: '''
Debt payoff progress update:
Total progress: ${progressPercent.toStringAsFixed(1)}%
Total paid: \$${totalPaid.toStringAsFixed(0)}
Remaining: \$${totalDebt.toStringAsFixed(0)}
Best performing debt: ${debtWithMostProgress.name} at ${debtProgress.toStringAsFixed(1)}% paid off
''',
    );

    await _showNudge(nudge);
  }

  /// Alert for upcoming payments
  Future<void> _checkUpcomingPayment() async {
    if (!_canShowNudge('upcoming_payment')) return;

    final debts = await DataService.getDebts();
    final now = DateTime.now();

    // Find debts due within 3 days
    final upcomingDebts = debts.where((d) {
      if (d.dueDate == null) return false;
      final daysUntil = d.dueDate!.difference(now).inDays;
      return daysUntil >= 0 && daysUntil <= 3;
    }).toList();

    if (upcomingDebts.isEmpty) return;

    final debt = upcomingDebts.first;
    final daysUntil = debt.dueDate!.difference(now).inDays;

    final nudge = await _generateDynamicNudge(
      nudgeId: 'upcoming_payment',
      context: '''
URGENT: Payment due soon!
Debt: ${debt.name}
Amount: \$${debt.minimumPayment}
Due in: $daysUntil days
Current balance: \$${debt.currentBalance}
''',
    );

    await _showNudge(nudge);
  }

  /// Weekly summary nudge
  Future<void> _checkWeeklySummary() async {
    if (!_canShowNudge('weekly_summary')) return;

    // Only show on Sundays
    if (DateTime.now().weekday != DateTime.sunday) return;

    final achievements = await DataService.getAchievements();
    final debts = await DataService.getDebts();
    final totalDebt = debts.fold(0.0, (sum, d) => sum + d.currentBalance);
    final totalPaid = achievements.totalAmountPaid;

    final nudge = await _generateDynamicNudge(
      nudgeId: 'weekly_summary',
      context: '''
Weekly summary:
Current streak: ${achievements.currentPaymentStreak} days
Total paid this month: \$${totalPaid.toStringAsFixed(0)}
Remaining debt: \$${totalDebt.toStringAsFixed(0)}
Number of debts: ${debts.length}
''',
    );

    await _showNudge(nudge);
  }

  // ============================================
  // AI-POWERED MESSAGE GENERATION
  // ============================================

  /// Generate dynamic nudge message using Gemini AI
  Future<DynamicNudge> _generateDynamicNudge({
    required String nudgeId,
    required String context,
  }) async {
    final config = _nudgeConfigs.firstWhere((c) => c.id == nudgeId);

    // Try AI generation first
    if (kGeminiApiKey.isNotEmpty) {
      try {
        final aiMessage = await _generateAIMessage(config.name, context);
        if (aiMessage != null) {
          return DynamicNudge(
            id: nudgeId,
            title: _extractTitle(aiMessage),
            message: _extractBody(aiMessage),
          );
        }
      } catch (e) {
        debugPrint('⚠️ AI generation failed: $e');
      }
    }

    // Fallback to template-based generation
    return _generateFallbackNudge(nudgeId, context);
  }

  /// Generate message using Gemini AI
  Future<String?> _generateAIMessage(String nudgeType, String context) async {
    final prompt = '''
You are a friendly financial wellness assistant for CogniCents app.
Generate a SHORT, encouraging push notification for: $nudgeType

USER CONTEXT:
$context

RULES:
1. Max 2 sentences
2. Be warm and motivating
3. Include specific numbers from the context
4. Use 1-2 emojis
5. Format: "TITLE: [title]\\nBODY: [body]"
''';

    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$kGeminiApiKey',
      );

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': prompt}
                  ]
                }
              ],
              'generationConfig': {
                'maxOutputTokens': 100,
                'temperature': 0.7,
              },
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['candidates']?[0]?['content']?['parts']?[0]?['text'];
      }
    } catch (e) {
      debugPrint('AI request failed: $e');
    }

    return null;
  }

  String _extractTitle(String aiResponse) {
    final match = RegExp(r'TITLE:\s*(.+?)(?:\n|$)').firstMatch(aiResponse);
    return match?.group(1)?.trim() ?? '💰 CogniCents';
  }

  String _extractBody(String aiResponse) {
    final match = RegExp(r'BODY:\s*(.+)$', dotAll: true).firstMatch(aiResponse);
    return match?.group(1)?.trim() ?? aiResponse;
  }

  /// Fallback template-based message generation
  DynamicNudge _generateFallbackNudge(String nudgeId, String context) {
    final random = Random();

    switch (nudgeId) {
      case 'inactive_payment':
        final templates = [
          '⏰ Time to check in on your debt progress!',
          '💪 Your streak is waiting for you!',
          '🎯 A small payment today keeps debt away!',
        ];
        return DynamicNudge(
          id: nudgeId,
          title: 'Payment Reminder',
          message: templates[random.nextInt(templates.length)],
        );

      case 'streak_celebration':
        final templates = [
          '🔥 You\'re on fire! Keep that streak going!',
          '🎉 Amazing consistency! You\'re crushing it!',
          '⭐ Streak milestone reached! You\'re unstoppable!',
        ];
        return DynamicNudge(
          id: nudgeId,
          title: 'Streak Milestone!',
          message: templates[random.nextInt(templates.length)],
        );

      case 'debt_progress':
        final templates = [
          '📈 Look at that progress! You\'re doing great!',
          '💰 Every payment counts! Keep it up!',
          '🚀 You\'re getting closer to debt freedom!',
        ];
        return DynamicNudge(
          id: nudgeId,
          title: 'Progress Update',
          message: templates[random.nextInt(templates.length)],
        );

      case 'upcoming_payment':
        return DynamicNudge(
          id: nudgeId,
          title: '⚡ Payment Due Soon',
          message: 'Don\'t forget your upcoming payment!',
        );

      case 'weekly_summary':
        return DynamicNudge(
          id: nudgeId,
          title: '📊 Weekly Summary',
          message: 'Check out how you did this week!',
        );

      default:
        return DynamicNudge(
          id: nudgeId,
          title: '💡 CogniCents Tip',
          message: 'Stay on track with your financial goals!',
        );
    }
  }

  /// Show the nudge as a notification
  Future<void> _showNudge(DynamicNudge nudge) async {
    await _notificationService.showNotification(
      id: nudge.id.hashCode,
      title: nudge.title,
      body: nudge.message,
      payload: 'nudge:${nudge.id}',
    );

    await _markAsShown(nudge.id);
    debugPrint('🔔 Nudge shown: ${nudge.title} - ${nudge.message}');
  }

  // ============================================
  // TEST METHODS (for manual testing)
  // ============================================

  /// Force show a specific nudge type (for testing)
  Future<DynamicNudge> testNudge(String nudgeId) async {
    if (!_isInitialized) await init();

    final context = await _getTestContext(nudgeId);
    final nudge = await _generateDynamicNudge(
      nudgeId: nudgeId,
      context: context,
    );

    await _notificationService.showNotification(
      id: nudge.id.hashCode,
      title: nudge.title,
      body: nudge.message,
      payload: 'nudge_test:${nudge.id}',
    );

    return nudge;
  }

  /// Get test context for a nudge
  Future<String> _getTestContext(String nudgeId) async {
    final debts = await DataService.getDebts();
    final achievements = await DataService.getAchievements();
    final totalDebt = debts.fold(0.0, (sum, d) => sum + d.currentBalance);

    switch (nudgeId) {
      case 'inactive_payment':
        return '''
User hasn't made a payment in 10 days.
Upcoming debt: ${debts.isNotEmpty ? debts.first.name : 'Credit Card'}
Amount due: \$${debts.isNotEmpty ? debts.first.minimumPayment : 50}
Due date: ${DateTime.now().add(const Duration(days: 5))}
Current streak: ${achievements.currentPaymentStreak} days
''';

      case 'streak_celebration':
        return '''
User hit a 7-day payment streak milestone!
Total amount paid: \$${achievements.totalAmountPaid.toStringAsFixed(0)}
Number of debts: ${debts.length}
''';

      case 'debt_progress':
        final progress = achievements.totalAmountPaid > 0
            ? (achievements.totalAmountPaid /
                    (totalDebt + achievements.totalAmountPaid)) *
                100
            : 25.0;
        return '''
Debt payoff progress update:
Total progress: ${progress.toStringAsFixed(1)}%
Total paid: \$${achievements.totalAmountPaid.toStringAsFixed(0)}
Remaining: \$${totalDebt.toStringAsFixed(0)}
Best performing debt: ${debts.isNotEmpty ? debts.first.name : 'Student Loan'} at 35% paid off
''';

      case 'upcoming_payment':
        return '''
URGENT: Payment due soon!
Debt: ${debts.isNotEmpty ? debts.first.name : 'Car Loan'}
Amount: \$${debts.isNotEmpty ? debts.first.minimumPayment : 250}
Due in: 2 days
Current balance: \$${debts.isNotEmpty ? debts.first.currentBalance : 5000}
''';

      case 'weekly_summary':
        return '''
Weekly summary:
Current streak: ${achievements.currentPaymentStreak} days
Total paid this month: \$${achievements.totalAmountPaid.toStringAsFixed(0)}
Remaining debt: \$${totalDebt.toStringAsFixed(0)}
Number of debts: ${debts.length}
''';

      case 'motivational':
        return '''
User needs encouragement!
Days since started: 45
Total saved by paying early: \$120
Current progress: 22%
''';

      default:
        return 'Test context for $nudgeId';
    }
  }

  /// Get all nudge configurations (for test UI)
  List<NudgeConfig> getNudgeConfigs() => List.unmodifiable(_nudgeConfigs);

  /// Reset all nudge cooldowns (for testing)
  Future<void> resetAllCooldowns() async {
    _lastShownTimes.clear();
    await _saveLastShownTimes();
    debugPrint('🔄 All nudge cooldowns reset');
  }
}
