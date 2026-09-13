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
  final _itemController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _listIdFuture = _fetchOrCreateDefaultList();
  }

  @override
  void dispose() {
    _itemController.dispose();
    super.dispose();
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

  Future<void> _addItem(String listId) async {
    final title = _itemController.text.trim();
    if (title.isEmpty) return;

    final userId = Supabase.instance.client.auth.currentUser!.id;
    await Supabase.instance.client.from('list_items').insert({
      'list_id': listId,
      'household_id': widget.householdId,
      'title': title,
      'added_by': userId,
    });

    _itemController.clear();
  }

  Future<void> _toggleChecked(String itemId, bool newValue) async {
    await Supabase.instance.client
        .from('list_items')
        .update({'checked': newValue}).eq('id', itemId);
  }

  Future<void> _clearChecked(String listId) async {
    await Supabase.instance.client
        .from('list_items')
        .delete()
        .eq('list_id', listId)
        .eq('checked', true);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Groceries')),
      child: SafeArea(
        child: FutureBuilder<String>(
          future: _listIdFuture,
          builder: (context, listSnapshot) {
            if (listSnapshot.connectionState != ConnectionState.done) {
              return const Center(child: CupertinoActivityIndicator());
            }
            if (listSnapshot.hasError) {
              return const Center(child: Text('Could not load list.'));
            }

            final listId = listSnapshot.data!;
            return _ListItemsBody(
              listId: listId,
              itemController: _itemController,
              onAdd: () => _addItem(listId),
              onToggle: _toggleChecked,
              onClearChecked: () => _clearChecked(listId),
            );
          },
        ),
      ),
    );
  }
}

class _ListItemsBody extends StatelessWidget {
  final String listId;
  final TextEditingController itemController;
  final VoidCallback onAdd;
  final void Function(String itemId, bool newValue) onToggle;
  final VoidCallback onClearChecked;

  const _ListItemsBody({
    required this.listId,
    required this.itemController,
    required this.onAdd,
    required this.onToggle,
    required this.onClearChecked,
  });

  @override
  Widget build(BuildContext context) {
    final itemsStream = Supabase.instance.client
        .from('list_items')
        .stream(primaryKey: ['id'])
        .eq('list_id', listId)
        .order('created_at');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: CupertinoTextField(
                  controller: itemController,
                  placeholder: 'Add an item',
                  padding: const EdgeInsets.all(12),
                  onSubmitted: (_) => onAdd(),
                ),
              ),
              CupertinoButton(
                onPressed: onAdd,
                child: const Icon(CupertinoIcons.add_circled_solid),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: itemsStream,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CupertinoActivityIndicator());
              }

              final items = snapshot.data!;
              if (items.isEmpty) {
                return const Center(child: Text('No items yet.'));
              }

              final hasChecked = items.any((item) => item['checked'] as bool);

              return Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final checked = item['checked'] as bool;
                        return CupertinoListTile(
                          title: Text(
                            item['title'] as String,
                            style: checked
                                ? const TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                    color: CupertinoColors.secondaryLabel,
                                  )
                                : null,
                          ),
                          leading: GestureDetector(
                            onTap: () =>
                                onToggle(item['id'] as String, !checked),
                            child: Icon(
                              checked
                                  ? CupertinoIcons.checkmark_circle_fill
                                  : CupertinoIcons.circle,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (hasChecked)
                    CupertinoButton(
                      onPressed: onClearChecked,
                      child: const Text('Clear Checked'),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
