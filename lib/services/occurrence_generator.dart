import 'package:supabase_flutter/supabase_flutter.dart';

/// Generates chore_occurrences from chore templates, keeping at most one
/// open (not completed, not skipped) occurrence per chore at any time.
class OccurrenceGenerator {
  static DateTime dateOnly(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day);

  static DateTime _startOfWeek(DateTime d) =>
      d.subtract(Duration(days: d.weekday - 1));

  static String formatDate(DateTime dt) {
    final d = dateOnly(dt);
    final month = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$month-$day';
  }

  /// Finds the earliest date >= [searchFrom] that satisfies [recurrenceRule].
  static DateTime computeNextDueDate(
    Map<String, dynamic> recurrenceRule, {
    required DateTime searchFrom,
  }) {
    final from = dateOnly(searchFrom);
    final type = recurrenceRule['type'] as String;

    if (type == 'daily') {
      return from;
    }

    if (type == 'weekly') {
      final days = (recurrenceRule['days'] as List).cast<int>();
      for (var i = 0; i < 7; i++) {
        final candidate = from.add(Duration(days: i));
        if (days.contains(candidate.weekday)) {
          return candidate;
        }
      }
      return from;
    }

    if (type == 'every_n_weeks') {
      final n = recurrenceRule['n'] as int;
      final weekday = recurrenceRule['weekday'] as int;
      final anchor = dateOnly(DateTime.parse(recurrenceRule['anchor'] as String));
      final anchorWeekStart = _startOfWeek(anchor);

      for (var i = 0; i < n * 7; i++) {
        final candidate = from.add(Duration(days: i));
        if (candidate.weekday != weekday) continue;
        final candidateWeekStart = _startOfWeek(candidate);
        final weeksSinceAnchor =
            candidateWeekStart.difference(anchorWeekStart).inDays ~/ 7;
        if (weeksSinceAnchor % n == 0) {
          return candidate;
        }
      }
      return from;
    }

    if (type == 'monthly') {
      final dayOfMonth = recurrenceRule['day_of_month'] as int;
      var candidateMonth = DateTime(from.year, from.month, 1);

      while (true) {
        final daysInMonth =
            DateTime(candidateMonth.year, candidateMonth.month + 1, 0).day;
        final actualDay = dayOfMonth > daysInMonth ? daysInMonth : dayOfMonth;
        final monthlyDate =
            DateTime(candidateMonth.year, candidateMonth.month, actualDay);
        if (!monthlyDate.isBefore(from)) {
          return monthlyDate;
        }
        candidateMonth =
            DateTime(candidateMonth.year, candidateMonth.month + 1, 1);
      }
    }

    if (type == 'every_n_months') {
      final n = recurrenceRule['n'] as int;
      final dayOfMonth = recurrenceRule['day_of_month'] as int;
      final anchor =
          dateOnly(DateTime.parse(recurrenceRule['anchor'] as String));
      final anchorMonthIndex = anchor.year * 12 + (anchor.month - 1);

      var candidateMonthIndex = from.year * 12 + (from.month - 1);
      final offset = (candidateMonthIndex - anchorMonthIndex) % n;
      candidateMonthIndex -= offset < 0 ? offset + n : offset;

      while (true) {
        final year = candidateMonthIndex ~/ 12;
        final month = candidateMonthIndex % 12 + 1;
        final daysInMonth = DateTime(year, month + 1, 0).day;
        final actualDay = dayOfMonth > daysInMonth ? daysInMonth : dayOfMonth;
        final candidate = DateTime(year, month, actualDay);
        if (!candidate.isBefore(from)) return candidate;
        candidateMonthIndex += n;
      }
    }

    throw ArgumentError('Unsupported recurrence type: $type');
  }

  static Future<void> ensureOccurrencesForHousehold(String householdId) async {
    final chores = await Supabase.instance.client
        .from('chores')
        .select(
            'id, recurrence_rule, assignment_strategy, assignee_order, fixed_assignee, area_id')
        .eq('household_id', householdId)
        .eq('active', true);

    for (final chore in chores) {
      await _ensureOccurrenceForChore(householdId, chore);
    }
  }

  static Future<void> _ensureOccurrenceForChore(
    String householdId,
    Map<String, dynamic> chore,
  ) async {
    final choreId = chore['id'] as String;

    final recent = await Supabase.instance.client
        .from('chore_occurrences')
        .select('id, due_date, completed_at, skipped, assigned_to')
        .eq('chore_id', choreId)
        .order('due_date', ascending: false)
        .limit(1);

    final today = dateOnly(DateTime.now());
    final recurrenceRule = chore['recurrence_rule'] as Map<String, dynamic>;

    final areaId = chore['area_id'] as String?;

    if (recent.isEmpty) {
      final dueDate = computeNextDueDate(recurrenceRule, searchFrom: today);
      final assignedTo = _resolveAssignee(chore, previousAssignee: null);
      await _insertOccurrence(householdId, choreId, dueDate, assignedTo, areaId);
      return;
    }

    final mostRecent = recent.first;
    final isOpen =
        mostRecent['completed_at'] == null && mostRecent['skipped'] == false;
    if (isOpen) {
      return;
    }

    final nextSearchFrom = today.add(const Duration(days: 1));
    final dueDate =
        computeNextDueDate(recurrenceRule, searchFrom: nextSearchFrom);
    final previousAssignee = mostRecent['assigned_to'] as String?;
    final assignedTo =
        _resolveAssignee(chore, previousAssignee: previousAssignee);
    await _insertOccurrence(householdId, choreId, dueDate, assignedTo, areaId);
  }

  static String? _resolveAssignee(
    Map<String, dynamic> chore, {
    required String? previousAssignee,
  }) {
    final strategy = chore['assignment_strategy'] as String;

    if (strategy == 'fixed') {
      return chore['fixed_assignee'] as String?;
    }

    if (strategy == 'anyone') {
      return null;
    }

    final order = (chore['assignee_order'] as List?)?.cast<String>() ?? [];
    if (order.isEmpty) return null;
    if (previousAssignee == null) return order.first;
    final index = order.indexOf(previousAssignee);
    if (index == -1) return order.first;
    return order[(index + 1) % order.length];
  }

  static Future<void> _insertOccurrence(
    String householdId,
    String choreId,
    DateTime dueDate,
    String? assignedTo,
    String? areaId,
  ) async {
    await Supabase.instance.client.from('chore_occurrences').insert({
      'household_id': householdId,
      'chore_id': choreId,
      'due_date': formatDate(dueDate),
      'assigned_to': assignedTo,
      'area_id': areaId,
    });
  }
}
