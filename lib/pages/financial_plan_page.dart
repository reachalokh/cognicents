import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../main.dart';

/// Financial Plan Page - View your complete financial plan
/// Shows income allocation, debt distribution, payoff projections, and actionable insights
class FinancialPlanPage extends StatefulWidget {
  const FinancialPlanPage({super.key});

  @override
  State<FinancialPlanPage> createState() => _FinancialPlanPageState();
}

class _FinancialPlanPageState extends State<FinancialPlanPage> {
  bool _isLoading = true;
  List<Debt> _debts = [];
  UserFinancialData? _financialData;
  double _extraPaymentAmount = 0; // User-adjustable extra payment
  String? _selectedDebtId; // Which debt gets extra payment

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _debts = await DataService.getDebts();
    _financialData = await DataService.getFinancialData();
    setState(() => _isLoading = false);
  }

  // Key Financial Metrics
  double get totalDebt => _debts.fold(0.0, (sum, d) => sum + d.currentBalance);
  double get totalPaid => _debts.fold(0.0, (sum, d) => sum + d.totalPaid);
  double get monthlyPayments =>
      _debts.fold(0.0, (sum, d) => sum + d.minimumPayment);
  double get monthlyIncome => _financialData?.monthlyIncome ?? 0;
  double get emergencySavings => _financialData?.emergencySavings ?? 0;

  double get monthlyExpenses {
    final expenses = _financialData?.essentialExpenses.values ?? [];
    return expenses.fold(0.0, (sum, val) => sum + val);
  }

  double get availableCash => monthlyIncome - monthlyExpenses - monthlyPayments;

  double get debtToIncomeRatio {
    if (monthlyIncome <= 0) return 0;
    return (totalDebt / (monthlyIncome * 12)) * 100;
  }

  double get averageInterestRate {
    if (_debts.isEmpty) return 0;
    return _debts.fold(0.0, (sum, d) => sum + d.interestRate) / _debts.length;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Your Financial Plan'),
          backgroundColor: const Color(0xFF4A90E2),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final hasDebts = _debts.isNotEmpty;
    final hasFinancialData = _financialData != null && monthlyIncome > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Financial Plan'),
        backgroundColor: const Color(0xFF4A90E2),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Header
              _buildSummaryHeader(),
              const SizedBox(height: 20),

              // Income Allocation Chart
              if (hasFinancialData) ...[
                _buildIncomeAllocationChart(),
                const SizedBox(height: 20),
              ],

              // Debt Distribution Chart
              if (hasDebts) ...[
                _buildDebtDistributionChart(),
                const SizedBox(height: 20),
              ],

              // Payoff Strategy Selector & Projections
              if (hasDebts) ...[
                _buildPayoffStrategySection(),
                const SizedBox(height: 20),
              ],

              // Monthly Budget Summary
              if (hasFinancialData) ...[
                _buildBudgetSummary(),
                const SizedBox(height: 20),
              ],

              // Personalized Recommendations
              _buildRecommendations(),
              const SizedBox(height: 20),

              // Empty state for no data
              if (!hasDebts && !hasFinancialData) _buildEmptyState(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A90E2), Color(0xFF357ABD)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A90E2).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildHeaderStat('Total Debt',
                  '\$${totalDebt.toStringAsFixed(0)}', Icons.credit_card),
              Container(width: 1, height: 50, color: Colors.white24),
              _buildHeaderStat(
                  'Monthly',
                  '\$${monthlyPayments.toStringAsFixed(0)}',
                  Icons.calendar_today),
              Container(width: 1, height: 50, color: Colors.white24),
              _buildHeaderStat('Paid Off', '\$${totalPaid.toStringAsFixed(0)}',
                  Icons.check_circle),
            ],
          ),
          const SizedBox(height: 16),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (totalPaid / (totalDebt + totalPaid + 1)).clamp(0, 1),
              minHeight: 10,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            totalDebt + totalPaid > 0
                ? '${((totalPaid / (totalDebt + totalPaid)) * 100).toStringAsFixed(0)}% of debt paid off'
                : 'Start adding debts to track progress',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStat(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomeAllocationChart() {
    final expenses = monthlyExpenses;
    final debtPayments = monthlyPayments;
    final available =
        (monthlyIncome - expenses - debtPayments).clamp(0.0, double.infinity);
    final total = monthlyIncome > 0 ? monthlyIncome : 1;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pie_chart,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text(
                  'Monthly Income Allocation',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 45,
                  sections: [
                    PieChartSectionData(
                      value: expenses,
                      title: '${(expenses / total * 100).toStringAsFixed(0)}%',
                      color: Colors.blue,
                      radius: 55,
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    PieChartSectionData(
                      value: debtPayments,
                      title:
                          '${(debtPayments / total * 100).toStringAsFixed(0)}%',
                      color: Colors.orange,
                      radius: 55,
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    PieChartSectionData(
                      value: available > 0 ? available : 0.01,
                      title: available > 0
                          ? '${(available / total * 100).toStringAsFixed(0)}%'
                          : '',
                      color: Colors.green,
                      radius: 55,
                      titleStyle: const TextStyle(
                        color: Colors.white,
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
                _buildLegendItem('Expenses', '\$${expenses.toStringAsFixed(0)}',
                    Colors.blue),
                _buildLegendItem('Debt', '\$${debtPayments.toStringAsFixed(0)}',
                    Colors.orange),
                _buildLegendItem('Available',
                    '\$${available.toStringAsFixed(0)}', Colors.green),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, String value, Color color) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          ],
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildDebtDistributionChart() {
    // Group debts by type
    final debtsByType = <String, double>{};
    for (var debt in _debts) {
      final type = debt.type.isNotEmpty ? debt.type : 'Other';
      debtsByType[type] = (debtsByType[type] ?? 0) + debt.currentBalance;
    }

    final sortedDebts = debtsByType.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final colors = [
      Colors.red,
      Colors.purple,
      Colors.indigo,
      Colors.teal,
      Colors.amber,
      Colors.pink,
      Colors.cyan,
    ];

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.donut_large,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text(
                  'Debt by Category',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 45,
                  sections: sortedDebts.asMap().entries.map((entry) {
                    final index = entry.key;
                    final debtEntry = entry.value;
                    final percentage = (debtEntry.value / totalDebt * 100);
                    return PieChartSectionData(
                      value: debtEntry.value,
                      title: percentage > 8
                          ? '${percentage.toStringAsFixed(0)}%'
                          : '',
                      color: colors[index % colors.length],
                      radius: 55,
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Legend
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: sortedDebts.asMap().entries.map((entry) {
                final index = entry.key;
                final debtEntry = entry.value;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: colors[index % colors.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${debtEntry.key}: \$${debtEntry.value.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayoffStrategySection() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timeline,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text(
                  'Payoff Projection',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Legend for the two lines
            Row(
              children: [
                _buildLegendDot('Avalanche', Colors.green),
                const SizedBox(width: 16),
                _buildLegendDot('Snowball', Colors.blue),
              ],
            ),
            const SizedBox(height: 16),
            // Projection Chart with BOTH lines
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: _calculateChartInterval(),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '\$${(value / 1000).toStringAsFixed(0)}k',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() % 6 == 0) {
                            return Text(
                              'M${value.toInt()}',
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(
                      show: true, border: Border.all(color: Colors.grey[300]!)),
                  lineBarsData: [
                    // Avalanche line (green)
                    LineChartBarData(
                      spots: _generatePayoffProjection(isAvalanche: true),
                      isCurved: true,
                      color: Colors.green,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.green.withOpacity(0.1),
                      ),
                    ),
                    // Snowball line (blue)
                    LineChartBarData(
                      spots: _generatePayoffProjection(isAvalanche: false),
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.blue.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Extra Payment Simulator
            _buildExtraPaymentSimulator(),
            const SizedBox(height: 16),
            // Strategy Comparison Summary
            _buildStrategyComparison(),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendDot(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
      ],
    );
  }

  Widget _buildExtraPaymentSimulator() {
    final maxExtra =
        (availableCash > 0 ? availableCash : 500.0).clamp(100.0, 2000.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune, size: 20, color: Colors.grey),
              const SizedBox(width: 8),
              const Text(
                'Experiment with Extra Payments',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Debt selector dropdown
          if (_debts.length > 1) ...[
            DropdownButtonFormField<String?>(
              value: _selectedDebtId,
              decoration: InputDecoration(
                labelText: 'Apply extra to specific debt',
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: Colors.white,
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('All debts (distributed)',
                      style: TextStyle(fontSize: 13)),
                ),
                ..._debts.map((d) => DropdownMenuItem(
                      value: d.id,
                      child: Text(
                        '${d.name} (\$${d.currentBalance.toStringAsFixed(0)})',
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    )),
              ],
              onChanged: (val) => setState(() => _selectedDebtId = val),
            ),
            const SizedBox(height: 12),
          ],
          // Extra payment slider
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Extra Monthly Payment',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: const Color(0xFF4A90E2),
                        thumbColor: const Color(0xFF4A90E2),
                        overlayColor: const Color(0xFF4A90E2).withOpacity(0.2),
                      ),
                      child: Slider(
                        value: _extraPaymentAmount,
                        min: 0,
                        max: maxExtra,
                        divisions: (maxExtra / 25).round(),
                        onChanged: (val) =>
                            setState(() => _extraPaymentAmount = val),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A90E2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+\$${_extraPaymentAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStrategyComparison() {
    final avalancheResult = _calculatePayoffStats(isAvalanche: true);
    final snowballResult = _calculatePayoffStats(isAvalanche: false);

    final avalancheMonths = avalancheResult['months'] as int;
    final snowballMonths = snowballResult['months'] as int;
    final avalancheInterest = avalancheResult['interest'] as double;
    final snowballInterest = snowballResult['interest'] as double;

    final monthsSaved = snowballMonths - avalancheMonths;
    final interestSaved = snowballInterest - avalancheInterest;
    final avalancheWins = avalancheMonths <= snowballMonths;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStrategyCard(
                'Avalanche',
                '${(avalancheMonths / 12).floor()}y ${avalancheMonths % 12}m',
                '\$${avalancheInterest.toStringAsFixed(0)} interest',
                Colors.green,
                avalancheWins,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStrategyCard(
                'Snowball',
                '${(snowballMonths / 12).floor()}y ${snowballMonths % 12}m',
                '\$${snowballInterest.toStringAsFixed(0)} interest',
                Colors.blue,
                !avalancheWins,
              ),
            ),
          ],
        ),
        if (monthsSaved.abs() > 0 || interestSaved.abs() > 50) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.amber[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    avalancheWins
                        ? 'Avalanche saves ${monthsSaved.abs()} months and \$${interestSaved.abs().toStringAsFixed(0)} in interest!'
                        : 'Snowball is faster! Consider it for motivation.',
                    style: TextStyle(fontSize: 12, color: Colors.amber[900]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStrategyCard(
      String name, String time, String interest, Color color, bool isWinner) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: isWinner ? Border.all(color: color, width: 2) : null,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                name,
                style: TextStyle(fontWeight: FontWeight.bold, color: color),
              ),
              if (isWinner) ...[
                const SizedBox(width: 4),
                Icon(Icons.star, color: color, size: 16),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            time,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(
            interest,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  double _calculateChartInterval() {
    if (totalDebt <= 1000) return 200;
    if (totalDebt <= 5000) return 1000;
    if (totalDebt <= 20000) return 5000;
    if (totalDebt <= 50000) return 10000;
    return 20000;
  }

  List<FlSpot> _generatePayoffProjection({required bool isAvalanche}) {
    final spots = <FlSpot>[];

    // Create a sorted copy of debts for the chosen strategy
    final sortedDebts = List<Map<String, dynamic>>.from(
      _debts.map((d) => {
            'id': d.id,
            'balance': d.currentBalance.toDouble(),
            'rate': d.interestRate,
            'minPayment': d.minimumPayment,
          }),
    );

    if (isAvalanche) {
      // Sort by interest rate (highest first)
      sortedDebts
          .sort((a, b) => (b['rate'] as double).compareTo(a['rate'] as double));
    } else {
      // Sort by balance (smallest first)
      sortedDebts.sort(
          (a, b) => (a['balance'] as double).compareTo(b['balance'] as double));
    }

    double totalRemaining = totalDebt;
    spots.add(FlSpot(0, totalRemaining));

    for (int month = 1; month <= 60; month++) {
      double extraAvailable = _extraPaymentAmount;

      for (var debt in sortedDebts) {
        if ((debt['balance'] as double) <= 0) continue;

        // Apply interest
        final monthlyInterest =
            (debt['balance'] as double) * ((debt['rate'] as double) / 100 / 12);
        debt['balance'] = (debt['balance'] as double) + monthlyInterest;

        // Apply minimum payment
        debt['balance'] =
            ((debt['balance'] as double) - (debt['minPayment'] as double))
                .clamp(0.0, double.infinity);

        // Apply extra payment to target debt (strategy focus)
        if (_selectedDebtId == null || _selectedDebtId == debt['id']) {
          final extraToApply =
              extraAvailable.clamp(0.0, debt['balance'] as double);
          debt['balance'] = (debt['balance'] as double) - extraToApply;
          extraAvailable -= extraToApply;
        }
      }

      totalRemaining =
          sortedDebts.fold(0.0, (sum, d) => sum + (d['balance'] as double));
      spots.add(FlSpot(month.toDouble(), totalRemaining));

      if (totalRemaining <= 0) break;
    }

    return spots;
  }

  Map<String, dynamic> _calculatePayoffStats({required bool isAvalanche}) {
    final sortedDebts = List<Map<String, dynamic>>.from(
      _debts.map((d) => {
            'id': d.id,
            'balance': d.currentBalance.toDouble(),
            'rate': d.interestRate,
            'minPayment': d.minimumPayment,
          }),
    );

    if (isAvalanche) {
      sortedDebts
          .sort((a, b) => (b['rate'] as double).compareTo(a['rate'] as double));
    } else {
      sortedDebts.sort(
          (a, b) => (a['balance'] as double).compareTo(b['balance'] as double));
    }

    double totalInterestPaid = 0;
    int months = 0;

    while (
        sortedDebts.any((d) => (d['balance'] as double) > 0) && months < 360) {
      months++;
      double extraAvailable = _extraPaymentAmount;

      for (var debt in sortedDebts) {
        if ((debt['balance'] as double) <= 0) continue;

        final monthlyInterest =
            (debt['balance'] as double) * ((debt['rate'] as double) / 100 / 12);
        totalInterestPaid += monthlyInterest;
        debt['balance'] = (debt['balance'] as double) + monthlyInterest;
        debt['balance'] =
            ((debt['balance'] as double) - (debt['minPayment'] as double))
                .clamp(0.0, double.infinity);

        if (_selectedDebtId == null || _selectedDebtId == debt['id']) {
          final extraToApply =
              extraAvailable.clamp(0.0, debt['balance'] as double);
          debt['balance'] = (debt['balance'] as double) - extraToApply;
          extraAvailable -= extraToApply;
        }
      }
    }

    return {'months': months, 'interest': totalInterestPaid};
  }

  Widget _buildBudgetSummary() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_balance_wallet,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text(
                  'Monthly Budget Summary',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildBudgetRow('Income', monthlyIncome, Colors.green),
            const Divider(height: 24),
            _buildBudgetRow(
                'Essential Expenses', -monthlyExpenses, Colors.blue),
            _buildBudgetRow('Debt Payments', -monthlyPayments, Colors.orange),
            const Divider(height: 24),
            _buildBudgetRow(
              'Available',
              availableCash,
              availableCash >= 0 ? Colors.green : Colors.red,
              isBold: true,
            ),
            const SizedBox(height: 16),
            // Debt-to-Income Ratio
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    debtToIncomeRatio > 35 ? Colors.red[50] : Colors.green[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    debtToIncomeRatio > 35 ? Icons.warning : Icons.check_circle,
                    color: debtToIncomeRatio > 35
                        ? Colors.red[700]
                        : Colors.green[700],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Debt-to-Income Ratio: ${debtToIncomeRatio.toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: debtToIncomeRatio > 35
                            ? Colors.red[900]
                            : Colors.green[900],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    debtToIncomeRatio > 35 ? 'High' : 'Healthy',
                    style: TextStyle(
                      color: debtToIncomeRatio > 35
                          ? Colors.red[700]
                          : Colors.green[700],
                      fontSize: 12,
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

  Widget _buildBudgetRow(String label, double amount, Color color,
      {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '${amount >= 0 ? '+' : ''}\$${amount.abs().toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendations() {
    final recommendations = <_Recommendation>[];

    // Emergency fund recommendation
    final monthsOfSavings =
        monthlyExpenses > 0 ? emergencySavings / monthlyExpenses : 0;
    if (monthsOfSavings < 3) {
      recommendations.add(_Recommendation(
        icon: Icons.savings,
        title: 'Build Emergency Fund',
        description:
            'You have ${monthsOfSavings.toStringAsFixed(1)} months saved. Aim for 3-6 months of expenses.',
        color: Colors.blue,
        priority: 1,
      ));
    }

    // High interest debt warning
    final highInterestDebts = _debts.where((d) => d.interestRate > 15).toList();
    if (highInterestDebts.isNotEmpty) {
      recommendations.add(_Recommendation(
        icon: Icons.warning_amber,
        title: 'Tackle High Interest Debt',
        description:
            '${highInterestDebts.length} debt(s) above 15% APR. Prioritize these to save on interest.',
        color: Colors.red,
        priority: 1,
      ));
    }

    // Extra payment recommendation
    if (availableCash > 100) {
      recommendations.add(_Recommendation(
        icon: Icons.add_circle,
        title: 'Make Extra Payments',
        description:
            'You have \$${availableCash.toStringAsFixed(0)}/month available. Extra payments accelerate debt payoff.',
        color: Colors.green,
        priority: 2,
      ));
    }

    // Debt consolidation suggestion
    if (_debts.length > 3 && averageInterestRate > 10) {
      recommendations.add(_Recommendation(
        icon: Icons.merge_type,
        title: 'Consider Consolidation',
        description:
            'With ${_debts.length} debts at ${averageInterestRate.toStringAsFixed(1)}% avg APR, consolidation may help.',
        color: Colors.purple,
        priority: 3,
      ));
    }

    if (recommendations.isEmpty) {
      recommendations.add(_Recommendation(
        icon: Icons.check_circle,
        title: 'You\'re On Track!',
        description: 'Keep up the great work with your financial plan.',
        color: Colors.green,
        priority: 1,
      ));
    }

    recommendations.sort((a, b) => a.priority.compareTo(b.priority));

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text(
                  'Recommendations',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...recommendations.map((rec) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: rec.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border(left: BorderSide(color: rec.color, width: 4)),
                  ),
                  child: Row(
                    children: [
                      Icon(rec.icon, color: rec.color, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rec.title,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              rec.description,
                              style: TextStyle(
                                  color: Colors.grey[700], fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.analytics, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No Financial Data Yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your debts and financial information to see your personalized plan.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Debts'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A90E2),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Recommendation {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final int priority;

  _Recommendation({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.priority,
  });
}
