import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'area_list_screen.dart';

class HomeScreen extends StatefulWidget {
  final String householdId;
  final VoidCallback onHouseholdChanged;

  const HomeScreen({
    super.key,
    required this.householdId,
    required this.onHouseholdChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<String> _householdNameFuture;
  late Future<List<Map<String, dynamic>>> _completionCountsFuture;

  @override
  void initState() {
    super.initState();
    _householdNameFuture = _fetchHouseholdName();
    _completionCountsFuture = _fetchCompletionCounts();
  }

  Future<String> _fetchHouseholdName() async {
    final row = await Supabase.instance.client
        .from('households')
        .select('name')
        .eq('id', widget.householdId)
        .single();
    return row['name'] as String;
  }

  Future<List<Map<String, dynamic>>> _fetchCompletionCounts() async {
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

    final thirtyDaysAgo =
        DateTime.now().toUtc().subtract(const Duration(days: 30));
    final completions = await Supabase.instance.client
        .from('chore_occurrences')
        .select('completed_by')
        .eq('household_id', widget.householdId)
        .gte('completed_at', thirtyDaysAgo.toIso8601String());

    final counts = <String, int>{for (final userId in userIds) userId: 0};
    for (final row in completions) {
      final completedBy = row['completed_by'] as String?;
      if (completedBy != null && counts.containsKey(completedBy)) {
        counts[completedBy] = counts[completedBy]! + 1;
      }
    }

    return userIds
        .map((userId) => {
              'name': namesById[userId] ?? 'Household member',
              'count': counts[userId] ?? 0,
            })
        .toList();
  }

  String _generateInviteCode([int length = 6]) {
    const charset = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  Future<String> _findOrCreateActiveInviteCode() async {
    final rows = await Supabase.instance.client
        .from('household_invites')
        .select('code, expires_at, max_uses, use_count')
        .eq('household_id', widget.householdId)
        .order('created_at', ascending: false)
        .limit(20);

    final now = DateTime.now();
    for (final row in rows) {
      final expiresAt = row['expires_at'] as String?;
      final notExpired =
          expiresAt == null || DateTime.parse(expiresAt).isAfter(now);
      final usesLeft = (row['use_count'] as int) < (row['max_uses'] as int);
      if (notExpired && usesLeft) {
        return row['code'] as String;
      }
    }

    final code = _generateInviteCode();
    final userId = Supabase.instance.client.auth.currentUser!.id;
    await Supabase.instance.client.from('household_invites').insert({
      'household_id': widget.householdId,
      'code': code,
      'created_by': userId,
      'expires_at':
          now.add(const Duration(days: 7)).toUtc().toIso8601String(),
      'max_uses': 10,
    });
    return code;
  }

  Future<void> _createInvite() async {
    try {
      final code = await _findOrCreateActiveInviteCode();

      if (!mounted) return;
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Invite Code'),
          content: Text('Share this code with someone to join: $code'),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Error'),
          content:
              const Text('Could not create an invite code. Please try again.'),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _leaveHousehold() async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Leave Household?'),
        content: const Text(
            'You will lose access to this household\'s chores and lists.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await Supabase.instance.client.rpc('leave_household');
      widget.onHouseholdChanged();
    } catch (error) {
      if (!mounted) return;
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Error'),
          content:
              const Text('Could not leave the household. Please try again.'),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: FutureBuilder<String>(
          future: _householdNameFuture,
          builder: (context, snapshot) {
            return Text(snapshot.data ?? 'Household');
          },
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Supabase.instance.client.auth.signOut(),
          child: const Text('Sign Out'),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            CupertinoButton.filled(
              onPressed: _createInvite,
              child: const Text('Invite Someone'),
            ),
            const SizedBox(height: 12),
            CupertinoButton(
              onPressed: () => Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (context) =>
                      AreaListScreen(householdId: widget.householdId),
                ),
              ),
              child: const Text('Manage Areas'),
            ),
            const SizedBox(height: 32),
            const Text(
              'Last 30 Days',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _completionCountsFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CupertinoActivityIndicator());
                }
                final counts = snapshot.data!;
                return CupertinoListSection.insetGrouped(
                  children: counts.map((entry) {
                    final count = entry['count'] as int;
                    return CupertinoListTile(
                      title: Text(entry['name'] as String),
                      trailing: Text(
                        '$count ${count == 1 ? 'chore' : 'chores'}',
                        style: const TextStyle(
                          color: CupertinoColors.secondaryLabel,
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 32),
            CupertinoButton(
              onPressed: _leaveHousehold,
              child: const Text(
                'Leave Household',
                style: TextStyle(color: CupertinoColors.destructiveRed),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
