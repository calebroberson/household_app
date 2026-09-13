import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://bgwzxmgrjzisyifnspyl.supabase.co',
    anonKey: 'sb_publishable_f3EToKpHPfOM4Cxy_rgnmA_bHfnKIp9',
  );

  runApp(const HouseholdApp());
}

class HouseholdApp extends StatelessWidget {
  const HouseholdApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      title: 'Household',
      home: CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Text('Household'),
        ),
        child: Center(
          child: Text('Welcome to Household'),
        ),
      ),
    );
  }
}
