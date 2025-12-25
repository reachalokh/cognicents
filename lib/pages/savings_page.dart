import 'package:flutter/material.dart';
import '../main.dart';

/// Savings Page - Track and manage your savings
/// Allows users to view, add, and track their savings progress
class SavingsPage extends StatefulWidget {
  const SavingsPage({super.key});

  @override
  State<SavingsPage> createState() => _SavingsPageState();
}

class _SavingsPageState extends State<SavingsPage> {
  bool _isLoading = true;
  UserFinancialData? _financialData;
  double _currentSavings = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _financialData = await DataService.getFinancialData();
    _currentSavings = _financialData?.emergencySavings ?? 0;
    setState(() => _isLoading = false);
  }

  Future<List<Map<String, dynamic>>> _loadSavingsHistory() async {
    // Load from shared prefs or return empty list
    return [];
  }

  Future<void> _addSavingsEntry(double amount, String note) async {
    if (_financialData == null) return;

    // Update savings amount
    final newSavings = _currentSavings + amount;

    // Update financial data with new savings
    final updatedData = UserFinancialData(
      monthlyIncome: _financialData!.monthlyIncome,
      payFrequency: _financialData!.payFrequency,
      isIncomeStable: _financialData!.isIncomeStable,
      essentialExpenses: _financialData!.essentialExpenses,
      emergencySavings: newSavings,
    );

    await DataService.saveFinancialData(updatedData);
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Savings'),
          backgroundColor: const Color(0xFF4A90E2),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final monthlyExpenses = _financialData?.essentialExpenses.values
            .fold(0.0, (sum, v) => sum + v) ??
        0.0;
    final monthsOfSavings =
        monthlyExpenses > 0 ? _currentSavings / monthlyExpenses : 0.0;
    final savingsGoal = monthlyExpenses * 6; // 6 months emergency fund goal

    return Scaffold(
      appBar: AppBar(
        title: const Text('Savings'),
        backgroundColor: const Color(0xFF4A90E2),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSavingsDialog(context),
        backgroundColor: Colors.green,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Savings', style: TextStyle(color: Colors.white)),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Current Savings Card
              _buildCurrentSavingsCard(monthsOfSavings),
              const SizedBox(height: 20),

              // Savings Goal Progress
              _buildSavingsGoalCard(savingsGoal, monthsOfSavings),
              const SizedBox(height: 20),

              // Quick Add Buttons
              _buildQuickAddSection(),
              const SizedBox(height: 20),

              // Savings Tips
              _buildSavingsTips(monthsOfSavings),
              const SizedBox(height: 20),

              // Savings Breakdown
              _buildSavingsBreakdown(monthlyExpenses),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentSavingsCard(double monthsOfSavings) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.savings, color: Colors.white, size: 48),
          const SizedBox(height: 12),
          const Text(
            'Emergency Savings',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            '\$${_currentSavings.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${monthsOfSavings.toStringAsFixed(1)} months of expenses',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavingsGoalCard(double goalAmount, double monthsOfSavings) {
    final progress =
        goalAmount > 0 ? (_currentSavings / goalAmount).clamp(0.0, 1.0) : 0.0;
    final remaining = (goalAmount - _currentSavings).clamp(0, double.infinity);

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
                Icon(Icons.flag, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text(
                  '6 Month Emergency Fund Goal',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 16,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  progress >= 1 ? Colors.green : const Color(0xFF4A90E2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(progress * 100).toStringAsFixed(0)}% complete',
                  style: TextStyle(
                    color: progress >= 1 ? Colors.green : Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  remaining > 0
                      ? '\$${remaining.toStringAsFixed(0)} to go'
                      : '🎉 Goal reached!',
                  style: TextStyle(
                    color: remaining > 0 ? Colors.grey[600] : Colors.green,
                  ),
                ),
              ],
            ),
            if (goalAmount > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Goal: \$${goalAmount.toStringAsFixed(0)}',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAddSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Add',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildQuickAddButton(25, '\$25'),
                _buildQuickAddButton(50, '\$50'),
                _buildQuickAddButton(100, '\$100'),
                _buildQuickAddButton(250, '\$250'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAddButton(double amount, String label) {
    return InkWell(
      onTap: () => _confirmQuickAdd(amount),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green[200]!),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.green[700],
          ),
        ),
      ),
    );
  }

  void _confirmQuickAdd(double amount) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Savings'),
        content: Text(
            'Add \$${amount.toStringAsFixed(0)} to your emergency savings?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _addSavingsEntry(amount, 'Quick add');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Added \$${amount.toStringAsFixed(0)} to savings!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildSavingsTips(double monthsOfSavings) {
    String tip;
    IconData icon;
    Color color;

    if (monthsOfSavings < 1) {
      tip =
          'Start small! Even \$10/week adds up to \$520/year. Focus on building your first month of expenses.';
      icon = Icons.rocket_launch;
      color = Colors.orange;
    } else if (monthsOfSavings < 3) {
      tip =
          'Great start! You have ${monthsOfSavings.toStringAsFixed(1)} months saved. Keep it up to reach 3 months!';
      icon = Icons.trending_up;
      color = Colors.blue;
    } else if (monthsOfSavings < 6) {
      tip =
          'Excellent progress! You\'re building financial security. The goal of 6 months is within reach!';
      icon = Icons.star;
      color = Colors.amber;
    } else {
      tip =
          'Amazing! You have a fully funded emergency fund. Consider investing additional savings for growth.';
      icon = Icons.celebration;
      color = Colors.green;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                tip,
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavingsBreakdown(double monthlyExpenses) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'What Your Savings Covers',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildCoverageRow(
              'Monthly Expenses',
              monthlyExpenses,
              _currentSavings >= monthlyExpenses,
            ),
            const Divider(height: 24),
            _buildCoverageRow(
              '3 Months Buffer',
              monthlyExpenses * 3,
              _currentSavings >= monthlyExpenses * 3,
            ),
            const Divider(height: 24),
            _buildCoverageRow(
              '6 Months Goal',
              monthlyExpenses * 6,
              _currentSavings >= monthlyExpenses * 6,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverageRow(String label, double amount, bool isCovered) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(
              isCovered ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isCovered ? Colors.green : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
        Text(
          '\$${amount.toStringAsFixed(0)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isCovered ? Colors.green : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Future<void> _showAddSavingsDialog(BuildContext context) async {
    final amountController = TextEditingController();
    final noteController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.savings, color: Colors.green),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Add to Savings',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text('Amount',
                  style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              TextField(
                controller: amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  prefixText: '\$ ',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  hintText: 'Enter amount',
                ),
              ),
              const SizedBox(height: 16),
              const Text('Note (optional)',
                  style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              TextField(
                controller: noteController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  hintText: 'e.g., Tax refund, bonus',
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final amount = double.tryParse(amountController.text) ?? 0;
                    if (amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Please enter a valid amount')),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    await _addSavingsEntry(amount, noteController.text);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Added \$${amount.toStringAsFixed(2)} to savings!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child:
                      const Text('Add Savings', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
