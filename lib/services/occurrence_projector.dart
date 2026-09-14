import 'occurrence_generator.dart';

/// Read-only, client-side projection of future occurrence dates for the
/// Calendar tab. Never writes anything -- no rows, no side effects. The
/// only real, completable occurrence per chore is still the single row
/// OccurrenceGenerator maintains; this just lets the calendar *see*
/// further ahead than that one row, for planning.
class OccurrenceProjector {
  /// Every date >= [from] and <= [through] that satisfies [recurrenceRule],
  /// reusing the exact same date math OccurrenceGenerator uses for real
  /// generation.
  static List<DateTime> projectDates(
    Map<String, dynamic> recurrenceRule, {
    required DateTime from,
    required DateTime through,
  }) {
    final dates = <DateTime>[];
    var searchFrom = OccurrenceGenerator.dateOnly(from);
    final throughDate = OccurrenceGenerator.dateOnly(through);

    while (!searchFrom.isAfter(throughDate)) {
      final next = OccurrenceGenerator.computeNextDueDate(
        recurrenceRule,
        searchFrom: searchFrom,
      );
      if (next.isAfter(throughDate)) break;
      dates.add(next);
      searchFrom = next.add(const Duration(days: 1));
    }

    return dates;
  }

  /// Projects every active chore forward from the day after its real
  /// occurrence's due date, through [through]. [realDueDates] maps
  /// chore id -> that chore's current real occurrence's due date (as
  /// produced by OccurrenceGenerator). A chore whose real occurrence is
  /// already due after [through] projects to an empty list -- nothing to
  /// show beyond what's already visible as the real row itself.
  ///
  /// If the real occurrence is overdue (due date in the past), projection
  /// starts from today rather than from that stale due date -- otherwise
  /// an overdue chore would appear to "recur" many times between its old
  /// due date and now, when really it's just stuck on one unresolved
  /// cycle. Projecting from today is a deliberate planning assumption
  /// ("if resolved around now, here's roughly what's next"), not a claim
  /// about exactly when it'll actually be completed.
  static Map<String, List<DateTime>> projectForChores(
    List<Map<String, dynamic>> chores, {
    required Map<String, DateTime> realDueDates,
    required DateTime through,
  }) {
    final result = <String, List<DateTime>>{};
    final today = OccurrenceGenerator.dateOnly(DateTime.now());

    for (final chore in chores) {
      final choreId = chore['id'] as String;
      final realDue = realDueDates[choreId];
      if (realDue == null) {
        result[choreId] = [];
        continue;
      }

      final baseline = realDue.isAfter(today) ? realDue : today;
      final projectFrom = baseline.add(const Duration(days: 1));
      if (projectFrom.isAfter(through)) {
        result[choreId] = [];
        continue;
      }

      final rule = chore['recurrence_rule'] as Map<String, dynamic>;
      result[choreId] = projectDates(rule, from: projectFrom, through: through);
    }

    return result;
  }
}
