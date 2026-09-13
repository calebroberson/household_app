import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Household'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Supabase.instance.client.auth.signOut(),
          child: const Text('Sign Out'),
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Text('Signed in as ${user?.email ?? user?.id ?? 'unknown'}'),
        ),
      ),
    );
  }
}
