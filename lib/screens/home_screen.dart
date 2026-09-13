import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeScreen extends StatefulWidget {
  final String householdId;

  const HomeScreen({super.key, required this.householdId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<String> _householdNameFuture;

  @override
  void initState() {
    super.initState();
    _householdNameFuture = _fetchHouseholdName();
  }

  Future<String> _fetchHouseholdName() async {
    final row = await Supabase.instance.client
        .from('households')
        .select('name')
        .eq('id', widget.householdId)
        .single();
    return row['name'] as String;
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
      'expires_at': now.add(const Duration(days: 7)).toIso8601String(),
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
          content: const Text('Could not create an invite code. Please try again.'),
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
        child: Center(
          child: CupertinoButton.filled(
            onPressed: _createInvite,
            child: const Text('Invite Someone'),
          ),
        ),
      ),
    );
  }
}
