import 'package:flutter/material.dart';
import 'home_page.dart';      // Make sure this points to your dashboard/home
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

  // Optionally, you can store logs in this widget and pass to children if needed
  late List<SugarLog> _logs;

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
          });
          // Optionally: you may want to update Home/Analytics with new data
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _currentIndex == 0
          ? HomePage(logs: _logs)
          : AnalyticsPage(logs: _logs),
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
              onPressed: () {
                setState(() => _currentIndex = 0);
              },
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
              onPressed: () {
                setState(() => _currentIndex = 1);
              },
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
