import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ListsScreen extends StatefulWidget {
  final String householdId;

  const ListsScreen({super.key, required this.householdId});

  @override
  State<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends State<ListsScreen> {
  late Future<String> _listIdFuture;

  @override
  void initState() {
    super.initState();
    _listIdFuture = _fetchOrCreateDefaultList();
  }

  Future<String> _fetchOrCreateDefaultList() async {
    final existing = await Supabase.instance.client
        .from('lists')
        .select('id')
        .eq('household_id', widget.householdId)
        .limit(1);

    if (existing.isNotEmpty) {
      return existing.first['id'] as String;
    }

    final created = await Supabase.instance.client
        .from('lists')
        .insert({
          'household_id': widget.householdId,
          'name': 'Groceries',
        })
        .select('id')
        .single();
    return created['id'] as String;
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Groceries')),
      child: SafeArea(
        child: FutureBuilder<String>(
          future: _listIdFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CupertinoActivityIndicator());
            }
            if (snapshot.hasError) {
              return const Center(child: Text('Could not load list.'));
            }
            return const Center(child: Text('List is ready. Items coming next.'));
          },
        ),
      ),
    );
  }
}
