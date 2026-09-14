import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/area_icons.dart';
import 'area_form_screen.dart';

class AreaListScreen extends StatefulWidget {
  final String householdId;

  const AreaListScreen({super.key, required this.householdId});

  @override
  State<AreaListScreen> createState() => _AreaListScreenState();
}

class _AreaListScreenState extends State<AreaListScreen> {
  bool _isReordering = false;

  Future<void> _swap(Map<String, dynamic> a, Map<String, dynamic> b) async {
    final aId = a['id'] as String;
    final bId = b['id'] as String;
    final aOrder = a['sort_order'] as int;
    final bOrder = b['sort_order'] as int;

    await Supabase.instance.client
        .from('areas')
        .update({'sort_order': bOrder}).eq('id', aId);
    await Supabase.instance.client
        .from('areas')
        .update({'sort_order': aOrder}).eq('id', bId);
  }

  @override
  Widget build(BuildContext context) {
    final areasStream = Supabase.instance.client
        .from('areas')
        .stream(primaryKey: ['id'])
        .eq('household_id', widget.householdId)
        .order('sort_order');

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Areas'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => setState(() => _isReordering = !_isReordering),
          child: Text(_isReordering ? 'Done' : 'Edit'),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).push(
            CupertinoPageRoute(
              builder: (context) =>
                  AreaFormScreen(householdId: widget.householdId),
            ),
          ),
          child: const Icon(CupertinoIcons.add),
        ),
      ),
      child: SafeArea(
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: areasStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CupertinoActivityIndicator());
            }

            final areas = snapshot.data!
                .where((a) => a['archived_at'] == null)
                .toList();

            if (areas.isEmpty) {
              return const Center(child: Text('No areas yet.'));
            }

            return ListView.builder(
              itemCount: areas.length,
              itemBuilder: (context, index) {
                final area = areas[index];
                final isPrivate = area['visibility'] == 'private';

                return CupertinoListTile(
                  leading: Icon(areaIconFor(area['icon'] as String?)),
                  title: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(child: Text(area['name'] as String)),
                      if (isPrivate) ...[
                        const SizedBox(width: 6),
                        const Icon(CupertinoIcons.lock_fill, size: 14),
                      ],
                    ],
                  ),
                  trailing: _isReordering
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: index == 0
                                  ? null
                                  : () => _swap(area, areas[index - 1]),
                              child: const Icon(CupertinoIcons.chevron_up),
                            ),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: index == areas.length - 1
                                  ? null
                                  : () => _swap(area, areas[index + 1]),
                              child: const Icon(CupertinoIcons.chevron_down),
                            ),
                          ],
                        )
                      : const Icon(CupertinoIcons.chevron_forward),
                  onTap: _isReordering
                      ? null
                      : () => Navigator.of(context).push(
                            CupertinoPageRoute(
                              builder: (context) => AreaFormScreen(
                                householdId: widget.householdId,
                                existingArea: area,
                              ),
                            ),
                          ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
