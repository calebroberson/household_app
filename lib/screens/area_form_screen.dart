import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/area_icons.dart';

class AreaFormScreen extends StatefulWidget {
  final String householdId;
  final Map<String, dynamic>? existingArea;

  const AreaFormScreen({
    super.key,
    required this.householdId,
    this.existingArea,
  });

  @override
  State<AreaFormScreen> createState() => _AreaFormScreenState();
}

class _AreaFormScreenState extends State<AreaFormScreen> {
  final _nameController = TextEditingController();
  String? _selectedIcon;
  String _visibility = 'shared';
  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _isEditing => widget.existingArea != null;

  @override
  void initState() {
    super.initState();
    final area = widget.existingArea;
    if (area != null) {
      _nameController.text = area['name'] as String;
      _selectedIcon = area['icon'] as String?;
      _visibility = area['visibility'] as String;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Enter an area name.');
      return;
    }

    if (!_isEditing && _visibility == 'private') {
      await _createPrivate(name);
      return;
    }

    if (_isEditing) {
      final currentVisibility = widget.existingArea!['visibility'] as String;
      if (currentVisibility == 'shared' && _visibility == 'private') {
        final confirmed = await _confirmSharedToPrivate();
        if (confirmed != true) return;
      }
    }

    await _save(name);
  }

  Future<bool?> _confirmSharedToPrivate() {
    return showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Make this area private?'),
        content: const Text(
            'Other household members will lose access to this area and everything in it. Every chore here must already be assigned to you.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Make Private'),
          ),
        ],
      ),
    );
  }

  Future<void> _createPrivate(String name) async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client.from('areas').insert({
        'household_id': widget.householdId,
        'name': name,
        'icon': _selectedIcon,
        'visibility': 'private',
        'owner_id': userId,
      });
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      setState(() => _errorMessage = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _save(String name) async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final data = <String, dynamic>{
        'name': name,
        'icon': _selectedIcon,
        'visibility': _visibility,
      };

      if (_isEditing) {
        final areaId = widget.existingArea!['id'] as String;
        await Supabase.instance.client
            .from('areas')
            .update(data)
            .eq('id', areaId);
      } else {
        await Supabase.instance.client.from('areas').insert({
          ...data,
          'household_id': widget.householdId,
        });
      }

      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      setState(() => _errorMessage = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _friendlyError(Object error) {
    final message = error.toString();
    if (message.contains('Cannot make area private')) {
      final start = message.indexOf('Cannot make area private');
      return message.substring(start).split('\n').first;
    }
    return 'Could not save this area. Please try again.';
  }

  Future<void> _archive() async {
    final areaId = widget.existingArea!['id'] as String;
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Archive Area?'),
        content: const Text(
            'Chores in this area keep their history but the area will no longer be usable.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await Supabase.instance.client
          .from('areas')
          .update({'archived_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', areaId);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(_isEditing ? 'Edit Area' : 'New Area'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _isSubmitting ? null : _submit,
          child: const Text('Save'),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            CupertinoTextField(
              controller: _nameController,
              placeholder: 'Area name',
              padding: const EdgeInsets.all(12),
            ),
            const SizedBox(height: 24),
            const Text('Icon', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: areaIconKeys.map((key) {
                final selected = _selectedIcon == key;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIcon = key),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: selected
                          ? CupertinoColors.activeBlue
                          : CupertinoColors.systemGrey5,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      areaIconFor(key),
                      color: selected
                          ? CupertinoColors.white
                          : CupertinoColors.label,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            const Text('Visibility',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            CupertinoSlidingSegmentedControl<String>(
              groupValue: _visibility,
              children: const {
                'shared': Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('Shared'),
                ),
                'private': Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('Private'),
                ),
              },
              onValueChanged: (value) {
                if (value != null) setState(() => _visibility = value);
              },
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(color: CupertinoColors.systemRed),
              ),
            ],
            if (_isEditing) ...[
              const SizedBox(height: 32),
              CupertinoButton(
                onPressed: _archive,
                child: const Text(
                  'Archive Area',
                  style: TextStyle(color: CupertinoColors.destructiveRed),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
