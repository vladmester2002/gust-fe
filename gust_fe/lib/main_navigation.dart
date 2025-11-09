import 'package:flutter/material.dart';
import 'home_page.dart';
import 'analytics_page.dart';
import 'profile_page.dart';
import 'community_page.dart'; // <-- NEW!
import 'sugar_log.dart';
import 'sugar_log_creation_dialog.dart';

class MainNavigation extends StatefulWidget {
  final List<SugarLog> logs;
  const MainNavigation({Key? key, required this.logs}) : super(key: key);

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  late List<SugarLog> _logs;

  @override
  void initState() {
    super.initState();
    _logs = List.from(widget.logs);
  }

  void _showRegisterModal() {
    showDialog(
      context: context,
      builder: (context) => SugarLogCreationDialog(
        onCreated: (log) {
          setState(() {
            _logs.add(log);
          });
        },
      ),
    );
  }

  void _onNavTap(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 4 pages: Home, Analytics, Community, Profile
    final pages = [
      HomePage(logs: _logs),
      AnalyticsPage(logs: _logs),
      CommunityPage(), // <-- Add Community Page
      ProfilePage(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showRegisterModal,
        child: const Icon(Icons.add),
        tooltip: "Register Sugar Intake",
        shape: const CircleBorder(),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Home
            Expanded(
              child: MaterialButton(
                minWidth: 40,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                onPressed: () => _onNavTap(0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.home,
                        size: 22,
                        color: _currentIndex == 0
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey),
                    const SizedBox(height: 2),
                    Text(
                      'Home',
                      style: TextStyle(
                        fontSize: 11,
                        color: _currentIndex == 0
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Analytics
            Expanded(
              child: MaterialButton(
                minWidth: 40,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                onPressed: () => _onNavTap(1),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bar_chart,
                        size: 22,
                        color: _currentIndex == 1
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey),
                    const SizedBox(height: 2),
                    Text(
                      'Analytics',
                      style: TextStyle(
                        fontSize: 11,
                        color: _currentIndex == 1
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Spacer for FAB
            const SizedBox(width: 48),
            // Community
            Expanded(
              child: MaterialButton(
                minWidth: 40,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                onPressed: () => _onNavTap(2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.emoji_events,
                        size: 22,
                        color: _currentIndex == 2
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey),
                    const SizedBox(height: 2),
                    Text(
                      'Community',
                      style: TextStyle(
                        fontSize: 11,
                        color: _currentIndex == 2
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Profile
            Expanded(
              child: MaterialButton(
                minWidth: 40,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                onPressed: () => _onNavTap(3),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person,
                        size: 22,
                        color: _currentIndex == 3
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey),
                    const SizedBox(height: 2),
                    Text(
                      'Profile',
                      style: TextStyle(
                        fontSize: 11,
                        color: _currentIndex == 3
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
