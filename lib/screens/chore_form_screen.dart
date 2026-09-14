import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChoreFormScreen extends StatefulWidget {
  final String householdId;

  const ChoreFormScreen({super.key, required this.householdId});

  @override
  State<ChoreFormScreen> createState() => _ChoreFormScreenState();
}

class _ChoreFormScreenState extends State<ChoreFormScreen> {
  final _titleController = TextEditingController();
  String _recurrenceType = 'daily';
  final Set<int> _selectedDays = {};
  String _assignmentStrategy = 'anyone';
  String? _fixedAssigneeId;
  List<Map<String, dynamic>> _members = [];
  bool _isLoadingMembers = true;
  bool _isSubmitting = false;
  String? _errorMessage;

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
    _loadMembers();
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
      final recurrenceRule = _recurrenceType == 'daily'
          ? {'type': 'daily'}
          : {'type': 'weekly', 'days': (_selectedDays.toList()..sort())};

      final userId = Supabase.instance.client.auth.currentUser!.id;
      final data = <String, dynamic>{
        'household_id': widget.householdId,
        'title': title,
        'recurrence_rule': recurrenceRule,
        'assignment_strategy': _assignmentStrategy,
        'created_by': userId,
      };

      if (_assignmentStrategy == 'fixed') {
        data['fixed_assignee'] = _fixedAssigneeId;
      } else if (_assignmentStrategy == 'rotate') {
        data['assignee_order'] =
            _members.map((m) => m['user_id'] as String).toList();
      }

      await Supabase.instance.client.from('chores').insert(data);

      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      setState(
          () => _errorMessage = 'Could not create chore. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('New Chore'),
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
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('Daily'),
                      ),
                      'weekly': Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('Weekly'),
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
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _dayLabels.entries.map((entry) {
                        final selected = _selectedDays.contains(entry.key);
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (selected) {
                                _selectedDays.remove(entry.key);
                              } else {
                                _selectedDays.add(entry.key);
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: selected
                                  ? CupertinoColors.activeBlue
                                  : CupertinoColors.systemGrey5,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              entry.value,
                              style: TextStyle(
                                color: selected
                                    ? CupertinoColors.white
                                    : CupertinoColors.label,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
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
                        onTap: () => setState(
                            () => _fixedAssigneeId = member['user_id'] as String),
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
}
