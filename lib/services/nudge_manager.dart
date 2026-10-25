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
  timeBased,
  behaviorBased,
}

/// Nudge categories (limited to 4 per best practices)
enum NudgeCategory {
  timing, // "Payment due in 3 days"
  reinforcement, // "14-day streak! Most stop at 7"
  opportunity, // "Extra $10 erases 4 days interest"
  reEngagement, // "Haven't checked in lately"
}

// ============================================
// SIGNAL LAYER - Behavioral Data Storage
// ============================================

/// Stores lightweight behavioral signals for nudge decisions
class UserSignals {
  final DateTime? lastAppOpen;
  final DateTime? lastPayment;
  final int paymentStreak;
  final int loginStreak;
  final DateTime? nearestDueDate;
  final String? nearestDebtName;
  final double? nearestDebtAmount;
  final int nudgesThisWeek;
  final double totalDebt;
  final double totalPaid;
  final double progressPercent;
  final DateTime? lastNudgeSent;

  UserSignals({
    this.lastAppOpen,
    this.lastPayment,
    this.paymentStreak = 0,
    this.loginStreak = 0,
    this.nearestDueDate,
    this.nearestDebtName,
    this.nearestDebtAmount,
    this.nudgesThisWeek = 0,
    this.totalDebt = 0,
    this.totalPaid = 0,
    this.progressPercent = 0,
    this.lastNudgeSent,
  });

  int get daysSinceAppOpen => lastAppOpen != null
      ? DateTime.now().difference(lastAppOpen!).inDays
      : 999;

  int get daysSincePayment => lastPayment != null
      ? DateTime.now().difference(lastPayment!).inDays
      : 999;

  int get daysUntilDue => nearestDueDate != null
      ? nearestDueDate!.difference(DateTime.now()).inDays
      : 999;

  int get hoursSinceLastNudge => lastNudgeSent != null
      ? DateTime.now().difference(lastNudgeSent!).inHours
      : 999;

  Map<String, dynamic> toJson() => {
        'lastAppOpen': lastAppOpen?.toIso8601String(),
        'lastPayment': lastPayment?.toIso8601String(),
        'paymentStreak': paymentStreak,
        'loginStreak': loginStreak,
        'nearestDueDate': nearestDueDate?.toIso8601String(),
        'nearestDebtName': nearestDebtName,
        'nearestDebtAmount': nearestDebtAmount,
        'nudgesThisWeek': nudgesThisWeek,
        'totalDebt': totalDebt,
        'totalPaid': totalPaid,
        'progressPercent': progressPercent,
        'lastNudgeSent': lastNudgeSent?.toIso8601String(),
      };

  factory UserSignals.fromJson(Map<String, dynamic> json) => UserSignals(
        lastAppOpen: json['lastAppOpen'] != null
            ? DateTime.parse(json['lastAppOpen'])
            : null,
        lastPayment: json['lastPayment'] != null
            ? DateTime.parse(json['lastPayment'])
            : null,
        paymentStreak: json['paymentStreak'] ?? 0,
        loginStreak: json['loginStreak'] ?? 0,
        nearestDueDate: json['nearestDueDate'] != null
            ? DateTime.parse(json['nearestDueDate'])
            : null,
        nearestDebtName: json['nearestDebtName'],
        nearestDebtAmount: (json['nearestDebtAmount'] as num?)?.toDouble(),
        nudgesThisWeek: json['nudgesThisWeek'] ?? 0,
        totalDebt: (json['totalDebt'] as num?)?.toDouble() ?? 0,
        totalPaid: (json['totalPaid'] as num?)?.toDouble() ?? 0,
        progressPercent: (json['progressPercent'] as num?)?.toDouble() ?? 0,
        lastNudgeSent: json['lastNudgeSent'] != null
            ? DateTime.parse(json['lastNudgeSent'])
            : null,
      );
}

/// Nudge configuration with eligibility rules
class NudgeConfig {
  final String id;
  final String name;
  final NudgeType type;
  final NudgeCategory category;
  final Duration cooldown;
  final int priority;

  NudgeConfig({
    required this.id,
    required this.name,
    required this.type,
    required this.category,
    this.cooldown = const Duration(days: 1),
    this.priority = 0,
  });
}

/// Dynamic nudge with real-time data
class DynamicNudge {
  final String id;
  final String title;
  final String message;
  final String explanation; // Why this nudge was triggered
  final DateTime generatedAt;

  DynamicNudge({
    required this.id,
    required this.title,
    required this.message,
    this.explanation = '',
    DateTime? generatedAt,
  }) : generatedAt = generatedAt ?? DateTime.now();
}

// ============================================
// NUDGE MANAGER - 3-Layer Architecture
// ============================================

class NudgeManager {
  static final NudgeManager _instance = NudgeManager._internal();
  factory NudgeManager() => _instance;
  NudgeManager._internal();

  final NotificationService _notificationService = NotificationService();
  final Map<String, DateTime> _lastShownTimes = {};
  bool _isInitialized = false;
  UserSignals? _cachedSignals;

  // HARD LIMITS (per best practices)
  static const int _maxNudgesPerDay = 1;
  static const int _maxNudgesPerWeek = 3;
  static const int _silentHourStart = 21; // 9 PM
  static const int _silentHourEnd = 8; // 8 AM

  // Nudge configurations with rules
  final List<NudgeConfig> _nudgeConfigs = [
    NudgeConfig(
      id: 'upcoming_payment',
      name: 'Payment Due Soon',
      type: NudgeType.timeBased,
      category: NudgeCategory.timing,
      cooldown: const Duration(days: 1),
      priority: 10, // Highest priority
    ),
    NudgeConfig(
      id: 'streak_milestone',
      name: 'Streak Milestone',
      type: NudgeType.behaviorBased,
      category: NudgeCategory.reinforcement,
      cooldown: const Duration(days: 7),
      priority: 8,
    ),
    NudgeConfig(
      id: 'extra_payment_opportunity',
      name: 'Extra Payment Opportunity',
      type: NudgeType.behaviorBased,
      category: NudgeCategory.opportunity,
      cooldown: const Duration(days: 3),
      priority: 6,
    ),
    NudgeConfig(
      id: 're_engagement',
      name: 'Check-In Reminder',
      type: NudgeType.behaviorBased,
      category: NudgeCategory.reEngagement,
      cooldown: const Duration(days: 2),
      priority: 4,
    ),
  ];

  /// Initialize the nudge manager
  Future<void> init() async {
    if (_isInitialized) return;

    await _notificationService.initialize();
    await _loadLastShownTimes();
    await refreshSignals();

    _isInitialized = true;
    debugPrint(
        '✅ NudgeManager initialized with ${_nudgeConfigs.length} nudge types');
  }

  // ============================================
  // SIGNAL LAYER - Collect & Store Behavioral Data
  // ============================================

  /// Refresh all signals from current data
  Future<UserSignals> refreshSignals() async {
    final debts = await DataService.getDebts();
    final achievements = await DataService.getAchievements();
    final prefs = await SharedPreferences.getInstance();

    // Find nearest due date
    DateTime? nearestDue;
    String? nearestDebtName;
    double? nearestDebtAmount;

    for (final debt in debts) {
      if (debt.dueDate != null && debt.dueDate!.isAfter(DateTime.now())) {
        if (nearestDue == null || debt.dueDate!.isBefore(nearestDue)) {
          nearestDue = debt.dueDate;
          nearestDebtName = debt.name;
          nearestDebtAmount = debt.minimumPayment;
        }
      }
    }

    // Fallback: if no upcoming due date, use first debt's info
    if (nearestDebtName == null && debts.isNotEmpty) {
      nearestDebtName = debts.first.name;
      nearestDebtAmount = debts.first.minimumPayment;
      nearestDue = debts.first.dueDate;
    }

    debugPrint(
        '📊 Signals: debts=${debts.length}, nearestDebt=$nearestDebtName, amount=$nearestDebtAmount');

    final totalDebt = debts.fold(0.0, (sum, d) => sum + d.currentBalance);
    final totalPaid = achievements.totalAmountPaid;
    final progress =
        totalPaid > 0 ? (totalPaid / (totalDebt + totalPaid)) * 100 : 0.0;

    // Load nudge tracking data
    final lastNudgeStr = prefs.getString('last_nudge_sent');
    final nudgesThisWeek = prefs.getInt('nudges_this_week') ?? 0;

    _cachedSignals = UserSignals(
      lastAppOpen: DateTime.now(),
      lastPayment: achievements.lastPaymentDate,
      paymentStreak: achievements.currentPaymentStreak,
      loginStreak:
          achievements.currentPaymentStreak, // Using payment streak as proxy
      nearestDueDate: nearestDue,
      nearestDebtName: nearestDebtName,
      nearestDebtAmount: nearestDebtAmount,
      nudgesThisWeek: nudgesThisWeek,
      totalDebt: totalDebt,
      totalPaid: totalPaid,
      progressPercent: progress,
      lastNudgeSent: lastNudgeStr != null ? DateTime.parse(lastNudgeStr) : null,
    );

    // Update last app open
    await prefs.setString('last_app_open', DateTime.now().toIso8601String());

    debugPrint(
        '📊 Signals refreshed: streak=${_cachedSignals!.paymentStreak}, dueIn=${_cachedSignals!.daysUntilDue} days');
    return _cachedSignals!;
  }

  /// Get current signals (cached or fresh)
  Future<UserSignals> getSignals() async {
    if (_cachedSignals == null) {
      return await refreshSignals();
    }
    return _cachedSignals!;
  }

  // ============================================
  // DECISION LAYER - Rules Engine
  // ============================================

  /// Check if we're in silent hours (9 PM - 8 AM)
  bool _isInSilentHours() {
    final hour = DateTime.now().hour;
    return hour >= _silentHourStart || hour < _silentHourEnd;
  }

  /// Check if we've hit daily/weekly limits
  Future<bool> _hasHitLimits(UserSignals signals) async {
    // Check 24-hour limit
    if (signals.hoursSinceLastNudge < 24) {
      debugPrint('⏳ Nudge blocked: Less than 24 hours since last nudge');
      return true;
    }

    // Check weekly limit
    if (signals.nudgesThisWeek >= _maxNudgesPerWeek) {
      debugPrint(
          '⏳ Nudge blocked: Weekly limit reached (${signals.nudgesThisWeek}/$_maxNudgesPerWeek)');
      return true;
    }

    return false;
  }

  /// Check if a specific nudge can be shown (respects cooldown)
  bool _canShowNudge(String nudgeId, NudgeConfig config) {
    final lastShown = _lastShownTimes[nudgeId];
    if (lastShown == null) return true;
    return DateTime.now().difference(lastShown) > config.cooldown;
  }

  /// Evaluate all rules and return the best eligible nudge (or null)
  Future<NudgeConfig?> evaluateRules() async {
    final signals = await getSignals();

    // Check hard limits first
    if (_isInSilentHours()) {
      debugPrint('🌙 Silent hours - no nudge');
      return null;
    }

    if (await _hasHitLimits(signals)) {
      return null;
    }

    // Evaluate each nudge rule by priority
    final sortedConfigs = List<NudgeConfig>.from(_nudgeConfigs)
      ..sort((a, b) => b.priority.compareTo(a.priority));

    for (final config in sortedConfigs) {
      if (!_canShowNudge(config.id, config)) continue;

      final isEligible = _checkEligibility(config, signals);
      if (isEligible) {
        debugPrint(
            '✅ Eligible nudge: ${config.id} (priority ${config.priority})');
        return config;
      }
    }

    debugPrint('❌ No eligible nudges');
    return null;
  }

  /// Check eligibility for a specific nudge type
  bool _checkEligibility(NudgeConfig config, UserSignals signals) {
    switch (config.id) {
      case 'upcoming_payment':
        // Payment due within 5 days AND haven't opened app recently
        return signals.daysUntilDue <= 5 &&
            signals.daysUntilDue >= 0 &&
            signals.nearestDebtName != null;

      case 'streak_milestone':
        // Hit a milestone (7, 14, 21, 30, etc.)
        final milestones = [7, 14, 21, 30, 60, 90, 180, 365];
        return milestones.contains(signals.paymentStreak);

      case 'extra_payment_opportunity':
        // Has made progress and has debt remaining
        return signals.progressPercent > 10 &&
            signals.progressPercent < 90 &&
            signals.totalDebt > 0;

      case 're_engagement':
        // Haven't opened app in 3+ days AND have debts
        return signals.daysSinceAppOpen >= 3 && signals.totalDebt > 0;

      default:
        return false;
    }
  }

  // ============================================
  // DELIVERY LAYER - Schedule Background Notifications
  // ============================================

  /// Run the full nudge evaluation and schedule if eligible
  Future<DynamicNudge?> runNudgeEngine() async {
    if (!_isInitialized) await init();

    debugPrint('🔍 Running nudge engine...');

    final eligibleConfig = await evaluateRules();
    if (eligibleConfig == null) return null;

    final signals = await getSignals();
    final nudge = await _generatePersonalizedNudge(eligibleConfig, signals);

    // Schedule for background delivery (in case app closed)
    await _scheduleBackgroundNudge(nudge);

    return nudge;
  }

  /// Schedule a nudge for background delivery
  Future<void> _scheduleBackgroundNudge(DynamicNudge nudge) async {
    // Schedule for 5 minutes from now (gives time to close app for demo)
    final scheduledTime = DateTime.now().add(const Duration(minutes: 2));

    await _notificationService.scheduleNotification(
      id: nudge.id.hashCode,
      title: nudge.title,
      body: nudge.message,
      scheduledDate: scheduledTime,
      payload: 'nudge:${nudge.id}',
    );

    // Track that we sent a nudge
    await _recordNudgeSent(nudge.id);

    debugPrint('📅 Nudge scheduled for background delivery: ${nudge.title}');
  }

  /// Record that a nudge was sent and update limits
  Future<void> _recordNudgeSent(String nudgeId) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    // Update last shown time for this nudge type
    _lastShownTimes[nudgeId] = now;
    await _saveLastShownTimes();

    // Update global nudge tracking
    await prefs.setString('last_nudge_sent', now.toIso8601String());

    // Reset weekly counter on Monday
    final lastReset = prefs.getString('nudge_week_reset');
    final lastResetDate = lastReset != null ? DateTime.parse(lastReset) : null;

    if (lastResetDate == null || now.difference(lastResetDate).inDays >= 7) {
      await prefs.setInt('nudges_this_week', 1);
      await prefs.setString('nudge_week_reset', now.toIso8601String());
    } else {
      final current = prefs.getInt('nudges_this_week') ?? 0;
      await prefs.setInt('nudges_this_week', current + 1);
    }

    // Refresh cached signals
    await refreshSignals();
  }

  // ============================================
  // PERSONALIZED MESSAGE GENERATION
  // ============================================

  /// Generate a deeply personalized nudge message
  Future<DynamicNudge> _generatePersonalizedNudge(
      NudgeConfig config, UserSignals signals) async {
    // Try AI generation first
    if (kGeminiApiKey.isNotEmpty) {
      try {
        final aiNudge = await _generateAINudge(config, signals);
        if (aiNudge != null) return aiNudge;
      } catch (e) {
        debugPrint('⚠️ AI generation failed: $e');
      }
    }

    // Fallback to personalized templates
    return _generateTemplateNudge(config, signals);
  }

  /// Generate nudge using Gemini AI with real user data
  Future<DynamicNudge?> _generateAINudge(
      NudgeConfig config, UserSignals signals) async {
    final contextData = _buildContextForAI(config, signals);

    final prompt = '''
You are a warm, encouraging financial wellness coach for the CogniCents app.
Generate a SHORT push notification for this situation:

NUDGE TYPE: ${config.name} (${config.category.name})

USER'S REAL DATA:
$contextData

RULES:
1. Max 2 sentences, be warm and human
2. Include the SPECIFIC numbers from their data (debt name, amount, streak length)
3. Use 1-2 emojis max
4. NO guilt or pressure language - be supportive
5. Make them feel good about their progress or gently remind them
6. Format exactly: "TITLE: [title]\\nBODY: [body]\\nWHY: [one sentence explaining why this nudge]"
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
              'generationConfig': {'maxOutputTokens': 150, 'temperature': 0.7},
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        if (text != null) {
          return _parseAIResponse(config.id, text);
        }
      }
    } catch (e) {
      debugPrint('AI request failed: $e');
    }

    return null;
  }

  /// Build context string for AI with real user data
  String _buildContextForAI(NudgeConfig config, UserSignals signals) {
    final buffer = StringBuffer();

    switch (config.id) {
      case 'upcoming_payment':
        buffer.writeln('• Debt name: ${signals.nearestDebtName}');
        buffer.writeln(
            '• Amount due: \$${signals.nearestDebtAmount?.toStringAsFixed(0)}');
        buffer.writeln('• Due in: ${signals.daysUntilDue} days');
        buffer.writeln('• Current streak: ${signals.paymentStreak} days');
        break;

      case 'streak_milestone':
        buffer.writeln('• Current streak: ${signals.paymentStreak} days!');
        buffer.writeln(
            '• Total paid so far: \$${signals.totalPaid.toStringAsFixed(0)}');
        buffer.writeln(
            '• Progress: ${signals.progressPercent.toStringAsFixed(0)}% of debt paid off');
        break;

      case 'extra_payment_opportunity':
        buffer.writeln(
            '• Total remaining debt: \$${signals.totalDebt.toStringAsFixed(0)}');
        buffer.writeln(
            '• Progress so far: ${signals.progressPercent.toStringAsFixed(0)}%');
        buffer.writeln('• Nearest debt: ${signals.nearestDebtName}');
        break;

      case 're_engagement':
        buffer
            .writeln('• Days since last check-in: ${signals.daysSinceAppOpen}');
        buffer.writeln('• Their streak: ${signals.paymentStreak} days');
        buffer.writeln(
            '• Progress: ${signals.progressPercent.toStringAsFixed(0)}%');
        break;
    }

    return buffer.toString();
  }

  /// Parse AI response into DynamicNudge
  DynamicNudge _parseAIResponse(String nudgeId, String response) {
    final titleMatch = RegExp(r'TITLE:\s*(.+?)(?:\n|$)').firstMatch(response);
    final bodyMatch = RegExp(r'BODY:\s*(.+?)(?:\n|WHY:|$)', dotAll: true)
        .firstMatch(response);
    final whyMatch = RegExp(r'WHY:\s*(.+)$', dotAll: true).firstMatch(response);

    return DynamicNudge(
      id: nudgeId,
      title: titleMatch?.group(1)?.trim() ?? '💰 CogniCents',
      message: bodyMatch?.group(1)?.trim() ?? 'Time to check your progress!',
      explanation: whyMatch?.group(1)?.trim() ?? '',
    );
  }

  /// Generate personalized template-based nudge (fallback)
  DynamicNudge _generateTemplateNudge(NudgeConfig config, UserSignals signals) {
    final random = Random();

    // Null-safe defaults for personalization
    final debtName = signals.nearestDebtName ?? 'your debt';
    final debtAmount = signals.nearestDebtAmount?.toStringAsFixed(0) ?? '0';
    final daysUntil = signals.daysUntilDue < 999 ? signals.daysUntilDue : 0;
    final streak = signals.paymentStreak;
    final progress = signals.progressPercent.toStringAsFixed(0);
    final totalPaid = signals.totalPaid.toStringAsFixed(0);
    final daysSinceOpen =
        signals.daysSinceAppOpen < 999 ? signals.daysSinceAppOpen : 1;

    switch (config.id) {
      case 'upcoming_payment':
        final templates = [
          'Your $debtName payment (\$$debtAmount) is due in $daysUntil days. You\'ve got this! 💪',
          '$daysUntil days until $debtName is due. Stay on your $streak-day streak! 🔥',
          'Friendly reminder: \$$debtAmount for $debtName coming up in $daysUntil days.',
        ];
        return DynamicNudge(
          id: config.id,
          title: '📅 Payment Coming Up',
          message: templates[random.nextInt(templates.length)],
          explanation: 'Your $debtName payment is due in $daysUntil days.',
        );

      case 'streak_milestone':
        final templates = [
          '$streak days strong! 🔥 You\'ve paid off \$$totalPaid so far. Most people never make it this far!',
          'Incredible! $streak-day streak achieved! You\'re in the top 10% of users. Keep crushing it! 🏆',
          '$streak days of consistency! That\'s $progress% of your debt conquered. Amazing! ⭐',
        ];
        return DynamicNudge(
          id: config.id,
          title: '🎉 Streak Milestone!',
          message: templates[random.nextInt(templates.length)],
          explanation: 'You hit a $streak-day payment streak milestone!',
        );

      case 'extra_payment_opportunity':
        final extraAmount =
            ((signals.nearestDebtAmount ?? 50) * 0.1).toStringAsFixed(0);
        final templates = [
          'An extra \$$extraAmount on $debtName could shave days off your payoff date! Every bit counts. 💪',
          'You\'re $progress% there! A small extra payment could accelerate your freedom date. 🚀',
          'Your momentum is building! Consider adding a little extra to your next payment. You\'re doing great! 🌟',
        ];
        return DynamicNudge(
          id: config.id,
          title: '💡 Opportunity',
          message: templates[random.nextInt(templates.length)],
          explanation:
              'You\'re making great progress and could accelerate your payoff.',
        );

      case 're_engagement':
        final templates = [
          'Hey! It\'s been $daysSinceOpen days. Your $streak-day streak is waiting for you! 👋',
          'Miss you! Quick check-in: you\'re $progress% of the way to debt freedom. See your progress? 📊',
          'Your financial journey called – it misses you! Let\'s keep that $streak-day momentum going. 🔥',
        ];
        return DynamicNudge(
          id: config.id,
          title: '👋 We Miss You!',
          message: templates[random.nextInt(templates.length)],
          explanation: 'You haven\'t opened the app in $daysSinceOpen days.',
        );

      default:
        return DynamicNudge(
          id: config.id,
          title: '💡 CogniCents',
          message: 'Keep up the great work on your financial journey!',
          explanation: 'General encouragement nudge.',
        );
    }
  }

  // ============================================
  // STORAGE HELPERS
  // ============================================

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

  Future<void> _saveLastShownTimes() async {
    final prefs = await SharedPreferences.getInstance();
    final data =
        _lastShownTimes.map((k, v) => MapEntry(k, v.toIso8601String()));
    await prefs.setString('nudge_last_shown', jsonEncode(data));
  }

  // ============================================
  // TEST/DEBUG METHODS
  // ============================================

  /// Force trigger a specific nudge type (for testing)
  Future<DynamicNudge> testNudge(String nudgeId) async {
    if (!_isInitialized) await init();

    final config = _nudgeConfigs.firstWhere(
      (c) => c.id == nudgeId,
      orElse: () => _nudgeConfigs.first,
    );

    // Always refresh signals to get latest data for testing
    final signals = await refreshSignals();
    final nudge = await _generatePersonalizedNudge(config, signals);

    await _notificationService.showNotification(
      id: nudge.id.hashCode,
      title: nudge.title,
      body: nudge.message,
      payload: 'nudge_test:${nudge.id}',
    );

    return nudge;
  }

  /// Get current signals for display (explainability)
  Future<Map<String, dynamic>> getSignalsForDisplay() async {
    final signals = await getSignals();
    return signals.toJson();
  }

  /// Get all nudge configurations (for test UI)
  List<NudgeConfig> getNudgeConfigs() => List.unmodifiable(_nudgeConfigs);

  /// Reset all nudge cooldowns and limits (for testing)
  Future<void> resetAllCooldowns() async {
    _lastShownTimes.clear();
    await _saveLastShownTimes();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_nudge_sent');
    await prefs.remove('nudges_this_week');
    await prefs.remove('nudge_week_reset');

    await refreshSignals();
    debugPrint('🔄 All nudge cooldowns and limits reset');
  }
}
