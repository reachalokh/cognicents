import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../shared_preferences_stub.dart';

/// XP Action types that earn experience points
enum XPAction {
  dailyLogin, // +5 XP
  makePayment, // +25 XP
  extraPayment, // +50 XP (paying more than minimum)
  earlyPayment, // +30 XP (paying before due date)
  addSavings, // +20 XP
  completeDaily, // +30 XP
  completeWeekly, // +100 XP
  unlockBadge, // +50 XP
}

/// Challenge types
enum ChallengeType { daily, weekly }

/// Challenge categories for tracking progress
enum ChallengeCategory { payment, savings, login, tracking }

/// Level information with thresholds
class LevelInfo {
  final int level;
  final String name;
  final int xpRequired;
  final int xpToNext;

  const LevelInfo({
    required this.level,
    required this.name,
    required this.xpRequired,
    required this.xpToNext,
  });
}

/// Challenge model for daily/weekly goals
class Challenge {
  final String id;
  final String title;
  final String description;
  final ChallengeType type;
  final ChallengeCategory category;
  final int xpReward;
  final double? targetAmount;
  final int? targetCount;
  final double currentProgress;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime expiresAt;

  Challenge({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.category,
    required this.xpReward,
    this.targetAmount,
    this.targetCount,
    this.currentProgress = 0,
    this.isCompleted = false,
    required this.createdAt,
    required this.expiresAt,
  });

  double get progressPercent {
    if (targetAmount != null && targetAmount! > 0) {
      return (currentProgress / targetAmount!).clamp(0.0, 1.0);
    }
    if (targetCount != null && targetCount! > 0) {
      return (currentProgress / targetCount!).clamp(0.0, 1.0);
    }
    return isCompleted ? 1.0 : 0.0;
  }

  Challenge copyWith({
    double? currentProgress,
    bool? isCompleted,
  }) {
    return Challenge(
      id: id,
      title: title,
      description: description,
      type: type,
      category: category,
      xpReward: xpReward,
      targetAmount: targetAmount,
      targetCount: targetCount,
      currentProgress: currentProgress ?? this.currentProgress,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt,
      expiresAt: expiresAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'type': type.toString(),
        'category': category.toString(),
        'xpReward': xpReward,
        'targetAmount': targetAmount,
        'targetCount': targetCount,
        'currentProgress': currentProgress,
        'isCompleted': isCompleted,
        'createdAt': createdAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
      };

  factory Challenge.fromJson(Map<String, dynamic> json) {
    return Challenge(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      type: ChallengeType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => ChallengeType.daily,
      ),
      category: ChallengeCategory.values.firstWhere(
        (e) => e.toString() == json['category'],
        orElse: () => ChallengeCategory.tracking,
      ),
      xpReward: json['xpReward'],
      targetAmount: json['targetAmount']?.toDouble(),
      targetCount: json['targetCount'],
      currentProgress: json['currentProgress']?.toDouble() ?? 0,
      isCompleted: json['isCompleted'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
      expiresAt: DateTime.parse(json['expiresAt']),
    );
  }
}

/// User gamification data
class GamificationData {
  final int totalXP;
  final int currentLevel;
  final DateTime? lastLoginDate;
  final int loginStreak;
  final int paymentStreak;
  final List<Challenge> activeChallenges;
  final List<String> completedChallengeIds;
  final List<XPHistoryEntry> xpHistory;

  GamificationData({
    this.totalXP = 0,
    this.currentLevel = 1,
    this.lastLoginDate,
    this.loginStreak = 0,
    this.paymentStreak = 0,
    List<Challenge>? activeChallenges,
    List<String>? completedChallengeIds,
    List<XPHistoryEntry>? xpHistory,
  })  : activeChallenges = activeChallenges ?? [],
        completedChallengeIds = completedChallengeIds ?? [],
        xpHistory = xpHistory ?? [];

  GamificationData copyWith({
    int? totalXP,
    int? currentLevel,
    DateTime? lastLoginDate,
    int? loginStreak,
    int? paymentStreak,
    List<Challenge>? activeChallenges,
    List<String>? completedChallengeIds,
    List<XPHistoryEntry>? xpHistory,
  }) {
    return GamificationData(
      totalXP: totalXP ?? this.totalXP,
      currentLevel: currentLevel ?? this.currentLevel,
      lastLoginDate: lastLoginDate ?? this.lastLoginDate,
      loginStreak: loginStreak ?? this.loginStreak,
      paymentStreak: paymentStreak ?? this.paymentStreak,
      activeChallenges: activeChallenges ?? this.activeChallenges,
      completedChallengeIds:
          completedChallengeIds ?? this.completedChallengeIds,
      xpHistory: xpHistory ?? this.xpHistory,
    );
  }

  Map<String, dynamic> toJson() => {
        'totalXP': totalXP,
        'currentLevel': currentLevel,
        'lastLoginDate': lastLoginDate?.toIso8601String(),
        'loginStreak': loginStreak,
        'paymentStreak': paymentStreak,
        'activeChallenges': activeChallenges.map((c) => c.toJson()).toList(),
        'completedChallengeIds': completedChallengeIds,
        'xpHistory': xpHistory.map((e) => e.toJson()).toList(),
      };

  factory GamificationData.fromJson(Map<String, dynamic> json) {
    return GamificationData(
      totalXP: json['totalXP'] ?? 0,
      currentLevel: json['currentLevel'] ?? 1,
      lastLoginDate: json['lastLoginDate'] != null
          ? DateTime.parse(json['lastLoginDate'])
          : null,
      loginStreak: json['loginStreak'] ?? 0,
      paymentStreak: json['paymentStreak'] ?? 0,
      activeChallenges: (json['activeChallenges'] as List?)
              ?.map((c) => Challenge.fromJson(c))
              .toList() ??
          [],
      completedChallengeIds:
          List<String>.from(json['completedChallengeIds'] ?? []),
      xpHistory: (json['xpHistory'] as List?)
              ?.map((e) => XPHistoryEntry.fromJson(e))
              .toList() ??
          [],
    );
  }
}

/// XP history entry for tracking
class XPHistoryEntry {
  final int amount;
  final String reason;
  final DateTime timestamp;

  XPHistoryEntry({
    required this.amount,
    required this.reason,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'reason': reason,
        'timestamp': timestamp.toIso8601String(),
      };

  factory XPHistoryEntry.fromJson(Map<String, dynamic> json) {
    return XPHistoryEntry(
      amount: json['amount'],
      reason: json['reason'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

/// Service for managing gamification features
class GamificationService {
  static const String _storageKey = 'gamification_data';

  // Level thresholds
  static const List<Map<String, dynamic>> _levels = [
    {'level': 1, 'name': 'Beginner', 'xpRequired': 0},
    {'level': 2, 'name': 'Saver', 'xpRequired': 100},
    {'level': 3, 'name': 'Budgeter', 'xpRequired': 300},
    {'level': 4, 'name': 'Debt Crusher', 'xpRequired': 600},
    {'level': 5, 'name': 'Money Manager', 'xpRequired': 1000},
    {'level': 6, 'name': 'Financial Pro', 'xpRequired': 1500},
    {'level': 7, 'name': 'Wealth Builder', 'xpRequired': 2500},
    {'level': 8, 'name': 'Expert', 'xpRequired': 4000},
    {'level': 9, 'name': 'Master', 'xpRequired': 6000},
    {'level': 10, 'name': 'Financial Legend', 'xpRequired': 10000},
  ];

  // XP amounts for each action
  static int getXPForAction(XPAction action) {
    switch (action) {
      case XPAction.dailyLogin:
        return 5;
      case XPAction.makePayment:
        return 25;
      case XPAction.extraPayment:
        return 50;
      case XPAction.earlyPayment:
        return 30;
      case XPAction.addSavings:
        return 20;
      case XPAction.completeDaily:
        return 30;
      case XPAction.completeWeekly:
        return 100;
      case XPAction.unlockBadge:
        return 50;
    }
  }

  /// Get current gamification data
  static Future<GamificationData> getData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKey);
      if (jsonStr != null) {
        return GamificationData.fromJson(jsonDecode(jsonStr));
      }
    } catch (e) {
      debugPrint('Error loading gamification data: $e');
    }
    return GamificationData();
  }

  /// Save gamification data
  static Future<void> _saveData(GamificationData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(data.toJson()));
    } catch (e) {
      debugPrint('Error saving gamification data: $e');
    }
  }

  /// Get level info for a given XP amount
  static LevelInfo getLevelInfo(int xp) {
    int currentLevel = 1;
    String levelName = 'Beginner';
    int xpRequired = 0;
    int xpToNext = 100;

    for (int i = 0; i < _levels.length; i++) {
      if (xp >= _levels[i]['xpRequired']) {
        currentLevel = _levels[i]['level'];
        levelName = _levels[i]['name'];
        xpRequired = _levels[i]['xpRequired'];
        if (i < _levels.length - 1) {
          xpToNext = _levels[i + 1]['xpRequired'] - xpRequired;
        } else {
          xpToNext = 0; // Max level
        }
      } else {
        break;
      }
    }

    return LevelInfo(
      level: currentLevel,
      name: levelName,
      xpRequired: xpRequired,
      xpToNext: xpToNext,
    );
  }

  /// Get XP progress within current level (0.0 to 1.0)
  static double getLevelProgress(int totalXP) {
    final levelInfo = getLevelInfo(totalXP);
    if (levelInfo.xpToNext == 0) return 1.0; // Max level
    final xpInCurrentLevel = totalXP - levelInfo.xpRequired;
    return (xpInCurrentLevel / levelInfo.xpToNext).clamp(0.0, 1.0);
  }

  /// Award XP for an action
  static Future<int> awardXP(XPAction action, {String? reason}) async {
    final data = await getData();
    final xpAmount = getXPForAction(action);
    final reasonText = reason ?? _getDefaultReason(action);

    final newHistory = List<XPHistoryEntry>.from(data.xpHistory)
      ..add(XPHistoryEntry(
        amount: xpAmount,
        reason: reasonText,
        timestamp: DateTime.now(),
      ));

    // Keep only last 50 history entries
    if (newHistory.length > 50) {
      newHistory.removeRange(0, newHistory.length - 50);
    }

    final newTotalXP = data.totalXP + xpAmount;
    final newLevel = getLevelInfo(newTotalXP).level;

    final updatedData = data.copyWith(
      totalXP: newTotalXP,
      currentLevel: newLevel,
      xpHistory: newHistory,
    );

    await _saveData(updatedData);
    debugPrint('🎮 Awarded $xpAmount XP for $action. Total: $newTotalXP');

    return xpAmount;
  }

  static String _getDefaultReason(XPAction action) {
    switch (action) {
      case XPAction.dailyLogin:
        return 'Daily login bonus';
      case XPAction.makePayment:
        return 'Made a payment';
      case XPAction.extraPayment:
        return 'Extra payment bonus';
      case XPAction.earlyPayment:
        return 'Early payment bonus';
      case XPAction.addSavings:
        return 'Added to savings';
      case XPAction.completeDaily:
        return 'Completed daily challenge';
      case XPAction.completeWeekly:
        return 'Completed weekly challenge';
      case XPAction.unlockBadge:
        return 'Unlocked a badge';
    }
  }

  /// Check and award daily login bonus
  static Future<bool> checkDailyLogin() async {
    final data = await getData();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (data.lastLoginDate != null) {
      final lastLogin = DateTime(
        data.lastLoginDate!.year,
        data.lastLoginDate!.month,
        data.lastLoginDate!.day,
      );

      if (lastLogin == today) {
        // Already logged in today
        return false;
      }

      final yesterday = today.subtract(const Duration(days: 1));
      final newStreak = lastLogin == yesterday ? data.loginStreak + 1 : 1;

      final updatedData = data.copyWith(
        lastLoginDate: now,
        loginStreak: newStreak,
      );
      await _saveData(updatedData);
      await awardXP(XPAction.dailyLogin);
      await updateChallengeProgress(ChallengeCategory.login);
      debugPrint('🔥 Login streak: $newStreak days');
      return true;
    } else {
      // First login ever
      final updatedData = data.copyWith(
        lastLoginDate: now,
        loginStreak: 1,
      );
      await _saveData(updatedData);
      await awardXP(XPAction.dailyLogin);
      await updateChallengeProgress(ChallengeCategory.login);
      return true;
    }
  }

  /// Update payment streak
  static Future<void> recordPaymentForStreak() async {
    final data = await getData();

    // Simple streak: consecutive days with payments
    // For demo purposes, just increment
    final updatedData = data.copyWith(
      paymentStreak: data.paymentStreak + 1,
    );
    await _saveData(updatedData);
    debugPrint('💰 Payment streak: ${updatedData.paymentStreak}');
  }

  /// Generate daily challenges
  static List<Challenge> _generateDailyChallenges() {
    final now = DateTime.now();
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final dailyId = '${now.year}-${now.month}-${now.day}';

    return [
      Challenge(
        id: 'daily-login-$dailyId',
        title: 'Daily Check-in',
        description: 'Open the app today',
        type: ChallengeType.daily,
        category: ChallengeCategory.login,
        xpReward: 5,
        targetCount: 1,
        createdAt: now,
        expiresAt: endOfDay,
      ),
      Challenge(
        id: 'daily-payment-$dailyId',
        title: 'Make a Payment',
        description: 'Record any debt payment',
        type: ChallengeType.daily,
        category: ChallengeCategory.payment,
        xpReward: 30,
        targetCount: 1,
        createdAt: now,
        expiresAt: endOfDay,
      ),
      Challenge(
        id: 'daily-review-$dailyId',
        title: 'Review Progress',
        description: 'Check your progress page',
        type: ChallengeType.daily,
        category: ChallengeCategory.tracking,
        xpReward: 10,
        targetCount: 1,
        createdAt: now,
        expiresAt: endOfDay,
      ),
    ];
  }

  /// Generate weekly challenges
  static List<Challenge> _generateWeeklyChallenges() {
    final now = DateTime.now();
    // End of week (next Sunday at 23:59:59)
    final daysUntilSunday = DateTime.sunday - now.weekday;
    final endOfWeek = DateTime(
      now.year,
      now.month,
      now.day + (daysUntilSunday <= 0 ? 7 + daysUntilSunday : daysUntilSunday),
      23,
      59,
      59,
    );
    final weekId = '${now.year}-W${(now.day / 7).ceil()}';

    return [
      Challenge(
        id: 'weekly-payments-$weekId',
        title: 'Payment Pro',
        description: 'Make 3 payments this week',
        type: ChallengeType.weekly,
        category: ChallengeCategory.payment,
        xpReward: 100,
        targetCount: 3,
        createdAt: now,
        expiresAt: endOfWeek,
      ),
      Challenge(
        id: 'weekly-savings-$weekId',
        title: 'Savings Goal',
        description: 'Add \$50 to emergency fund',
        type: ChallengeType.weekly,
        category: ChallengeCategory.savings,
        xpReward: 75,
        targetAmount: 50,
        createdAt: now,
        expiresAt: endOfWeek,
      ),
      Challenge(
        id: 'weekly-streak-$weekId',
        title: 'Consistency King',
        description: 'Log in 5 days this week',
        type: ChallengeType.weekly,
        category: ChallengeCategory.login,
        xpReward: 50,
        targetCount: 5,
        createdAt: now,
        expiresAt: endOfWeek,
      ),
    ];
  }

  /// Refresh challenges (called on app open)
  static Future<void> refreshChallenges() async {
    final data = await getData();
    final now = DateTime.now();

    // Filter out expired challenges
    final validChallenges =
        data.activeChallenges.where((c) => c.expiresAt.isAfter(now)).toList();

    // Check if we need new daily challenges
    final hasTodaysDailies = validChallenges.any(
      (c) =>
          c.type == ChallengeType.daily &&
          c.createdAt.day == now.day &&
          c.createdAt.month == now.month &&
          c.createdAt.year == now.year,
    );

    if (!hasTodaysDailies) {
      validChallenges.addAll(_generateDailyChallenges());
    }

    // Check if we need new weekly challenges
    final hasThisWeeksWeeklies = validChallenges.any(
      (c) => c.type == ChallengeType.weekly && c.expiresAt.isAfter(now),
    );

    if (!hasThisWeeksWeeklies) {
      validChallenges.addAll(_generateWeeklyChallenges());
    }

    final updatedData = data.copyWith(activeChallenges: validChallenges);
    await _saveData(updatedData);
    debugPrint('📋 Refreshed challenges: ${validChallenges.length} active');
  }

  /// Update challenge progress
  static Future<void> updateChallengeProgress(
    ChallengeCategory category, {
    double amount = 1,
  }) async {
    final data = await getData();
    final updatedChallenges = <Challenge>[];
    var xpEarned = 0;

    for (final challenge in data.activeChallenges) {
      if (challenge.category == category && !challenge.isCompleted) {
        final newProgress = challenge.currentProgress + amount;
        final isNowCompleted = challenge.targetAmount != null
            ? newProgress >= challenge.targetAmount!
            : challenge.targetCount != null
                ? newProgress >= challenge.targetCount!
                : false;

        if (isNowCompleted && !challenge.isCompleted) {
          xpEarned += challenge.xpReward;
          debugPrint('🏆 Challenge completed: ${challenge.title}');
        }

        updatedChallenges.add(challenge.copyWith(
          currentProgress: newProgress,
          isCompleted: isNowCompleted,
        ));
      } else {
        updatedChallenges.add(challenge);
      }
    }

    var updatedData = data.copyWith(activeChallenges: updatedChallenges);

    // Award XP for completed challenges
    if (xpEarned > 0) {
      final newHistory = List<XPHistoryEntry>.from(updatedData.xpHistory)
        ..add(XPHistoryEntry(
          amount: xpEarned,
          reason: 'Challenge completed',
          timestamp: DateTime.now(),
        ));
      updatedData = updatedData.copyWith(
        totalXP: updatedData.totalXP + xpEarned,
        currentLevel: getLevelInfo(updatedData.totalXP + xpEarned).level,
        xpHistory: newHistory,
      );
    }

    await _saveData(updatedData);
  }

  /// Get all level definitions
  static List<LevelInfo> getAllLevels() {
    return _levels.asMap().entries.map((entry) {
      final idx = entry.key;
      final level = entry.value;
      final xpToNext = idx < _levels.length - 1
          ? _levels[idx + 1]['xpRequired'] - level['xpRequired']
          : 0;
      return LevelInfo(
        level: level['level'],
        name: level['name'],
        xpRequired: level['xpRequired'],
        xpToNext: xpToNext,
      );
    }).toList();
  }
}
