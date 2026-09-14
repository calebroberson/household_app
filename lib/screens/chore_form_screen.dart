import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/occurrence_generator.dart';

class ChoreFormScreen extends StatefulWidget {
  final String householdId;
  final Map<String, dynamic>? existingChore;

  const ChoreFormScreen({
    super.key,
    required this.householdId,
    this.existingChore,
  });

  @override
  State<ChoreFormScreen> createState() => _ChoreFormScreenState();
}

class _ChoreFormScreenState extends State<ChoreFormScreen> {
  final _titleController = TextEditingController();
  String _recurrenceType = 'daily';
  final Set<int> _selectedDays = {};
  int _everyNWeeksN = 2;
  int _everyNWeeksWeekday = 1;
  String? _everyNWeeksAnchor;
  int _monthlyDayOfMonth = 1;
  String _assignmentStrategy = 'anyone';
  String? _fixedAssigneeId;
  List<Map<String, dynamic>> _members = [];
  bool _isLoadingMembers = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _isEditing => widget.existingChore != null;

  static const _dayLabels = {
    1: 'Mon',
    2: 'Tue',
    3: 'Wed',
    4: 'Thu',
    5: 'Fri',
    6: 'Sat',
    7: 'Sun',
  };

  @override
  void initState() {
    super.initState();
    if (widget.existingChore != null) {
      _loadFromExistingChore(widget.existingChore!);
    }
    _loadMembers();
  }

  void _loadFromExistingChore(Map<String, dynamic> chore) {
    _titleController.text = chore['title'] as String;
    final rule = chore['recurrence_rule'] as Map<String, dynamic>;
    _recurrenceType = rule['type'] as String;

    if (_recurrenceType == 'weekly') {
      _selectedDays.addAll((rule['days'] as List).cast<int>());
    } else if (_recurrenceType == 'every_n_weeks') {
      _everyNWeeksN = rule['n'] as int;
      _everyNWeeksWeekday = rule['weekday'] as int;
      _everyNWeeksAnchor = rule['anchor'] as String;
    } else if (_recurrenceType == 'monthly') {
      _monthlyDayOfMonth = rule['day_of_month'] as int;
    }

    _assignmentStrategy = chore['assignment_strategy'] as String;
    _fixedAssigneeId = chore['fixed_assignee'] as String?;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
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

    setState(() {
      _members = userIds
          .map((userId) => {
                'user_id': userId,
                'display_name': namesById[userId] ?? 'Household member',
              })
          .toList();
      _isLoadingMembers = false;
    });
  }

  Map<String, dynamic> _buildRecurrenceRule() {
    switch (_recurrenceType) {
      case 'daily':
        return {'type': 'daily'};
      case 'weekly':
        return {'type': 'weekly', 'days': (_selectedDays.toList()..sort())};
      case 'every_n_weeks':
        final anchor =
            _everyNWeeksAnchor ?? OccurrenceGenerator.formatDate(DateTime.now());
        return {
          'type': 'every_n_weeks',
          'n': _everyNWeeksN,
          'weekday': _everyNWeeksWeekday,
          'anchor': anchor,
        };
      case 'monthly':
        return {'type': 'monthly', 'day_of_month': _monthlyDayOfMonth};
      default:
        throw StateError('Unknown recurrence type: $_recurrenceType');
    }
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _errorMessage = 'Enter a chore title.');
      return;
    }
    if (_recurrenceType == 'weekly' && _selectedDays.isEmpty) {
      setState(() => _errorMessage = 'Select at least one day.');
      return;
    }
    if (_assignmentStrategy == 'fixed' && _fixedAssigneeId == null) {
      setState(() => _errorMessage = 'Choose who this is assigned to.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final recurrenceRule = _buildRecurrenceRule();
      final data = <String, dynamic>{
        'title': title,
        'recurrence_rule': recurrenceRule,
        'assignment_strategy': _assignmentStrategy,
        'fixed_assignee':
            _assignmentStrategy == 'fixed' ? _fixedAssigneeId : null,
        'assignee_order': _assignmentStrategy == 'rotate'
            ? _members.map((m) => m['user_id'] as String).toList()
            : null,
      };

      if (_isEditing) {
        final choreId = widget.existingChore!['id'] as String;
        await Supabase.instance.client
            .from('chores')
            .update(data)
            .eq('id', choreId);
      } else {
        final userId = Supabase.instance.client.auth.currentUser!.id;
        data['household_id'] = widget.householdId;
        data['created_by'] = userId;
        await Supabase.instance.client.from('chores').insert(data);
      }

      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      setState(
          () => _errorMessage = 'Could not save chore. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(_isEditing ? 'Edit Chore' : 'New Chore'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _isSubmitting ? null : _submit,
          child: const Text('Save'),
        ),
      ),
      child: SafeArea(
        child: _isLoadingMembers
            ? const Center(child: CupertinoActivityIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  CupertinoTextField(
                    controller: _titleController,
                    placeholder: 'Chore title',
                    padding: const EdgeInsets.all(12),
                  ),
                  const SizedBox(height: 24),
                  const Text('Repeats',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  CupertinoSlidingSegmentedControl<String>(
                    groupValue: _recurrenceType,
                    children: const {
                      'daily': Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text('Daily'),
                      ),
                      'weekly': Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text('Weekly'),
                      ),
                      'every_n_weeks': Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text('Every N Wks'),
                      ),
                      'monthly': Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text('Monthly'),
                      ),
                    },
                    onValueChanged: (value) {
                      if (value != null) {
                        setState(() => _recurrenceType = value);
                      }
                    },
                  ),
                  if (_recurrenceType == 'weekly') ...[
                    const SizedBox(height: 12),
                    _buildDayChips(
                      selected: _selectedDays,
                      onToggle: (day) {
                        setState(() {
                          if (_selectedDays.contains(day)) {
                            _selectedDays.remove(day);
                          } else {
                            _selectedDays.add(day);
                          }
                        });
                      },
                    ),
                  ],
                  if (_recurrenceType == 'every_n_weeks') ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('Every'),
                        const SizedBox(width: 8),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => setState(() {
                            if (_everyNWeeksN > 1) _everyNWeeksN--;
                          }),
                          child: const Icon(CupertinoIcons.minus_circle),
                        ),
                        Text('$_everyNWeeksN'),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () =>
                              setState(() => _everyNWeeksN++),
                          child: const Icon(CupertinoIcons.plus_circle),
                        ),
                        const SizedBox(width: 8),
                        const Text('weeks on:'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildDayChips(
                      selected: {_everyNWeeksWeekday},
                      onToggle: (day) {
                        setState(() => _everyNWeeksWeekday = day);
                      },
                    ),
                  ],
                  if (_recurrenceType == 'monthly') ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('Day of month:'),
                        const SizedBox(width: 8),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => setState(() {
                            if (_monthlyDayOfMonth > 1) _monthlyDayOfMonth--;
                          }),
                          child: const Icon(CupertinoIcons.minus_circle),
                        ),
                        Text('$_monthlyDayOfMonth'),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => setState(() {
                            if (_monthlyDayOfMonth < 31) _monthlyDayOfMonth++;
                          }),
                          child: const Icon(CupertinoIcons.plus_circle),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  const Text('Assign to',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  CupertinoSlidingSegmentedControl<String>(
                    groupValue: _assignmentStrategy,
                    children: const {
                      'anyone': Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('Anyone'),
                      ),
                      'rotate': Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('Rotate'),
                      ),
                      'fixed': Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('Fixed'),
                      ),
                    },
                    onValueChanged: (value) {
                      if (value != null) {
                        setState(() => _assignmentStrategy = value);
                      }
                    },
                  ),
                  if (_assignmentStrategy == 'fixed') ...[
                    const SizedBox(height: 12),
                    ..._members.map((member) {
                      final selected = _fixedAssigneeId == member['user_id'];
                      return CupertinoListTile(
                        title: Text(member['display_name'] as String),
                        trailing: selected
                            ? const Icon(CupertinoIcons.checkmark_alt)
                            : null,
                        onTap: () => setState(() =>
                            _fixedAssigneeId = member['user_id'] as String),
                      );
                    }),
                  ],
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: CupertinoColors.systemRed),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildDayChips({
    required Set<int> selected,
    required void Function(int day) onToggle,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _dayLabels.entries.map((entry) {
        final isSelected = selected.contains(entry.key);
        return GestureDetector(
          onTap: () => onToggle(entry.key),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? CupertinoColors.activeBlue
                  : CupertinoColors.systemGrey5,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              entry.value,
              style: TextStyle(
                color: isSelected
                    ? CupertinoColors.white
                    : CupertinoColors.label,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
