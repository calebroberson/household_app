import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'chore_detail_screen.dart';

class ChoreListScreen extends StatefulWidget {
  final String householdId;

  const ChoreListScreen({super.key, required this.householdId});

  @override
  State<ChoreListScreen> createState() => _ChoreListScreenState();
}

class _ChoreListScreenState extends State<ChoreListScreen> {
  late Future<List<Map<String, dynamic>>> _choresFuture;

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
    _choresFuture = _fetchChores();
  }

  Future<List<Map<String, dynamic>>> _fetchChores() async {
    return await Supabase.instance.client
        .from('chores')
        .select('id, title, recurrence_rule')
        .eq('household_id', widget.householdId)
        .eq('active', true)
        .order('title');
  }

  void _refresh() {
    setState(() {
      _choresFuture = _fetchChores();
    });
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

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Chores')),
      child: SafeArea(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _choresFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CupertinoActivityIndicator());
            }
            final chores = snapshot.data!;
            if (chores.isEmpty) {
              return const Center(child: Text('No chores yet.'));
            }
            return ListView.builder(
              itemCount: chores.length,
              itemBuilder: (context, index) {
                final chore = chores[index];
                final rule =
                    chore['recurrence_rule'] as Map<String, dynamic>;
                return CupertinoListTile(
                  title: Text(chore['title'] as String),
                  subtitle: Text(_recurrenceSummary(rule)),
                  trailing: const Icon(CupertinoIcons.chevron_forward),
                  onTap: () async {
                    await Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (context) => ChoreDetailScreen(
                          householdId: widget.householdId,
                          choreId: chore['id'] as String,
                        ),
                      ),
                    );
                    _refresh();
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
