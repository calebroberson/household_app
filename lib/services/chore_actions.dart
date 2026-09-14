import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'occurrence_generator.dart';

/// Shared chore-occurrence mutations (complete/skip/reassign) and their
/// action-sheet UI flows, used identically from Today and Calendar so
/// completion behavior is never forked between the two screens.
class ChoreActions {
  static Future<void> complete(String occurrenceId, String householdId) async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    await Supabase.instance.client.from('chore_occurrences').update({
      'completed_at': DateTime.now().toUtc().toIso8601String(),
      'completed_by': userId,
    }).eq('id', occurrenceId);
    await OccurrenceGenerator.ensureOccurrencesForHousehold(householdId);
  }

  static Future<void> skip(String occurrenceId, String householdId) async {
    await Supabase.instance.client.from('chore_occurrences').update({
      'skipped': true,
      'skipped_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', occurrenceId);
    await OccurrenceGenerator.ensureOccurrencesForHousehold(householdId);
  }

  /// Undoes a completed or skipped occurrence, restoring it to open.
  ///
  /// Refuses (throws a [StateError]) if the same chore has already been
  /// resolved again more recently than [occurrenceId] -- undoing an older
  /// resolution in that case would silently discard real, later history.
  /// On success, also removes the single open occurrence
  /// [OccurrenceGenerator] auto-generated right after [occurrenceId]
  /// resolved, so the "at most one open occurrence per chore" invariant
  /// holds again with [occurrenceId] itself as that one open occurrence.
  static Future<void> reopen(String occurrenceId, String householdId) async {
    final client = Supabase.instance.client;

    final occurrence = await client
        .from('chore_occurrences')
        .select('chore_id, completed_at, skipped_at')
        .eq('id', occurrenceId)
        .single();

    final choreId = occurrence['chore_id'] as String;
    final resolvedAtRaw =
        (occurrence['completed_at'] ?? occurrence['skipped_at']) as String?;
    if (resolvedAtRaw == null) return;
    final resolvedAt = DateTime.parse(resolvedAtRaw);

    final siblings = await client
        .from('chore_occurrences')
        .select('id, completed_at, skipped_at')
        .eq('chore_id', choreId);

    for (final sibling in siblings) {
      if (sibling['id'] == occurrenceId) continue;
      final siblingResolvedRaw =
          (sibling['completed_at'] ?? sibling['skipped_at']) as String?;
      if (siblingResolvedRaw == null) continue;
      if (DateTime.parse(siblingResolvedRaw).isAfter(resolvedAt)) {
        throw StateError(
          'This chore has already been done again since -- can\'t undo.',
        );
      }
    }

    await client
        .from('chore_occurrences')
        .delete()
        .eq('chore_id', choreId)
        .isFilter('completed_at', null)
        .eq('skipped', false)
        .neq('id', occurrenceId);

    await client.from('chore_occurrences').update({
      'completed_at': null,
      'completed_by': null,
      'skipped': false,
      'skipped_at': null,
    }).eq('id', occurrenceId);

    await OccurrenceGenerator.ensureOccurrencesForHousehold(householdId);
  }

  static Future<void> reassign(
    String occurrenceId,
    String householdId,
    String? newAssignee,
  ) async {
    await Supabase.instance.client
        .from('chore_occurrences')
        .update({'assigned_to': newAssignee}).eq('id', occurrenceId);
    await OccurrenceGenerator.ensureOccurrencesForHousehold(householdId);
  }

  static Future<void> showReassignSheet({
    required BuildContext context,
    required String occurrenceId,
    required String householdId,
    required Map<String, String> memberNames,
  }) async {
    final result = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Reassign to'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('Anyone'),
          ),
          ...memberNames.entries.map((entry) => CupertinoActionSheetAction(
                onPressed: () => Navigator.pop(context, entry.key),
                child: Text(entry.value),
              )),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );

    if (result == null) return;
    final newAssignee = result.isEmpty ? null : result;
    await reassign(occurrenceId, householdId, newAssignee);
  }

  static Future<void> showActionsSheet({
    required BuildContext context,
    required String occurrenceId,
    required String householdId,
    required String choreTitle,
    required Map<String, String> memberNames,
  }) async {
    final action = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(choreTitle),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, 'reassign'),
            child: const Text('Reassign'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, 'skip'),
            child: const Text('Skip'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );

    if (action == 'reassign') {
      if (!context.mounted) return;
      await showReassignSheet(
        context: context,
        occurrenceId: occurrenceId,
        householdId: householdId,
        memberNames: memberNames,
      );
    } else if (action == 'skip') {
      await skip(occurrenceId, householdId);
    }
  }
}
