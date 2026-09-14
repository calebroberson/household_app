import 'package:flutter/cupertino.dart';

import '../services/chore_actions.dart';

/// Renders a list of chore_occurrences rows grouped into area sub-sections
/// (sorted by area sort_order, "General" last, lock glyph on private areas).
/// Shared by Today and Calendar so the two screens' day lists render and
/// behave identically -- tap completes, long-press opens the reassign/skip
/// action sheet, both via ChoreActions.
List<Widget> buildAreaGroupedChildren({
  required BuildContext context,
  required List<Map<String, dynamic>> rows,
  required Map<String, Map<String, dynamic>> areasById,
  required Map<String, String> choreTitles,
  required Map<String, String> memberNames,
  required String householdId,
}) {
  final byArea = <String?, List<Map<String, dynamic>>>{};
  for (final row in rows) {
    final areaId = row['area_id'] as String?;
    byArea.putIfAbsent(areaId, () => []).add(row);
  }

  final areaKeys = byArea.keys.toList()
    ..sort((a, b) {
      if (a == null) return 1;
      if (b == null) return -1;
      final aOrder = areasById[a]?['sort_order'] as int? ?? 0;
      final bOrder = areasById[b]?['sort_order'] as int? ?? 0;
      return aOrder.compareTo(bOrder);
    });

  final children = <Widget>[];
  for (final areaKey in areaKeys) {
    final area = areaKey == null ? null : areasById[areaKey];
    final areaName = area?['name'] as String? ?? 'General';
    final isPrivate = area?['visibility'] == 'private';

    children.add(
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              areaName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            if (isPrivate) ...[
              const SizedBox(width: 4),
              const Icon(
                CupertinoIcons.lock_fill,
                size: 12,
                color: CupertinoColors.secondaryLabel,
              ),
            ],
          ],
        ),
      ),
    );

    for (final row in byArea[areaKey]!) {
      final choreId = row['chore_id'] as String;
      final occurrenceId = row['id'] as String;
      final title = choreTitles[choreId] ?? 'Chore';
      children.add(
        GestureDetector(
          onLongPress: () => ChoreActions.showActionsSheet(
            context: context,
            occurrenceId: occurrenceId,
            householdId: householdId,
            choreTitle: title,
            memberNames: memberNames,
          ),
          child: CupertinoListTile(
            title: Text(title),
            leading: const Icon(CupertinoIcons.circle),
            onTap: () => ChoreActions.complete(occurrenceId, householdId),
          ),
        ),
      );
    }
  }

  return children;
}
