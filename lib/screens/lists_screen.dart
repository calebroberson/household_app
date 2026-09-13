import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ListsScreen extends StatefulWidget {
  final String householdId;

  const ListsScreen({super.key, required this.householdId});

  @override
  State<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends State<ListsScreen> {
  String? _listId;
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  final _itemController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _itemController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    final listId = await _fetchOrCreateDefaultList();
    setState(() => _listId = listId);
    await _refreshItems();
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

  Future<void> _refreshItems() async {
    if (_listId == null) return;
    final rows = await Supabase.instance.client
        .from('list_items')
        .select('id, title, checked')
        .eq('list_id', _listId!)
        .order('created_at');

    setState(() {
      _items = List<Map<String, dynamic>>.from(rows);
      _isLoading = false;
    });
  }

  Future<void> _addItem() async {
    final title = _itemController.text.trim();
    if (title.isEmpty || _listId == null) return;

    final userId = Supabase.instance.client.auth.currentUser!.id;
    await Supabase.instance.client.from('list_items').insert({
      'list_id': _listId,
      'household_id': widget.householdId,
      'title': title,
      'added_by': userId,
    });

    _itemController.clear();
    await _refreshItems();
  }

  Future<void> _toggleChecked(String itemId, bool newValue) async {
    await Supabase.instance.client
        .from('list_items')
        .update({'checked': newValue}).eq('id', itemId);
    await _refreshItems();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Groceries')),
      child: SafeArea(
        child: _isLoading
            ? const Center(child: CupertinoActivityIndicator())
            : Column(
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
                    child: _items.isEmpty
                        ? const Center(child: Text('No items yet.'))
                        : ListView.builder(
                            itemCount: _items.length,
                            itemBuilder: (context, index) {
                              final item = _items[index];
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
                                      _toggleChecked(item['id'] as String, !checked),
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
                ],
              ),
      ),
    );
  }
}
