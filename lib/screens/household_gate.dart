import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'create_or_join_household_screen.dart';
import 'main_tab_scaffold.dart';

class HouseholdGate extends StatefulWidget {
  const HouseholdGate({super.key});

  @override
  State<HouseholdGate> createState() => _HouseholdGateState();
}

class _HouseholdGateState extends State<HouseholdGate> {
  late Future<String?> _householdIdFuture;

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

        final householdId = snapshot.data;
        if (householdId == null) {
          return CreateOrJoinHouseholdScreen(onSuccess: _refresh);
        }
        return MainTabScaffold(
          householdId: householdId,
          onHouseholdChanged: _refresh,
        );
      },
    );
  }
}
