import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 1; // Register tab as default

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });

    if (index == 1) {
      _showRegisterModal();
    } else if (index == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile coming soon")),
      );
    } else if (index == 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Settings coming soon")),
      );
    }
  }

void _showRegisterModal() {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      final theme = Theme.of(context);
      bool isManual = false;
      final TextEditingController _descriptionController = TextEditingController();
      final TextEditingController _sugarAmountController = TextEditingController();

      return StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isManual ? 'Log Sugar Manually' : 'Register Sugar Intake',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 20),

                if (!isManual) ...[
                  ElevatedButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text('Log Sugar Manually'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: theme.colorScheme.primary,
                    ),
                    onPressed: () => setState(() => isManual = true),
                  ),
                  const SizedBox(height: 4),
                  const Text('Manually input what you consumed and sugar amount.', style: TextStyle(fontSize: 12)),

                  const SizedBox(height: 16),

                  ElevatedButton.icon(
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan Product Barcode'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: theme.colorScheme.secondary,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Barcode scanner coming soon")),
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  const Text('Scan a barcode to auto-log sugar info.', style: TextStyle(fontSize: 12)),
                ],

                if (isManual) ...[
                  TextField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(labelText: 'Food Description'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _sugarAmountController,
                    decoration: const InputDecoration(labelText: 'Sugar Amount (grams)'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check),
                    label: const Text('Save'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: theme.colorScheme.primary,
                    ),
                    onPressed: () {
                      final desc = _descriptionController.text.trim();
                      final sugar = _sugarAmountController.text.trim();

                      if (desc.isEmpty || sugar.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Please fill all fields")),
                        );
                        return;
                      }

                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Saved')),
                      );

                    },
                  ),
                ],
              ],
            ),
          );
        },
      );
    },
  );
}


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.inversePrimary,
        title: const Text('GUST Dashboard'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // User greeting
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
                  child: Icon(Icons.person, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Welcome back,', style: theme.textTheme.bodySmall),
                    Text('GUST User', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                )
              ],
            ),
            const SizedBox(height: 24),

            // Sugar intake card
            _buildCard(
              theme,
              title: 'Daily Sugar Intake',
              content: const Text('Summary: 50g / 75g (Goal)'),
              icon: Icons.coffee,
            ),
            const SizedBox(height: 16),

            // Coach tip
            _buildCard(
              theme,
              title: 'AI Coach Tip',
              content: const Text('Try swapping sugary drinks with water.'),
              icon: Icons.lightbulb_outline,
            ),
            const SizedBox(height: 16),

            // Daily goal
            _buildCard(
              theme,
              title: 'Daily Goal Tracker',
              content: const Text('Goal: Reduce sugar intake by 10g'),
              icon: Icons.flag,
            ),
            const SizedBox(height: 16),

            // Quick scan placeholder
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Quick Scan Pressed')),
                );
              },
              child: _buildCard(
                theme,
                title: 'Quick Scan',
                content: const Text('Scan a food label to track sugar', textAlign: TextAlign.center),
                icon: Icons.qr_code_scanner,
                centerContent: true,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: theme.colorScheme.surface,
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: theme.colorScheme.outline,
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline), label: 'Register'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }

  Widget _buildCard(
    ThemeData theme, {
    required String title,
    required Widget content,
    required IconData icon,
    bool centerContent = false,
  }) {
    return Card(
      elevation: 4.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: centerContent
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(icon, size: 48, color: theme.colorScheme.primary),
                  const SizedBox(height: 8),
                  Text(title, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  content,
                ],
              )
            : Row(
                children: [
                  Icon(icon, size: 40, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.textTheme.titleMedium),
                        const SizedBox(height: 4),
                        content,
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
