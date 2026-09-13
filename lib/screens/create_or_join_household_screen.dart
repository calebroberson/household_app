import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreateOrJoinHouseholdScreen extends StatefulWidget {
  final VoidCallback onSuccess;

  const CreateOrJoinHouseholdScreen({super.key, required this.onSuccess});

  @override
  State<CreateOrJoinHouseholdScreen> createState() =>
      _CreateOrJoinHouseholdScreenState();
}

class _CreateOrJoinHouseholdScreenState
    extends State<CreateOrJoinHouseholdScreen> {
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  Future<void> _createHousehold() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Enter a household name.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await Supabase.instance.client
          .rpc('create_household', params: {'household_name': name});
      widget.onSuccess();
    } catch (error) {
      setState(() => _errorMessage = 'Could not create household. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _joinHousehold() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _errorMessage = 'Enter an invite code.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await Supabase.instance.client
          .rpc('redeem_invite', params: {'invite_code': code});
      widget.onSuccess();
    } catch (error) {
      setState(() => _errorMessage = 'Invalid or expired invite code.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Household')),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Create a household',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            CupertinoTextField(
              controller: _nameController,
              placeholder: 'e.g. The Robersons',
              padding: const EdgeInsets.all(12),
            ),
            const SizedBox(height: 8),
            CupertinoButton.filled(
              onPressed: _isSubmitting ? null : _createHousehold,
              child: const Text('Create'),
            ),
            const SizedBox(height: 32),
            const Text(
              'Or join with an invite code',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            CupertinoTextField(
              controller: _codeController,
              placeholder: 'Invite code',
              textCapitalization: TextCapitalization.characters,
              padding: const EdgeInsets.all(12),
            ),
            const SizedBox(height: 8),
            CupertinoButton(
              onPressed: _isSubmitting ? null : _joinHousehold,
              child: const Text('Join'),
            ),
            if (_isSubmitting) ...[
              const SizedBox(height: 16),
              const Center(child: CupertinoActivityIndicator()),
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
