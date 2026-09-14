import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Bridges the native iOS push-registration flow
/// (ios/Runner/AppDelegate.swift, MethodChannel 'household_app/push') to
/// Dart, and upserts the resulting APNs device token into
/// `device_tokens`. No Firebase/FCM -- this app registers for raw APNs
/// directly, per CLAUDE.md's "APNs via Supabase Edge Function" design.
class PushRegistration {
  static const _channel = MethodChannel('household_app/push');
  static const _softAskShownKey = 'push_soft_ask_shown';

  /// Shows a one-time, plain-language explanation before the native OS
  /// permission prompt (which can only be shown meaningfully once), then
  /// requests authorization and wires up the token -> `device_tokens`
  /// upsert. Safe to call on every app launch: the native
  /// `requestAuthorization` call is idempotent once the user has already
  /// decided (iOS won't re-show its own prompt), so only the in-app soft
  /// ask itself is gated to "once ever" via shared_preferences.
  static Future<void> registerForPushNotifications({
    required BuildContext context,
    required String householdId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyAsked = prefs.getBool(_softAskShownKey) ?? false;

    if (!alreadyAsked) {
      if (!context.mounted) return;
      final allow = await _showSoftAsk(context);
      await prefs.setBool(_softAskShownKey, true);
      if (allow != true) return;
    }

    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onToken':
          await _saveToken(call.arguments as String, householdId);
          break;
        case 'onRegistrationError':
          // Non-fatal -- no device token registered this launch.
          break;
      }
    });

    await _channel.invokeMethod<bool>('requestAuthorization');
  }

  static Future<bool?> _showSoftAsk(BuildContext context) {
    return showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Morning Reminder'),
        content: const Text(
          "Get a notification each morning with what's due today?",
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not Now'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Allow'),
          ),
        ],
      ),
    );
  }

  static Future<void> _saveToken(String token, String householdId) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    await Supabase.instance.client.from('device_tokens').upsert(
      {
        'user_id': userId,
        'household_id': householdId,
        'token': token,
        'platform': 'ios',
        'last_seen_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'token',
    );
  }
}
