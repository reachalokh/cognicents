import 'package:flutter/material.dart';
import '../services/nudge_manager.dart';

/// Test page for manually triggering and testing all nudge types
class NudgeTestPage extends StatefulWidget {
  const NudgeTestPage({super.key});

  @override
  State<NudgeTestPage> createState() => _NudgeTestPageState();
}

class _NudgeTestPageState extends State<NudgeTestPage> {
  final NudgeManager _nudgeManager = NudgeManager();
  List<NudgeConfig> _configs = [];
  final Map<String, DynamicNudge?> _lastResults = {};
  final Map<String, bool> _loading = {};
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    _initializeManager();
  }

  Future<void> _initializeManager() async {
    await _nudgeManager.init();
    setState(() {
      _configs = _nudgeManager.getNudgeConfigs();
      _initializing = false;
    });
  }

  Future<void> _testNudge(String nudgeId) async {
    setState(() => _loading[nudgeId] = true);

    try {
      final nudge = await _nudgeManager.testNudge(nudgeId);
      setState(() {
        _lastResults[nudgeId] = nudge;
        _loading[nudgeId] = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Nudge sent: ${nudge.title}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() => _loading[nudgeId] = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _resetCooldowns() async {
    await _nudgeManager.resetAllCooldowns();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔄 All cooldowns reset!'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  Future<void> _evaluateAllNudges() async {
    setState(() {
      for (var config in _configs) {
        _loading[config.id] = true;
      }
    });

    await _nudgeManager.evaluateNudges();

    setState(() {
      for (var config in _configs) {
        _loading[config.id] = false;
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Evaluated all nudges (check notifications)'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  IconData _getIconForNudge(String nudgeId) {
    switch (nudgeId) {
      case 'inactive_payment':
        return Icons.schedule;
      case 'streak_celebration':
        return Icons.local_fire_department;
      case 'debt_progress':
        return Icons.trending_up;
      case 'upcoming_payment':
        return Icons.alarm;
      case 'weekly_summary':
        return Icons.calendar_today;
      case 'motivational':
        return Icons.lightbulb;
      default:
        return Icons.notifications;
    }
  }

  Color _getColorForNudge(String nudgeId) {
    switch (nudgeId) {
      case 'inactive_payment':
        return Colors.orange;
      case 'streak_celebration':
        return Colors.red;
      case 'debt_progress':
        return Colors.green;
      case 'upcoming_payment':
        return Colors.purple;
      case 'weekly_summary':
        return Colors.blue;
      case 'motivational':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🧪 Nudge Testing'),
        foregroundColor: Colors.white,
        backgroundColor: const Color(0xFF4A90E2),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset all cooldowns',
            onPressed: _resetCooldowns,
          ),
        ],
      ),
      body: _initializing
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header with evaluate all button
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Colors.grey[100],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Test Individual Nudges',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Tap any nudge type below to trigger it immediately. '
                        'AI-powered messages will use your real data!',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _evaluateAllNudges,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Evaluate All Nudges'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4A90E2),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Nudge list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _configs.length,
                    itemBuilder: (context, index) {
                      final config = _configs[index];
                      final isLoading = _loading[config.id] ?? false;
                      final lastResult = _lastResults[config.id];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        child: InkWell(
                          onTap: isLoading ? null : () => _testNudge(config.id),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: _getColorForNudge(config.id)
                                            .withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        _getIconForNudge(config.id),
                                        color: _getColorForNudge(config.id),
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            config.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: config.type ==
                                                      NudgeType.behaviorBased
                                                  ? Colors.blue.withOpacity(0.1)
                                                  : Colors.purple
                                                      .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              config.type ==
                                                      NudgeType.behaviorBased
                                                  ? 'Behavior-based'
                                                  : 'Time-based',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: config.type ==
                                                        NudgeType.behaviorBased
                                                    ? Colors.blue
                                                    : Colors.purple,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isLoading)
                                      const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    else
                                      Icon(
                                        Icons.send,
                                        color: Colors.grey[400],
                                      ),
                                  ],
                                ),

                                // Show last result if available
                                if (lastResult != null) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.circular(8),
                                      border:
                                          Border.all(color: Colors.grey[200]!),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          lastResult.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          lastResult.message,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
