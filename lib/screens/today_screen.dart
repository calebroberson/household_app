import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/occurrence_generator.dart';
import 'chore_form_screen.dart';
import 'chore_list_screen.dart';

class TodayScreen extends StatefulWidget {
  final String householdId;

  const TodayScreen({super.key, required this.householdId});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  late Future<void> _readyFuture;
  Map<String, String> _choreTitles = {};
  Map<String, String> _memberNames = {};
  Map<String, Map<String, dynamic>> _areasById = {};
  String? _areaFilter;

  static const _starterTemplates = [
    {
      'title': 'Take out trash',
      'recurrence': {'type': 'daily'},
    },
    {
      'title': 'Wash dishes',
      'recurrence': {'type': 'daily'},
    },
    {
      'title': 'Vacuum',
      'recurrence': {
        'type': 'weekly',
        'days': [6]
      },
    },
    {
      'title': 'Laundry',
      'recurrence': {
        'type': 'weekly',
        'days': [7]
      },
    },
  ];

  @override
  void initState() {
    super.initState();
    _readyFuture = _prepare();
  }

  Future<void> _prepare() async {
    await OccurrenceGenerator.ensureOccurrencesForHousehold(widget.householdId);
    await _loadLookups();
  }

  Future<void> _loadLookups() async {
    final choreRows = await Supabase.instance.client
        .from('chores')
        .select('id, title')
        .eq('household_id', widget.householdId)
        .eq('active', true);

    final memberRows = await Supabase.instance.client
        .from('household_members')
        .select('user_id')
        .eq('household_id', widget.householdId)
        .order('joined_at');

    final userIds = memberRows.map((row) => row['user_id'] as String).toList();

    final profileRows = userIds.isEmpty
        ? <Map<String, dynamic>>[]
        : await Supabase.instance.client
            .from('profiles')
            .select('id, display_name')
            .inFilter('id', userIds);

    final namesById = {
      for (final row in profileRows)
        row['id'] as String: row['display_name'] as String?,
    };

    final areaRows = await Supabase.instance.client
        .from('areas')
        .select('id, name, sort_order, visibility')
        .eq('household_id', widget.householdId);

    setState(() {
      _choreTitles = {
        for (final row in choreRows)
          row['id'] as String: row['title'] as String,
      };
      _memberNames = {
        for (final userId in userIds)
          userId: namesById[userId] ?? 'Household member',
      };
      _areasById = {
        for (final row in areaRows) row['id'] as String: row,
      };
    });
  }

  Future<void> _refreshOccurrences() async {
    await OccurrenceGenerator.ensureOccurrencesForHousehold(widget.householdId);
  }

  Future<void> _addStarterChore(Map<String, dynamic> template) async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    await Supabase.instance.client.from('chores').insert({
      'household_id': widget.householdId,
      'title': template['title'],
      'recurrence_rule': template['recurrence'],
      'assignment_strategy': 'anyone',
      'created_by': userId,
    });
    await _loadLookups();
    await _refreshOccurrences();
  }

  Future<void> _complete(String occurrenceId) async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    await Supabase.instance.client.from('chore_occurrences').update({
      'completed_at': DateTime.now().toUtc().toIso8601String(),
      'completed_by': userId,
    }).eq('id', occurrenceId);
    await _refreshOccurrences();
  }

  Future<void> _skip(String occurrenceId) async {
    await Supabase.instance.client
        .from('chore_occurrences')
        .update({'skipped': true}).eq('id', occurrenceId);
    await _refreshOccurrences();
  }

  Future<void> _reassign(String occurrenceId) async {
    final result = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Reassign to'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('Anyone'),
          ),
          ..._memberNames.entries.map((entry) => CupertinoActionSheetAction(
                onPressed: () => Navigator.pop(context, entry.key),
                child: Text(entry.value),
              )),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );

    if (result == null) return;

    final newAssignee = result.isEmpty ? null : result;
    await Supabase.instance.client
        .from('chore_occurrences')
        .update({'assigned_to': newAssignee}).eq('id', occurrenceId);
    await _refreshOccurrences();
  }

  Future<void> _showActionsFor(String occurrenceId, String choreTitle) async {
    final action = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(choreTitle),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, 'reassign'),
            child: const Text('Reassign'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, 'skip'),
            child: const Text('Skip Today'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );

    if (action == 'reassign') {
      await _reassign(occurrenceId);
    } else if (action == 'skip') {
      await _skip(occurrenceId);
    }
  }

  Future<void> _showAreaFilter() async {
    final areas = _areasById.values.toList()
      ..sort((a, b) =>
          (a['sort_order'] as int).compareTo(b['sort_order'] as int));

    final selected = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Filter by Area'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('All Areas'),
          ),
          ...areas.map((area) => CupertinoActionSheetAction(
                onPressed: () => Navigator.pop(context, area['id'] as String),
                child: Text(area['name'] as String),
              )),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );

    if (selected == null) return;
    setState(() => _areaFilter = selected.isEmpty ? null : selected);
  }

  List<Widget> _buildAreaGroupedChildren(List<Map<String, dynamic>> rows) {
    final byArea = <String?, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      final areaId = row['area_id'] as String?;
      byArea.putIfAbsent(areaId, () => []).add(row);
    }

    final areaKeys = byArea.keys.toList()
      ..sort((a, b) {
        if (a == null) return 1;
        if (b == null) return -1;
        final aOrder = _areasById[a]?['sort_order'] as int? ?? 0;
        final bOrder = _areasById[b]?['sort_order'] as int? ?? 0;
        return aOrder.compareTo(bOrder);
      });

    final children = <Widget>[];
    for (final areaKey in areaKeys) {
      final area = areaKey == null ? null : _areasById[areaKey];
      final areaName = area?['name'] as String? ?? 'General';
      final isPrivate = area?['visibility'] == 'private';

      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                areaName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
              if (isPrivate) ...[
                const SizedBox(width: 4),
                const Icon(
                  CupertinoIcons.lock_fill,
                  size: 12,
                  color: CupertinoColors.secondaryLabel,
                ),
              ],
            ],
          ),
        ),
      );

      for (final row in byArea[areaKey]!) {
        final choreId = row['chore_id'] as String;
        final occurrenceId = row['id'] as String;
        final title = _choreTitles[choreId] ?? 'Chore';
        children.add(
          GestureDetector(
            onLongPress: () => _showActionsFor(occurrenceId, title),
            child: CupertinoListTile(
              title: Text(title),
              leading: const Icon(CupertinoIcons.circle),
              onTap: () => _complete(occurrenceId),
            ),
          ),
        );
      }
    }

    return children;
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () async {
            await Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (context) =>
                    ChoreListScreen(householdId: widget.householdId),
              ),
            );
            await _loadLookups();
          },
          child: const Icon(CupertinoIcons.list_bullet),
        ),
        middle: const Text('Today'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _showAreaFilter,
              child: Icon(
                _areaFilter == null
                    ? CupertinoIcons.line_horizontal_3_decrease_circle
                    : CupertinoIcons.line_horizontal_3_decrease_circle_fill,
              ),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () async {
                await Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (context) =>
                        ChoreFormScreen(householdId: widget.householdId),
                  ),
                );
                await _loadLookups();
                await _refreshOccurrences();
              },
              child: const Icon(CupertinoIcons.add),
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: FutureBuilder<void>(
          future: _readyFuture,
          builder: (context, readySnapshot) {
            if (readySnapshot.connectionState != ConnectionState.done) {
              return const Center(child: CupertinoActivityIndicator());
            }

            final occurrencesStream = Supabase.instance.client
                .from('chore_occurrences')
                .stream(primaryKey: ['id']).eq(
                    'household_id', widget.householdId);

            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: occurrencesStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CupertinoActivityIndicator());
                }

                final today = OccurrenceGenerator.formatDate(DateTime.now());
                final visible = snapshot.data!.where((row) {
                  final dueDate = row['due_date'] as String;
                  final completed = row['completed_at'] != null;
                  final skipped = row['skipped'] as bool;
                  return dueDate.compareTo(today) <= 0 &&
                      !completed &&
                      !skipped;
                }).toList();

                if (visible.isEmpty) {
                  if (_choreTitles.isEmpty) {
                    return _buildOnboarding();
                  }
                  return const Center(child: Text('Nothing due today.'));
                }

                final areaFiltered = _areaFilter == null
                    ? visible
                    : visible
                        .where((row) => row['area_id'] == _areaFilter)
                        .toList();

                if (areaFiltered.isEmpty) {
                  return const Center(
                      child: Text('Nothing due today in this area.'));
                }

                final grouped = <String?, List<Map<String, dynamic>>>{};
                for (final row in areaFiltered) {
                  final assignedTo = row['assigned_to'] as String?;
                  grouped.putIfAbsent(assignedTo, () => []).add(row);
                }

                final groupKeys = grouped.keys.toList()
                  ..sort((a, b) {
                    if (a == null) return 1;
                    if (b == null) return -1;
                    return 0;
                  });

                return ListView(
                  children: groupKeys.map((key) {
                    final label = key == null
                        ? 'Anyone'
                        : (_memberNames[key] ?? 'Household member');
                    final rows = grouped[key]!;
                    return CupertinoListSection.insetGrouped(
                      header: Text(label),
                      children: _buildAreaGroupedChildren(rows),
                    );
                  }).toList(),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildOnboarding() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'No chores yet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add one of these to get started, or use the + button above.',
              textAlign: TextAlign.center,
              style: TextStyle(color: CupertinoColors.secondaryLabel),
            ),
            const SizedBox(height: 16),
            ..._starterTemplates.map((template) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: CupertinoButton(
                  color: CupertinoColors.systemGrey5,
                  onPressed: () => _addStarterChore(template),
                  child: Text(
                    template['title'] as String,
                    style: const TextStyle(color: CupertinoColors.label),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
