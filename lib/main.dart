import 'package:flutter/cupertino.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/household_gate.dart';
import 'screens/sign_in_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://bgwzxmgrjzisyifnspyl.supabase.co',
    publishableKey: 'sb_publishable_f3EToKpHPfOM4Cxy_rgnmA_bHfnKIp9',
  );

  await SentryFlutter.init(
    (options) {
      options.dsn =
          'https://1a3bb9e35df02e78b1a3384cf13f23e7@o4512082394349568.ingest.us.sentry.io/4512082400903168';
    },
    appRunner: () => runApp(const HouseholdApp()),
  );
}

class HouseholdApp extends StatelessWidget {
  const HouseholdApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      title: 'Household',
      home: AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          return const HouseholdGate();
        }
        return const SignInScreen();
      },
    );
  }
}
