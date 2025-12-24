import 'dart:math';
import '../shared_preferences_stub.dart';
import 'dart:convert';

// Mock Banking Transaction Model
class BankingTransaction {
  final String id;
  final DateTime date;
  final double amount;
  final String description;
  final String category;
  final String merchant;
  final bool isDebit;

  BankingTransaction({
    required this.id,
    required this.date,
    required this.amount,
    required this.description,
    required this.category,
    required this.merchant,
    this.isDebit = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'amount': amount,
        'description': description,
        'category': category,
        'merchant': merchant,
        'isDebit': isDebit,
      };

  factory BankingTransaction.fromJson(Map<String, dynamic> json) =>
      BankingTransaction(
        id: json['id'],
        date: DateTime.parse(json['date']),
        amount: json['amount'].toDouble(),
        description: json['description'],
        category: json['category'],
        merchant: json['merchant'],
        isDebit: json['isDebit'] ?? true,
      );
}

// Mock Banking Account Model
class BankingAccount {
  final String id;
  final String accountName;
  final String accountType; // checking, savings, credit
  final double balance;
  final String bankName;
  final String accountNumber; // masked

  BankingAccount({
    required this.id,
    required this.accountName,
    required this.accountType,
    required this.balance,
    required this.bankName,
    this.accountNumber = '****1234',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'accountName': accountName,
        'accountType': accountType,
        'balance': balance,
        'bankName': bankName,
        'accountNumber': accountNumber,
      };

  factory BankingAccount.fromJson(Map<String, dynamic> json) => BankingAccount(
        id: json['id'],
        accountName: json['accountName'],
        accountType: json['accountType'],
        balance: json['balance'].toDouble(),
        bankName: json['bankName'],
        accountNumber: json['accountNumber'] ?? '****1234',
      );
}

// Mock Banking Service
class BankingService {
  static final Random _random = Random();
  static final List<String> _merchants = [
    'Amazon',
    'Target',
    'Walmart',
    'Starbucks',
    'McDonald\'s',
    'Shell',
    'CVS',
    'Whole Foods',
    'Best Buy',
    'Home Depot',
    'Netflix',
    'Spotify',
    'Uber',
    'Lyft',
    'DoorDash',
  ];

  static final List<String> _categories = [
    'Groceries',
    'Dining',
    'Gas',
    'Shopping',
    'Entertainment',
    'Bills',
    'Transportation',
    'Healthcare',
    'Utilities',
    'Other',
  ];

  // Generate fake transactions
  static Future<List<BankingTransaction>> generateFakeTransactions({
    int count = 30,
    DateTime? startDate,
  }) async {
    final transactions = <BankingTransaction>[];
    final now = DateTime.now();
    final start = startDate ?? now.subtract(const Duration(days: 30));

    for (int i = 0; i < count; i++) {
      final daysAgo = _random.nextInt(30);
      final date = start.add(Duration(days: daysAgo));
      final category = _categories[_random.nextInt(_categories.length)];
      final merchant = _merchants[_random.nextInt(_merchants.length)];
      final amount = _random.nextDouble() * 200 + 5; // $5-$205

      transactions.add(BankingTransaction(
        id: 'txn_${DateTime.now().millisecondsSinceEpoch}_$i',
        date: date,
        amount: double.parse(amount.toStringAsFixed(2)),
        description: '$merchant - $category',
        category: category,
        merchant: merchant,
        isDebit: _random.nextBool(),
      ));
    }

    // Sort by date descending
    transactions.sort((a, b) => b.date.compareTo(a.date));
    return transactions;
  }

  // Get connected accounts (mock)
  static Future<List<BankingAccount>> getConnectedAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final accountsJson = prefs.getString('banking_accounts');

    if (accountsJson != null) {
      final List<dynamic> accountsList = jsonDecode(accountsJson);
      return accountsList.map((a) => BankingAccount.fromJson(a)).toList();
    }

    // Return default mock accounts
    return [
      BankingAccount(
        id: 'acc_1',
        accountName: 'Primary Checking',
        accountType: 'checking',
        balance: 2500.0,
        bankName: 'Chase Bank',
        accountNumber: '****5678',
      ),
      BankingAccount(
        id: 'acc_2',
        accountName: 'Savings Account',
        accountType: 'savings',
        balance: 5000.0,
        bankName: 'Chase Bank',
        accountNumber: '****9012',
      ),
    ];
  }

  // Save connected accounts
  static Future<void> saveConnectedAccounts(
      List<BankingAccount> accounts) async {
    final prefs = await SharedPreferences.getInstance();
    final accountsJson = jsonEncode(accounts.map((a) => a.toJson()).toList());
    await prefs.setString('banking_accounts', accountsJson);
  }

  // Get transactions for an account
  static Future<List<BankingTransaction>> getTransactions(
      String accountId) async {
    final prefs = await SharedPreferences.getInstance();
    final transactionsJson = prefs.getString('banking_transactions_$accountId');

    if (transactionsJson != null) {
      final List<dynamic> transactionsList = jsonDecode(transactionsJson);
      return transactionsList
          .map((t) => BankingTransaction.fromJson(t))
          .toList();
    }

    // Generate and save fake transactions
    final transactions = await generateFakeTransactions();
    await saveTransactions(accountId, transactions);
    return transactions;
  }

  // Save transactions
  static Future<void> saveTransactions(
      String accountId, List<BankingTransaction> transactions) async {
    final prefs = await SharedPreferences.getInstance();
    final transactionsJson =
        jsonEncode(transactions.map((t) => t.toJson()).toList());
    await prefs.setString('banking_transactions_$accountId', transactionsJson);
  }

  // Get spending by category
  static Future<Map<String, double>> getSpendingByCategory(
      String accountId) async {
    final transactions = await getTransactions(accountId);
    final spending = <String, double>{};

    for (var transaction in transactions) {
      if (transaction.isDebit) {
        spending[transaction.category] =
            (spending[transaction.category] ?? 0) + transaction.amount;
      }
    }

    return spending;
  }

  // Get monthly spending
  static Future<double> getMonthlySpending(String accountId) async {
    final transactions = await getTransactions(accountId);
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month, 1);

    double total = 0.0;
    for (var t in transactions) {
      if (t.isDebit && t.date.isAfter(thisMonth)) {
        total += t.amount;
      }
    }
    return total;
  }

  // Connect a new bank account (mock)
  static Future<BankingAccount> connectBankAccount({
    required String bankName,
    required String accountType,
    required String accountNumber,
  }) async {
    final account = BankingAccount(
      id: 'acc_${DateTime.now().millisecondsSinceEpoch}',
      accountName: '$accountType Account',
      accountType: accountType,
      balance: _random.nextDouble() * 10000 + 1000,
      bankName: bankName,
      accountNumber: '****${accountNumber.substring(accountNumber.length - 4)}',
    );

    final accounts = await getConnectedAccounts();
    accounts.add(account);
    await saveConnectedAccounts(accounts);

    // Generate initial transactions
    final transactions = await generateFakeTransactions(count: 50);
    await saveTransactions(account.id, transactions);

    return account;
  }

  // Disconnect a bank account
  static Future<void> disconnectBankAccount(String accountId) async {
    final accounts = await getConnectedAccounts();
    accounts.removeWhere((a) => a.id == accountId);
    await saveConnectedAccounts(accounts);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('banking_transactions_$accountId');
  }
}
