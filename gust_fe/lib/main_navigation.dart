import 'package:flutter/material.dart';
import 'home_page.dart';
import 'analytics_page.dart'; // Make sure this file exists and exports AnalyticsPage


class MainNavigation extends StatefulWidget {
  const MainNavigation({Key? key}) : super(key: key);

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0; // 0 = Home, 1 = Register, 2 = Analytics

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_currentIndex == 0) {
      body = HomePage(logs: const []); // pass logs or fetch inside HomePage
    } else if (_currentIndex == 1) {
      // You could open a dialog or show a register page here if you want
      body = HomePage(logs: const []); // Or some other widget for "Register"
    } else {
      body = AnalyticsPage(logs: const []);
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (int idx) {
          setState(() {
            _currentIndex = idx;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline), label: 'Register'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Analytics'),
        ],
      ),
    );
  }
}
