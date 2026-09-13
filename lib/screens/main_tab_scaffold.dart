import 'package:flutter/cupertino.dart';

import 'home_screen.dart';
import 'lists_screen.dart';

class MainTabScaffold extends StatelessWidget {
  final String householdId;

  const MainTabScaffold({super.key, required this.householdId});

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.house_fill),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.list_bullet),
            label: 'Lists',
          ),
        ],
      ),
      tabBuilder: (context, index) {
        if (index == 0) {
          return HomeScreen(householdId: householdId);
        }
        return ListsScreen(householdId: householdId);
      },
    );
  }
}
