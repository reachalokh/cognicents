import 'package:flutter/material.dart';
import 'shared_preferences_stub.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'gemini_config.dart';
import 'pages/progress_page.dart';
import 'pages/financial_plan_page.dart';
import 'pages/calendar_page.dart';
import 'pages/savings_page.dart' as savings;
import 'services/banking_service.dart';
import 'services/notification_service.dart';
import 'services/bill_reminder_service.dart';
import 'pages/nudge_test_page.dart';
import 'widgets/plaid_link_simulator.dart';

void main() {
  // Debug logging for black screen issue
  debugPrint('🔥🔥🔥 DART STARTING MAIN 🔥🔥🔥');

  try {
    WidgetsFlutterBinding.ensureInitialized();
    debugPrint('✅ WidgetsFlutterBinding initialized');

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('❌ FLUTTER ERROR: ${details.exception}');
      debugPrint('Stack trace: ${details.stack}');
    };

    debugPrint('🚀 Calling runApp(MyApp)');
    runApp(const MyApp());
    debugPrint('✅ runApp returned (this line is rarely reached)');

    // Initialize bill reminder service after app starts
    Future.delayed(const Duration(seconds: 2), () {
      BillReminderService().init();
    });
  } catch (e, stack) {
    debugPrint('❌ CRITICAL MAIN ERROR: $e');
    debugPrint(stack.toString());
  }
}

// Data Models
class Debt {
  final String id;
  final String name;
  final String type;
  final double currentBalance;
  final double interestRate;
  final double minimumPayment;
  final DateTime? dueDate;
  final String lenderName;
  final double totalPaid;
  final List<PaymentRecord> paymentHistory;

  Debt({
    required this.id,
    required this.name,
    required this.type,
    required this.currentBalance,
    required this.interestRate,
    required this.minimumPayment,
    this.dueDate,
    required this.lenderName,
    this.totalPaid = 0,
    List<PaymentRecord>? paymentHistory,
  }) : paymentHistory = paymentHistory ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'currentBalance': currentBalance,
        'interestRate': interestRate,
        'minimumPayment': minimumPayment,
        'dueDate': dueDate?.toIso8601String(),
        'lenderName': lenderName,
        'totalPaid': totalPaid,
        'paymentHistory': paymentHistory.map((p) => p.toJson()).toList(),
      };

  factory Debt.fromJson(Map<String, dynamic> json) => Debt(
        id: json['id'],
        name: json['name'],
        type: json['type'],
        currentBalance: json['currentBalance'].toDouble(),
        interestRate: json['interestRate'].toDouble(),
        minimumPayment: json['minimumPayment'].toDouble(),
        dueDate:
            json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
        lenderName: json['lenderName'],
        totalPaid: json['totalPaid']?.toDouble() ?? 0,
        paymentHistory: (json['paymentHistory'] as List?)
                ?.map((p) => PaymentRecord.fromJson(p))
                .toList() ??
            [],
      );
}

// Strategy & Planning page. Body intentionally left blank for now.
class StrategyPlanningPage extends StatelessWidget {
  const StrategyPlanningPage({super.key});

  void _openChat(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const ChatGeminiDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Strategy & Planning'),
        foregroundColor: Colors.white,
      ),
      body: const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: Text(''), // Page body left blank intentionally
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openChat(context),
        tooltip: 'Chat with Gemini',
        child: const Icon(Icons.smart_toy),
      ),
    );
  }
}

// Enhanced Agentic AI Chat Dialog
class ChatGeminiDialog extends StatefulWidget {
  const ChatGeminiDialog({super.key});

  @override
  State<ChatGeminiDialog> createState() => _ChatGeminiDialogState();
}

class _ChatGeminiDialogState extends State<ChatGeminiDialog> {
  final _apiKeyController = TextEditingController();
  final _promptController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  late final bool _useEmbeddedKey;

  @override
  void initState() {
    super.initState();
    _useEmbeddedKey = kGeminiApiKey.isNotEmpty;
    if (_useEmbeddedKey) {
      _apiKeyController.text = kGeminiApiKey;
    } else {
      _loadSavedApiKey();
    }
    _loadConversationHistory();
    _showProactiveSuggestion();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _promptController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString('gemini_api_key') ?? '';
    _apiKeyController.text = key;
  }

  Future<void> _saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gemini_api_key', key);
  }

  Future<void> _loadConversationHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString('ai_conversation_history');
    if (historyJson != null) {
      final List<dynamic> history = jsonDecode(historyJson);
      setState(() {
        _messages.addAll(history.map((m) => ChatMessage.fromJson(m)));
      });
    }
  }

  Future<void> _saveConversationHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = jsonEncode(_messages.map((m) => m.toJson()).toList());
    await prefs.setString('ai_conversation_history', historyJson);
  }

  Future<void> _showProactiveSuggestion() async {
    // Get user's financial context
    final debts = await DataService.getDebts();

    // Generate proactive suggestion based on context
    String suggestion = '';
    if (debts.isEmpty) {
      suggestion =
          'I notice you haven\'t added any debts yet. Would you like help setting up your debt tracking?';
    } else {
      final totalDebt =
          debts.fold(0.0, (sum, debt) => sum + debt.currentBalance);
      final totalPaid = debts.fold(0.0, (sum, debt) => sum + debt.totalPaid);
      final progress = totalPaid / (totalDebt + totalPaid);

      if (progress < 0.1) {
        suggestion =
            'You\'re just getting started! I can help you create a payment strategy to pay off your debts faster.';
      } else if (progress < 0.5) {
        suggestion =
            'Great progress! You\'ve paid off ${(progress * 100).toStringAsFixed(0)}% of your debt. Want tips to accelerate?';
      } else {
        suggestion =
            'Excellent work! You\'re over halfway there. Let\'s discuss strategies to finish strong!';
      }
    }

    if (suggestion.isNotEmpty && _messages.isEmpty) {
      setState(() {
        _messages.add(ChatMessage(
          text: suggestion,
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
      await _saveConversationHistory();
    }
  }

  Future<String> _buildContextualPrompt(String userPrompt) async {
    // Build context from user's financial data
    final debts = await DataService.getDebts();
    final financialData = await DataService.getFinancialData();
    final achievements = await DataService.getAchievements();

    final totalDebt = debts.fold(0.0, (sum, debt) => sum + debt.currentBalance);
    final totalPaid = debts.fold(0.0, (sum, debt) => sum + debt.totalPaid);
    final monthlyIncome = financialData.monthlyIncome;
    final savings = financialData.emergencySavings;
    final paymentStreak = achievements.currentPaymentStreak;

    String context =
        '''You are CogniCents AI, a friendly and expert financial advisor. You help users pay off debt faster.

USER'S FINANCIAL SNAPSHOT:
• Total Debt: \$${totalDebt.toStringAsFixed(0)}
• Paid Off: \$${totalPaid.toStringAsFixed(0)} 
• Monthly Income: \$${monthlyIncome.toStringAsFixed(0)}
• Emergency Fund: \$${savings.toStringAsFixed(0)}
• Payment Streak: $paymentStreak days
• Number of Debts: ${debts.length}

THEIR DEBTS:
${debts.isEmpty ? '• No debts added yet' : debts.map((d) => '• ${d.name}: \$${d.currentBalance.toStringAsFixed(0)} @ ${d.interestRate}% APR (min \$${d.minimumPayment.toStringAsFixed(0)}/mo)').join('\n')}

RESPONSE FORMATTING RULES:
1. Be concise - max 150 words
2. Use bullet points (•) for lists
3. Include specific numbers from their data
4. End with ONE clear action step
5. Be encouraging but realistic
6. Use **bold** for key terms''';

    // Add conversation history
    if (_messages.isNotEmpty) {
      context += '\n\nRecent Conversation:\n';
      for (var msg in _messages.take(5)) {
        context += '${msg.isUser ? "User" : "Assistant"}: ${msg.text}\n';
      }
    }

    context += '\n\nUser Question: $userPrompt';
    return context;
  }

  Future<void> _submitPrompt() async {
    final apiKey =
        _useEmbeddedKey ? kGeminiApiKey : _apiKeyController.text.trim();
    final prompt = _promptController.text.trim();

    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter your API key.')));
      return;
    }
    if (prompt.isEmpty) {
      return;
    }

    // Add user message
    final userMessage = ChatMessage(
      text: prompt,
      isUser: true,
      timestamp: DateTime.now(),
    );
    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
    });
    _promptController.clear();
    await _saveConversationHistory();
    _scrollToBottom();

    try {
      if (!_useEmbeddedKey) {
        await _saveApiKey(apiKey);
      }

      final contextualPrompt = await _buildContextualPrompt(prompt);

      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey',
      );

      final headers = {
        'Content-Type': 'application/json',
      };

      final body = jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': contextualPrompt}
            ]
          }
        ]
      });

      final response = await http
          .post(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String? text;
        try {
          text = data['candidates']?[0]?['content']?['parts']?[0]?['text']
              as String?;
        } catch (_) {
          // ignore
        }
        final aiMessage = ChatMessage(
          text: text ??
              'I apologize, but I couldn\'t generate a response. Please try again.',
          isUser: false,
          timestamp: DateTime.now(),
        );
        setState(() {
          _messages.add(aiMessage);
          _isLoading = false;
        });
        await _saveConversationHistory();
        _scrollToBottom();
      } else {
        final errorMessage = ChatMessage(
          text:
              'Error: ${response.statusCode}. Please check your API key and try again.',
          isUser: false,
          timestamp: DateTime.now(),
        );
        setState(() {
          _messages.add(errorMessage);
          _isLoading = false;
        });
        await _saveConversationHistory();
      }
    } catch (e) {
      final errorMessage = ChatMessage(
        text: 'Request failed: $e. Please check your internet connection.',
        isUser: false,
        timestamp: DateTime.now(),
      );
      setState(() {
        _messages.add(errorMessage);
        _isLoading = false;
      });
      await _saveConversationHistory();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 600,
        height: 700,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.smart_toy, color: Colors.white),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'AI Financial Advisor',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (!_useEmbeddedKey)
                    IconButton(
                      icon: const Icon(Icons.settings, color: Colors.white),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('API Key'),
                            content: TextField(
                              controller: _apiKeyController,
                              decoration: const InputDecoration(
                                hintText: 'Enter your Gemini API key',
                                border: OutlineInputBorder(),
                              ),
                              obscureText: true,
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Save'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Messages
            Expanded(
              child: _messages.isEmpty
                  ? const Center(
                      child: Text('Start a conversation with your AI advisor!'),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length + (_isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _messages.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final message = _messages[index];
                        return _buildMessageBubble(message);
                      },
                    ),
            ),
            // Quick suggestion chips
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildSuggestionChip('💡 Best payoff strategy?'),
                    _buildSuggestionChip('📊 Review my progress'),
                    _buildSuggestionChip('💰 How to save more?'),
                    _buildSuggestionChip('🎯 Set a goal'),
                  ],
                ),
              ),
            ),
            // Input area
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(
                  top: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _promptController,
                      decoration: InputDecoration(
                        hintText: 'Ask about your finances...',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(
                              color: Color(0xFF4A90E2), width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                      ),
                      maxLines: 1,
                      onSubmitted: (_) => _submitPrompt(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF4A90E2),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon:
                          const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: _isLoading ? null : _submitPrompt,
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

  Widget _buildMessageBubble(ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: message.isUser ? const Color(0xFF4A90E2) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: message.isUser
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
          border: message.isUser ? null : Border.all(color: Colors.grey[200]!),
        ),
        constraints: const BoxConstraints(maxWidth: 320),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!message.isUser) ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A90E2).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.auto_awesome,
                        size: 16, color: Color(0xFF4A90E2)),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'CogniCents AI',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Color(0xFF4A90E2),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            _buildFormattedText(message.text, message.isUser),
          ],
        ),
      ),
    );
  }

  Widget _buildFormattedText(String text, bool isUser) {
    if (isUser) {
      return Text(text,
          style: const TextStyle(color: Colors.white, fontSize: 15));
    }

    // Parse and format AI response
    final lines = text.split('\n');
    final widgets = <Widget>[];

    for (int i = 0; i < lines.length; i++) {
      var line = lines[i].trim();
      if (line.isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }

      // Check for bullet points
      bool isBullet =
          line.startsWith('•') || line.startsWith('-') || line.startsWith('*');
      if (isBullet) {
        line = line.substring(1).trim();
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 4, top: 4, bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 6, right: 8),
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFF4A90E2),
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(child: _buildRichLine(line)),
            ],
          ),
        ));
      } else if (RegExp(r'^\d+\.').hasMatch(line)) {
        // Numbered list
        final match = RegExp(r'^(\d+)\.\s*(.*)').firstMatch(line);
        if (match != null) {
          final num = match.group(1)!;
          final content = match.group(2)!;
          widgets.add(Padding(
            padding: const EdgeInsets.only(left: 4, top: 4, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A90E2).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(num,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4A90E2))),
                ),
                Expanded(child: _buildRichLine(content)),
              ],
            ),
          ));
        }
      } else {
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: _buildRichLine(line),
        ));
      }
    }

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
  }

  Widget _buildRichLine(String text) {
    // Parse **bold** text
    final spans = <TextSpan>[];
    final regex = RegExp(r'\*\*(.+?)\*\*');
    int lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: const TextStyle(
            fontWeight: FontWeight.bold, color: Color(0xFF2D3748)),
      ));
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(
            fontSize: 14, color: Color(0xFF4A5568), height: 1.5),
        children: spans.isEmpty ? [TextSpan(text: text)] : spans,
      ),
    );
  }

  Widget _buildSuggestionChip(String text) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(text, style: const TextStyle(fontSize: 12)),
        backgroundColor: const Color(0xFF4A90E2).withOpacity(0.1),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onPressed: () {
          _promptController.text = text.replaceAll(RegExp(r'^[^\s]+\s'), '');
          _submitPrompt();
        },
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'isUser': isUser,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        text: json['text'],
        isUser: json['isUser'],
        timestamp: DateTime.parse(json['timestamp']),
      );
}

class PaymentRecord {
  final DateTime date;
  final double amount;
  final bool isOnTime;
  final bool isMinimum;

  PaymentRecord({
    required this.date,
    required this.amount,
    this.isOnTime = true,
    this.isMinimum = false,
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'amount': amount,
        'isOnTime': isOnTime,
        'isMinimum': isMinimum,
      };

  factory PaymentRecord.fromJson(Map<String, dynamic> json) => PaymentRecord(
        date: DateTime.parse(json['date']),
        amount: json['amount'].toDouble(),
        isOnTime: json['isOnTime'] ?? true,
        isMinimum: json['isMinimum'] ?? false,
      );
}

class UserFinancialData {
  final double monthlyIncome;
  final String payFrequency; // weekly, biweekly, monthly
  final bool isIncomeStable;
  final Map<String, double> essentialExpenses; // category -> amount
  final double emergencySavings;
  final double monthlySavingsTarget;
  final int stressLevel; // 1-10
  final DateTime? lastStressCheck;
  final Map<String, int> stressHistory; // date -> level
  final Map<String, dynamic> nudgePreferences;

  UserFinancialData({
    required this.monthlyIncome,
    this.payFrequency = 'monthly',
    this.isIncomeStable = true,
    Map<String, double>? essentialExpenses,
    this.emergencySavings = 0,
    this.monthlySavingsTarget = 0,
    this.stressLevel = 5,
    this.lastStressCheck,
    Map<String, int>? stressHistory,
    Map<String, dynamic>? nudgePreferences,
  })  : essentialExpenses = essentialExpenses ?? {},
        stressHistory = stressHistory ?? {},
        nudgePreferences = nudgePreferences ??
            {
              'frequency': 'daily',
              'channels': ['push'],
              'leaderboards': false,
            };

  Map<String, dynamic> toJson() => {
        'monthlyIncome': monthlyIncome,
        'payFrequency': payFrequency,
        'isIncomeStable': isIncomeStable,
        'essentialExpenses': essentialExpenses,
        'emergencySavings': emergencySavings,
        'monthlySavingsTarget': monthlySavingsTarget,
        'stressLevel': stressLevel,
        'lastStressCheck': lastStressCheck?.toIso8601String(),
        'stressHistory': stressHistory,
        'nudgePreferences': nudgePreferences,
      };

  factory UserFinancialData.fromJson(Map<String, dynamic> json) =>
      UserFinancialData(
        monthlyIncome: json['monthlyIncome']?.toDouble() ?? 0,
        payFrequency: json['payFrequency'] ?? 'monthly',
        isIncomeStable: json['isIncomeStable'] ?? true,
        essentialExpenses: Map<String, double>.from(
          json['essentialExpenses']?.map((k, v) => MapEntry(k, v.toDouble())) ??
              {},
        ),
        emergencySavings: json['emergencySavings']?.toDouble() ?? 0,
        monthlySavingsTarget: json['monthlySavingsTarget']?.toDouble() ?? 0,
        stressLevel: json['stressLevel'] ?? 5,
        lastStressCheck: json['lastStressCheck'] != null
            ? DateTime.parse(json['lastStressCheck'])
            : null,
        stressHistory: Map<String, int>.from(
          json['stressHistory']?.map((k, v) => MapEntry(k, v as int)) ?? {},
        ),
        nudgePreferences:
            Map<String, dynamic>.from(json['nudgePreferences'] ?? {}),
      );
}

// Badge Model
enum BadgeType {
  paymentStreak,
  savingsMilestone,
  totalPayments,
  debtFree,
  earlyPayer,
  savingsStreak,
  consistency,
}

class Badge {
  final String id;
  final String name;
  final String description;
  final BadgeType type;
  final IconData icon;
  final Color color;
  final int requiredValue; // e.g., 7 days for streak, $1000 for savings
  final DateTime? unlockedAt;

  Badge({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.icon,
    required this.color,
    required this.requiredValue,
    this.unlockedAt,
  });

  bool get isUnlocked => unlockedAt != null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'type': type.toString(),
        'requiredValue': requiredValue,
        'unlockedAt': unlockedAt?.toIso8601String(),
      };

  factory Badge.fromJson(Map<String, dynamic> json) {
    final typeString = json['type'] as String;
    final type = BadgeType.values.firstWhere(
      (e) => e.toString() == typeString,
      orElse: () => BadgeType.consistency,
    );

    // Get icon and color based on type
    IconData icon;
    Color color;
    switch (type) {
      case BadgeType.paymentStreak:
        icon = Icons.local_fire_department;
        color = Colors.orange;
        break;
      case BadgeType.savingsMilestone:
        icon = Icons.savings;
        color = Colors.green;
        break;
      case BadgeType.totalPayments:
        icon = Icons.payments;
        color = Colors.blue;
        break;
      case BadgeType.debtFree:
        icon = Icons.celebration;
        color = Colors.purple;
        break;
      case BadgeType.earlyPayer:
        icon = Icons.schedule;
        color = Colors.teal;
        break;
      case BadgeType.savingsStreak:
        icon = Icons.trending_up;
        color = Colors.amber;
        break;
      case BadgeType.consistency:
        icon = Icons.check_circle;
        color = Colors.indigo;
        break;
    }

    return Badge(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      type: type,
      icon: icon,
      color: color,
      requiredValue: json['requiredValue'],
      unlockedAt: json['unlockedAt'] != null
          ? DateTime.parse(json['unlockedAt'])
          : null,
    );
  }
}

class UserAchievements {
  final Map<String, Badge> badges;
  final int totalPoints;
  final int currentPaymentStreak;
  final int currentSavingsStreak;
  final int totalOnTimePayments;
  final double totalAmountSaved;
  final double totalAmountPaid;
  final DateTime? lastPaymentDate;
  final DateTime? lastSavingsDate;

  UserAchievements({
    Map<String, Badge>? badges,
    this.totalPoints = 0,
    this.currentPaymentStreak = 0,
    this.currentSavingsStreak = 0,
    this.totalOnTimePayments = 0,
    this.totalAmountSaved = 0,
    this.totalAmountPaid = 0,
    this.lastPaymentDate,
    this.lastSavingsDate,
  }) : badges = badges ?? {};

  Map<String, dynamic> toJson() => {
        'badges': badges.map((k, v) => MapEntry(k, v.toJson())),
        'totalPoints': totalPoints,
        'currentPaymentStreak': currentPaymentStreak,
        'currentSavingsStreak': currentSavingsStreak,
        'totalOnTimePayments': totalOnTimePayments,
        'totalAmountSaved': totalAmountSaved,
        'totalAmountPaid': totalAmountPaid,
        'lastPaymentDate': lastPaymentDate?.toIso8601String(),
        'lastSavingsDate': lastSavingsDate?.toIso8601String(),
      };

  factory UserAchievements.fromJson(Map<String, dynamic> json) =>
      UserAchievements(
        badges: (json['badges'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(k, Badge.fromJson(v)),
            ) ??
            {},
        totalPoints: json['totalPoints'] ?? 0,
        currentPaymentStreak: json['currentPaymentStreak'] ?? 0,
        currentSavingsStreak: json['currentSavingsStreak'] ?? 0,
        totalOnTimePayments: json['totalOnTimePayments'] ?? 0,
        totalAmountSaved: json['totalAmountSaved']?.toDouble() ?? 0,
        totalAmountPaid: json['totalAmountPaid']?.toDouble() ?? 0,
        lastPaymentDate: json['lastPaymentDate'] != null
            ? DateTime.parse(json['lastPaymentDate'])
            : null,
        lastSavingsDate: json['lastSavingsDate'] != null
            ? DateTime.parse(json['lastSavingsDate'])
            : null,
      );
}

class LeaderboardEntry {
  final String userId;
  final String userName;
  final int points;
  final int rank;
  final int paymentStreak;
  final double totalPaid;
  final double totalSaved;

  LeaderboardEntry({
    required this.userId,
    required this.userName,
    required this.points,
    required this.rank,
    this.paymentStreak = 0,
    this.totalPaid = 0,
    this.totalSaved = 0,
  });
}

// Data Service
class DataService {
  static Future<List<Debt>> getDebts() async {
    final prefs = await SharedPreferences.getInstance();
    final debtsJson = prefs.getString('debts') ?? '[]';
    final List<dynamic> debtsList = jsonDecode(debtsJson);
    return debtsList.map((d) => Debt.fromJson(d)).toList();
  }

  static Future<void> saveDebt(Debt debt) async {
    final debts = await getDebts();
    final index = debts.indexWhere((d) => d.id == debt.id);
    if (index >= 0) {
      debts[index] = debt;
    } else {
      debts.add(debt);
    }
    await _saveDebts(debts);
  }

  static Future<void> deleteDebt(String id) async {
    final debts = await getDebts();
    debts.removeWhere((d) => d.id == id);
    await _saveDebts(debts);
  }

  static Future<void> _saveDebts(List<Debt> debts) async {
    final prefs = await SharedPreferences.getInstance();
    final debtsJson = jsonEncode(debts.map((d) => d.toJson()).toList());
    await prefs.setString('debts', debtsJson);
  }

  static Future<UserFinancialData> getFinancialData() async {
    final prefs = await SharedPreferences.getInstance();
    final dataJson = prefs.getString('financialData');
    if (dataJson != null) {
      return UserFinancialData.fromJson(jsonDecode(dataJson));
    }
    return UserFinancialData(monthlyIncome: 0);
  }

  static Future<void> saveFinancialData(UserFinancialData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('financialData', jsonEncode(data.toJson()));
    // Update achievements when savings change
    await _updateAchievements();
  }

  static Future<void> recordPayment(
      String debtId, PaymentRecord payment) async {
    final debts = await getDebts();
    final debtIndex = debts.indexWhere((d) => d.id == debtId);
    if (debtIndex >= 0) {
      final debt = debts[debtIndex];
      final updatedHistory = List<PaymentRecord>.from(debt.paymentHistory)
        ..add(payment);
      final updatedDebt = Debt(
        id: debt.id,
        name: debt.name,
        type: debt.type,
        currentBalance:
            (debt.currentBalance - payment.amount).clamp(0, double.infinity),
        interestRate: debt.interestRate,
        minimumPayment: debt.minimumPayment,
        dueDate: debt.dueDate,
        lenderName: debt.lenderName,
        totalPaid: debt.totalPaid + payment.amount,
        paymentHistory: updatedHistory,
      );
      debts[debtIndex] = updatedDebt;
      await _saveDebts(debts);

      // Update achievements after payment
      await _updateAchievements();
    }
  }

  static Future<UserAchievements> getAchievements() async {
    final prefs = await SharedPreferences.getInstance();
    final achievementsJson = prefs.getString('achievements');
    if (achievementsJson != null) {
      return UserAchievements.fromJson(jsonDecode(achievementsJson));
    }
    return UserAchievements();
  }

  static Future<void> saveAchievements(UserAchievements achievements) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('achievements', jsonEncode(achievements.toJson()));
  }

  static Future<void> _updateAchievements() async {
    final debts = await getDebts();
    final financialData = await getFinancialData();
    final achievements = await getAchievements();

    // Calculate stats
    int totalOnTimePayments = 0;
    double totalAmountPaid = 0;
    int paymentStreak = achievements.currentPaymentStreak;
    int savingsStreak = achievements.currentSavingsStreak;
    DateTime? lastPaymentDate = achievements.lastPaymentDate;
    DateTime? lastSavingsDate = achievements.lastSavingsDate;

    // Get all payments sorted by date
    final allPayments = <PaymentRecord>[];
    for (var debt in debts) {
      allPayments.addAll(debt.paymentHistory);
      totalAmountPaid += debt.totalPaid;
    }
    allPayments.sort((a, b) => a.date.compareTo(b.date));

    // Count on-time payments
    for (var payment in allPayments) {
      if (payment.isOnTime) {
        totalOnTimePayments++;
      }
    }

    // Calculate payment streak
    if (allPayments.isNotEmpty) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final lastPayment = allPayments.last;
      final lastPaymentDay = DateTime(
          lastPayment.date.year, lastPayment.date.month, lastPayment.date.day);

      if (lastPayment.isOnTime) {
        final daysSinceLastPayment = today.difference(lastPaymentDay).inDays;
        if (daysSinceLastPayment <= 1) {
          if (lastPaymentDate != null &&
              lastPaymentDay
                      .difference(DateTime(lastPaymentDate.year,
                          lastPaymentDate.month, lastPaymentDate.day))
                      .inDays <=
                  1) {
            paymentStreak++;
          } else {
            paymentStreak = 1;
          }
          lastPaymentDate = lastPayment.date;
        }
      }
    }

    // Calculate savings streak
    final currentSavings = financialData.emergencySavings;
    if (currentSavings > (achievements.totalAmountSaved - 0.01)) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      if (lastSavingsDate != null) {
        final lastSavingsDay = DateTime(
            lastSavingsDate.year, lastSavingsDate.month, lastSavingsDate.day);
        final daysSinceLastSavings = today.difference(lastSavingsDay).inDays;
        if (daysSinceLastSavings <= 1) {
          savingsStreak++;
        } else {
          savingsStreak = 1;
        }
      } else {
        savingsStreak = 1;
      }
      lastSavingsDate = now;
    }

    // Update achievements
    final updatedAchievements = UserAchievements(
      badges: Map<String, Badge>.from(achievements.badges),
      totalPoints: achievements.totalPoints,
      currentPaymentStreak: paymentStreak,
      currentSavingsStreak: savingsStreak,
      totalOnTimePayments: totalOnTimePayments,
      totalAmountSaved: currentSavings,
      totalAmountPaid: totalAmountPaid,
      lastPaymentDate: lastPaymentDate ?? achievements.lastPaymentDate,
      lastSavingsDate: lastSavingsDate ?? achievements.lastSavingsDate,
    );

    // Check and award badges
    await _checkAndAwardBadges(updatedAchievements, debts, financialData);
  }

  static Future<void> _checkAndAwardBadges(
    UserAchievements achievements,
    List<Debt> debts,
    UserFinancialData financialData,
  ) async {
    final badges = Map<String, Badge>.from(achievements.badges);

    // Define all possible badges
    final allBadges = [
      // Payment streak badges
      Badge(
        id: 'streak_7',
        name: 'Week Warrior',
        description: 'Make 7 on-time payments in a row',
        type: BadgeType.paymentStreak,
        icon: Icons.local_fire_department,
        color: Colors.orange,
        requiredValue: 7,
        unlockedAt: achievements.currentPaymentStreak >= 7 &&
                !badges.containsKey('streak_7')
            ? DateTime.now()
            : badges['streak_7']?.unlockedAt,
      ),
      Badge(
        id: 'streak_30',
        name: 'Monthly Master',
        description: 'Make 30 on-time payments in a row',
        type: BadgeType.paymentStreak,
        icon: Icons.local_fire_department,
        color: Colors.deepOrange,
        requiredValue: 30,
        unlockedAt: achievements.currentPaymentStreak >= 30 &&
                !badges.containsKey('streak_30')
            ? DateTime.now()
            : badges['streak_30']?.unlockedAt,
      ),
      Badge(
        id: 'streak_100',
        name: 'Century Club',
        description: 'Make 100 on-time payments in a row',
        type: BadgeType.paymentStreak,
        icon: Icons.local_fire_department,
        color: Colors.red,
        requiredValue: 100,
        unlockedAt: achievements.currentPaymentStreak >= 100 &&
                !badges.containsKey('streak_100')
            ? DateTime.now()
            : badges['streak_100']?.unlockedAt,
      ),

      // Savings milestone badges
      Badge(
        id: 'savings_100',
        name: 'First \$100',
        description: 'Save your first \$100',
        type: BadgeType.savingsMilestone,
        icon: Icons.savings,
        color: Colors.green,
        requiredValue: 100,
        unlockedAt: achievements.totalAmountSaved >= 100 &&
                !badges.containsKey('savings_100')
            ? DateTime.now()
            : badges['savings_100']?.unlockedAt,
      ),
      Badge(
        id: 'savings_1000',
        name: 'Thousandaire',
        description: 'Save \$1,000',
        type: BadgeType.savingsMilestone,
        icon: Icons.savings,
        color: Colors.green.shade700,
        requiredValue: 1000,
        unlockedAt: achievements.totalAmountSaved >= 1000 &&
                !badges.containsKey('savings_1000')
            ? DateTime.now()
            : badges['savings_1000']?.unlockedAt,
      ),
      Badge(
        id: 'savings_5000',
        name: 'Emergency Fund',
        description: 'Save \$5,000',
        type: BadgeType.savingsMilestone,
        icon: Icons.savings,
        color: Colors.green.shade900,
        requiredValue: 5000,
        unlockedAt: achievements.totalAmountSaved >= 5000 &&
                !badges.containsKey('savings_5000')
            ? DateTime.now()
            : badges['savings_5000']?.unlockedAt,
      ),

      // Total payments badges
      Badge(
        id: 'payments_10',
        name: 'Getting Started',
        description: 'Make 10 on-time payments',
        type: BadgeType.totalPayments,
        icon: Icons.payments,
        color: Colors.blue,
        requiredValue: 10,
        unlockedAt: achievements.totalOnTimePayments >= 10 &&
                !badges.containsKey('payments_10')
            ? DateTime.now()
            : badges['payments_10']?.unlockedAt,
      ),
      Badge(
        id: 'payments_50',
        name: 'Dedicated',
        description: 'Make 50 on-time payments',
        type: BadgeType.totalPayments,
        icon: Icons.payments,
        color: Colors.blue.shade700,
        requiredValue: 50,
        unlockedAt: achievements.totalOnTimePayments >= 50 &&
                !badges.containsKey('payments_50')
            ? DateTime.now()
            : badges['payments_50']?.unlockedAt,
      ),
      Badge(
        id: 'payments_100',
        name: 'Centurion',
        description: 'Make 100 on-time payments',
        type: BadgeType.totalPayments,
        icon: Icons.payments,
        color: Colors.blue.shade900,
        requiredValue: 100,
        unlockedAt: achievements.totalOnTimePayments >= 100 &&
                !badges.containsKey('payments_100')
            ? DateTime.now()
            : badges['payments_100']?.unlockedAt,
      ),

      // Debt free badge
      Badge(
        id: 'debt_free',
        name: 'Debt Free!',
        description: 'Pay off all your debts',
        type: BadgeType.debtFree,
        icon: Icons.celebration,
        color: Colors.purple,
        requiredValue: 1,
        unlockedAt: debts.isNotEmpty &&
                debts.every((d) => d.currentBalance <= 0.01) &&
                !badges.containsKey('debt_free')
            ? DateTime.now()
            : badges['debt_free']?.unlockedAt,
      ),

      // Savings streak badges
      Badge(
        id: 'savings_streak_7',
        name: 'Savings Streak',
        description: 'Save money 7 days in a row',
        type: BadgeType.savingsStreak,
        icon: Icons.trending_up,
        color: Colors.amber,
        requiredValue: 7,
        unlockedAt: achievements.currentSavingsStreak >= 7 &&
                !badges.containsKey('savings_streak_7')
            ? DateTime.now()
            : badges['savings_streak_7']?.unlockedAt,
      ),
    ];

    // Update badges
    for (var badge in allBadges) {
      if (badge.isUnlocked && !badges.containsKey(badge.id)) {
        badges[badge.id] = badge;
      } else if (badge.isUnlocked) {
        badges[badge.id] = badge;
      } else {
        // Keep existing badge if not unlocked yet
        if (!badges.containsKey(badge.id)) {
          badges[badge.id] = Badge(
            id: badge.id,
            name: badge.name,
            description: badge.description,
            type: badge.type,
            icon: badge.icon,
            color: badge.color,
            requiredValue: badge.requiredValue,
          );
        }
      }
    }

    // Calculate total points (10 points per badge)
    final totalPoints = badges.values.where((b) => b.isUnlocked).length * 10;

    final updatedAchievements = UserAchievements(
      badges: badges,
      totalPoints: totalPoints,
      currentPaymentStreak: achievements.currentPaymentStreak,
      currentSavingsStreak: achievements.currentSavingsStreak,
      totalOnTimePayments: achievements.totalOnTimePayments,
      totalAmountSaved: achievements.totalAmountSaved,
      totalAmountPaid: achievements.totalAmountPaid,
      lastPaymentDate: achievements.lastPaymentDate,
      lastSavingsDate: achievements.lastSavingsDate,
    );

    await saveAchievements(updatedAchievements);
  }

  static Future<List<LeaderboardEntry>> getLeaderboard() async {
    // For now, return a single user entry (local leaderboard)
    // In a real app, this would fetch from a server
    final achievements = await getAchievements();
    final prefs = await SharedPreferences.getInstance();
    final firstName = prefs.getString('firstName') ?? 'You';

    return [
      LeaderboardEntry(
        userId: 'local_user',
        userName: firstName,
        points: achievements.totalPoints,
        rank: 1,
        paymentStreak: achievements.currentPaymentStreak,
        totalPaid: achievements.totalAmountPaid,
        totalSaved: achievements.totalAmountSaved,
      ),
    ];
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('🏗️ MyApp.build called');
    return MaterialApp(
      title: 'Debt Manager',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const WelcomePage(),
    );
  }
}

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF4A90E2), // Blue background
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 60),
                    // Shield Icon
                    Container(
                      width: 120,
                      height: 120,
                      decoration: const BoxDecoration(
                        color: Color(0xFF87CEEB), // Light blue
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.shield,
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // App Title
                    const Text(
                      'CogniCents',
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your path to financial peace',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 48),
                    // Information Cards
                    _buildInfoCard(
                      context,
                      title: 'Smart Debt Planning',
                      description:
                          'Choose strategies that work for you and see your debt-free future',
                      icon: Icons.show_chart,
                    ),
                    const SizedBox(height: 16),
                    _buildInfoCard(
                      context,
                      title: 'Reduce Financial Stress',
                      description:
                          'Track progress and receive supportive nudges to stay on track',
                      icon: Icons.favorite_border,
                    ),
                    const SizedBox(height: 16),
                    _buildInfoCard(
                      context,
                      title: 'Personalized Insights',
                      description:
                          'AI-powered recommendations tailored to your unique situation',
                      icon: Icons.auto_awesome,
                    ),
                  ],
                ),
              ),
            ),
            // Get Started Button
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const WelcomeIntroPage(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF4A90E2),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Get Started',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Color(0xFF87CEEB),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
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

// Welcome Intro Page (Step 1 of 5)
class WelcomeIntroPage extends StatelessWidget {
  const WelcomeIntroPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Text(
                'Welcome to CogniCents',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[900],
                    ),
              ),
              const SizedBox(height: 24),
              Text(
                'Let\'s take a few moments to understand your financial situation. This will help us provide personalized guidance and support.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
              ),
              const SizedBox(height: 16),
              Text(
                'Everything you share is private and secure. You can skip any question you\'re not comfortable answering.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
              ),
              const Spacer(),
              _buildPaginationDots(1, 5),
              const SizedBox(height: 24),
              _buildContinueButton(
                context,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PersonalInfoPage(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Personal Info Page (new onboarding step before financial questions)
class PersonalInfoPage extends StatefulWidget {
  const PersonalInfoPage({super.key});

  @override
  State<PersonalInfoPage> createState() => _PersonalInfoPageState();
}

class _PersonalInfoPageState extends State<PersonalInfoPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _countryController = TextEditingController();
  final _stateController = TextEditingController();
  final _cityController = TextEditingController();
  final _ageController = TextEditingController();
  String _gender = 'Prefer not to say';
  final _specialController = TextEditingController();

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _countryController.dispose();
    _stateController.dispose();
    _cityController.dispose();
    _ageController.dispose();
    _specialController.dispose();
    super.dispose();
  }

  Future<void> _saveAndContinue() async {
    if (!_formKey.currentState!.validate()) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('firstName', _firstNameController.text.trim());
    await prefs.setString('lastName', _lastNameController.text.trim());
    await prefs.setString('country', _countryController.text.trim());
    await prefs.setString('state', _stateController.text.trim());
    await prefs.setString('city', _cityController.text.trim());

    final ageValue = int.tryParse(_ageController.text.trim());
    if (ageValue != null) {
      await prefs.setInt('age', ageValue);
    }

    await prefs.setString('gender', _gender);
    await prefs.setString(
        'specialCircumstances', _specialController.text.trim());

    // Navigate to the existing financial snapshot page
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const FinancialSnapshotPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF0F4F8), Color(0xFFE8EEF4)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    Text(
                      'About You',
                      style:
                          Theme.of(context).textTheme.headlineLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[900],
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Let\'s get to know you better to personalize your experience.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: Scrollbar(
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.only(right: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildRequiredLabel('First name'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _firstNameController,
                                decoration: _inputDecoration('First name'),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'Enter first name'
                                        : null,
                              ),
                              const SizedBox(height: 16),
                              _buildRequiredLabel('Last name'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _lastNameController,
                                decoration: _inputDecoration('Last name'),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'Enter last name'
                                        : null,
                              ),
                              const SizedBox(height: 16),
                              _buildLabel('Country'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _countryController,
                                decoration: _inputDecoration('Country'),
                              ),
                              const SizedBox(height: 16),
                              _buildLabel('State / Province'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _stateController,
                                decoration: _inputDecoration(
                                    'State / Province (if applicable)'),
                              ),
                              const SizedBox(height: 16),
                              _buildLabel('City'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _cityController,
                                decoration: _inputDecoration('City'),
                              ),
                              const SizedBox(height: 16),
                              _buildLabel('Age'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _ageController,
                                decoration: _inputDecoration('Age'),
                                keyboardType: TextInputType.number,
                              ),
                              const SizedBox(height: 16),
                              _buildLabel('Gender'),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                value: _gender,
                                decoration: _inputDecoration(''),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'Female', child: Text('Female')),
                                  DropdownMenuItem(
                                      value: 'Male', child: Text('Male')),
                                  DropdownMenuItem(
                                      value: 'Non-binary',
                                      child: Text('Non-binary')),
                                  DropdownMenuItem(
                                      value: 'Prefer not to say',
                                      child: Text('Prefer not to say')),
                                ],
                                onChanged: (v) => setState(
                                    () => _gender = v ?? 'Prefer not to say'),
                              ),
                              const SizedBox(height: 16),
                              _buildLabel('Special circumstances'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _specialController,
                                decoration: _inputDecoration(
                                    'e.g. disability, irregular income, family support'),
                                minLines: 3,
                                maxLines: 6,
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    ),
                    _buildPaginationDots(1, 6),
                    const SizedBox(height: 16),
                    _buildContinueButton(
                      context,
                      onPressed: _saveAndContinue,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequiredLabel(String text) {
    return Row(
      children: [
        Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
        const Text(' *',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Text(text, style: const TextStyle(fontWeight: FontWeight.bold));
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
    );
  }
}

// Financial Snapshot Page (Step 2 of 5)
class FinancialSnapshotPage extends StatefulWidget {
  const FinancialSnapshotPage({super.key});

  @override
  State<FinancialSnapshotPage> createState() => _FinancialSnapshotPageState();
}

class _FinancialSnapshotPageState extends State<FinancialSnapshotPage> {
  final _formKey = GlobalKey<FormState>();
  final _totalDebtController = TextEditingController();
  final _monthlyIncomeController = TextEditingController();
  final _incomeVariabilityController = TextEditingController();
  String _payFrequency = 'monthly';
  bool _isIncomeStable = true;

  @override
  void dispose() {
    _totalDebtController.dispose();
    _monthlyIncomeController.dispose();
    _incomeVariabilityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF0F4F8), Color(0xFFE8EEF4)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Scrollbar(
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.only(right: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 40),
                              Text(
                                'Your Financial Snapshot',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[900],
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Help us understand your current situation so we can create a personalized plan.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                              ),
                              const SizedBox(height: 40),
                              // Total Debt Amount
                              Row(
                                children: [
                                  Text(
                                    'Total Debt Amount',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey[900],
                                        ),
                                  ),
                                  const Text(' *',
                                      style: TextStyle(
                                          color: Colors.red,
                                          fontWeight: FontWeight.bold)),
                                  _buildInfoButton(
                                    context,
                                    'Why we need this',
                                    'This helps us calculate your debt-to-income ratio and estimate when you\'ll be debt-free. You can add individual debts later for detailed tracking.',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Enter the total amount you owe across all debts. You can add each debt individually later for detailed tracking.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _totalDebtController,
                                decoration: InputDecoration(
                                  hintText: 'Enter amount',
                                  prefixText: '\$ ',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide:
                                        BorderSide(color: Colors.grey[300]!),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                keyboardType: TextInputType.number,
                                style: const TextStyle(fontSize: 18),
                              ),
                              const SizedBox(height: 24),
                              // Monthly Income
                              Row(
                                children: [
                                  Text(
                                    'Monthly Income (after tax)',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey[900],
                                        ),
                                  ),
                                  const Text(' *',
                                      style: TextStyle(
                                          color: Colors.red,
                                          fontWeight: FontWeight.bold)),
                                  _buildInfoButton(
                                    context,
                                    'Why we need this',
                                    'We use this to determine how much you can comfortably put toward debt each month and calculate your debt-to-income ratio.',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _monthlyIncomeController,
                                decoration: InputDecoration(
                                  hintText: 'Enter amount',
                                  prefixText: '\$ ',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide:
                                        BorderSide(color: Colors.grey[300]!),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                keyboardType: TextInputType.number,
                                style: const TextStyle(fontSize: 18),
                              ),
                              const SizedBox(height: 24),
                              // Pay Frequency
                              Row(
                                children: [
                                  const Text(
                                    'Pay Frequency',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  _buildInfoButton(
                                    context,
                                    'Why we need this',
                                    'Knowing when you get paid helps us time payment reminders and budget your cash flow between paychecks.',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildFrequencyButton(
                                        'weekly', 'Weekly'),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildFrequencyButton(
                                        'biweekly', 'Biweekly'),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildFrequencyButton(
                                        'monthly', 'Monthly'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Income Stability
                              Row(
                                children: [
                                  Checkbox(
                                    value: _isIncomeStable,
                                    onChanged: (value) => setState(
                                        () => _isIncomeStable = value ?? true),
                                  ),
                                  const Expanded(
                                    child: Text(
                                      'My income is stable and predictable',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  ),
                                  _buildInfoButton(
                                    context,
                                    'Why we ask this',
                                    'Stable income lets us recommend more aggressive payoff strategies. Variable income means we\'ll suggest a larger emergency buffer first.',
                                  ),
                                ],
                              ),
                              // Show textbox if income is unstable
                              if (!_isIncomeStable) ...[
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _incomeVariabilityController,
                                  decoration: InputDecoration(
                                    hintText:
                                        'Tell us more about your income situation...',
                                    helperText:
                                        'e.g., freelance, seasonal work, commission-based',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  minLines: 2,
                                  maxLines: 4,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    _buildPaginationDots(2, 5),
                    const SizedBox(height: 24),
                    _buildContinueButton(
                      context,
                      onPressed: () async {
                        if (_formKey.currentState!.validate()) {
                          // Save data to SharedPreferences
                          try {
                            final monthlyIncome = double.tryParse(
                                    _monthlyIncomeController.text) ??
                                0;
                            final financialData = UserFinancialData(
                              monthlyIncome: monthlyIncome,
                              payFrequency: _payFrequency,
                              isIncomeStable: _isIncomeStable,
                            );
                            await DataService.saveFinancialData(financialData);
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setString(
                                'totalDebt', _totalDebtController.text);
                          } catch (e) {
                            // Continue even if save fails
                          }

                          if (context.mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const EssentialExpensesPage(),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFrequencyButton(String value, String label) {
    final isSelected = _payFrequency == value;
    return GestureDetector(
      onTap: () => setState(() => _payFrequency = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4A90E2) : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoButton(BuildContext context, String title, String message) {
    return IconButton(
      icon: Icon(Icons.info_outline, size: 20, color: Colors.grey[500]),
      padding: const EdgeInsets.only(left: 4),
      constraints: const BoxConstraints(),
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Got it'),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Essential Expenses Page
class EssentialExpensesPage extends StatefulWidget {
  const EssentialExpensesPage({super.key});

  @override
  State<EssentialExpensesPage> createState() => _EssentialExpensesPageState();
}

class _EssentialExpensesPageState extends State<EssentialExpensesPage> {
  // Use a map of double values for sliders instead of TextEditingControllers
  final Map<String, double> _expenses = {
    'Rent/Mortgage': 0,
    'Utilities': 0,
    'Groceries': 0,
    'Transportation': 0,
    'Insurance': 0,
    'Other': 0,
  };

  // Maximum values for each category (can be adjusted)
  final Map<String, double> _maxValues = {
    'Rent/Mortgage': 5000,
    'Utilities': 1000,
    'Groceries': 2000,
    'Transportation': 1500,
    'Insurance': 1500,
    'Other': 2000,
  };

  // Global median values (US averages) for reference
  final Map<String, double> _medianValues = {
    'Rent/Mortgage': 1800,
    'Utilities': 300,
    'Groceries': 600,
    'Transportation': 700,
    'Insurance': 500,
    'Other': 400,
  };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF0F4F8), Color(0xFFE8EEF4)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  Text(
                    'Essential Expenses',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[900],
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tell us about your monthly essential expenses.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 32),
                  Expanded(
                    child: Scrollbar(
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(right: 16),
                        child: Column(
                          children: _expenses.entries.map((entry) {
                            final maxValue = _maxValues[entry.key] ?? 3000;
                            final medianValue =
                                _medianValues[entry.key] ?? maxValue * 0.3;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        entry.key,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF4A90E2)
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '\$${entry.value.round()}',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF4A90E2),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  // Slider with median marker overlay
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      SliderTheme(
                                        data: SliderTheme.of(context).copyWith(
                                          activeTrackColor:
                                              const Color(0xFF4A90E2),
                                          inactiveTrackColor: Colors.grey[300],
                                          thumbColor: const Color(0xFF4A90E2),
                                          overlayColor: const Color(0xFF4A90E2)
                                              .withOpacity(0.2),
                                          trackHeight: 8,
                                          thumbShape:
                                              const RoundSliderThumbShape(
                                                  enabledThumbRadius: 12),
                                        ),
                                        child: Slider(
                                          value: entry.value,
                                          min: 0,
                                          max: maxValue,
                                          divisions: (maxValue / 50).round(),
                                          onChanged: (value) {
                                            setState(() {
                                              _expenses[entry.key] = value;
                                            });
                                          },
                                        ),
                                      ),
                                      // Median marker
                                      Positioned(
                                        left: (medianValue / maxValue) *
                                                (MediaQuery.of(context)
                                                        .size
                                                        .width -
                                                    72) +
                                            12,
                                        top: 0,
                                        bottom: 0,
                                        child: Container(
                                          width: 2,
                                          decoration: BoxDecoration(
                                            color: Colors.orange[700],
                                            borderRadius:
                                                BorderRadius.circular(1),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Min, Median, Max labels
                                  Stack(
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('\$0',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[500])),
                                          Text('\$${maxValue.round()}',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[500])),
                                        ],
                                      ),
                                      Positioned(
                                        left: (medianValue / maxValue) *
                                            (MediaQuery.of(context).size.width -
                                                72),
                                        child: Text(
                                          'Avg \$${medianValue.round()}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.orange[700],
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                  _buildPaginationDots(3, 6),
                  const SizedBox(height: 24),
                  _buildContinueButton(
                    context,
                    onPressed: () async {
                      final expenses = <String, double>{};
                      for (var entry in _expenses.entries) {
                        if (entry.value > 0) {
                          expenses[entry.key] = entry.value;
                        }
                      }

                      final financialData =
                          await DataService.getFinancialData();
                      final updatedData = UserFinancialData(
                        monthlyIncome: financialData.monthlyIncome,
                        payFrequency: financialData.payFrequency,
                        isIncomeStable: financialData.isIncomeStable,
                        essentialExpenses: expenses,
                        emergencySavings: financialData.emergencySavings,
                        monthlySavingsTarget:
                            financialData.monthlySavingsTarget,
                        stressLevel: financialData.stressLevel,
                        lastStressCheck: financialData.lastStressCheck,
                        stressHistory: financialData.stressHistory,
                        nudgePreferences: financialData.nudgePreferences,
                      );
                      await DataService.saveFinancialData(updatedData);

                      if (context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SavingsPage(),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Savings Page
class SavingsPage extends StatefulWidget {
  const SavingsPage({super.key});

  @override
  State<SavingsPage> createState() => _SavingsPageState();
}

class _SavingsPageState extends State<SavingsPage> {
  final _emergencySavingsController = TextEditingController();
  final _monthlySavingsTargetController = TextEditingController();

  @override
  void dispose() {
    _emergencySavingsController.dispose();
    _monthlySavingsTargetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Text(
                'Savings & Buffers',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[900],
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Help us understand your savings situation.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 40),
              // Emergency Savings
              const Text(
                'Emergency Savings',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emergencySavingsController,
                decoration: InputDecoration(
                  hintText: '\$ 0',
                  prefixText: '\$ ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 24),
              // Monthly Savings Target
              const Text(
                'Monthly Savings Target',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _monthlySavingsTargetController,
                decoration: InputDecoration(
                  hintText: '\$ 0',
                  prefixText: '\$ ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 18),
              ),
              const Spacer(),
              _buildPaginationDots(4, 6),
              const SizedBox(height: 24),
              _buildContinueButton(
                context,
                onPressed: () async {
                  final financialData = await DataService.getFinancialData();
                  final updatedData = UserFinancialData(
                    monthlyIncome: financialData.monthlyIncome,
                    payFrequency: financialData.payFrequency,
                    isIncomeStable: financialData.isIncomeStable,
                    essentialExpenses: financialData.essentialExpenses,
                    emergencySavings:
                        double.tryParse(_emergencySavingsController.text) ?? 0,
                    monthlySavingsTarget:
                        double.tryParse(_monthlySavingsTargetController.text) ??
                            0,
                    stressLevel: financialData.stressLevel,
                    lastStressCheck: financialData.lastStressCheck,
                    stressHistory: financialData.stressHistory,
                    nudgePreferences: financialData.nudgePreferences,
                  );
                  await DataService.saveFinancialData(updatedData);

                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FinancialWellnessPage(),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Financial Wellness Check Page (Step 5 of 6)
class FinancialWellnessPage extends StatefulWidget {
  const FinancialWellnessPage({super.key});

  @override
  State<FinancialWellnessPage> createState() => _FinancialWellnessPageState();
}

class _FinancialWellnessPageState extends State<FinancialWellnessPage> {
  int? stressLevel;
  String? difficultyLevel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Text(
                'Financial Wellness Check',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[900],
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Understanding your stress helps us provide better support.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 40),
              // Stress Level Question
              Text(
                'How stressed do you feel about your finances?',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[900],
                    ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(5, (index) {
                  final level = index + 1;
                  return GestureDetector(
                    onTap: () => setState(() => stressLevel = level),
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: stressLevel == level
                            ? const Color(0xFF4A90E2)
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '$level',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: stressLevel == level
                                ? Colors.white
                                : Colors.grey[700],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Not stressed',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  Text(
                    'Very stressed',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              // Difficulty Question
              Text(
                'Are you having difficulty paying for essential expenses?',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[900],
                    ),
              ),
              const SizedBox(height: 16),
              _buildDifficultyButton('No difficulty'),
              const SizedBox(height: 12),
              _buildDifficultyButton('Some difficulty'),
              const SizedBox(height: 12),
              _buildDifficultyButton('A lot of difficulty'),
              const Spacer(),
              _buildPaginationDots(5, 6),
              const SizedBox(height: 24),
              _buildContinueButton(
                context,
                onPressed: () async {
                  // Save stress data
                  final financialData = await DataService.getFinancialData();
                  final today = DateTime.now();
                  final dateKey = '${today.year}-${today.month}-${today.day}';
                  final updatedHistory =
                      Map<String, int>.from(financialData.stressHistory);
                  final newStressLevel =
                      stressLevel ?? financialData.stressLevel;
                  updatedHistory[dateKey] = newStressLevel;

                  final updatedData = UserFinancialData(
                    monthlyIncome: financialData.monthlyIncome,
                    payFrequency: financialData.payFrequency,
                    isIncomeStable: financialData.isIncomeStable,
                    essentialExpenses: financialData.essentialExpenses,
                    emergencySavings: financialData.emergencySavings,
                    monthlySavingsTarget: financialData.monthlySavingsTarget,
                    stressLevel: newStressLevel,
                    lastStressCheck: today,
                    stressHistory: updatedHistory,
                    nudgePreferences: financialData.nudgePreferences,
                  );
                  await DataService.saveFinancialData(updatedData);

                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CompletionPage(),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDifficultyButton(String text) {
    final isSelected = difficultyLevel == text;
    return GestureDetector(
      onTap: () => setState(() => difficultyLevel = text),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4A90E2) : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }
}

// Completion Page (Step 5 of 5)
class CompletionPage extends StatelessWidget {
  const CompletionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              // Success Icon
              Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  color: Color(0xFF90EE90),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  size: 60,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'You\'re All Set!',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[900],
                    ),
              ),
              const SizedBox(height: 24),
              Text(
                'We\'ve created a personalized plan to help you manage your debt and reduce financial stress.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
              ),
              const SizedBox(height: 16),
              Text(
                'Remember: Every journey starts with a single step. You\'ve already taken yours.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[500],
                      height: 1.5,
                    ),
              ),
              const Spacer(),
              _buildPaginationDots(6, 6),
              const SizedBox(height: 24),
              _buildContinueButton(
                context,
                label: 'Go to Dashboard',
                onPressed: () async {
                  // Save onboarding completion
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('onboardingCompleted', true);

                  if (context.mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HomePage(),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Helper Widgets
Widget _buildPaginationDots(int currentStep, int totalSteps) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: List.generate(totalSteps, (index) {
      final isActive = index < currentStep;
      return Container(
        width: 8,
        height: 8,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF4A90E2) : Colors.grey[300],
          shape: BoxShape.circle,
        ),
      );
    }),
  );
}

Widget _buildContinueButton(
  BuildContext context, {
  required VoidCallback onPressed,
  String label = 'Continue',
}) {
  return SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF4A90E2),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward, size: 20),
        ],
      ),
    ),
  );
}

// Add Debt Page
class AddDebtPage extends StatefulWidget {
  const AddDebtPage({super.key});

  @override
  State<AddDebtPage> createState() => _AddDebtPageState();
}

class _AddDebtPageState extends State<AddDebtPage> {
  final _formKey = GlobalKey<FormState>();
  final _debtNameController = TextEditingController();
  final _currentBalanceController = TextEditingController();
  final _interestRateController = TextEditingController();
  final _minimumPaymentController = TextEditingController();
  final _lenderNameController = TextEditingController();
  String? _selectedDebtType;
  DateTime? _dueDate;

  final List<String> _debtTypes = [
    'Credit Card',
    'Student Loan',
    'Personal Loan',
    'Mortgage',
    'Auto Loan',
    'Medical',
    'Other',
  ];

  @override
  void dispose() {
    _debtNameController.dispose();
    _currentBalanceController.dispose();
    _interestRateController.dispose();
    _minimumPaymentController.dispose();
    _lenderNameController.dispose();
    super.dispose();
  }

  Future<void> _saveDebt() async {
    if (_formKey.currentState!.validate() && _selectedDebtType != null) {
      try {
        final debt = Debt(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: _debtNameController.text,
          type: _selectedDebtType!,
          currentBalance: double.parse(_currentBalanceController.text),
          interestRate: double.parse(_interestRateController.text),
          minimumPayment: double.tryParse(_minimumPaymentController.text) ?? 0,
          dueDate: _dueDate,
          lenderName: _lenderNameController.text.isNotEmpty
              ? _lenderNameController.text
              : 'Unknown',
        );
        await DataService.saveDebt(debt);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Debt saved successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(
              context, true); // Return true to indicate refresh needed
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving debt: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else if (_selectedDebtType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a debt type'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Add Debt',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Debt Name
                const Text(
                  'Debt Name',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _debtNameController,
                  decoration: InputDecoration(
                    hintText: 'e.g., Chase Visa',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a debt name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                // Debt Type
                const Text(
                  'Debt Type',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _debtTypes.map((type) {
                    final isSelected = _selectedDebtType == type;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedDebtType = type),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF4A90E2)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF4A90E2)
                                : Colors.grey[300]!,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          type,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isSelected ? Colors.white : Colors.grey[700],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                // Current Balance
                const Text(
                  'Current Balance',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _currentBalanceController,
                  decoration: InputDecoration(
                    hintText: '\$ 0',
                    prefixText: '\$ ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 18),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter current balance';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                // Interest Rate
                const Text(
                  'Interest Rate (APR %)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _interestRateController,
                  decoration: InputDecoration(
                    hintText: '0.00',
                    suffixText: '%',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 18),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter interest rate';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                // Minimum Payment
                const Text(
                  'Minimum Payment',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _minimumPaymentController,
                  decoration: InputDecoration(
                    hintText: '\$ 0',
                    prefixText: '\$ ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 24),
                // Lender Name
                const Text(
                  'Lender Name',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _lenderNameController,
                  decoration: InputDecoration(
                    hintText: 'e.g., Chase Bank',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                ),
                const SizedBox(height: 24),
                // Due Date
                const Text(
                  'Due Date (Optional)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 1825)),
                    );
                    if (date != null) {
                      setState(() => _dueDate = date);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _dueDate == null
                              ? 'Select due date'
                              : '${_dueDate!.month}/${_dueDate!.day}/${_dueDate!.year}',
                          style: TextStyle(
                            fontSize: 18,
                            color: _dueDate == null
                                ? Colors.grey[600]
                                : Colors.black87,
                          ),
                        ),
                        const Icon(Icons.calendar_today, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                // Save Button
                ElevatedButton(
                  onPressed: _saveDebt,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A90E2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Save Debt',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _clearAllData(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Clear all stored data

    // Show confirmation dialog and restart to welcome page
    if (context.mounted) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Data Cleared'),
          content:
              const Text('All data has been cleared. The app will restart.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                // Navigate to welcome page and clear navigation stack
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const MyApp()),
                  (route) => false,
                );
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _showClearDataConfirmation(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text(
          'This will permanently delete all your debt information, financial data, '
          'and settings. This action cannot be undone. Are you sure you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear Data'),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      await _clearAllData(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.account_balance, color: Colors.blue),
            title: const Text('Banking & Transactions'),
            subtitle: const Text('Connect accounts and view spending'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BankingPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.notifications, color: Colors.orange),
            title: const Text('Notifications'),
            subtitle: const Text('Manage reminders and nudges'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const NotificationSettingsPage()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Clear All Data'),
            subtitle: const Text('Delete all debt info and restart the app'),
            onTap: () => _showClearDataConfirmation(context),
          ),
          const Divider(),
          // Future: Add more settings options here
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('About'),
            subtitle: const Text('Version 1.0.0'),
            onTap: () async {
              await showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('About CogniCents'),
                  content: const Text(
                    'CogniCents is your personal debt management companion. '
                    'Track your debts, manage your budget, and take control of your financial future.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// Badges Page
class BadgesPage extends StatefulWidget {
  const BadgesPage({super.key});

  @override
  State<BadgesPage> createState() => _BadgesPageState();
}

class _BadgesPageState extends State<BadgesPage> {
  UserAchievements? achievements;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAchievements();
  }

  Future<void> _loadAchievements() async {
    final achievementsData = await DataService.getAchievements();
    setState(() {
      achievements = achievementsData;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Badges'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final allBadges = _getAllBadges();
    final unlockedBadges = allBadges
        .where((b) => achievements!.badges[b.id]?.isUnlocked ?? false)
        .toList();
    final lockedBadges = allBadges
        .where((b) => !(achievements!.badges[b.id]?.isUnlocked ?? false))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Badges'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _loadAchievements,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stats Card
              Container(
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
                  children: [
                    Text(
                      '${achievements!.totalPoints}',
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Text(
                      'Total Points',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(
                          Icons.local_fire_department,
                          '${achievements!.currentPaymentStreak}',
                          'Day Streak',
                        ),
                        _buildStatItem(
                          Icons.savings,
                          '\$${achievements!.totalAmountSaved.toStringAsFixed(0)}',
                          'Saved',
                        ),
                        _buildStatItem(
                          Icons.payments,
                          '${achievements!.totalOnTimePayments}',
                          'On-Time',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Unlocked Badges
              if (unlockedBadges.isNotEmpty) ...[
                Text(
                  'Unlocked (${unlockedBadges.length})',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: unlockedBadges.length,
                  itemBuilder: (context, index) {
                    final badge =
                        achievements!.badges[unlockedBadges[index].id]!;
                    return _buildBadgeCard(badge, true);
                  },
                ),
                const SizedBox(height: 24),
              ],
              // Locked Badges
              Text(
                'Locked (${lockedBadges.length})',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.9,
                ),
                itemCount: lockedBadges.length,
                itemBuilder: (context, index) {
                  final badge = lockedBadges[index];
                  return _buildBadgeCard(badge, false);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildBadgeCard(Badge badge, bool isUnlocked) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUnlocked ? badge.color.withOpacity(0.1) : Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUnlocked ? badge.color : Colors.grey[300]!,
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            badge.icon,
            size: 48,
            color: isUnlocked ? badge.color : Colors.grey[400],
          ),
          const SizedBox(height: 8),
          Text(
            badge.name,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isUnlocked ? Colors.black87 : Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            badge.description,
            style: TextStyle(
              fontSize: 11,
              color: isUnlocked ? Colors.black54 : Colors.grey[500],
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (isUnlocked && badge.unlockedAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Unlocked ${_formatDate(badge.unlockedAt!)}',
              style: TextStyle(
                fontSize: 10,
                color: badge.color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inDays == 0) {
      return 'today';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }

  List<Badge> _getAllBadges() {
    return [
      Badge(
        id: 'streak_7',
        name: 'Week Warrior',
        description: 'Make 7 on-time payments in a row',
        type: BadgeType.paymentStreak,
        icon: Icons.local_fire_department,
        color: Colors.orange,
        requiredValue: 7,
      ),
      Badge(
        id: 'streak_30',
        name: 'Monthly Master',
        description: 'Make 30 on-time payments in a row',
        type: BadgeType.paymentStreak,
        icon: Icons.local_fire_department,
        color: Colors.deepOrange,
        requiredValue: 30,
      ),
      Badge(
        id: 'streak_100',
        name: 'Century Club',
        description: 'Make 100 on-time payments in a row',
        type: BadgeType.paymentStreak,
        icon: Icons.local_fire_department,
        color: Colors.red,
        requiredValue: 100,
      ),
      Badge(
        id: 'savings_100',
        name: 'First \$100',
        description: 'Save your first \$100',
        type: BadgeType.savingsMilestone,
        icon: Icons.savings,
        color: Colors.green,
        requiredValue: 100,
      ),
      Badge(
        id: 'savings_1000',
        name: 'Thousandaire',
        description: 'Save \$1,000',
        type: BadgeType.savingsMilestone,
        icon: Icons.savings,
        color: Colors.green.shade700,
        requiredValue: 1000,
      ),
      Badge(
        id: 'savings_5000',
        name: 'Emergency Fund',
        description: 'Save \$5,000',
        type: BadgeType.savingsMilestone,
        icon: Icons.savings,
        color: Colors.green.shade900,
        requiredValue: 5000,
      ),
      Badge(
        id: 'payments_10',
        name: 'Getting Started',
        description: 'Make 10 on-time payments',
        type: BadgeType.totalPayments,
        icon: Icons.payments,
        color: Colors.blue,
        requiredValue: 10,
      ),
      Badge(
        id: 'payments_50',
        name: 'Dedicated',
        description: 'Make 50 on-time payments',
        type: BadgeType.totalPayments,
        icon: Icons.payments,
        color: Colors.blue.shade700,
        requiredValue: 50,
      ),
      Badge(
        id: 'payments_100',
        name: 'Centurion',
        description: 'Make 100 on-time payments',
        type: BadgeType.totalPayments,
        icon: Icons.payments,
        color: Colors.blue.shade900,
        requiredValue: 100,
      ),
      Badge(
        id: 'debt_free',
        name: 'Debt Free!',
        description: 'Pay off all your debts',
        type: BadgeType.debtFree,
        icon: Icons.celebration,
        color: Colors.purple,
        requiredValue: 1,
      ),
      Badge(
        id: 'savings_streak_7',
        name: 'Savings Streak',
        description: 'Save money 7 days in a row',
        type: BadgeType.savingsStreak,
        icon: Icons.trending_up,
        color: Colors.amber,
        requiredValue: 7,
      ),
    ];
  }
}

// Leaderboard Page
class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  List<LeaderboardEntry>? leaderboard;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    final leaderboardData = await DataService.getLeaderboard();
    setState(() {
      leaderboard = leaderboardData;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Leaderboard'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _loadLeaderboard,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // Header with time period selector
              Container(
                padding: const EdgeInsets.all(16),
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.emoji_events,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Your Rankings',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Leaderboard entries
              if (leaderboard!.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.leaderboard_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No leaderboard data yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start making payments to see your ranking!',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
                ...leaderboard!.asMap().entries.map((entry) {
                  final index = entry.key;
                  final user = entry.value;
                  final isCurrentUser = user.userId == 'local_user';

                  return _buildLeaderboardEntry(user, index + 1, isCurrentUser);
                }),
              const SizedBox(height: 16),
              // Stats summary
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Stats',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 16),
                      _buildStatRow(
                          'Total Points', '${leaderboard!.first.points}'),
                      _buildStatRow('Payment Streak',
                          '${leaderboard!.first.paymentStreak} days'),
                      _buildStatRow('Total Paid',
                          '\$${leaderboard!.first.totalPaid.toStringAsFixed(2)}'),
                      _buildStatRow('Total Saved',
                          '\$${leaderboard!.first.totalSaved.toStringAsFixed(2)}'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderboardEntry(
      LeaderboardEntry entry, int rank, bool isCurrentUser) {
    Color rankColor;
    IconData? rankIcon;

    if (rank == 1) {
      rankColor = Colors.amber;
      rankIcon = Icons.emoji_events;
    } else if (rank == 2) {
      rankColor = Colors.grey[400]!;
      rankIcon = Icons.emoji_events;
    } else if (rank == 3) {
      rankColor = Colors.brown[400]!;
      rankIcon = Icons.emoji_events;
    } else {
      rankColor = Colors.grey[600]!;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentUser
              ? Theme.of(context).colorScheme.primary
              : Colors.grey[300]!,
          width: isCurrentUser ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          // Rank
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: rank <= 3 ? rankColor.withOpacity(0.2) : Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: rank <= 3 && rankIcon != null
                  ? Icon(rankIcon, color: rankColor, size: 28)
                  : Text(
                      '#$rank',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: rankColor,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 16),
          // User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      entry.userName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isCurrentUser
                            ? Theme.of(context).colorScheme.primary
                            : Colors.black87,
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'You',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.local_fire_department,
                        size: 16, color: Colors.orange),
                    const SizedBox(width: 4),
                    Text(
                      '${entry.paymentStreak} day streak',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Points
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.points}',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              Text(
                'points',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// Banking Page
class BankingPage extends StatefulWidget {
  const BankingPage({super.key});

  @override
  State<BankingPage> createState() => _BankingPageState();
}

class _BankingPageState extends State<BankingPage> {
  List<BankingAccount> _accounts = [];
  BankingAccount? _selectedAccount;
  List<BankingTransaction> _transactions = [];
  Map<String, double> _spendingByCategory = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final accounts = await BankingService.getConnectedAccounts();
    setState(() {
      _accounts = accounts;
      // Always reset selected account to fix dropdown value mismatch
      // Find by ID if we had a previous selection, otherwise use first
      if (accounts.isNotEmpty) {
        if (_selectedAccount != null) {
          // Try to find the same account by ID
          final matchingAccount =
              accounts.where((a) => a.id == _selectedAccount!.id).toList();
          _selectedAccount = matchingAccount.isNotEmpty
              ? matchingAccount.first
              : accounts.first;
        } else {
          _selectedAccount = accounts.first;
        }
      } else {
        _selectedAccount = null;
      }
    });
    if (_selectedAccount != null) {
      await _loadAccountData(_selectedAccount!.id);
    }
    setState(() => _isLoading = false);
  }

  Future<void> _loadAccountData(String accountId) async {
    final transactions = await BankingService.getTransactions(accountId);
    final spending = await BankingService.getSpendingByCategory(accountId);
    setState(() {
      _transactions = transactions;
      _spendingByCategory = spending;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Banking & Transactions'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showConnectAccountDialog(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _accounts.isEmpty
              ? _buildEmptyState()
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      // Account selector
                      Container(
                        padding: const EdgeInsets.all(16),
                        child: DropdownButton<BankingAccount>(
                          value: _selectedAccount,
                          isExpanded: true,
                          items: _accounts.map((account) {
                            return DropdownMenuItem(
                              value: account,
                              child: Text(
                                  '${account.accountName} - ${account.bankName}'),
                            );
                          }).toList(),
                          onChanged: (account) {
                            setState(() => _selectedAccount = account);
                            if (account != null) {
                              _loadAccountData(account.id);
                            }
                          },
                        ),
                      ),
                      // Account balance card
                      if (_selectedAccount != null) ...[
                        Card(
                          margin: const EdgeInsets.all(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedAccount!.accountName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Balance: \$${_selectedAccount!.balance.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                                Text(
                                  'Account: ${_selectedAccount!.accountNumber}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Spending by category
                        if (_spendingByCategory.isNotEmpty) ...[
                          Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Spending by Category',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ..._spendingByCategory.entries.map((entry) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 4),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(entry.key),
                                          Text(
                                            '\$${entry.value.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ),
                        ],
                        // Recent transactions
                        Card(
                          margin: const EdgeInsets.all(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Recent Transactions',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ..._transactions.take(10).map((transaction) {
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: transaction.isDebit
                                          ? Colors.red[100]
                                          : Colors.green[100],
                                      child: Icon(
                                        transaction.isDebit
                                            ? Icons.arrow_downward
                                            : Icons.arrow_upward,
                                        color: transaction.isDebit
                                            ? Colors.red
                                            : Colors.green,
                                      ),
                                    ),
                                    title: Text(transaction.merchant),
                                    subtitle: Text(
                                      '${transaction.date.toString().split(' ')[0]} • ${transaction.category}',
                                    ),
                                    trailing: Text(
                                      '\$${transaction.amount.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: transaction.isDebit
                                            ? Colors.red
                                            : Colors.green,
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_balance, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No bank accounts connected',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => _showConnectAccountDialog(),
            child: const Text('Connect Bank Account'),
          ),
        ],
      ),
    );
  }

  Future<void> _showConnectAccountDialog() async {
    final result = await Navigator.push<List<BankingAccount>>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => PlaidLinkSimulator(
          onSuccess: (accounts) {
            Navigator.pop(context, accounts);
          },
          onCancel: () {
            Navigator.pop(context);
          },
        ),
      ),
    );

    if (result != null && result.isNotEmpty) {
      _loadData();
    }
  }
}

// Notification Settings Page
class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool _notificationsEnabled = true;
  String _nudgeTime = '09:00';
  bool _emailNotificationsEnabled = false;
  String _emailAddress = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _nudgeTime = prefs.getString('nudge_time') ?? '09:00';
      _emailNotificationsEnabled =
          prefs.getBool('email_notifications_enabled') ?? false;
      _emailAddress = prefs.getString('email_address') ?? '';
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', _notificationsEnabled);
    await prefs.setString('nudge_time', _nudgeTime);
    await prefs.setBool(
        'email_notifications_enabled', _emailNotificationsEnabled);
    await prefs.setString('email_address', _emailAddress);
    // Notifications disabled
  }

  Future<void> _selectTime() async {
    final parts = _nudgeTime.split(':');
    final initialTime = TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (selectedTime != null) {
      setState(() {
        _nudgeTime =
            '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';
      });
      await _saveSettings();
    }
  }

  Future<void> _testNotification() async {
    // Notifications disabled
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notifications are currently disabled')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Local Notifications
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Push Notifications',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Switch(
                        value: _notificationsEnabled,
                        onChanged: (value) async {
                          setState(() => _notificationsEnabled = value);
                          await _saveSettings();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(Icons.access_time),
                    title: const Text('Daily Nudge Time'),
                    subtitle: Text(_nudgeTime),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: _selectTime,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _testNotification,
                    icon: const Icon(Icons.notifications_active),
                    label: const Text('Send Test Notification'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Email Notifications
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Email Notifications',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Switch(
                        value: _emailNotificationsEnabled,
                        onChanged: (value) async {
                          setState(() => _emailNotificationsEnabled = value);
                          await _saveSettings();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      hintText: 'your.email@example.com',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (value) async {
                      _emailAddress = value;
                      await _saveSettings();
                    },
                    controller: TextEditingController(text: _emailAddress),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Note: Email notifications are simulated in this demo. In production, this would use a service like SendGrid.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? firstName;
  String? lastName;
  double totalDebt = 0;
  double enteredTotalDebt = 0; // Total debt entered in Financial Snapshot
  double currentSalary = 0;
  double monthlyExpenses = 0;
  bool isLoading = true;
  int touchedIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  List<Debt> debts = [];
  UserFinancialData? financialData;
  DateTime? debtFreeDate;
  double totalPaid = 0;
  int upcomingPayments = 0;
  int overduePayments = 0;
  int onTimeStreak = 0;
  String riskScore = 'Low';
  Color riskColor = Colors.green;
  int currentStressLevel = 5;
  double? previousStressLevel;
  List<String> behaviorHighlights = [];

  Future<void> _loadUserData() async {
    try {
      setState(() => isLoading = true);
      final prefs = await SharedPreferences.getInstance();
      firstName = prefs.getString('firstName') ?? '';
      lastName = prefs.getString('lastName') ?? '';

      debts = await DataService.getDebts();
      financialData = await DataService.getFinancialData();

      // Load entered total debt from SharedPreferences
      final enteredDebtStr = prefs.getString('totalDebt') ?? '0';
      enteredTotalDebt = double.tryParse(enteredDebtStr) ?? 0;

      // Calculate statistics (tracked debts)
      totalDebt = debts.fold(0.0, (sum, debt) => sum + debt.currentBalance);
      totalPaid = debts.fold(0.0, (sum, debt) => sum + debt.totalPaid);
      currentSalary = financialData!.monthlyIncome * 12;
      monthlyExpenses = financialData!.essentialExpenses.values
          .fold(0.0, (sum, val) => sum + val);

      // Calculate debt-free date
      debtFreeDate = _calculateDebtFreeDate();

      // Calculate payment status
      _calculatePaymentStatus();

      // Calculate risk score
      _calculateRiskScore();

      // Get stress level
      currentStressLevel = financialData!.stressLevel;
      previousStressLevel = _getPreviousStressLevel();

      // Generate behavior highlights
      behaviorHighlights = _generateBehaviorHighlights();

      setState(() => isLoading = false);
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  DateTime? _calculateDebtFreeDate() {
    if (debts.isEmpty || availableForDebt <= 0) return null;

    double remainingDebt = totalDebt;
    DateTime currentDate = DateTime.now();
    int months = 0;

    while (remainingDebt > 0 && months < 600) {
      // Calculate monthly interest
      double monthlyInterest = 0;
      for (var debt in debts) {
        if (debt.currentBalance > 0) {
          monthlyInterest +=
              (debt.currentBalance * debt.interestRate / 100) / 12;
        }
      }

      double payment = availableForDebt;
      remainingDebt = remainingDebt + monthlyInterest - payment;
      if (remainingDebt < 0) remainingDebt = 0;

      months++;
      if (remainingDebt <= 0) break;
    }

    return currentDate.add(Duration(days: months * 30));
  }

  void _calculatePaymentStatus() {
    final now = DateTime.now();
    final next30Days = now.add(const Duration(days: 30));

    upcomingPayments = 0;
    overduePayments = 0;
    onTimeStreak = 0;

    for (var debt in debts) {
      if (debt.dueDate != null) {
        if (debt.dueDate!.isBefore(now)) {
          overduePayments++;
        } else if (debt.dueDate!.isBefore(next30Days)) {
          upcomingPayments++;
        }
      }

      // Calculate on-time streak
      int streak = 0;
      for (var payment in debt.paymentHistory.reversed) {
        if (payment.isOnTime) {
          streak++;
        } else {
          break;
        }
      }
      if (streak > onTimeStreak) onTimeStreak = streak;
    }
  }

  void _calculateRiskScore() {
    int riskPoints = 0;

    // Late payments
    if (overduePayments > 0) riskPoints += 3;
    if (onTimeStreak < 3) riskPoints += 1;

    // Debt to income ratio
    final ratio = debtToIncomeRatio;
    if (ratio > 40) {
      riskPoints += 3;
    } else if (ratio > 20) {
      riskPoints += 1;
    }

    // Low cash buffer
    if (financialData != null) {
      final monthlyExpenses = this.monthlyExpenses;
      final bufferMonths = financialData!.emergencySavings / monthlyExpenses;
      if (bufferMonths < 1) {
        riskPoints += 2;
      } else if (bufferMonths < 3) {
        riskPoints += 1;
      }
    }

    // High stress
    if (currentStressLevel >= 8) riskPoints += 1;

    if (riskPoints >= 5) {
      riskScore = 'High';
      riskColor = Colors.red;
    } else if (riskPoints >= 2) {
      riskScore = 'Medium';
      riskColor = Colors.orange;
    } else {
      riskScore = 'Low';
      riskColor = Colors.green;
    }
  }

  double? _getPreviousStressLevel() {
    if (financialData == null) return null;
    final history = financialData!.stressHistory;
    if (history.isEmpty) return null;

    final sortedDates = history.keys.toList()..sort();
    if (sortedDates.length < 2) return null;

    return history[sortedDates[sortedDates.length - 2]]?.toDouble();
  }

  List<String> _generateBehaviorHighlights() {
    final highlights = <String>[];

    // Check for early payoff
    for (var debt in debts) {
      if (debt.paymentHistory.isNotEmpty) {
        final avgPayment =
            debt.paymentHistory.map((p) => p.amount).reduce((a, b) => a + b) /
                debt.paymentHistory.length;
        if (avgPayment > debt.minimumPayment * 1.5) {
          final monthsEarly = ((debt.currentBalance / avgPayment) -
                  (debt.currentBalance / debt.minimumPayment))
              .round();
          if (monthsEarly > 0) {
            highlights.add(
                'You\'re on track to pay off ${debt.name} $monthsEarly months early!');
            break;
          }
        }
      }
    }

    // Check spending trends (simplified - would need transaction data)
    if (financialData != null && financialData!.monthlySavingsTarget > 0) {
      final savingsRate =
          (availableForDebt / financialData!.monthlyIncome) * 100;
      if (savingsRate > 20) {
        highlights.add(
            'Great job! You\'re saving ${savingsRate.toStringAsFixed(0)}% of your income.');
      }
    }

    if (highlights.isEmpty) {
      highlights.add('Keep making consistent payments to build your streak!');
    }

    return highlights;
  }

  double get monthlyIncome => financialData?.monthlyIncome ?? 0;
  double get availableForDebt {
    if (financialData == null) return 0;
    final expenses = financialData!.essentialExpenses.values
        .fold(0.0, (sum, val) => sum + val);
    final totalMinPayments =
        debts.fold(0.0, (sum, debt) => sum + debt.minimumPayment);
    return monthlyIncome - expenses - totalMinPayments;
  }

  double get debtToIncomeRatio {
    if (monthlyIncome == 0) return 0;
    return (totalDebt / (monthlyIncome * 12)) * 100;
  }

  int get monthsToPayoff {
    if (availableForDebt <= 0) return 0;
    return (totalDebt / availableForDebt).ceil();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          firstName != null && firstName!.isNotEmpty
                              ? 'Hello, $firstName!'
                              : 'Hello!',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[900],
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Here\'s your financial overview',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        // Test Notification Button
                        IconButton(
                          icon: Icon(Icons.notifications_active,
                              color: Colors.grey[600]),
                          tooltip: 'Test Notification',
                          onPressed: () async {
                            final notificationService = NotificationService();
                            await notificationService.initialize();
                            await notificationService.requestPermissions();
                            await notificationService.showNotification(
                              id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                              title: '🔔 Test Notification',
                              body:
                                  'Notifications are working! You\'re all set.',
                              payload: 'test',
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Notification sent! Check your notification center.'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                        ),
                        // Nudge Lab Button
                        IconButton(
                          icon: Icon(Icons.science, color: Colors.purple[400]),
                          tooltip: 'Nudge Lab',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const NudgeTestPage(),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.settings, color: Colors.grey[600]),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const SettingsPage()),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Debt Snapshot Card
                _buildDebtSnapshotCard(context),
                const SizedBox(height: 16),
                // Payoff Strategy Comparison Chart
                _buildPayoffStrategiesChart(context),
                const SizedBox(height: 12),
                // View Debt Snapshot Button
                TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DebtSnapshotPage(
                            debts: debts, financialData: financialData),
                      ),
                    );
                  },
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('View Debt Snapshot'),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),
                // Monthly Cash Flow Card
                _buildCashFlowCard(context),
                const SizedBox(height: 16),
                // Payment Status Card
                _buildPaymentStatusCard(context),
                const SizedBox(height: 16),
                // Risk Score & Stress Indicator Row
                Row(
                  children: [
                    Expanded(child: _buildRiskScoreCard(context)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildStressIndicatorCard(context)),
                  ],
                ),
                const SizedBox(height: 16),
                // Behavior Highlights
                if (behaviorHighlights.isNotEmpty)
                  _buildBehaviorHighlightsCard(context),
                const SizedBox(height: 16),
                // AI Chat Banner
                _buildAIChatBanner(context),
                const SizedBox(height: 24),
                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildActionButton(
                      context,
                      icon: Icons.track_changes,
                      label: 'View Plan',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FinancialPlanPage(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    _buildActionButton(
                      context,
                      icon: Icons.calendar_month,
                      label: 'Calendar',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CalendarPage(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    _buildActionButton(
                      context,
                      icon: Icons.trending_down,
                      label: 'Progress',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProgressPage(
                              debts: debts,
                              financialData: financialData,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Savings Button
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        context,
                        icon: Icons.savings,
                        label: 'Savings',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const savings.SavingsPage(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Badges and Leaderboard Row
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        context,
                        icon: Icons.emoji_events,
                        label: 'Badges',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const BadgesPage(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionButton(
                        context,
                        icon: Icons.leaderboard,
                        label: 'Leaderboard',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LeaderboardPage(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Debt List
                if (debts.isEmpty)
                  _buildEmptyState(context)
                else ...[
                  _buildDebtList(context),
                  const SizedBox(height: 16),
                  // Add Another Debt button (shows when debts exist)
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AddDebtPage(),
                          ),
                        );
                        if (result == true) {
                          _loadUserData();
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add Another Debt'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                // Debt Tracking Progress Pie Chart
                if (enteredTotalDebt > 0) _buildDebtTrackingPieChart(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDebtSnapshotCard(BuildContext context) {
    final totalMinPayments =
        debts.fold(0.0, (sum, debt) => sum + debt.minimumPayment);
    final untrackedDebt =
        enteredTotalDebt > totalDebt ? enteredTotalDebt - totalDebt : 0.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Debt Snapshot',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: riskColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    riskScore,
                    style: TextStyle(
                        color: riskColor, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Show entered total if available
            if (enteredTotalDebt > 0) ...[
              _buildStatRow('Your Total Debt',
                  _formatCurrency(enteredTotalDebt), Colors.red),
              const SizedBox(height: 12),
              _buildStatRow(
                  'Tracked Debts', _formatCurrency(totalDebt), Colors.orange),
              if (untrackedDebt > 0) ...[
                const SizedBox(height: 12),
                _buildStatRow(
                    'Untracked', _formatCurrency(untrackedDebt), Colors.grey),
              ],
            ] else ...[
              _buildStatRow('Total Debt', _formatCurrency(totalDebt)),
            ],
            const SizedBox(height: 12),
            _buildStatRow('Total Paid', _formatCurrency(totalPaid)),
            const SizedBox(height: 12),
            _buildStatRow(
                'Min. Payments', '${_formatCurrency(totalMinPayments)}/mo'),
            if (debtFreeDate != null) ...[
              const SizedBox(height: 12),
              _buildStatRow(
                'Debt-Free Date',
                '${debtFreeDate!.month}/${debtFreeDate!.year}',
              ),
            ],
            // Prompt to add remaining debts
            if (untrackedDebt > 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline,
                        color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Add your remaining debts to get a complete picture',
                        style: TextStyle(fontSize: 13, color: Colors.blue[700]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPayoffStrategiesChart(BuildContext context) {
    if (debts.isEmpty || totalDebt <= 0) {
      return const SizedBox.shrink();
    }

    // Calculate Avalanche (highest interest first) projection
    final avalancheDebts = List<Debt>.from(debts)
      ..sort((a, b) => b.interestRate.compareTo(a.interestRate));
    final avalancheData = _calculatePayoffProjection(avalancheDebts);

    // Calculate Snowball (lowest balance first) projection
    final snowballDebts = List<Debt>.from(debts)
      ..sort((a, b) => a.currentBalance.compareTo(b.currentBalance));
    final snowballData = _calculatePayoffProjection(snowballDebts);

    final maxMonths = [avalancheData.length, snowballData.length]
        .reduce((a, b) => a > b ? a : b);
    final maxDebt = totalDebt;

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
                const Icon(Icons.show_chart, color: Color(0xFF4A90E2)),
                const SizedBox(width: 8),
                const Text(
                  'Payoff Strategy Comparison',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'See how different strategies affect your payoff timeline',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxDebt / 4,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey[200],
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        getTitlesWidget: (value, meta) {
                          if (value == 0 || value == maxDebt) {
                            return Text(
                              '\$${(value / 1000).toStringAsFixed(0)}k',
                              style: TextStyle(
                                  fontSize: 10, color: Colors.grey[600]),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: (maxMonths / 4).ceilToDouble(),
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toInt()}mo',
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey[600]),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: maxMonths.toDouble(),
                  minY: 0,
                  maxY: maxDebt,
                  lineBarsData: [
                    // Avalanche line (blue)
                    LineChartBarData(
                      spots: avalancheData
                          .asMap()
                          .entries
                          .map((e) => FlSpot(e.key.toDouble(), e.value))
                          .toList(),
                      isCurved: true,
                      color: const Color(0xFF4A90E2),
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: const Color(0xFF4A90E2).withOpacity(0.1),
                      ),
                    ),
                    // Snowball line (green)
                    LineChartBarData(
                      spots: snowballData
                          .asMap()
                          .entries
                          .map((e) => FlSpot(e.key.toDouble(), e.value))
                          .toList(),
                      isCurved: true,
                      color: Colors.green,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.green.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildChartLegendItem('Avalanche', const Color(0xFF4A90E2),
                    '${avalancheData.length} mo'),
                const SizedBox(width: 24),
                _buildChartLegendItem(
                    'Snowball', Colors.green, '${snowballData.length} mo'),
              ],
            ),
            const SizedBox(height: 12),
            // Which is better?
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: avalancheData.length <= snowballData.length
                    ? const Color(0xFF4A90E2).withOpacity(0.1)
                    : Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: avalancheData.length <= snowballData.length
                        ? const Color(0xFF4A90E2)
                        : Colors.green,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      avalancheData.length <= snowballData.length
                          ? 'Avalanche saves you time and money (highest interest first)'
                          : 'Snowball gives quick wins for motivation (lowest balance first)',
                      style: TextStyle(
                        fontSize: 13,
                        color: avalancheData.length <= snowballData.length
                            ? const Color(0xFF4A90E2)
                            : Colors.green[700],
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

  Widget _buildChartLegendItem(String label, Color color, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(width: 4),
        Text(value, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }

  List<double> _calculatePayoffProjection(List<Debt> sortedDebts) {
    if (sortedDebts.isEmpty) return [0];

    // Use mutable local copies of balances
    final balances = sortedDebts.map((d) => d.currentBalance).toList();
    final rates = sortedDebts.map((d) => d.interestRate / 100 / 12).toList();
    final minPayments = sortedDebts.map((d) => d.minimumPayment).toList();

    final List<double> balanceHistory = [
      balances.fold(0.0, (sum, b) => sum + b)
    ];
    final extraPayment = (monthlyIncome * 0.1).clamp(50.0, 500.0);

    int month = 0;
    const maxMonths = 360;

    while (balances.any((b) => b > 0) && month < maxMonths) {
      month++;
      double remainingExtra = extraPayment;

      for (int i = 0; i < balances.length; i++) {
        if (balances[i] <= 0) continue;

        // Apply interest
        balances[i] += balances[i] * rates[i];

        // Apply minimum payment
        balances[i] -= minPayments[i];

        // Apply extra payment to first debt with balance
        if (remainingExtra > 0 && i == balances.indexWhere((b) => b > 0)) {
          final payment = remainingExtra.clamp(0.0, balances[i]);
          balances[i] -= payment;
          remainingExtra -= payment;
        }

        if (balances[i] < 0) balances[i] = 0;
      }

      balanceHistory.add(balances.fold(0.0, (sum, b) => sum + b));
    }

    return balanceHistory;
  }

  Widget _buildCashFlowCard(BuildContext context) {
    final totalDebtPayments =
        debts.fold(0.0, (sum, debt) => sum + debt.minimumPayment);
    final essentialExpenses = financialData?.essentialExpenses.values
            .fold(0.0, (sum, val) => sum + val) ??
        0;
    final safeToSpend = monthlyIncome - essentialExpenses - totalDebtPayments;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Monthly Cash Flow',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildStatRow(
                'Income', _formatCurrency(monthlyIncome), Colors.green),
            const SizedBox(height: 12),
            _buildStatRow('Essential Expenses',
                _formatCurrency(essentialExpenses), Colors.orange),
            const SizedBox(height: 12),
            _buildStatRow('Debt Payments', _formatCurrency(totalDebtPayments),
                Colors.red),
            const Divider(height: 24),
            _buildStatRow('Safe to Spend', _formatCurrency(safeToSpend),
                Colors.blue, true),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentStatusCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildStatRow(
                'Upcoming (30 days)', '$upcomingPayments', Colors.blue),
            const SizedBox(height: 12),
            _buildStatRow(
              'Overdue',
              '$overduePayments',
              overduePayments > 0 ? Colors.red : Colors.green,
            ),
            const SizedBox(height: 12),
            _buildStatRow(
                'On-Time Streak', '$onTimeStreak payments', Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _buildRiskScoreCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Risk Score',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: riskColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: riskColor, width: 2),
              ),
              child: Center(
                child: Text(
                  riskScore,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: riskColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStressIndicatorCard(BuildContext context) {
    final trend = previousStressLevel != null
        ? (currentStressLevel > previousStressLevel!
            ? '↑'
            : currentStressLevel < previousStressLevel!
                ? '↓'
                : '→')
        : '';
    final trendColor = previousStressLevel != null
        ? (currentStressLevel > previousStressLevel!
            ? Colors.red
            : currentStressLevel < previousStressLevel!
                ? Colors.green
                : Colors.grey)
        : Colors.grey;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Stress Level',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$currentStressLevel/10',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                if (trend.isNotEmpty)
                  Text(
                    trend,
                    style: TextStyle(
                        fontSize: 20,
                        color: trendColor,
                        fontWeight: FontWeight.bold),
                  ),
              ],
            ),
            if (previousStressLevel != null)
              Text(
                'vs ${previousStressLevel!.toInt()}/10 last week',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBehaviorHighlightsCard(BuildContext context) {
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
                Icon(Icons.auto_awesome, color: Colors.amber[700]),
                const SizedBox(width: 8),
                const Text(
                  'AI Insights',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // AI-generated insights based on user data
            ..._generateAIInsights().map((insight) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF4A90E2),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          insight,
                          style: const TextStyle(fontSize: 14, height: 1.4),
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

  List<String> _generateAIInsights() {
    final insights = <String>[];

    // Debt-to-income insight
    if (monthlyIncome > 0 && totalDebt > 0) {
      final dti = (totalDebt / (monthlyIncome * 12)) * 100;
      if (dti > 50) {
        insights.add(
            'Your debt-to-income ratio is ${dti.toStringAsFixed(0)}% – focus on high-interest debts first');
      } else if (dti > 20) {
        insights.add(
            'Solid progress! Your debt is ${dti.toStringAsFixed(0)}% of annual income');
      } else {
        insights.add(
            'Excellent! Your debt is only ${dti.toStringAsFixed(0)}% of your annual income');
      }
    }

    // Payment strategy insight
    if (debts.length > 1) {
      final highestRate =
          debts.map((d) => d.interestRate).reduce((a, b) => a > b ? a : b);
      final highestDebt =
          debts.firstWhere((d) => d.interestRate == highestRate);
      insights.add(
          'Pay extra on ${highestDebt.name} (${highestRate.toStringAsFixed(1)}% APR) to save on interest');
    }

    // Payoff timeline insight
    if (availableForDebt > 0 && totalDebt > 0) {
      final months = (totalDebt / availableForDebt).ceil();
      if (months <= 12) {
        insights.add(
            'At your current pace, you could be debt-free in ~$months months!');
      } else if (months <= 24) {
        insights.add(
            'You\'re about ${(months / 12).toStringAsFixed(1)} years from debt freedom');
      }
    }

    // Default if no insights
    if (insights.isEmpty) {
      insights.add('Add debts to get personalized AI-powered insights');
    }

    return insights.take(3).toList();
  }

  Widget _buildAIChatBanner(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => const ChatGeminiDialog(),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4A90E2), Color(0xFF5BA3F5)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4A90E2).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Chat with CogniCents AI',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    'Ask questions about your finances →',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chat_bubble_outline,
                  color: Colors.white, size: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value,
      [Color? color, bool isBold = false]) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            color: color ?? Colors.black87,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[800],
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.attach_money,
              size: 60,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No debts added yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[900],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first debt to start building your payoff plan.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddDebtPage(),
                ),
              );
              if (result == true) {
                _loadUserData();
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Your First Debt'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDebtTrackingPieChart(BuildContext context) {
    final trackedAmount = totalDebt;
    final untrackedAmount =
        enteredTotalDebt > totalDebt ? enteredTotalDebt - totalDebt : 0.0;
    final trackedPercent =
        enteredTotalDebt > 0 ? (trackedAmount / enteredTotalDebt * 100) : 0.0;
    final isFullyTracked = untrackedAmount <= 0 && trackedAmount > 0;

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
                  isFullyTracked ? Icons.celebration : Icons.pie_chart,
                  color:
                      isFullyTracked ? Colors.green : const Color(0xFF4A90E2),
                ),
                const SizedBox(width: 8),
                Text(
                  isFullyTracked
                      ? 'All Debts Tracked!'
                      : 'Debt Tracking Progress',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (isFullyTracked)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle,
                        color: Colors.green[700], size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Congratulations! You\'ve added all your debts. Now you can track your payoff journey!',
                        style: TextStyle(
                            color: Colors.green[800],
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              )
            else
              Row(
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 30,
                        sections: [
                          PieChartSectionData(
                            value: trackedAmount,
                            color: const Color(0xFF4A90E2),
                            title: '',
                            radius: 25,
                          ),
                          PieChartSectionData(
                            value: untrackedAmount > 0 ? untrackedAmount : 0.01,
                            color: Colors.grey[300],
                            title: '',
                            radius: 25,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: const Color(0xFF4A90E2),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Tracked: \$${trackedAmount.toStringAsFixed(0)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Untracked: \$${untrackedAmount.toStringAsFixed(0)}',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${trackedPercent.toStringAsFixed(0)}% tracked',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: trackedPercent >= 100
                                ? Colors.green
                                : const Color(0xFF4A90E2),
                          ),
                        ),
                        if (untrackedAmount > 0) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Add more debts to complete tracking',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[500]),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebtList(BuildContext context) {
    // For now, just show a placeholder. Later you can add actual debt items
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Debts',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  Theme.of(context).colorScheme.primary.withOpacity(0.1),
              child: Icon(
                Icons.account_balance,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            title: const Text('Total Debt'),
            subtitle: const Text('Entered during onboarding'),
            trailing: Text(
              _formatCurrency(totalDebt),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatCurrency(double amount) {
    if (amount >= 1000000) {
      return '\$${(amount / 1000000).toStringAsFixed(2)}M';
    } else if (amount >= 1000) {
      return '\$${(amount / 1000).toStringAsFixed(1)}k';
    } else {
      return '\$${amount.toStringAsFixed(0)}';
    }
  }
}

// Debt Snapshot Detail Page
class DebtSnapshotPage extends StatefulWidget {
  final List<Debt> debts;
  final UserFinancialData? financialData;

  const DebtSnapshotPage({
    super.key,
    required this.debts,
    this.financialData,
  });

  @override
  State<DebtSnapshotPage> createState() => _DebtSnapshotPageState();
}

class _DebtSnapshotPageState extends State<DebtSnapshotPage> {
  double extraPayment = 0;
  final _extraPaymentController = TextEditingController();
  String selectedMethod = 'snowball'; // 'snowball' or 'avalanche'

  @override
  void initState() {
    super.initState();
    _extraPaymentController.addListener(() {
      setState(() {
        extraPayment = double.tryParse(_extraPaymentController.text) ?? 0;
      });
    });
  }

  @override
  void dispose() {
    _extraPaymentController.dispose();
    super.dispose();
  }

  PayoffResult _calculateSnowball() {
    // Sort by balance (smallest first)
    final sortedDebts = List<Debt>.from(widget.debts)
      ..sort((a, b) => a.currentBalance.compareTo(b.currentBalance));

    return _calculatePayoff(sortedDebts, 'Snowball');
  }

  PayoffResult _calculateAvalanche() {
    // Sort by interest rate (highest first)
    final sortedDebts = List<Debt>.from(widget.debts)
      ..sort((a, b) => b.interestRate.compareTo(a.interestRate));

    return _calculatePayoff(sortedDebts, 'Avalanche');
  }

  PayoffResult _calculatePayoff(List<Debt> debtOrder, String methodName) {
    final monthlyIncome = widget.financialData?.monthlyIncome ?? 0;
    final essentialExpenses = widget.financialData?.essentialExpenses.values
            .fold(0.0, (sum, val) => sum + val) ??
        0;
    final availableForDebt = monthlyIncome - essentialExpenses;

    // Create mutable debt balances map
    final debtBalances = <String, double>{};
    final debtInfo = <String, Map<String, dynamic>>{};

    for (var debt in debtOrder) {
      debtBalances[debt.id] = debt.currentBalance;
      debtInfo[debt.id] = {
        'minPayment': debt.minimumPayment,
        'interestRate': debt.interestRate,
      };
    }

    double totalInterest = 0;
    int months = 0;
    final monthlyData = <MonthlyData>[];
    double totalPaid = 0;

    while (debtBalances.values.any((b) => b > 0) && months < 600) {
      double remainingPayment = availableForDebt + extraPayment;
      double monthInterest = 0;

      // Calculate interest and pay minimums on all debts
      for (var debtId in debtBalances.keys.toList()) {
        final balance = debtBalances[debtId]!;
        if (balance > 0) {
          final info = debtInfo[debtId]!;
          final minPayment = info['minPayment'] as double;
          final interestRate = info['interestRate'] as double;
          final interest = (balance * interestRate / 100) / 12;
          monthInterest += interest;

          final newBalance = balance + interest;

          if (remainingPayment >= minPayment) {
            final payment = minPayment;
            debtBalances[debtId] =
                (newBalance - payment).clamp(0, double.infinity);
            remainingPayment -= payment;
            totalPaid += payment;
          } else {
            // Can't pay minimum, just add interest
            debtBalances[debtId] = newBalance;
          }
        }
      }

      // Apply extra payment to first unpaid debt in order
      for (var debtId in debtBalances.keys.toList()) {
        if (remainingPayment <= 0) break;
        final balance = debtBalances[debtId]!;
        if (balance > 0) {
          final payment = remainingPayment.clamp(0, balance);
          debtBalances[debtId] = (balance - payment).clamp(0, double.infinity);
          totalPaid += payment;
          remainingPayment -= payment;
        }
      }

      totalInterest += monthInterest;
      months++;

      final totalRemaining = debtBalances.values.fold(0.0, (sum, b) => sum + b);
      monthlyData.add(MonthlyData(
          month: months, remaining: totalRemaining, interest: monthInterest));

      if (totalRemaining <= 0) break;
    }

    return PayoffResult(
      methodName: methodName,
      totalMonths: months,
      totalInterest: totalInterest,
      totalPaid: totalPaid,
      monthlyData: monthlyData,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.debts.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Debt Snapshot')),
        body: const Center(child: Text('No debts to analyze')),
      );
    }

    final snowballResult = _calculateSnowball();
    final avalancheResult = _calculateAvalanche();
    final currentResult =
        selectedMethod == 'snowball' ? snowballResult : avalancheResult;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debt Snapshot'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Method Selection
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payoff Strategy',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMethodButton(
                              'snowball', 'Snowball', 'Pay smallest first'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMethodButton('avalanche', 'Avalanche',
                              'Pay highest interest first'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Extra Payment Input
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Extra Monthly Payment',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _extraPaymentController,
                      decoration: InputDecoration(
                        labelText: 'Additional amount per month',
                        prefixText: '\$ ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Results Summary
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${currentResult.methodName} Method Results',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    _buildStatRow('Time to Payoff',
                        '${currentResult.totalMonths} months'),
                    const SizedBox(height: 8),
                    _buildStatRow('Total Interest',
                        _formatCurrency(currentResult.totalInterest)),
                    const SizedBox(height: 8),
                    _buildStatRow(
                        'Total Paid', _formatCurrency(currentResult.totalPaid)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Comparison Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Method Comparison',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    _buildComparisonRow(
                        'Time to Payoff',
                        '${snowballResult.totalMonths} months',
                        '${avalancheResult.totalMonths} months'),
                    const SizedBox(height: 8),
                    _buildComparisonRow(
                        'Total Interest',
                        _formatCurrency(snowballResult.totalInterest),
                        _formatCurrency(avalancheResult.totalInterest)),
                    const SizedBox(height: 8),
                    _buildComparisonRow(
                        'Savings vs Current',
                        _formatCurrency(snowballResult.totalInterest),
                        _formatCurrency(avalancheResult.totalInterest)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Payoff Timeline Graph
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payoff Timeline',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 250,
                      child: _buildPayoffGraph(snowballResult, avalancheResult),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Debt Breakdown
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Debt Breakdown',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    ...widget.debts.map((debt) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      debt.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      '${debt.type} • ${debt.interestRate.toStringAsFixed(1)}% APR',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                _formatCurrency(debt.currentBalance),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodButton(String method, String title, String subtitle) {
    final isSelected = selectedMethod == method;
    return GestureDetector(
      onTap: () => setState(() => selectedMethod = method),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.white70 : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600])),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  Widget _buildComparisonRow(String label, String snowball, String avalanche) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Snowball',
                        style: TextStyle(fontSize: 12, color: Colors.blue)),
                    Text(snowball,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Avalanche',
                        style: TextStyle(fontSize: 12, color: Colors.green)),
                    Text(avalanche,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPayoffGraph(PayoffResult snowball, PayoffResult avalanche) {
    final maxMonths = [snowball.totalMonths, avalanche.totalMonths]
        .reduce((a, b) => a > b ? a : b);
    final maxDebt = widget.debts.fold(0.0, (sum, d) => sum + d.currentBalance);

    return Stack(
      children: [
        CustomPaint(
          painter: PayoffGraphPainter(
            snowballData: snowball.monthlyData,
            avalancheData: avalanche.monthlyData,
            maxMonths: maxMonths,
            maxDebt: maxDebt,
          ),
          child: Container(),
        ),
        // Y-axis label
        Positioned(
          left: 0,
          top: 10,
          child: Transform.rotate(
            angle: -1.5708, // -90 degrees
            child: const Text(
              'Remaining Debt',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ),
        // X-axis label
        const Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Center(
            child: Text(
              'Months',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ),
      ],
    );
  }

  String _formatCurrency(double amount) {
    if (amount >= 1000000) {
      return '\$${(amount / 1000000).toStringAsFixed(2)}M';
    } else if (amount >= 1000) {
      return '\$${(amount / 1000).toStringAsFixed(1)}k';
    } else {
      return '\$${amount.toStringAsFixed(0)}';
    }
  }
}

// Data classes for payoff calculations
class PayoffResult {
  final String methodName;
  final int totalMonths;
  final double totalInterest;
  final double totalPaid;
  final List<MonthlyData> monthlyData;

  PayoffResult({
    required this.methodName,
    required this.totalMonths,
    required this.totalInterest,
    required this.totalPaid,
    required this.monthlyData,
  });
}

class MonthlyData {
  final int month;
  final double remaining;
  final double interest;

  MonthlyData({
    required this.month,
    required this.remaining,
    required this.interest,
  });
}

// Custom painter for payoff graph
class PayoffGraphPainter extends CustomPainter {
  final List<MonthlyData> snowballData;
  final List<MonthlyData> avalancheData;
  final int maxMonths;
  final double maxDebt;
  final double animationValue; // For smooth animation if needed

  static const double leftMargin = 60;
  static const double rightMargin = 20;
  static const double topMargin = 20;
  static const double bottomMargin = 50;

  PayoffGraphPainter({
    required this.snowballData,
    required this.avalancheData,
    required this.maxMonths,
    required this.maxDebt,
    this.animationValue = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 100 || size.height < 100) return; // Minimum size check

    // Define margins for axes and labels
    const double leftMargin = 60;
    const double rightMargin = 20;
    const double topMargin = 20;
    const double bottomMargin = 50;

    // Calculate drawing area
    final drawingWidth = size.width - leftMargin - rightMargin;
    final drawingHeight = size.height - topMargin - bottomMargin;

    // Early exit if no data or negative values
    if (maxMonths <= 0 ||
        maxDebt <= 0 ||
        drawingWidth <= 0 ||
        drawingHeight <= 0) {
      _drawEmptyState(canvas, size);
      return;
    }

    // Draw axes
    _drawAxes(canvas, size, leftMargin, topMargin, drawingWidth, drawingHeight);

    // Draw grid
    _drawGrid(canvas, size, leftMargin, topMargin, drawingWidth, drawingHeight);

    // Draw tick marks and labels
    _drawTicksAndLabels(
        canvas, size, leftMargin, topMargin, drawingWidth, drawingHeight);

    // Draw data lines
    if (snowballData.isNotEmpty || avalancheData.isNotEmpty) {
      _drawDataLines(
          canvas, size, leftMargin, topMargin, drawingWidth, drawingHeight);
    }
  }

  void _drawEmptyState(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'No data to display',
        style: TextStyle(color: Colors.grey, fontSize: 12),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
        canvas,
        Offset(size.width / 2 - textPainter.width / 2,
            size.height / 2 - textPainter.height / 2));
  }

  void _drawAxes(Canvas canvas, Size size, double leftMargin, double topMargin,
      double drawingWidth, double drawingHeight) {
    final axisPaint = Paint()
      ..color = Colors.black54
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Y-axis (vertical)
    canvas.drawLine(
      Offset(leftMargin, topMargin),
      Offset(leftMargin, size.height - bottomMargin),
      axisPaint,
    );

    // X-axis (horizontal)
    canvas.drawLine(
      Offset(leftMargin, size.height - bottomMargin),
      Offset(size.width - rightMargin, size.height - bottomMargin),
      axisPaint,
    );
  }

  void _drawGrid(Canvas canvas, Size size, double leftMargin, double topMargin,
      double drawingWidth, double drawingHeight) {
    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.3)
      ..strokeWidth = 0.5;

    // Vertical grid lines (time intervals)
    const numXTickIntervals = 5;
    for (int i = 1; i <= numXTickIntervals; i++) {
      final x = leftMargin + (i * drawingWidth) / numXTickIntervals;
      canvas.drawLine(
        Offset(x, topMargin),
        Offset(x, size.height - bottomMargin),
        gridPaint,
      );
    }

    // Horizontal grid lines (debt amounts)
    const numYTickIntervals = 4;
    for (int i = 1; i <= numYTickIntervals; i++) {
      final y = topMargin + (i * drawingHeight) / numYTickIntervals;
      canvas.drawLine(
        Offset(leftMargin, y),
        Offset(size.width - rightMargin, y),
        gridPaint,
      );
    }
  }

  void _drawTicksAndLabels(Canvas canvas, Size size, double leftMargin,
      double topMargin, double drawingWidth, double drawingHeight) {
    final tickPaint = Paint()
      ..color = Colors.black54
      ..strokeWidth = 1.0;
    const tickLength = 5.0;

    // X-axis ticks and labels (months)
    const numXTickIntervals = 5;
    for (int i = 0; i <= numXTickIntervals; i++) {
      final fraction = i / numXTickIntervals;
      final x = leftMargin + fraction * drawingWidth;
      final y = size.height - bottomMargin;

      // Tick mark
      canvas.drawLine(
        Offset(x, y),
        Offset(x, y + tickLength),
        tickPaint,
      );

      // Label
      final monthValue = (maxMonths * fraction).round();
      final label = '${monthValue}m';
      final textPainter = TextPainter(
        text: TextSpan(
            text: label,
            style: const TextStyle(color: Colors.grey, fontSize: 10)),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
          canvas, Offset(x - textPainter.width / 2, y + tickLength + 2));
    }

    // Y-axis ticks and labels (debt amounts)
    const numYTickIntervals = 4;
    for (int i = 0; i <= numYTickIntervals; i++) {
      final fraction = i / numYTickIntervals;
      final yPos = size.height - bottomMargin - fraction * drawingHeight;
      final x = leftMargin;

      // Tick mark
      canvas.drawLine(
        Offset(x - tickLength, yPos),
        Offset(x, yPos),
        tickPaint,
      );

      // Label
      final debtValue = (maxDebt * fraction).round();
      final formattedValue = _formatDebtLabel(debtValue);
      final textPainter = TextPainter(
        text: TextSpan(
            text: formattedValue,
            style: const TextStyle(color: Colors.grey, fontSize: 10)),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
          canvas,
          Offset(x - tickLength - textPainter.width - 4,
              yPos - textPainter.height / 2));
    }
  }

  void _drawDataLines(Canvas canvas, Size size, double leftMargin,
      double topMargin, double drawingWidth, double drawingHeight) {
    // Snowball line
    if (snowballData.isNotEmpty) {
      final pathSnowball = Path();
      bool isFirstPoint = true;

      for (final data in snowballData) {
        final x =
            leftMargin + (data.month.toDouble() / maxMonths) * drawingWidth;
        final y = size.height -
            bottomMargin -
            (data.remaining / maxDebt) * drawingHeight;

        if (isFirstPoint) {
          pathSnowball.moveTo(x, y);
          isFirstPoint = false;
        } else {
          pathSnowball.lineTo(x, y);
        }
      }

      final paintSnowball = Paint()
        ..color = Colors.blue
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      canvas.drawPath(pathSnowball, paintSnowball);

      // Draw circular points at key intervals
      _drawDataPoints(canvas, size, snowballData, leftMargin, topMargin,
          drawingWidth, drawingHeight, Colors.blue);
    }

    // Avalanche line
    if (avalancheData.isNotEmpty) {
      final pathAvalanche = Path();
      bool isFirstPoint = true;

      for (final data in avalancheData) {
        final x =
            leftMargin + (data.month.toDouble() / maxMonths) * drawingWidth;
        final y = size.height -
            bottomMargin -
            (data.remaining / maxDebt) * drawingHeight;

        if (isFirstPoint) {
          pathAvalanche.moveTo(x, y);
          isFirstPoint = false;
        } else {
          pathAvalanche.lineTo(x, y);
        }
      }

      final paintAvalanche = Paint()
        ..color = Colors.green
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      canvas.drawPath(pathAvalanche, paintAvalanche);

      // Draw circular points at key intervals
      _drawDataPoints(canvas, size, avalancheData, leftMargin, topMargin,
          drawingWidth, drawingHeight, Colors.green);
    }
  }

  void _drawDataPoints(
      Canvas canvas,
      Size canvasSize,
      List<MonthlyData> data,
      double leftMargin,
      double topMargin,
      double drawingWidth,
      double drawingHeight,
      Color color) {
    const pointsToShow = 6; // Limit number of points to avoid clutter
    final interval = (data.length / (pointsToShow - 1)).ceil();
    const bottomMargin = 50;

    for (int i = 0; i < data.length; i += interval) {
      final x =
          leftMargin + (data[i].month.toDouble() / maxMonths) * drawingWidth;
      final y = (canvasSize.height - bottomMargin) -
          (data[i].remaining / maxDebt) * drawingHeight;

      final pointPaint = Paint()
        ..color = color.withOpacity(0.8)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), 4, pointPaint);

      // White border for better visibility
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawCircle(Offset(x, y), 4, borderPaint);
    }
  }

  String _formatDebtLabel(int value) {
    if (value >= 1000000) {
      return '\$${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '\$${(value / 1000).toStringAsFixed(0)}k';
    } else {
      return '\$${value.toString()}';
    }
  }

  @override
  bool shouldRepaint(covariant PayoffGraphPainter oldDelegate) {
    return oldDelegate.snowballData.length != snowballData.length ||
        oldDelegate.avalancheData.length != avalancheData.length ||
        oldDelegate.animationValue != animationValue;
  }
}
