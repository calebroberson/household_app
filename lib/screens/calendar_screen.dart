import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/occurrence_generator.dart';
import '../services/occurrence_projector.dart';
import '../widgets/area_grouped_chore_list.dart';

class CalendarScreen extends StatefulWidget {
  final String householdId;

  const CalendarScreen({super.key, required this.householdId});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  static const _pageMidpoint = 1200;
  static const _mineFilterPrefsKey = 'calendar_show_mine';

  late final PageController _pageController;
  late DateTime _anchorMonth;
  late DateTime _visibleMonth;
  late DateTime _selectedDay;
  bool _showMine = false;
  late Future<void> _readyFuture;

  List<Map<String, dynamic>> _chores = [];
  Map<String, String> _choreTitles = {};
  Map<String, String> _memberNames = {};
  Map<String, Map<String, dynamic>> _areasById = {};
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _anchorMonth = DateTime(now.year, now.month, 1);
    _visibleMonth = _anchorMonth;
    _selectedDay = OccurrenceGenerator.dateOnly(now);
    _pageController = PageController(initialPage: _pageMidpoint);
    _currentUserId = Supabase.instance.client.auth.currentUser?.id;
    _readyFuture = _prepare();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _prepare() async {
    await OccurrenceGenerator.ensureOccurrencesForHousehold(widget.householdId);
    await _loadPreferences();
    await _loadLookups();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getBool(_mineFilterPrefsKey);
    if (stored != null && mounted) {
      setState(() => _showMine = stored);
    }
  }

  Future<void> _setShowMine(bool value) async {
    setState(() => _showMine = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_mineFilterPrefsKey, value);
  }

  Future<void> _loadLookups() async {
    final choreRows = await Supabase.instance.client
        .from('chores')
        .select(
            'id, title, area_id, recurrence_rule, assignment_strategy, fixed_assignee')
        .eq('household_id', widget.householdId)
        .eq('active', true);

    final memberRows = await Supabase.instance.client
        .from('household_members')
        .select('user_id')
        .eq('household_id', widget.householdId)
        .order('joined_at');

    final userIds = memberRows.map((row) => row['user_id'] as String).toList();

    final profileRows = userIds.isEmpty
        ? <Map<String, dynamic>>[]
        : await Supabase.instance.client
            .from('profiles')
            .select('id, display_name')
            .inFilter('id', userIds);

    final namesById = {
      for (final row in profileRows)
        row['id'] as String: row['display_name'] as String?,
    };

    final areaRows = await Supabase.instance.client
        .from('areas')
        .select('id, name, sort_order, visibility')
        .eq('household_id', widget.householdId);

    if (!mounted) return;
    setState(() {
      _chores = List<Map<String, dynamic>>.from(choreRows);
      _choreTitles = {
        for (final row in choreRows) row['id'] as String: row['title'] as String,
      };
      _memberNames = {
        for (final userId in userIds) userId: namesById[userId] ?? 'Household member',
      };
      _areasById = {
        for (final row in areaRows) row['id'] as String: row,
      };
    });
  }

  bool _isMine(
    Map<String, dynamic> chore, {
    String? realAssignedTo,
    required bool isProjected,
  }) {
    final strategy = chore['assignment_strategy'] as String;
    if (strategy == 'anyone') return true;
    if (strategy == 'fixed') return chore['fixed_assignee'] == _currentUserId;
    // rotate: only the real occurrence's current assignee counts as
    // "mine" -- no forward-projection of whose turn is next.
    if (isProjected) return false;
    return realAssignedTo == _currentUserId;
  }

  String _formatShortDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  /// Merges real occurrences (this month) with read-only projections
  /// beyond each chore's real occurrence, keyed by day. Projected rows
  /// carry the real occurrence's own id/fields plus a "Next due" subtitle
  /// -- tapping one always completes the one real occurrence, never
  /// creates anything.
  Map<DateTime, List<Map<String, dynamic>>> _buildMonthData(
    List<Map<String, dynamic>> allOccurrences,
  ) {
    final monthStart = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final daysInMonth =
        DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    final monthEnd =
        DateTime(_visibleMonth.year, _visibleMonth.month, daysInMonth);

    final result = <DateTime, List<Map<String, dynamic>>>{};
    final choresById = {for (final c in _chores) c['id'] as String: c};
    final openDueDates = <String, DateTime>{};
    final openRowByChoreId = <String, Map<String, dynamic>>{};

    for (final row in allOccurrences) {
      final choreId = row['chore_id'] as String?;
      if (choreId == null || !choresById.containsKey(choreId)) continue;
      final chore = choresById[choreId]!;
      final completed = row['completed_at'] != null;
      final skipped = row['skipped'] == true;
      final assignedTo = row['assigned_to'] as String?;
      final due =
          OccurrenceGenerator.dateOnly(DateTime.parse(row['due_date'] as String));

      if (!completed && !skipped) {
        openDueDates[choreId] = due;
        openRowByChoreId[choreId] = row;
      }

      if (_showMine &&
          !_isMine(chore, realAssignedTo: assignedTo, isProjected: false)) {
        continue;
      }
      if (due.isBefore(monthStart) || due.isAfter(monthEnd)) continue;
      result.putIfAbsent(due, () => []).add(row);
    }

    final projections = OccurrenceProjector.projectForChores(
      _chores,
      realDueDates: openDueDates,
      through: monthEnd,
    );

    for (final chore in _chores) {
      final choreId = chore['id'] as String;
      final dates = projections[choreId] ?? [];
      if (dates.isEmpty) continue;
      if (_showMine && !_isMine(chore, isProjected: true)) continue;

      final realRow = openRowByChoreId[choreId];
      final realDue = openDueDates[choreId];
      if (realRow == null || realDue == null) continue;

      final subtitle = 'Next due: ${_formatShortDate(realDue)}';

      for (final date in dates) {
        if (date.isBefore(monthStart) || date.isAfter(monthEnd)) continue;
        result.putIfAbsent(date, () => []).add({
          ...realRow,
          'subtitle': subtitle,
        });
      }
    }

    return result;
  }

  DateTime _monthForPage(int page) {
    final offset = page - _pageMidpoint;
    return DateTime(_anchorMonth.year, _anchorMonth.month + offset, 1);
  }

  void _goToToday() {
    _pageController.animateToPage(
      _pageMidpoint,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
    setState(() {
      _visibleMonth = _anchorMonth;
      _selectedDay = OccurrenceGenerator.dateOnly(DateTime.now());
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Calendar'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _goToToday,
          child: const Text('Today'),
        ),
      ),
      child: SafeArea(
        child: FutureBuilder<void>(
          future: _readyFuture,
          builder: (context, readySnapshot) {
            if (readySnapshot.connectionState != ConnectionState.done) {
              return const Center(child: CupertinoActivityIndicator());
            }

            final occurrencesStream = Supabase.instance.client
                .from('chore_occurrences')
                .stream(primaryKey: ['id']).eq(
                    'household_id', widget.householdId);

            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: occurrencesStream,
              builder: (context, snapshot) {
                final monthData = snapshot.hasData
                    ? _buildMonthData(snapshot.data!)
                    : <DateTime, List<Map<String, dynamic>>>{};

                return Column(
                  children: [
                    _buildMineEveryoneToggle(),
                    SizedBox(
                      height: 320,
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: (page) {
                          final month = _monthForPage(page);
                          setState(() {
                            _visibleMonth = month;
                            _selectedDay =
                                DateTime(month.year, month.month, 1);
                          });
                        },
                        itemBuilder: (context, page) {
                          final month = _monthForPage(page);
                          final isCurrentPage =
                              month.year == _visibleMonth.year &&
                                  month.month == _visibleMonth.month;
                          return _MonthGrid(
                            month: month,
                            selectedDay: _selectedDay,
                            dayRows: isCurrentPage
                                ? monthData
                                : const <DateTime, List<Map<String, dynamic>>>{},
                            onDaySelected: (day) =>
                                setState(() => _selectedDay = day),
                          );
                        },
                      ),
                    ),
                    Container(height: 1, color: CupertinoColors.separator),
                    Expanded(
                      child: !snapshot.hasData
                          ? const Center(child: CupertinoActivityIndicator())
                          : _buildDayDetail(monthData),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildMineEveryoneToggle() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: CupertinoSlidingSegmentedControl<bool>(
        groupValue: _showMine,
        children: const {
          false: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('Everyone'),
          ),
          true: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('Mine'),
          ),
        },
        onValueChanged: (value) {
          if (value != null) _setShowMine(value);
        },
      ),
    );
  }

  Widget _buildDayDetail(Map<DateTime, List<Map<String, dynamic>>> monthData) {
    final rows = monthData[_selectedDay] ?? [];

    if (rows.isEmpty) {
      return const Center(child: Text('Nothing due.'));
    }

    return ListView(
      children: [
        CupertinoListSection.insetGrouped(
          children: buildAreaGroupedChildren(
            context: context,
            rows: rows,
            areasById: _areasById,
            choreTitles: _choreTitles,
            memberNames: _memberNames,
            householdId: widget.householdId,
          ),
        ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  final DateTime month;
  final DateTime selectedDay;
  final Map<DateTime, List<Map<String, dynamic>>> dayRows;
  final void Function(DateTime day) onDaySelected;

  const _MonthGrid({
    required this.month,
    required this.selectedDay,
    required this.dayRows,
    required this.onDaySelected,
  });

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingBlanks = firstOfMonth.weekday % 7; // Sunday-first grid
    final today = OccurrenceGenerator.dateOnly(DateTime.now());

    final cells = <DateTime?>[
      ...List.filled(leadingBlanks, null),
      for (var d = 1; d <= daysInMonth; d++)
        DateTime(month.year, month.month, d),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '${_monthNames[month.month - 1]} ${month.year}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        Row(
          children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
              .map((d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: const TextStyle(
                          fontSize: 12,
                          color: CupertinoColors.secondaryLabel,
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        Expanded(
          child: GridView.count(
            crossAxisCount: 7,
            physics: const NeverScrollableScrollPhysics(),
            children: cells.map((day) {
              if (day == null) return const SizedBox.shrink();
              final count = dayRows[day]?.length ?? 0;
              final isToday = day == today;
              final isSelected = day == selectedDay;
              return GestureDetector(
                onTap: () => onDaySelected(day),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? CupertinoColors.activeBlue
                        : (isToday ? CupertinoColors.systemGrey5 : null),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${day.day}',
                        style: TextStyle(
                          color: isSelected
                              ? CupertinoColors.white
                              : CupertinoColors.label,
                        ),
                      ),
                      if (count > 0)
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? CupertinoColors.white
                                : CupertinoColors.activeBlue,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$count',
                            style: TextStyle(
                              fontSize: 10,
                              color: isSelected
                                  ? CupertinoColors.activeBlue
                                  : CupertinoColors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
