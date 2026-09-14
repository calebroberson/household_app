import 'package:flutter/cupertino.dart';

import 'home_screen.dart';
import 'lists_screen.dart';
import 'today_screen.dart';

class MainTabScaffold extends StatelessWidget {
  final String householdId;

  const MainTabScaffold({super.key, required this.householdId});

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.checkmark_circle),
            label: 'Today',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.list_bullet),
            label: 'Lists',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.house_fill),
            label: 'Household',
          ),
        ],
      ),
      tabBuilder: (context, index) {
        switch (index) {
          case 0:
            return TodayScreen(householdId: householdId);
          case 1:
            return ListsScreen(householdId: householdId);
          default:
            return HomeScreen(householdId: householdId);
        }
      },
    );
  }
}
