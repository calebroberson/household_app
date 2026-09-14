import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/occurrence_generator.dart';
import 'chore_form_screen.dart';

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

    setState(() {
      _choreTitles = {
        for (final row in choreRows)
          row['id'] as String: row['title'] as String,
      };
      _memberNames = {
        for (final userId in userIds)
          userId: namesById[userId] ?? 'Household member',
      };
    });
  }

  Future<void> _refreshOccurrences() async {
    await OccurrenceGenerator.ensureOccurrencesForHousehold(widget.householdId);
  }

  Future<void> _complete(String occurrenceId) async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    await Supabase.instance.client.from('chore_occurrences').update({
      'completed_at': DateTime.now().toUtc().toIso8601String(),
      'completed_by': userId,
    }).eq('id', occurrenceId);
    await _refreshOccurrences();
  }

  Future<void> _confirmSkip(String occurrenceId, String choreTitle) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Skip today?'),
        content: Text('Skip "$choreTitle" for today?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Skip'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await Supabase.instance.client
          .from('chore_occurrences')
          .update({'skipped': true}).eq('id', occurrenceId);
      await _refreshOccurrences();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Today'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).push(
            CupertinoPageRoute(
              builder: (context) =>
                  ChoreFormScreen(householdId: widget.householdId),
            ),
          ),
          child: const Icon(CupertinoIcons.add),
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
                  return const Center(child: Text('Nothing due today.'));
                }

                final grouped = <String?, List<Map<String, dynamic>>>{};
                for (final row in visible) {
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
                      children: rows.map((row) {
                        final choreId = row['chore_id'] as String;
                        final occurrenceId = row['id'] as String;
                        final title = _choreTitles[choreId] ?? 'Chore';
                        return GestureDetector(
                          onLongPress: () =>
                              _confirmSkip(occurrenceId, title),
                          child: CupertinoListTile(
                            title: Text(title),
                            leading: const Icon(CupertinoIcons.circle),
                            onTap: () => _complete(occurrenceId),
                          ),
                        );
                      }).toList(),
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
}
