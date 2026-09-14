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
  late Future<void> _loadFuture;
  List<Map<String, dynamic>> _chores = [];
  Map<String, Map<String, dynamic>> _areasById = {};

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
    final chores = await Supabase.instance.client
        .from('chores')
        .select('id, title, recurrence_rule, area_id')
        .eq('household_id', widget.householdId)
        .eq('active', true)
        .order('title');

    final areaRows = await Supabase.instance.client
        .from('areas')
        .select('id, name, sort_order, visibility')
        .eq('household_id', widget.householdId);

    if (!mounted) return;
    setState(() {
      _chores = chores;
      _areasById = {
        for (final row in areaRows) row['id'] as String: row,
      };
    });
  }

  void _refresh() {
    setState(() {
      _loadFuture = _loadAll();
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
      case 'every_n_months':
        return 'Every ${rule['n']} months on day ${rule['day_of_month']}';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Chores')),
      child: SafeArea(
        child: FutureBuilder<void>(
          future: _loadFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CupertinoActivityIndicator());
            }
            if (_chores.isEmpty) {
              return const Center(child: Text('No chores yet.'));
            }

            final byArea = <String?, List<Map<String, dynamic>>>{};
            for (final chore in _chores) {
              final areaId = chore['area_id'] as String?;
              byArea.putIfAbsent(areaId, () => []).add(chore);
            }

            final areaKeys = byArea.keys.toList()
              ..sort((a, b) {
                if (a == null) return 1;
                if (b == null) return -1;
                final aOrder = _areasById[a]?['sort_order'] as int? ?? 0;
                final bOrder = _areasById[b]?['sort_order'] as int? ?? 0;
                return aOrder.compareTo(bOrder);
              });

            return ListView(
              children: areaKeys.map((areaKey) {
                final area = areaKey == null ? null : _areasById[areaKey];
                final areaName = area?['name'] as String? ?? 'General';
                final isPrivate = area?['visibility'] == 'private';
                final chores = byArea[areaKey]!;

                return CupertinoListSection.insetGrouped(
                  header: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(areaName),
                      if (isPrivate) ...[
                        const SizedBox(width: 4),
                        const Icon(CupertinoIcons.lock_fill, size: 12),
                      ],
                    ],
                  ),
                  children: chores.map((chore) {
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
                  }).toList(),
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }
}
