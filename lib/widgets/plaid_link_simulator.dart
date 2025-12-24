import 'package:flutter/material.dart';
import '../services/banking_service.dart';

/// Mock bank data for the simulation
class MockBank {
  final String id;
  final String name;
  final String logoColor;
  final IconData icon;

  const MockBank({
    required this.id,
    required this.name,
    required this.logoColor,
    this.icon = Icons.account_balance,
  });
}

/// Mock account for selection
class MockAvailableAccount {
  final String id;
  final String name;
  final String type;
  final double balance;
  bool isSelected;

  MockAvailableAccount({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    this.isSelected = true,
  });
}

/// Plaid Link Simulator - demonstrates realistic bank connection flow
class PlaidLinkSimulator extends StatefulWidget {
  final Function(List<BankingAccount>) onSuccess;
  final VoidCallback onCancel;

  const PlaidLinkSimulator({
    super.key,
    required this.onSuccess,
    required this.onCancel,
  });

  @override
  State<PlaidLinkSimulator> createState() => _PlaidLinkSimulatorState();
}

class _PlaidLinkSimulatorState extends State<PlaidLinkSimulator> {
  // Flow steps
  int _currentStep = 0;

  // Bank selection
  final TextEditingController _searchController = TextEditingController();
  MockBank? _selectedBank;

  // Credentials
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  // Account selection
  List<MockAvailableAccount> _availableAccounts = [];

  // Popular banks
  static const List<MockBank> _banks = [
    MockBank(id: 'chase', name: 'Chase', logoColor: '0xFF0A6CB4'),
    MockBank(id: 'bofa', name: 'Bank of America', logoColor: '0xFFE31837'),
    MockBank(id: 'wells', name: 'Wells Fargo', logoColor: '0xFFD71920'),
    MockBank(id: 'citi', name: 'Citibank', logoColor: '0xFF003B70'),
    MockBank(id: 'usbank', name: 'U.S. Bank', logoColor: '0xFF0033A0'),
    MockBank(id: 'capital', name: 'Capital One', logoColor: '0xFFD03027'),
    MockBank(id: 'pnc', name: 'PNC Bank', logoColor: '0xFFF58025'),
    MockBank(id: 'td', name: 'TD Bank', logoColor: '0xFF34A853'),
  ];

  List<MockBank> get _filteredBanks {
    if (_searchController.text.isEmpty) return _banks;
    return _banks
        .where((bank) => bank.name
            .toLowerCase()
            .contains(_searchController.text.toLowerCase()))
        .toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: widget.onCancel,
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF00D09C),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.link, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
            const Text(
              'Plaid',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _buildCurrentStep(),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildBankSelectionStep();
      case 1:
        return _buildCredentialsStep();
      case 2:
        return _buildConnectingStep();
      case 3:
        return _buildAccountSelectionStep();
      case 4:
        return _buildSuccessStep();
      default:
        return _buildBankSelectionStep();
    }
  }

  // Step 1: Bank Selection
  Widget _buildBankSelectionStep() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select your bank',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Search for your financial institution to connect securely.',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search for your bank',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _filteredBanks.length,
            itemBuilder: (context, index) {
              final bank = _filteredBanks[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Color(int.parse(bank.logoColor)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(bank.icon, color: Colors.white),
                  ),
                  title: Text(
                    bank.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    setState(() {
                      _selectedBank = bank;
                      _currentStep = 1;
                    });
                  },
                ),
              );
            },
          ),
        ),
        // Security notice
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[50],
          child: Row(
            children: [
              Icon(Icons.lock_outline, size: 20, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Your credentials are encrypted and never stored by this app.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Step 2: Credentials Entry
  Widget _buildCredentialsStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Color(int.parse(_selectedBank!.logoColor)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_selectedBank!.icon, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Text(
                _selectedBank!.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Enter your credentials',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This is a simulation. Enter any username and password.',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _usernameController,
            decoration: InputDecoration(
              labelText: 'Username',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _usernameController.text.isNotEmpty &&
                      _passwordController.text.isNotEmpty
                  ? () {
                      setState(() => _currentStep = 2);
                      _simulateConnection();
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D09C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Continue',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => setState(() => _currentStep = 0),
            child: const Text('← Choose a different bank'),
          ),
        ],
      ),
    );
  }

  // Step 3: Connecting Animation
  Widget _buildConnectingStep() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Color(int.parse(_selectedBank!.logoColor)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(_selectedBank!.icon, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 32),
          const CircularProgressIndicator(
            color: Color(0xFF00D09C),
          ),
          const SizedBox(height: 24),
          const Text(
            'Connecting securely...',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Establishing a secure connection to ${_selectedBank!.name}',
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _simulateConnection() async {
    // Simulate connection delay
    await Future.delayed(const Duration(seconds: 2));

    // Generate mock accounts for this bank
    _availableAccounts = [
      MockAvailableAccount(
        id: 'acc_${DateTime.now().millisecondsSinceEpoch}_1',
        name: 'Checking Account',
        type: 'checking',
        balance: 2500 + (DateTime.now().millisecond * 10).toDouble(),
      ),
      MockAvailableAccount(
        id: 'acc_${DateTime.now().millisecondsSinceEpoch}_2',
        name: 'Savings Account',
        type: 'savings',
        balance: 8000 + (DateTime.now().millisecond * 5).toDouble(),
      ),
      MockAvailableAccount(
        id: 'acc_${DateTime.now().millisecondsSinceEpoch}_3',
        name: 'Credit Card',
        type: 'credit',
        balance: -1200 - (DateTime.now().millisecond).toDouble(),
      ),
    ];

    if (mounted) {
      setState(() => _currentStep = 3);
    }
  }

  // Step 4: Account Selection
  Widget _buildAccountSelectionStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select accounts to link',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose which accounts you want to connect to CogniCents.',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: _availableAccounts.length,
              itemBuilder: (context, index) {
                final account = _availableAccounts[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: account.isSelected
                          ? const Color(0xFF00D09C)
                          : Colors.grey[300]!,
                      width: account.isSelected ? 2 : 1,
                    ),
                  ),
                  child: CheckboxListTile(
                    value: account.isSelected,
                    onChanged: (value) {
                      setState(() => account.isSelected = value ?? false);
                    },
                    activeColor: const Color(0xFF00D09C),
                    title: Text(
                      account.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${account.type.toUpperCase()} • ${account.balance >= 0 ? '\$' : '-\$'}${account.balance.abs().toStringAsFixed(2)}',
                    ),
                    secondary: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _getAccountColor(account.type),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getAccountIcon(account.type),
                        color: Colors.white,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _availableAccounts.any((a) => a.isSelected)
                  ? () => setState(() => _currentStep = 4)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D09C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Link ${_availableAccounts.where((a) => a.isSelected).length} account(s)',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getAccountColor(String type) {
    switch (type) {
      case 'checking':
        return Colors.blue;
      case 'savings':
        return Colors.green;
      case 'credit':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getAccountIcon(String type) {
    switch (type) {
      case 'checking':
        return Icons.account_balance_wallet;
      case 'savings':
        return Icons.savings;
      case 'credit':
        return Icons.credit_card;
      default:
        return Icons.account_balance;
    }
  }

  // Step 5: Success
  Widget _buildSuccessStep() {
    final selectedAccounts =
        _availableAccounts.where((a) => a.isSelected).toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF00D09C),
              borderRadius: BorderRadius.circular(40),
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 48),
          ),
          const SizedBox(height: 24),
          const Text(
            'Successfully linked!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${selectedAccounts.length} account(s) from ${_selectedBank!.name}',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 32),
          ...selectedAccounts.map((account) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _getAccountColor(account.type),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getAccountIcon(account.type),
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        account.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      '${account.balance >= 0 ? '\$' : '-\$'}${account.balance.abs().toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () => _completeLink(selectedAccounts),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D09C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Done',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _completeLink(
      List<MockAvailableAccount> selectedAccounts) async {
    // Convert to BankingAccount objects and save
    final bankingAccounts = <BankingAccount>[];

    for (final account in selectedAccounts) {
      final bankingAccount = await BankingService.connectBankAccount(
        bankName: _selectedBank!.name,
        accountType: account.type,
        accountNumber: account.id.substring(account.id.length - 4),
      );
      bankingAccounts.add(bankingAccount);
    }

    widget.onSuccess(bankingAccounts);
  }
}
