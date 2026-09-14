import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ListDetailScreen extends StatefulWidget {
  final String householdId;
  final String listId;
  final String listName;

  const ListDetailScreen({
    super.key,
    required this.householdId,
    required this.listId,
    required this.listName,
  });

  @override
  State<ListDetailScreen> createState() => _ListDetailScreenState();
}

class _ListDetailScreenState extends State<ListDetailScreen> {
  final _itemController = TextEditingController();

  @override
  void dispose() {
    _itemController.dispose();
    super.dispose();
  }

  Future<void> _addItem() async {
    final title = _itemController.text.trim();
    if (title.isEmpty) return;

    final userId = Supabase.instance.client.auth.currentUser!.id;
    await Supabase.instance.client.from('list_items').insert({
      'list_id': widget.listId,
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

  Future<void> _clearChecked() async {
    await Supabase.instance.client
        .from('list_items')
        .delete()
        .eq('list_id', widget.listId)
        .eq('checked', true);
  }

  @override
  Widget build(BuildContext context) {
    final itemsStream = Supabase.instance.client
        .from('list_items')
        .stream(primaryKey: ['id'])
        .eq('list_id', widget.listId)
        .order('created_at');

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(middle: Text(widget.listName)),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoTextField(
                      controller: _itemController,
                      placeholder: 'Add an item',
                      padding: const EdgeInsets.all(12),
                      onSubmitted: (_) => _addItem(),
                    ),
                  ),
                  CupertinoButton(
                    onPressed: _addItem,
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

                  final hasChecked =
                      items.any((item) => item['checked'] as bool);

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
                                onTap: () => _toggleChecked(
                                    item['id'] as String, !checked),
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
                          onPressed: _clearChecked,
                          child: const Text('Clear Checked'),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
