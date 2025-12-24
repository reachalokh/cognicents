import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../main.dart';
import '../services/banking_service.dart';
import '../services/spending_analysis_service.dart';
import '../gemini_config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class FinancialPlanPage extends StatefulWidget {
  const FinancialPlanPage({super.key});

  @override
  State<FinancialPlanPage> createState() => _FinancialPlanPageState();
}

class _FinancialPlanPageState extends State<FinancialPlanPage> {
  bool _isLoading = true;
  List<SpendingPattern> _spendingPatterns = [];
  List<Subscription> _subscriptions = [];
  List<BudgetRecommendation> _recommendations = [];
  String _aiInsights = '';
  List<Debt> _debts = [];
  UserFinancialData? _financialData;
  List<BankingAccount> _accounts = [];
  List<BankingTransaction> _allTransactions = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // Load all data
    _debts = await DataService.getDebts();
    _financialData = await DataService.getFinancialData();
    _accounts = await BankingService.getConnectedAccounts();

    // Get all transactions from all accounts
    _allTransactions = [];
    for (var account in _accounts) {
      final transactions = await BankingService.getTransactions(account.id);
      _allTransactions.addAll(transactions);
    }

    // Analyze spending
    if (_allTransactions.isNotEmpty && _financialData != null) {
      _spendingPatterns = await SpendingAnalysisService.analyzeSpendingPatterns(
        _allTransactions,
        _debts,
        _financialData!,
      );
      _subscriptions =
          await SpendingAnalysisService.detectSubscriptions(_allTransactions);
      _recommendations =
          await SpendingAnalysisService.generateBudgetRecommendations(
        _allTransactions,
        _debts,
        _financialData!,
      );
      _aiInsights = await SpendingAnalysisService.generateAISummary(
        _spendingPatterns,
        _subscriptions,
        _recommendations,
        _debts,
        _financialData!,
      );
    }

    // Generate AI-powered personalized insights
    await _generateAIPersonalizedInsights();

    setState(() => _isLoading = false);
  }

  Future<void> _generateAIPersonalizedInsights() async {
    if (kGeminiApiKey.isEmpty || _allTransactions.isEmpty) return;

    try {
      final totalDebt =
          _debts.fold(0.0, (sum, debt) => sum + debt.currentBalance);
      final monthlyIncome = _financialData?.monthlyIncome ?? 0;
      final totalSubscriptions =
          _subscriptions.fold(0.0, (sum, sub) => sum + sub.monthlyCost);
      final totalSavings =
          SpendingAnalysisService.calculateTotalPotentialSavings(
              _recommendations);

      final prompt =
          '''You are a friendly financial advisor. Analyze this user's financial situation and provide encouraging, actionable advice.

User's Situation:
- Total Debt: \$${totalDebt.toStringAsFixed(2)}
- Monthly Income: \$${monthlyIncome.toStringAsFixed(2)}
- Active Subscriptions: ${_subscriptions.length} (costing \$${totalSubscriptions.toStringAsFixed(2)}/month)
- Potential Monthly Savings: \$${totalSavings.toStringAsFixed(2)}

Top Spending Categories:
${_spendingPatterns.take(3).map((p) => '- ${p.category}: \$${p.monthlyAverage.toStringAsFixed(2)}/month').join('\n')}

Provide a friendly, encouraging summary (2-3 sentences) that:
1. Acknowledges their situation positively
2. Highlights 1-2 key opportunities
3. Ends with an encouraging note

Be warm, supportive, and specific. Don't be judgmental.''';

      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$kGeminiApiKey',
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
              ]
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text']
            as String?;
        if (text != null && mounted) {
          setState(() => _aiInsights = text);
        }
      }
    } catch (e) {
      // Fallback to generated insights if AI fails
      debugPrint('AI insights generation failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Your Financial Plan'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Financial Plan'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh Analysis',
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
              // AI Insights Card
              if (_aiInsights.isNotEmpty) _buildAIInsightsCard(),
              const SizedBox(height: 16),

              // Quick Stats
              _buildQuickStats(),
              const SizedBox(height: 16),

              // Subscriptions Section
              if (_subscriptions.isNotEmpty) ...[
                _buildSubscriptionsSection(),
                const SizedBox(height: 16),
              ],

              // Spending Patterns
              if (_spendingPatterns.isNotEmpty) ...[
                _buildSpendingPatternsSection(),
                const SizedBox(height: 16),
              ],

              // Budget Recommendations
              if (_recommendations.isNotEmpty) ...[
                _buildBudgetRecommendationsSection(),
                const SizedBox(height: 16),
              ],

              // Spending Breakdown Chart
              if (_allTransactions.isNotEmpty) ...[
                _buildSpendingChart(),
                const SizedBox(height: 16),
              ],

              // Action Items
              _buildActionItems(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAIInsightsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.white, size: 24),
              SizedBox(width: 8),
              Text(
                'AI-Powered Insights',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _aiInsights,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.white,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    final totalDebt =
        _debts.fold(0.0, (sum, debt) => sum + debt.currentBalance);
    final totalSubscriptions =
        _subscriptions.fold(0.0, (sum, sub) => sum + sub.monthlyCost);
    final totalSavings = SpendingAnalysisService.calculateTotalPotentialSavings(
        _recommendations);

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Debt',
            '\$${totalDebt.toStringAsFixed(0)}',
            Icons.account_balance_wallet,
            Colors.red,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Subscriptions',
            '\$${totalSubscriptions.toStringAsFixed(0)}/mo',
            Icons.subscriptions,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Potential Savings',
            '\$${totalSavings.toStringAsFixed(0)}/mo',
            Icons.savings,
            Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.subscriptions,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text(
                  'Your Subscriptions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._subscriptions.map((sub) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sub.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              sub.category,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '\$${sub.monthlyCost.toStringAsFixed(2)}/mo',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: sub.isActive ? Colors.red : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb, color: Colors.orange[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Total: \$${_subscriptions.fold(0.0, (sum, sub) => sum + sub.monthlyCost).toStringAsFixed(2)}/month. Review and cancel unused subscriptions!',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange[900],
                      ),
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

  Widget _buildSpendingPatternsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text(
                  'Spending Patterns',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._spendingPatterns.take(5).map((pattern) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: pattern.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: pattern.color.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              pattern.category,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              '\$${pattern.monthlyAverage.toStringAsFixed(0)}/mo',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: pattern.color,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          pattern.insight,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.tips_and_updates,
                                  size: 16, color: pattern.color),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  pattern.recommendation,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[800],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetRecommendationsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_balance,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text(
                  'Budget Recommendations',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._recommendations.map((rec) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              rec.category,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Save \$${rec.potentialSavings.toStringAsFixed(0)}/mo',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              'Current: \$${rec.currentSpending.toStringAsFixed(0)}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '→ Recommended: \$${rec.recommendedSpending.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          rec.reasoning,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildSpendingChart() {
    final categorySpending = <String, double>{};
    for (var transaction in _allTransactions) {
      if (transaction.isDebit) {
        categorySpending[transaction.category] =
            (categorySpending[transaction.category] ?? 0) + transaction.amount;
      }
    }

    if (categorySpending.isEmpty) return const SizedBox.shrink();

    final total = categorySpending.values.fold(0.0, (sum, val) => sum + val);
    final colors = [
      Colors.blue,
      Colors.orange,
      Colors.green,
      Colors.purple,
      Colors.pink,
      Colors.teal,
      Colors.amber,
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Spending Breakdown',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: categorySpending.entries
                      .toList()
                      .asMap()
                      .entries
                      .map((entry) {
                    final index = entry.key;
                    final categoryEntry = entry.value;
                    final percentage = (categoryEntry.value / total * 100);
                    return PieChartSectionData(
                      value: categoryEntry.value,
                      title: percentage > 5
                          ? '${percentage.toStringAsFixed(0)}%'
                          : '',
                      color: colors[index % colors.length],
                      radius: 80,
                    );
                  }).toList(),
                  centerSpaceRadius: 40,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: categorySpending.entries
                  .toList()
                  .asMap()
                  .entries
                  .map((entry) {
                final index = entry.key;
                final categoryEntry = entry.value;
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
                    const SizedBox(width: 4),
                    Text(
                      '${categoryEntry.key}: \$${categoryEntry.value.toStringAsFixed(0)}',
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

  Widget _buildActionItems() {
    final totalSavings = SpendingAnalysisService.calculateTotalPotentialSavings(
        _recommendations);
    final totalSubscriptions =
        _subscriptions.fold(0.0, (sum, sub) => sum + sub.monthlyCost);

    return Card(
      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text(
                  'Your Action Plan',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_subscriptions.isNotEmpty)
              _buildActionItem(
                'Review ${_subscriptions.length} subscription${_subscriptions.length > 1 ? 's' : ''}',
                'Cancel unused ones to save \$${totalSubscriptions.toStringAsFixed(0)}/month',
                Icons.subscriptions,
              ),
            if (_recommendations.isNotEmpty)
              _buildActionItem(
                'Follow budget recommendations',
                'Save \$${totalSavings.toStringAsFixed(0)}/month by adjusting spending',
                Icons.account_balance,
              ),
            _buildActionItem(
              'Track your progress',
              'Check back weekly to see how you\'re doing',
              Icons.trending_up,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionItem(String title, String subtitle, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
