import 'package:flutter/material.dart';
import 'home_page.dart';      // Your dashboard/home
import 'analytics_page.dart'; // Your analytics page
import 'SugarLog.dart';      // Your SugarLog model
import 'sugar_log_creation_dialog.dart'; // For the register dialog

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key, required this.logs});
  final List<SugarLog> logs;

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0; // 0 = Home, 1 = Analytics
  late List<SugarLog> _logs;

  // This key will force AnalyticsPage to rebuild every time it's changed
  Key _analyticsKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _logs = widget.logs;
  }

  void _showRegisterModal() {
    showDialog(
      context: context,
      builder: (context) => SugarLogCreationDialog(
        onCreated: (log) {
          setState(() {
            _logs.add(log);
            // If user adds a log, also refresh Analytics next time it's opened:
            _analyticsKey = UniqueKey();
          });
        },
      ),
    );
  }

  void _onNavTap(int index) {
    setState(() {
      if (index == 1) {
        // Always generate a new key for Analytics so it refreshes every time
        _analyticsKey = UniqueKey();
      }
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _currentIndex == 0
          ? HomePage(logs: _logs)
          : AnalyticsPage(key: _analyticsKey, logs: _logs),
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            MaterialButton(
              minWidth: 40,
              onPressed: () => _onNavTap(0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.home,
                    color: _currentIndex == 0
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                  ),
                  Text(
                    'Home',
                    style: TextStyle(
                      color: _currentIndex == 0
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            MaterialButton(
              minWidth: 40,
              onPressed: () => _onNavTap(1),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bar_chart,
                    color: _currentIndex == 1
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                  ),
                  Text(
                    'Analytics',
                    style: TextStyle(
                      color: _currentIndex == 1
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
