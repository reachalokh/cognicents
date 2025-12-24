import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

/// Progress Page - Track savings and solvency journey
/// Focuses on the path to financial freedom with milestones and achievements
class ProgressPage extends StatefulWidget {
  final List<dynamic> debts;
  final dynamic financialData;

  const ProgressPage({
    super.key,
    required this.debts,
    this.financialData,
  });

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  int _selectedView = 0; // 0: Journey, 1: Milestones, 2: Insights

  // Calculate key financial metrics
  double get totalDebt =>
      widget.debts.fold(0.0, (sum, debt) => sum + (debt.currentBalance ?? 0));

  double get totalPaid =>
      widget.debts.fold(0.0, (sum, debt) => sum + (debt.totalPaid ?? 0));

  double get emergencySavings => widget.financialData?.emergencySavings ?? 0.0;

  double get monthlyIncome => widget.financialData?.monthlyIncome ?? 0.0;

  double get monthlyExpenses {
    final expenses = widget.financialData?.essentialExpenses?.values ?? [];
    return expenses.fold(0.0, (sum, val) => sum + val);
  }

  double get debtPayments =>
      widget.debts.fold(0.0, (sum, debt) => sum + (debt.minimumPayment ?? 0));

  double get netWorth => emergencySavings - totalDebt;

  double get debtToIncomeRatio {
    if (monthlyIncome <= 0) return 0;
    return (totalDebt / (monthlyIncome * 12)) * 100;
  }

  int get solvencyScore {
    // Calculate a 0-100 solvency score based on multiple factors
    double score = 50; // Base score

    // Net worth factor (-20 to +20)
    if (netWorth >= 0) {
      score += 20;
    } else if (netWorth > -10000) {
      score += 10;
    } else if (netWorth > -50000) {
      score -= 5;
    } else {
      score -= 15;
    }

    // Debt-to-income ratio factor (-15 to +15)
    if (debtToIncomeRatio <= 10) {
      score += 15;
    } else if (debtToIncomeRatio <= 20) {
      score += 10;
    } else if (debtToIncomeRatio <= 35) {
      score += 0;
    } else if (debtToIncomeRatio <= 50) {
      score -= 10;
    } else {
      score -= 15;
    }

    // Emergency fund factor (-10 to +15)
    final monthsOfExpenses =
        monthlyExpenses > 0 ? emergencySavings / monthlyExpenses : 0;
    if (monthsOfExpenses >= 6) {
      score += 15;
    } else if (monthsOfExpenses >= 3) {
      score += 10;
    } else if (monthsOfExpenses >= 1) {
      score += 0;
    } else {
      score -= 10;
    }

    // Payment progress factor (0 to +10)
    final totalOriginalDebt = totalDebt + totalPaid;
    if (totalOriginalDebt > 0) {
      final progressPct = totalPaid / totalOriginalDebt;
      score += (progressPct * 10);
    }

    return score.clamp(0, 100).round();
  }

  String get solvencyLabel {
    if (solvencyScore >= 80) return 'Excellent';
    if (solvencyScore >= 60) return 'Good';
    if (solvencyScore >= 40) return 'Fair';
    if (solvencyScore >= 20) return 'Needs Work';
    return 'Critical';
  }

  Color get solvencyColor {
    if (solvencyScore >= 80) return Colors.green;
    if (solvencyScore >= 60) return Colors.lightGreen;
    if (solvencyScore >= 40) return Colors.amber;
    if (solvencyScore >= 20) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Your Journey'),
        backgroundColor: const Color(0xFF4A90E2),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // View selector
            _buildViewSelector(),
            // Content based on selected view
            Expanded(
              child: IndexedStack(
                index: _selectedView,
                children: [
                  _buildJourneyView(),
                  _buildMilestonesView(),
                  _buildInsightsView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewSelector() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildViewTab(0, 'Journey', Icons.route),
          _buildViewTab(1, 'Milestones', Icons.flag),
          _buildViewTab(2, 'Insights', Icons.lightbulb),
        ],
      ),
    );
  }

  Widget _buildViewTab(int index, String label, IconData icon) {
    final isSelected = _selectedView == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedView = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.1), blurRadius: 4)
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey[600],
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== JOURNEY VIEW ====================
  Widget _buildJourneyView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Solvency Score Card
          _buildSolvencyScoreCard(),
          const SizedBox(height: 16),
          // Net Worth Card
          _buildNetWorthCard(),
          const SizedBox(height: 16),
          // Progress Chart
          _buildProgressChart(),
          const SizedBox(height: 16),
          // Quick Stats Row
          _buildQuickStatsRow(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSolvencyScoreCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              solvencyColor.withOpacity(0.8),
              solvencyColor,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.shield, color: Colors.white, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Solvency Score',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    solvencyLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 140,
                  height: 140,
                  child: CircularProgressIndicator(
                    value: solvencyScore / 100,
                    strokeWidth: 12,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                Column(
                  children: [
                    Text(
                      '$solvencyScore',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'out of 100',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _getSolvencyAdvice(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getSolvencyAdvice() {
    if (solvencyScore >= 80) {
      return "Outstanding! You're on a great path to financial freedom.";
    } else if (solvencyScore >= 60) {
      return "Good progress! Keep building savings and paying down debt.";
    } else if (solvencyScore >= 40) {
      return "You're making progress. Focus on building an emergency fund.";
    } else if (solvencyScore >= 20) {
      return "Stay focused on reducing debt and tracking expenses.";
    }
    return "Start with small steps - track spending and make minimum payments.";
  }

  Widget _buildNetWorthCard() {
    final isPositive = netWorth >= 0;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isPositive ? Icons.trending_up : Icons.trending_down,
                  color: isPositive ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Net Worth',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '${isPositive ? '+' : ''}\$${netWorth.abs().toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: isPositive ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 16),
            // Assets vs Liabilities bar
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Savings',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$${emergencySavings.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.grey[300],
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Total Debt',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$${totalDebt.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Visual balance bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (emergencySavings / (emergencySavings + totalDebt + 1))
                    .clamp(0, 1),
                minHeight: 8,
                backgroundColor: Colors.red.withOpacity(0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressChart() {
    final originalDebt = totalDebt + totalPaid;
    final progressPercent =
        originalDebt > 0 ? (totalPaid / originalDebt * 100) : 0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Debt Payoff Progress',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 50,
                  sections: [
                    PieChartSectionData(
                      value: totalPaid,
                      title: 'Paid\n${progressPercent.toStringAsFixed(0)}%',
                      color: Colors.green,
                      radius: 50,
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    PieChartSectionData(
                      value: totalDebt > 0 ? totalDebt : 1,
                      title: 'Remaining',
                      color: Colors.grey[300],
                      radius: 50,
                      titleStyle: TextStyle(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildProgressStat('Paid Off',
                    '\$${totalPaid.toStringAsFixed(0)}', Colors.green),
                _buildProgressStat('Remaining',
                    '\$${totalDebt.toStringAsFixed(0)}', Colors.grey),
                _buildProgressStat('Original',
                    '\$${originalDebt.toStringAsFixed(0)}', Colors.blue),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressStat(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildQuickStatCard(
            icon: Icons.credit_card,
            label: 'Debts',
            value: '${widget.debts.length}',
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildQuickStatCard(
            icon: Icons.payments,
            label: 'Monthly',
            value: '\$${debtPayments.toStringAsFixed(0)}',
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildQuickStatCard(
            icon: Icons.percent,
            label: 'DTI Ratio',
            value: '${debtToIncomeRatio.toStringAsFixed(0)}%',
            color: debtToIncomeRatio > 35 ? Colors.red : Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== MILESTONES VIEW ====================
  Widget _buildMilestonesView() {
    final milestones = _generateMilestones();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Financial Milestones',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Track your journey to financial freedom',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),
          ...milestones.map((milestone) => _buildMilestoneCard(milestone)),
        ],
      ),
    );
  }

  List<_Milestone> _generateMilestones() {
    final originalDebt = totalDebt + totalPaid;
    final progressPercent =
        originalDebt > 0 ? (totalPaid / originalDebt * 100) : 0;
    final monthsOfEmergencyFund =
        monthlyExpenses > 0 ? emergencySavings / monthlyExpenses : 0;

    return [
      _Milestone(
        title: 'First Payment Made',
        description: 'Made your first debt payment',
        icon: Icons.celebration,
        isCompleted: totalPaid > 0,
        color: Colors.purple,
      ),
      _Milestone(
        title: '10% Debt Paid',
        description: 'Paid off 10% of your total debt',
        icon: Icons.trending_down,
        isCompleted: progressPercent >= 10,
        progress: (progressPercent / 10).clamp(0, 1),
        color: Colors.blue,
      ),
      _Milestone(
        title: '25% Debt Paid',
        description: 'A quarter of your debt is gone!',
        icon: Icons.pie_chart,
        isCompleted: progressPercent >= 25,
        progress: (progressPercent / 25).clamp(0, 1),
        color: Colors.teal,
      ),
      _Milestone(
        title: '1 Month Emergency Fund',
        description: 'Saved 1 month of expenses',
        icon: Icons.savings,
        isCompleted: monthsOfEmergencyFund >= 1,
        progress: monthsOfEmergencyFund.clamp(0.0, 1.0).toDouble(),
        color: Colors.green,
      ),
      _Milestone(
        title: '50% Debt Paid',
        description: 'Halfway there! Keep going!',
        icon: Icons.flag,
        isCompleted: progressPercent >= 50,
        progress: (progressPercent / 50).clamp(0, 1),
        color: Colors.amber,
      ),
      _Milestone(
        title: '3 Month Emergency Fund',
        description: 'Built a solid safety net',
        icon: Icons.shield,
        isCompleted: monthsOfEmergencyFund >= 3,
        progress: (monthsOfEmergencyFund / 3).clamp(0, 1),
        color: Colors.cyan,
      ),
      _Milestone(
        title: '75% Debt Paid',
        description: 'The finish line is in sight!',
        icon: Icons.sports_score,
        isCompleted: progressPercent >= 75,
        progress: (progressPercent / 75).clamp(0, 1),
        color: Colors.orange,
      ),
      _Milestone(
        title: 'Debt Free!',
        description: 'All debts have been paid off',
        icon: Icons.emoji_events,
        isCompleted: totalDebt == 0 && totalPaid > 0,
        progress: (progressPercent / 100).clamp(0, 1),
        color: Colors.yellow[700]!,
      ),
      _Milestone(
        title: 'Positive Net Worth',
        description: 'Your savings exceed your debts',
        icon: Icons.star,
        isCompleted: netWorth > 0,
        color: Colors.green[700]!,
      ),
      _Milestone(
        title: '6 Month Emergency Fund',
        description: 'Fully funded emergency savings',
        icon: Icons.workspace_premium,
        isCompleted: monthsOfEmergencyFund >= 6,
        progress: (monthsOfEmergencyFund / 6).clamp(0, 1),
        color: Colors.indigo,
      ),
    ];
  }

  Widget _buildMilestoneCard(_Milestone milestone) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: milestone.isCompleted ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: milestone.isCompleted
            ? BorderSide(color: milestone.color, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color:
                    milestone.isCompleted ? milestone.color : Colors.grey[200],
                shape: BoxShape.circle,
              ),
              child: Icon(
                milestone.isCompleted ? milestone.icon : Icons.lock_outline,
                color: milestone.isCompleted ? Colors.white : Colors.grey[400],
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    milestone.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: milestone.isCompleted
                          ? Colors.black
                          : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    milestone.description,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                  if (milestone.progress != null && !milestone.isCompleted) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: milestone.progress!,
                        minHeight: 6,
                        backgroundColor: Colors.grey[200],
                        valueColor:
                            AlwaysStoppedAnimation<Color>(milestone.color),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (milestone.isCompleted)
              Icon(Icons.check_circle, color: milestone.color, size: 28),
          ],
        ),
      ),
    );
  }

  // ==================== INSIGHTS VIEW ====================
  Widget _buildInsightsView() {
    final insights = _generateInsights();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Financial Insights',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Personalized tips based on your situation',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),
          ...insights.map((insight) => _buildInsightCard(insight)),
          const SizedBox(height: 16),
          // Key Metrics
          _buildKeyMetricsCard(),
        ],
      ),
    );
  }

  List<_Insight> _generateInsights() {
    final insights = <_Insight>[];
    final monthsOfEmergencyFund =
        monthlyExpenses > 0 ? emergencySavings / monthlyExpenses : 0;

    // Emergency fund insight
    if (monthsOfEmergencyFund < 1) {
      insights.add(_Insight(
        icon: Icons.warning_amber,
        title: 'Build Emergency Fund',
        description:
            'Aim to save at least 1 month of expenses (\$${monthlyExpenses.toStringAsFixed(0)}) for unexpected costs.',
        color: Colors.orange,
        priority: 1,
      ));
    } else if (monthsOfEmergencyFund < 3) {
      insights.add(_Insight(
        icon: Icons.savings,
        title: 'Grow Your Safety Net',
        description:
            'You have ${monthsOfEmergencyFund.toStringAsFixed(1)} months saved. Target 3-6 months for security.',
        color: Colors.blue,
        priority: 2,
      ));
    }

    // Debt-to-income ratio insight
    if (debtToIncomeRatio > 35) {
      insights.add(_Insight(
        icon: Icons.trending_down,
        title: 'High Debt-to-Income Ratio',
        description:
            'Your DTI is ${debtToIncomeRatio.toStringAsFixed(0)}%. Aim to get below 35% for better financial health.',
        color: Colors.red,
        priority: 1,
      ));
    } else if (debtToIncomeRatio > 20) {
      insights.add(_Insight(
        icon: Icons.info,
        title: 'Manageable Debt Load',
        description:
            'Your DTI is ${debtToIncomeRatio.toStringAsFixed(0)}%. Keep paying down to reach the ideal 20% or less.',
        color: Colors.amber,
        priority: 3,
      ));
    }

    // Net worth insight
    if (netWorth < 0) {
      insights.add(_Insight(
        icon: Icons.balance,
        title: 'Path to Positive Net Worth',
        description:
            'You\'re \$${(-netWorth).toStringAsFixed(0)} away from positive net worth. Every payment helps!',
        color: Colors.purple,
        priority: 2,
      ));
    }

    // Available cash flow insight
    final availableCash = monthlyIncome - monthlyExpenses - debtPayments;
    if (availableCash > 0) {
      insights.add(_Insight(
        icon: Icons.attach_money,
        title: 'Monthly Surplus',
        description:
            'You have \$${availableCash.toStringAsFixed(0)} available each month. Consider extra debt payments or savings.',
        color: Colors.green,
        priority: 3,
      ));
    } else if (availableCash < 0) {
      insights.add(_Insight(
        icon: Icons.warning,
        title: 'Budget Shortfall',
        description:
            'Expenses exceed income by \$${(-availableCash).toStringAsFixed(0)}. Review spending for areas to cut.',
        color: Colors.red,
        priority: 1,
      ));
    }

    // Sort by priority
    insights.sort((a, b) => a.priority.compareTo(b.priority));
    return insights;
  }

  Widget _buildInsightCard(_Insight insight) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border(
            left: BorderSide(color: insight.color, width: 4),
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: insight.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(insight.icon, color: insight.color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    insight.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    insight.description,
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyMetricsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Key Metrics',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildMetricRow(
                'Monthly Income',
                '\$${monthlyIncome.toStringAsFixed(0)}',
                Icons.account_balance_wallet),
            _buildMetricRow('Monthly Expenses',
                '\$${monthlyExpenses.toStringAsFixed(0)}', Icons.shopping_cart),
            _buildMetricRow('Debt Payments',
                '\$${debtPayments.toStringAsFixed(0)}', Icons.credit_card),
            _buildMetricRow(
                'Available Cash',
                '\$${(monthlyIncome - monthlyExpenses - debtPayments).toStringAsFixed(0)}',
                Icons.money),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

// Helper classes
class _Milestone {
  final String title;
  final String description;
  final IconData icon;
  final bool isCompleted;
  final double? progress;
  final Color color;

  _Milestone({
    required this.title,
    required this.description,
    required this.icon,
    required this.isCompleted,
    this.progress,
    required this.color,
  });
}

class _Insight {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final int priority;

  _Insight({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.priority,
  });
}
