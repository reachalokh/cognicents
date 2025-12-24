import 'package:flutter/material.dart';
import '../services/banking_service.dart';
import '../main.dart';

// Spending Pattern Analysis
class SpendingPattern {
  final String category;
  final double monthlyAverage;
  final int frequency;
  final String insight;
  final String recommendation;
  final Color color;

  SpendingPattern({
    required this.category,
    required this.monthlyAverage,
    required this.frequency,
    required this.insight,
    required this.recommendation,
    required this.color,
  });
}

// Subscription Detection
class Subscription {
  final String name;
  final double monthlyCost;
  final DateTime? lastCharge;
  final int frequency; // days between charges
  final String category;
  final bool isActive;

  Subscription({
    required this.name,
    required this.monthlyCost,
    this.lastCharge,
    this.frequency = 30,
    required this.category,
    this.isActive = true,
  });
}

// Budget Recommendation
class BudgetRecommendation {
  final String category;
  final double currentSpending;
  final double recommendedSpending;
  final double potentialSavings;
  final String reasoning;

  BudgetRecommendation({
    required this.category,
    required this.currentSpending,
    required this.recommendedSpending,
    required this.potentialSavings,
    required this.reasoning,
  });
}

// Spending Analysis Service
class SpendingAnalysisService {
  // Analyze spending patterns from transactions
  static Future<List<SpendingPattern>> analyzeSpendingPatterns(
    List<BankingTransaction> transactions,
    List<Debt> debts,
    UserFinancialData financialData,
  ) async {
    final patterns = <SpendingPattern>[];
    final categoryTotals = <String, List<double>>{};
    final categoryFrequencies = <String, int>{};

    // Group transactions by category
    for (var transaction in transactions) {
      if (transaction.isDebit) {
        categoryTotals.putIfAbsent(transaction.category, () => []).add(transaction.amount);
        categoryFrequencies[transaction.category] = (categoryFrequencies[transaction.category] ?? 0) + 1;
      }
    }

    // Calculate monthly averages and identify patterns
    for (var entry in categoryTotals.entries) {
      final category = entry.key;
      final amounts = entry.value;
      final monthlyAverage = amounts.fold(0.0, (sum, amount) => sum + amount);
      final frequency = categoryFrequencies[category] ?? 0;

      String insight = '';
      String recommendation = '';
      Color color = Colors.blue;

      // Identify problematic patterns
      if (category == 'Dining' && monthlyAverage > 200 && debts.isNotEmpty) {
        final totalDebt = debts.fold(0.0, (sum, debt) => sum + debt.currentBalance);
        if (totalDebt > 1000) {
          insight = 'You\'re spending \$${monthlyAverage.toStringAsFixed(0)}/month on dining while carrying debt.';
          recommendation = 'Consider meal prepping or reducing dining out to \$${(monthlyAverage * 0.5).toStringAsFixed(0)}/month. This could save \$${(monthlyAverage * 0.5).toStringAsFixed(0)} monthly!';
          color = Colors.orange;
        }
      } else if (category == 'Entertainment' && monthlyAverage > 100) {
        insight = 'Entertainment spending is \$${monthlyAverage.toStringAsFixed(0)}/month.';
        recommendation = 'Look for free alternatives or bundle subscriptions to save money.';
        color = Colors.purple;
      } else if (category == 'Shopping' && monthlyAverage > 300) {
        insight = 'Shopping expenses average \$${monthlyAverage.toStringAsFixed(0)}/month.';
        recommendation = 'Try a 24-hour "cooling off" period before non-essential purchases.';
        color = Colors.pink;
      } else if (category == 'Gas' && monthlyAverage > 150) {
        insight = 'Gas spending is \$${monthlyAverage.toStringAsFixed(0)}/month.';
        recommendation = 'Consider carpooling or using public transport when possible.';
        color = Colors.teal;
      }

      if (insight.isNotEmpty) {
        patterns.add(SpendingPattern(
          category: category,
          monthlyAverage: monthlyAverage,
          frequency: frequency,
          insight: insight,
          recommendation: recommendation,
          color: color,
        ));
      }
    }

    return patterns;
  }

  // Detect subscriptions from recurring transactions
  static Future<List<Subscription>> detectSubscriptions(
    List<BankingTransaction> transactions,
  ) async {
    final subscriptions = <Subscription>[];
    final merchantCharges = <String, List<BankingTransaction>>{};

    // Group by merchant
    for (var transaction in transactions) {
      if (transaction.isDebit) {
        final merchant = transaction.merchant.toLowerCase();
        merchantCharges.putIfAbsent(merchant, () => []).add(transaction);
      }
    }

    // Identify recurring charges (subscriptions)
    final subscriptionMerchants = [
      'netflix', 'spotify', 'amazon prime', 'disney', 'hulu', 'apple',
      'microsoft', 'adobe', 'gym', 'fitness', 'youtube', 'hbo', 'paramount',
      'peacock', 'audible', 'dropbox', 'icloud', 'google', 'zoom',
    ];

    for (var entry in merchantCharges.entries) {
      final merchant = entry.key;
      final charges = entry.value;

      // Check if it's a known subscription merchant
      bool isSubscriptionMerchant = subscriptionMerchants.any(
        (sub) => merchant.contains(sub),
      );

      // Or check for recurring pattern (same amount, regular intervals)
      if (charges.length >= 2) {
        charges.sort((a, b) => a.date.compareTo(b.date));
        final amounts = charges.map((t) => t.amount).toSet();
        
        // If same amount appears multiple times, likely a subscription
        if (amounts.length == 1 || isSubscriptionMerchant) {
          final avgAmount = charges.fold(0.0, (sum, t) => sum + t.amount) / charges.length;
          final lastCharge = charges.last.date;
          
          // Calculate frequency
          int frequency = 30;
          if (charges.length >= 2) {
            final daysBetween = charges.last.date.difference(charges[charges.length - 2].date).inDays;
            if (daysBetween > 0 && daysBetween <= 35) {
              frequency = daysBetween;
            }
          }

          subscriptions.add(Subscription(
            name: entry.key.split(' ').map((w) => w[0].toUpperCase() + w.substring(1)).join(' '),
            monthlyCost: avgAmount * (30 / frequency),
            lastCharge: lastCharge,
            frequency: frequency,
            category: charges.first.category,
            isActive: lastCharge.isAfter(DateTime.now().subtract(const Duration(days: 45))),
          ));
        }
      }
    }

    return subscriptions;
  }

  // Generate budget recommendations
  static Future<List<BudgetRecommendation>> generateBudgetRecommendations(
    List<BankingTransaction> transactions,
    List<Debt> debts,
    UserFinancialData financialData,
  ) async {
    final recommendations = <BudgetRecommendation>[];
    final categorySpending = <String, double>{};

    // Calculate current spending by category
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month, 1);
    
    for (var transaction in transactions) {
      if (transaction.isDebit && transaction.date.isAfter(thisMonth)) {
        categorySpending[transaction.category] =
            (categorySpending[transaction.category] ?? 0) + transaction.amount;
      }
    }

    // Calculate total debt
    final totalDebt = debts.fold(0.0, (sum, debt) => sum + debt.currentBalance);

    // Generate recommendations for each category
    for (var entry in categorySpending.entries) {
      final category = entry.key;
      final currentSpending = entry.value;
      
      // Skip essential categories
      if (['Groceries', 'Utilities', 'Insurance', 'Healthcare'].contains(category)) {
        continue;
      }

      double recommendedSpending = currentSpending;
      String reasoning = '';

      // Dining recommendations
      if (category == 'Dining') {
        if (totalDebt > 5000) {
          recommendedSpending = currentSpending * 0.4; // Reduce by 60%
          reasoning = 'With significant debt, reducing dining out can free up \$${(currentSpending - recommendedSpending).toStringAsFixed(0)}/month for debt payments.';
        } else if (totalDebt > 0) {
          recommendedSpending = currentSpending * 0.6; // Reduce by 40%
          reasoning = 'Cutting back on dining out by 40% can help accelerate your debt payoff.';
        }
      }
      // Entertainment recommendations
      else if (category == 'Entertainment') {
        if (totalDebt > 0) {
          recommendedSpending = currentSpending * 0.5;
          reasoning = 'Consider free entertainment options or bundle subscriptions to save money.';
        }
      }
      // Shopping recommendations
      else if (category == 'Shopping') {
        if (totalDebt > 0) {
          recommendedSpending = currentSpending * 0.3;
          reasoning = 'Pause non-essential shopping until debt is under control. This could save \$${(currentSpending - recommendedSpending).toStringAsFixed(0)}/month!';
        }
      }
      // Gas recommendations
      else if (category == 'Gas') {
        recommendedSpending = currentSpending * 0.9;
        reasoning = 'Small reductions through carpooling or planning trips can add up.';
      }

      if (recommendedSpending < currentSpending) {
        recommendations.add(BudgetRecommendation(
          category: category,
          currentSpending: currentSpending,
          recommendedSpending: recommendedSpending,
          potentialSavings: currentSpending - recommendedSpending,
          reasoning: reasoning,
        ));
      }
    }

    return recommendations;
  }

  // Calculate total potential savings
  static double calculateTotalPotentialSavings(List<BudgetRecommendation> recommendations) {
    return recommendations.fold(0.0, (sum, rec) => sum + rec.potentialSavings);
  }

  // Generate AI-powered insights summary
  static Future<String> generateAISummary(
    List<SpendingPattern> patterns,
    List<Subscription> subscriptions,
    List<BudgetRecommendation> recommendations,
    List<Debt> debts,
    UserFinancialData financialData,
  ) async {
    final totalDebt = debts.fold(0.0, (sum, debt) => sum + debt.currentBalance);
    final totalSubscriptions = subscriptions.fold(0.0, (sum, sub) => sum + sub.monthlyCost);
    final totalSavings = calculateTotalPotentialSavings(recommendations);

    String summary = '';

    if (totalDebt > 0) {
      summary += 'I noticed you have \$${totalDebt.toStringAsFixed(0)} in debt. ';
    }

    if (subscriptions.isNotEmpty) {
      summary += 'You have ${subscriptions.length} active subscription${subscriptions.length > 1 ? 's' : ''} costing \$${totalSubscriptions.toStringAsFixed(0)}/month. ';
      
      // Find forgotten subscriptions
      final inactiveSubs = subscriptions.where((s) => !s.isActive).toList();
      if (inactiveSubs.isNotEmpty) {
        summary += 'You might want to cancel ${inactiveSubs.length} subscription${inactiveSubs.length > 1 ? 's' : ''} you\'re not actively using. ';
      }
    }

    if (patterns.isNotEmpty) {
      final problematicPattern = patterns.firstWhere(
        (p) => p.monthlyAverage > 200,
        orElse: () => patterns.first,
      );
      summary += 'Your ${problematicPattern.category.toLowerCase()} spending is \$${problematicPattern.monthlyAverage.toStringAsFixed(0)}/month. ';
    }

    if (totalSavings > 0) {
      summary += 'By following these recommendations, you could save \$${totalSavings.toStringAsFixed(0)}/month, which could help pay off your debt ${(totalDebt / totalSavings).toStringAsFixed(0)} months faster!';
    }

    return summary.isEmpty
        ? 'Your spending looks balanced! Keep up the good work.'
        : summary;
  }
}

