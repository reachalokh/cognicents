import 'package:flutter/material.dart';
import '../main.dart';

/// Calendar page for tracking bill due dates and payment schedules
/// Helps users living paycheck-to-paycheck manage their payments
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  List<Debt> _debts = [];
  bool _isLoading = true;
  DateTime _selectedMonth = DateTime.now();
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _loadDebts();
  }

  Future<void> _loadDebts() async {
    setState(() => _isLoading = true);
    try {
      final debts = await DataService.getDebts();
      setState(() {
        _debts = debts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  /// Get all bills due in the selected month
  List<_BillEvent> _getBillsForMonth(DateTime month) {
    final events = <_BillEvent>[];

    for (final debt in _debts) {
      if (debt.dueDate != null) {
        // Get the due date for this month (recurring monthly)
        final dueDay = debt.dueDate!.day;
        final dueInMonth = DateTime(month.year, month.month, dueDay);

        // Check if this date is valid for the month
        if (dueInMonth.month == month.month) {
          events.add(_BillEvent(
            debt: debt,
            dueDate: dueInMonth,
            isPastDue: dueInMonth.isBefore(DateTime.now()),
          ));
        }
      }
    }

    events.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return events;
  }

  /// Get bills due on a specific date
  List<_BillEvent> _getBillsForDate(DateTime date) {
    return _getBillsForMonth(date)
        .where((e) => _isSameDay(e.dueDate, date))
        .toList();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Get dates with bills in the current month
  Set<int> _getDaysWithBills() {
    final days = <int>{};
    for (final event in _getBillsForMonth(_selectedMonth)) {
      days.add(event.dueDate.day);
    }
    return days;
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
      _selectedDate = null;
    });
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
      _selectedDate = null;
    });
  }

  void _goToToday() {
    setState(() {
      _selectedMonth = DateTime.now();
      _selectedDate = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Bill Calendar'),
          backgroundColor: const Color(0xFF4A90E2),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final billsThisMonth = _getBillsForMonth(_selectedMonth);
    final totalDueThisMonth = billsThisMonth.fold<double>(
      0,
      (sum, e) => sum + e.debt.minimumPayment,
    );
    final daysWithBills = _getDaysWithBills();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bill Calendar'),
        backgroundColor: const Color(0xFF4A90E2),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            tooltip: 'Go to today',
            onPressed: _goToToday,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadDebts,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Monthly summary card
            _buildMonthlySummary(billsThisMonth, totalDueThisMonth),

            // Month navigation and calendar
            _buildMonthHeader(),
            _buildCalendarGrid(daysWithBills),

            // Selected date bills or upcoming bills
            Expanded(
              child: _selectedDate != null
                  ? _buildSelectedDateBills()
                  : _buildUpcomingBills(billsThisMonth),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlySummary(List<_BillEvent> bills, double total) {
    final paidCount = bills.where((b) => b.isPastDue).length;
    final upcomingCount = bills.length - paidCount;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Monthly Bills Due',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '\$${total.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSummaryItem(
                icon: Icons.check_circle,
                label: 'Past Due',
                value: paidCount.toString(),
                color: Colors.orange[200]!,
              ),
              Container(width: 1, height: 30, color: Colors.white24),
              _buildSummaryItem(
                icon: Icons.schedule,
                label: 'Upcoming',
                value: upcomingCount.toString(),
                color: Colors.green[200]!,
              ),
              Container(width: 1, height: 30, color: Colors.white24),
              _buildSummaryItem(
                icon: Icons.receipt_long,
                label: 'Total Bills',
                value: bills.length.toString(),
                color: Colors.white,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildMonthHeader() {
    final monthNames = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _previousMonth,
          ),
          GestureDetector(
            onTap: _goToToday,
            child: Text(
              '${monthNames[_selectedMonth.month]} ${_selectedMonth.year}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _nextMonth,
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid(Set<int> daysWithBills) {
    final firstDayOfMonth =
        DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final lastDayOfMonth =
        DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    final firstWeekday = firstDayOfMonth.weekday % 7; // 0 = Sunday
    final daysInMonth = lastDayOfMonth.day;
    final today = DateTime.now();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Weekday headers
          Row(
            children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                .map((day) => Expanded(
                      child: Center(
                        child: Text(
                          day,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          // Calendar days
          ...List.generate(6, (weekIndex) {
            return Row(
              children: List.generate(7, (dayIndex) {
                final dayNumber = weekIndex * 7 + dayIndex - firstWeekday + 1;

                if (dayNumber < 1 || dayNumber > daysInMonth) {
                  return const Expanded(child: SizedBox(height: 40));
                }

                final date = DateTime(
                    _selectedMonth.year, _selectedMonth.month, dayNumber);
                final isToday = _isSameDay(date, today);
                final isSelected =
                    _selectedDate != null && _isSameDay(date, _selectedDate!);
                final hasBill = daysWithBills.contains(dayNumber);
                final isPastDue = hasBill && date.isBefore(today);

                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedDate = date;
                      });
                    },
                    child: Container(
                      height: 40,
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : isToday
                                ? Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.1)
                                : null,
                        borderRadius: BorderRadius.circular(8),
                        border: isToday && !isSelected
                            ? Border.all(
                                color: Theme.of(context).colorScheme.primary)
                            : null,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Text(
                            dayNumber.toString(),
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : isToday
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                              fontWeight: isToday ? FontWeight.bold : null,
                            ),
                          ),
                          if (hasBill)
                            Positioned(
                              bottom: 4,
                              child: Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color:
                                      isPastDue ? Colors.orange : Colors.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSelectedDateBills() {
    final bills = _getBillsForDate(_selectedDate!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Bills on ${_formatDate(_selectedDate!)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _selectedDate = null),
                child: const Text('Show All'),
              ),
            ],
          ),
        ),
        Expanded(
          child: bills.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle,
                          size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text(
                        'No bills due on this date',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: bills.length,
                  itemBuilder: (context, index) => _buildBillCard(bills[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildUpcomingBills(List<_BillEvent> allBills) {
    final now = DateTime.now();
    final upcomingBills = allBills
        .where((b) => !b.dueDate.isBefore(now) || _isSameDay(b.dueDate, now))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.upcoming, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Upcoming Bills',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${upcomingBills.length} bills',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        Expanded(
          child: upcomingBills.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.celebration,
                          size: 48, color: Colors.green[400]),
                      const SizedBox(height: 8),
                      Text(
                        'All caught up for this month!',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'No more upcoming bills',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: upcomingBills.length,
                  itemBuilder: (context, index) =>
                      _buildBillCard(upcomingBills[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildBillCard(_BillEvent event) {
    final daysUntil = event.dueDate.difference(DateTime.now()).inDays;
    final isToday = _isSameDay(event.dueDate, DateTime.now());
    final isPastDue = event.isPastDue && !isToday;

    String urgencyText;
    Color urgencyColor;

    if (isPastDue) {
      urgencyText = 'Past Due';
      urgencyColor = Colors.red;
    } else if (isToday) {
      urgencyText = 'Due Today!';
      urgencyColor = Colors.orange;
    } else if (daysUntil == 1) {
      urgencyText = 'Due Tomorrow';
      urgencyColor = Colors.orange;
    } else if (daysUntil <= 7) {
      urgencyText = 'Due in $daysUntil days';
      urgencyColor = Colors.amber;
    } else {
      urgencyText = 'Due ${_formatDate(event.dueDate)}';
      urgencyColor = Colors.green;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Icon based on debt type
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: urgencyColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getIconForDebtType(event.debt.type),
                color: urgencyColor,
              ),
            ),
            const SizedBox(width: 16),
            // Bill details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.debt.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    event.debt.lenderName,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: urgencyColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      urgencyText,
                      style: TextStyle(
                        color: urgencyColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Amount
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${event.debt.minimumPayment.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  'min. payment',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForDebtType(String type) {
    switch (type.toLowerCase()) {
      case 'credit card':
        return Icons.credit_card;
      case 'mortgage':
      case 'home loan':
        return Icons.home;
      case 'auto loan':
      case 'car loan':
        return Icons.directions_car;
      case 'student loan':
        return Icons.school;
      case 'personal loan':
        return Icons.person;
      case 'medical':
        return Icons.local_hospital;
      default:
        return Icons.receipt_long;
    }
  }

  String _formatDate(DateTime date) {
    final monthNames = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${monthNames[date.month]} ${date.day}';
  }
}

/// Internal class representing a bill event on the calendar
class _BillEvent {
  final Debt debt;
  final DateTime dueDate;
  final bool isPastDue;

  _BillEvent({
    required this.debt,
    required this.dueDate,
    required this.isPastDue,
  });
}
