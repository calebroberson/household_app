import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'list_detail_screen.dart';

class ListsScreen extends StatefulWidget {
  final String householdId;

  const ListsScreen({super.key, required this.householdId});

  @override
  State<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends State<ListsScreen> {
  late Future<void> _ensureDefaultListFuture;

  @override
  void initState() {
    super.initState();
    _ensureDefaultListFuture = _ensureDefaultList();
  }

  Future<void> _ensureDefaultList() async {
    final existing = await Supabase.instance.client
        .from('lists')
        .select('id')
        .eq('household_id', widget.householdId)
        .limit(1);

    if (existing.isEmpty) {
      await Supabase.instance.client.from('lists').insert({
        'household_id': widget.householdId,
        'name': 'Groceries',
      });
    }
  }

  Future<void> _createList() async {
    final controller = TextEditingController();
    final name = await showCupertinoDialog<String>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('New List'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            placeholder: 'e.g. Household Items',
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;
    await Supabase.instance.client.from('lists').insert({
      'household_id': widget.householdId,
      'name': name,
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Our Lists'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _createList,
          child: const Icon(CupertinoIcons.add),
        ),
      ),
      child: SafeArea(
        child: FutureBuilder<void>(
          future: _ensureDefaultListFuture,
          builder: (context, ensureSnapshot) {
            if (ensureSnapshot.connectionState != ConnectionState.done) {
              return const Center(child: CupertinoActivityIndicator());
            }

            final listsStream = Supabase.instance.client
                .from('lists')
                .stream(primaryKey: ['id'])
                .eq('household_id', widget.householdId)
                .order('created_at');

            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: listsStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CupertinoActivityIndicator());
                }

                final lists = snapshot.data!;
                if (lists.isEmpty) {
                  return const Center(child: Text('No lists yet.'));
                }

                return ListView.builder(
                  itemCount: lists.length,
                  itemBuilder: (context, index) {
                    final list = lists[index];
                    final listId = list['id'] as String;
                    final listName = list['name'] as String;
                    return CupertinoListTile(
                      title: Text(listName),
                      trailing: const Icon(CupertinoIcons.chevron_forward),
                      onTap: () => Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (context) => ListDetailScreen(
                            householdId: widget.householdId,
                            listId: listId,
                            listName: listName,
                          ),
                        ),
                      ),
                    );
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
