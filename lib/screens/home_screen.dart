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

  Future<void> _createInvite() async {
    final code = _generateInviteCode();
    final userId = Supabase.instance.client.auth.currentUser!.id;

    try {
      await Supabase.instance.client.from('household_invites').insert({
        'household_id': widget.householdId,
        'code': code,
        'created_by': userId,
      });

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
