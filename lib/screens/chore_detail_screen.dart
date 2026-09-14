import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'chore_form_screen.dart';

class ChoreDetailScreen extends StatefulWidget {
  final String householdId;
  final String choreId;

  const ChoreDetailScreen({
    super.key,
    required this.householdId,
    required this.choreId,
  });

  @override
  State<ChoreDetailScreen> createState() => _ChoreDetailScreenState();
}

class _ChoreDetailScreenState extends State<ChoreDetailScreen> {
  late Future<void> _loadFuture;
  Map<String, dynamic>? _chore;
  String _historyText = 'Loading history...';

  static const _dayLabels = {
    1: 'Mon',
    2: 'Tue',
    3: 'Wed',
    4: 'Thu',
    5: 'Fri',
    6: 'Sat',
    7: 'Sun',
  };

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadAll();
  }

  Future<void> _loadAll() async {
    final choreRow = await Supabase.instance.client
        .from('chores')
        .select(
            'id, title, recurrence_rule, assignment_strategy, fixed_assignee, assignee_order, active')
        .eq('id', widget.choreId)
        .single();

    final historyText = await _fetchHistoryText();

    if (!mounted) return;
    setState(() {
      _chore = choreRow;
      _historyText = historyText;
    });
  }

  Future<String> _fetchHistoryText() async {
    final rows = await Supabase.instance.client
        .from('chore_occurrences')
        .select('completed_at, completed_by')
        .eq('chore_id', widget.choreId)
        .not('completed_at', 'is', null)
        .order('completed_at', ascending: false)
        .limit(1);

    if (rows.isEmpty) {
      return 'Never completed yet.';
    }

    final row = rows.first;
    final completedBy = row['completed_by'] as String?;
    final completedAt = row['completed_at'] as String;
    final date = DateTime.parse(completedAt).toLocal();
    final dateStr = '${date.month}/${date.day}/${date.year}';

    if (completedBy == null) {
      return 'Last done on $dateStr.';
    }

    final profileRow = await Supabase.instance.client
        .from('profiles')
        .select('display_name')
        .eq('id', completedBy)
        .maybeSingle();

    final name = profileRow?['display_name'] as String? ?? 'Someone';
    return 'Last done by $name on $dateStr.';
  }

  String _recurrenceSummary(Map<String, dynamic> rule) {
    switch (rule['type']) {
      case 'daily':
        return 'Daily';
      case 'weekly':
        final days = (rule['days'] as List).cast<int>();
        return 'Weekly: ${days.map((d) => _dayLabels[d]).join(', ')}';
      case 'every_n_weeks':
        return 'Every ${rule['n']} weeks on ${_dayLabels[rule['weekday']]}';
      case 'monthly':
        return 'Monthly on day ${rule['day_of_month']}';
      default:
        return '';
    }
  }

  Future<void> _archive() async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Archive Chore?'),
        content: const Text(
            'This chore will stop generating new occurrences. History is kept.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await Supabase.instance.client
          .from('chores')
          .update({'active': false}).eq('id', widget.choreId);
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _edit() async {
    if (_chore == null) return;
    await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => ChoreFormScreen(
          householdId: widget.householdId,
          existingChore: _chore,
        ),
      ),
    );
    setState(() {
      _loadFuture = _loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(_chore?['title'] as String? ?? 'Chore'),
        trailing: _chore == null
            ? null
            : CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _edit,
                child: const Text('Edit'),
              ),
      ),
      child: SafeArea(
        child: FutureBuilder<void>(
          future: _loadFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done ||
                _chore == null) {
              return const Center(child: CupertinoActivityIndicator());
            }

            final rule =
                _chore!['recurrence_rule'] as Map<String, dynamic>;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  _recurrenceSummary(rule),
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  _historyText,
                  style: const TextStyle(
                      color: CupertinoColors.secondaryLabel),
                ),
                const SizedBox(height: 32),
                CupertinoButton(
                  onPressed: _archive,
                  child: const Text(
                    'Archive Chore',
                    style: TextStyle(color: CupertinoColors.destructiveRed),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
