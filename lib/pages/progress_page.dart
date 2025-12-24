import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

// Progress Tracking Page with debt tabs, payment history, and charts
class ProgressPage extends StatefulWidget {
  final List<dynamic> debts; // List of Debt objects
  final dynamic financialData; // UserFinancialData object

  const ProgressPage({
    super.key,
    required this.debts,
    this.financialData,
  });

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, int> paymentsCount = {}; // Track payment count per debt ID
  String _selectedChartType =
      'overview'; // 'overview', 'debt', 'payments', 'savings'

  @override
  void initState() {
    super.initState();
    final debtList =
        widget.debts.isEmpty ? [_createTemplatDebt()] : widget.debts;
    _tabController = TabController(length: debtList.length, vsync: this);
    // Initialize payment counts from payment history
    for (var debt in debtList) {
      paymentsCount[debt.id] = debt.paymentHistory?.length ?? 0;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  dynamic _createTemplatDebt() {
    // Create a template debt object for display when no debts exist
    return {
      'id': 'template',
      'name': 'Example Debt',
      'type': 'Credit Card',
      'currentBalance': 5000.0,
      'interestRate': 18.5,
      'minimumPayment': 150.0,
      'dueDate': null,
      'lenderName': 'Example Bank',
      'totalPaid': 0.0,
      'paymentHistory': [],
    };
  }

  List<PieChartSectionData> _generateIncomeChart() {
    final monthlyIncome = widget.financialData?.monthlyIncome ?? 0.0;
    if (monthlyIncome <= 0) {
      return [
        PieChartSectionData(
          value: 100,
          title: 'No Data',
          color: Colors.grey[300],
        ),
      ];
    }

    final essentialExpenses = widget.financialData?.essentialExpenses.values
            .fold(0.0, (sum, val) => sum + val) ??
        0;
    final debtPayments =
        widget.debts.fold(0.0, (sum, debt) => sum + debt.minimumPayment);
    final remaining = (monthlyIncome - essentialExpenses - debtPayments)
        .clamp(0, double.infinity);

    return [
      PieChartSectionData(
        value: essentialExpenses,
        title: 'Essential\nExpenses\n\$${essentialExpenses.toStringAsFixed(0)}',
        color: Colors.blue,
        radius: 80,
      ),
      PieChartSectionData(
        value: debtPayments,
        title: 'Debt\nPayments\n\$${debtPayments.toStringAsFixed(0)}',
        color: Colors.orange,
        radius: 80,
      ),
      PieChartSectionData(
        value: remaining,
        title: 'Available/\nSavings\n\$${remaining.toStringAsFixed(0)}',
        color: Colors.green,
        radius: 80,
      ),
    ];
  }

  // Generate debt balance over time data
  List<FlSpot> _generateDebtBalanceOverTime(dynamic debt) {
    final spots = <FlSpot>[];
    final paymentHistory = (debt.paymentHistory as List?) ?? [];

    if (paymentHistory.isEmpty) {
      // Generate mock data if no history
      double balance = debt.currentBalance + (debt.totalPaid ?? 0);
      spots.add(FlSpot(0, balance));

      for (int i = 1; i <= 6; i++) {
        final monthsAgo = 6 - i;
        balance -=
            ((debt.minimumPayment ?? 150) * (monthsAgo + 1) * 0.3).toDouble();
        spots.add(FlSpot(i.toDouble(), balance.clamp(0, double.infinity)));
      }
    } else {
      // Use actual payment history
      paymentHistory.sort((a, b) => a.date.compareTo(b.date));
      double runningBalance = debt.currentBalance + (debt.totalPaid ?? 0);
      spots.add(FlSpot(0, runningBalance));

      for (int i = 0; i < paymentHistory.length && i < 12; i++) {
        final payment = paymentHistory[i];
        runningBalance -= payment.amount;
        spots.add(FlSpot(
            (i + 1).toDouble(), runningBalance.clamp(0, double.infinity)));
      }
    }

    return spots;
  }

  // Generate payment trends data
  List<FlSpot> _generatePaymentTrends(dynamic debt) {
    final spots = <FlSpot>[];
    final paymentHistory = (debt.paymentHistory as List?) ?? [];

    if (paymentHistory.isEmpty) {
      // Generate mock data
      for (int i = 0; i < 6; i++) {
        spots.add(FlSpot(i.toDouble(),
            (debt.minimumPayment ?? 150) * (0.8 + (i % 3) * 0.1)));
      }
    } else {
      paymentHistory.sort((a, b) => a.date.compareTo(b.date));
      final recentPayments = paymentHistory.length > 12
          ? paymentHistory.sublist(paymentHistory.length - 12)
          : paymentHistory;

      for (int i = 0; i < recentPayments.length; i++) {
        spots.add(FlSpot(i.toDouble(), recentPayments[i].amount));
      }
    }

    return spots;
  }

  // Generate overall debt reduction data
  List<FlSpot> _generateOverallDebtReduction() {
    final spots = <FlSpot>[];
    double totalDebt =
        widget.debts.fold(0.0, (sum, debt) => sum + (debt.currentBalance ?? 0));
    double totalPaid =
        widget.debts.fold(0.0, (sum, debt) => sum + (debt.totalPaid ?? 0));
    double initialDebt = totalDebt + totalPaid;

    spots.add(FlSpot(0, initialDebt));

    // Generate monthly progression
    for (int i = 1; i <= 12; i++) {
      final monthlyPayment = widget.debts
          .fold(0.0, (sum, debt) => sum + (debt.minimumPayment ?? 0));
      final projectedDebt = (initialDebt - (monthlyPayment * i.toDouble()))
          .clamp(0.0, double.infinity);
      spots.add(FlSpot(i.toDouble(), projectedDebt.toDouble()));
    }

    return spots;
  }

  // Generate savings growth data
  List<FlSpot> _generateSavingsGrowth() {
    final spots = <FlSpot>[];
    final currentSavings = widget.financialData?.emergencySavings ?? 0.0;
    final monthlySavingsTarget =
        widget.financialData?.monthlySavingsTarget ?? 0.0;

    spots.add(FlSpot(0, currentSavings));

    for (int i = 1; i <= 12; i++) {
      final projectedSavings = currentSavings + (monthlySavingsTarget * i);
      spots.add(FlSpot(i.toDouble(), projectedSavings));
    }

    return spots;
  }

  @override
  Widget build(BuildContext context) {
    final debtList =
        widget.debts.isEmpty ? [_createTemplatDebt()] : widget.debts;

    return DefaultTabController(
      length: debtList.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Progress Tracking'),
          foregroundColor: Colors.white,
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: debtList
                .map((debt) => Tab(
                      text: debt.name,
                      icon: const Icon(Icons.attach_money),
                    ))
                .toList(),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Chart type selector
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildChartTypeButton('Overview', 'overview'),
                      const SizedBox(width: 8),
                      _buildChartTypeButton('Debt Trends', 'debt'),
                      const SizedBox(width: 8),
                      _buildChartTypeButton('Payments', 'payments'),
                      const SizedBox(width: 8),
                      _buildChartTypeButton('Savings', 'savings'),
                    ],
                  ),
                ),
              ),
              // Income allocation pie chart (Overview)
              if (_selectedChartType == 'overview')
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Monthly Income Allocation',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 250,
                            child: PieChart(
                              PieChartData(
                                sections: _generateIncomeChart(),
                                centerSpaceRadius: 40,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              // Overall debt reduction chart
              if (_selectedChartType == 'debt')
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Overall Debt Reduction',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 250,
                            child: LineChart(
                              LineChartData(
                                gridData: const FlGridData(show: true),
                                titlesData: FlTitlesData(
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        return Text(
                                            '\$${(value / 1000).toStringAsFixed(0)}k',
                                            style:
                                                const TextStyle(fontSize: 10));
                                      },
                                    ),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        return Text('M${value.toInt()}',
                                            style:
                                                const TextStyle(fontSize: 10));
                                      },
                                    ),
                                  ),
                                  rightTitles: const AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false)),
                                  topTitles: const AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false)),
                                ),
                                borderData: FlBorderData(show: true),
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: _generateOverallDebtReduction(),
                                    isCurved: true,
                                    color: Colors.blue,
                                    barWidth: 3,
                                    dotData: const FlDotData(show: false),
                                    belowBarData: BarAreaData(
                                        show: true,
                                        color: Colors.blue.withOpacity(0.1)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              // Savings growth chart
              if (_selectedChartType == 'savings')
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Savings Growth Projection',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 250,
                            child: LineChart(
                              LineChartData(
                                gridData: const FlGridData(show: true),
                                titlesData: FlTitlesData(
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        return Text(
                                            '\$${(value / 1000).toStringAsFixed(0)}k',
                                            style:
                                                const TextStyle(fontSize: 10));
                                      },
                                    ),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        return Text('M${value.toInt()}',
                                            style:
                                                const TextStyle(fontSize: 10));
                                      },
                                    ),
                                  ),
                                  rightTitles: const AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false)),
                                  topTitles: const AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false)),
                                ),
                                borderData: FlBorderData(show: true),
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: _generateSavingsGrowth(),
                                    isCurved: true,
                                    color: Colors.green,
                                    barWidth: 3,
                                    dotData: const FlDotData(show: false),
                                    belowBarData: BarAreaData(
                                        show: true,
                                        color: Colors.green.withOpacity(0.1)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              // Debt tabs
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: debtList
                      .map((debt) => _buildDebtDetailTab(context, debt))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChartTypeButton(String label, String type) {
    final isSelected = _selectedChartType == type;
    return GestureDetector(
      onTap: () => setState(() => _selectedChartType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildDebtDetailTab(BuildContext context, dynamic debt) {
    final paymentCount = paymentsCount[debt.id] ?? 0;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Debt summary card
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      debt.name,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    _buildSummaryRow('Type:', debt.type),
                    _buildSummaryRow('Lender:', debt.lenderName),
                    _buildSummaryRow('Current Balance:',
                        '\$${debt.currentBalance.toStringAsFixed(2)}'),
                    _buildSummaryRow('Interest Rate:', '${debt.interestRate}%'),
                    _buildSummaryRow('Min Payment:',
                        '\$${debt.minimumPayment.toStringAsFixed(2)}'),
                    _buildSummaryRow('Total Paid:',
                        '\$${debt.totalPaid.toStringAsFixed(2)}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Debt balance over time chart
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Balance Over Time',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 200,
                      child: LineChart(
                        LineChartData(
                          gridData: const FlGridData(show: true),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  return Text(
                                      '\$${(value / 1000).toStringAsFixed(0)}k',
                                      style: const TextStyle(fontSize: 10));
                                },
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  return Text('${value.toInt()}',
                                      style: const TextStyle(fontSize: 10));
                                },
                              ),
                            ),
                            rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(show: true),
                          lineBarsData: [
                            LineChartBarData(
                              spots: _generateDebtBalanceOverTime(debt),
                              isCurved: true,
                              color: Colors.red,
                              barWidth: 3,
                              dotData: const FlDotData(show: true),
                              belowBarData: BarAreaData(
                                  show: true,
                                  color: Colors.red.withOpacity(0.1)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Payment trends chart
            if (_selectedChartType == 'payments')
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Payment Trends',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 200,
                        child: LineChart(
                          LineChartData(
                            gridData: const FlGridData(show: true),
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    return Text('\$${value.toInt()}',
                                        style: const TextStyle(fontSize: 10));
                                  },
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    return Text('${value.toInt()}',
                                        style: const TextStyle(fontSize: 10));
                                  },
                                ),
                              ),
                              rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                            ),
                            borderData: FlBorderData(show: true),
                            lineBarsData: [
                              LineChartBarData(
                                spots: _generatePaymentTrends(debt),
                                isCurved: true,
                                color: Colors.orange,
                                barWidth: 3,
                                dotData: const FlDotData(show: true),
                                belowBarData: BarAreaData(
                                    show: true,
                                    color: Colors.orange.withOpacity(0.1)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_selectedChartType == 'payments') const SizedBox(height: 16),
            // Payment tracking section
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payment Progress',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text('Payments Made: $paymentCount'),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: debt.currentBalance > 0
                          ? (debt.totalPaid /
                                  (debt.totalPaid + debt.currentBalance))
                              .clamp(0, 1)
                          : 1,
                      minHeight: 8,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Progress: ${((debt.totalPaid / (debt.totalPaid + debt.currentBalance)) * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Payment history section
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payment History',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    if ((debt.paymentHistory as List?)?.isEmpty ?? true)
                      const Text('No payments recorded yet.')
                    else
                      Column(
                        children: (debt.paymentHistory as List)
                            .take(10)
                            .map((payment) => Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        payment.date
                                                ?.toString()
                                                .split(' ')[0] ??
                                            'Unknown date',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      Row(
                                        children: [
                                          if (payment.isOnTime ?? false)
                                            const Icon(Icons.check_circle,
                                                color: Colors.green, size: 16),
                                          const SizedBox(width: 8),
                                          Text(
                                            '\$${payment.amount.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ))
                            .toList(),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
