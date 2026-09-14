import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/push_registration.dart';
import 'create_or_join_household_screen.dart';
import 'main_tab_scaffold.dart';

class HouseholdGate extends StatefulWidget {
  const HouseholdGate({super.key});

  @override
  State<HouseholdGate> createState() => _HouseholdGateState();
}

class _HouseholdGateState extends State<HouseholdGate> {
  late Future<String?> _householdIdFuture;
  bool _pushRegistrationTriggered = false;

  @override
  void initState() {
    super.initState();
    _householdIdFuture = _fetchHouseholdId();
  }

  Future<String?> _fetchHouseholdId() async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    final rows = await Supabase.instance.client
        .from('household_members')
        .select('household_id')
        .eq('user_id', userId)
        .limit(1);
    if (rows.isEmpty) return null;
    return rows.first['household_id'] as String;
  }

  void _refresh() {
    setState(() {
      _householdIdFuture = _fetchHouseholdId();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _householdIdFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const CupertinoPageScaffold(
            child: Center(child: CupertinoActivityIndicator()),
          );
        }

        if (snapshot.hasError) {
          return CupertinoPageScaffold(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Could not load your household.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    CupertinoButton.filled(
                      onPressed: _refresh,
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final householdId = snapshot.data;
        if (householdId == null) {
          return CreateOrJoinHouseholdScreen(onSuccess: _refresh);
        }
        if (!_pushRegistrationTriggered) {
          _pushRegistrationTriggered = true;
          PushRegistration.registerForPushNotifications(
            context: context,
            householdId: householdId,
          );
        }
        return MainTabScaffold(
          householdId: householdId,
          onHouseholdChanged: _refresh,
        );
      },
    );
  }
}
