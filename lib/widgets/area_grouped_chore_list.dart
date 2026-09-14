import 'package:flutter/cupertino.dart';

import '../services/chore_actions.dart';

/// Renders a list of chore_occurrences-shaped rows grouped into area
/// sub-sections (sorted by area sort_order, "General" last, lock glyph on
/// private areas). Shared by Today and Calendar so the two screens' day
/// lists render and behave identically.
///
/// Each row may be open (tappable: tap completes, long-press opens the
/// reassign/skip sheet), completed, or skipped (shown de-emphasized,
/// not actionable) -- Today only ever passes open rows, Calendar passes
/// all three plus optionally a `'subtitle'` key (used for the "Next due:
/// [date]" label on a projected future instance, which still targets the
/// same real occurrence id).
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
      children.add(_ChoreRow(
        row: row,
        choreTitles: choreTitles,
        memberNames: memberNames,
        householdId: householdId,
      ));
    }
  }

  return children;
}

class _ChoreRow extends StatelessWidget {
  final Map<String, dynamic> row;
  final Map<String, String> choreTitles;
  final Map<String, String> memberNames;
  final String householdId;

  const _ChoreRow({
    required this.row,
    required this.choreTitles,
    required this.memberNames,
    required this.householdId,
  });

  @override
  Widget build(BuildContext context) {
    final choreId = row['chore_id'] as String;
    final occurrenceId = row['id'] as String;
    final title = choreTitles[choreId] ?? 'Chore';
    final completed = row['completed_at'] != null;
    final skipped = row['skipped'] == true;
    final isActionable = !completed && !skipped;

    Widget leadingIcon;
    TextStyle? titleStyle;
    String? subtitle = row['subtitle'] as String?;

    if (completed) {
      leadingIcon = const Icon(
        CupertinoIcons.checkmark_circle_fill,
        color: CupertinoColors.activeGreen,
      );
      titleStyle = const TextStyle(
        decoration: TextDecoration.lineThrough,
        color: CupertinoColors.secondaryLabel,
      );
      final completedBy = row['completed_by'] as String?;
      final completedByName =
          completedBy != null ? memberNames[completedBy] : null;
      subtitle ??=
          completedByName != null ? 'Completed by $completedByName' : 'Completed';
    } else if (skipped) {
      leadingIcon = const Icon(
        CupertinoIcons.xmark_circle,
        color: CupertinoColors.secondaryLabel,
      );
      titleStyle = const TextStyle(color: CupertinoColors.secondaryLabel);
      subtitle ??= 'Skipped';
    } else {
      leadingIcon = const Icon(CupertinoIcons.circle);
    }

    return GestureDetector(
      onLongPress: isActionable
          ? () => ChoreActions.showActionsSheet(
                context: context,
                occurrenceId: occurrenceId,
                householdId: householdId,
                choreTitle: title,
                memberNames: memberNames,
              )
          : null,
      child: CupertinoListTile(
        title: Text(title, style: titleStyle),
        subtitle: subtitle != null ? Text(subtitle) : null,
        leading: leadingIcon,
        onTap: isActionable
            ? () => ChoreActions.complete(occurrenceId, householdId)
            : null,
      ),
    );
  }
}
