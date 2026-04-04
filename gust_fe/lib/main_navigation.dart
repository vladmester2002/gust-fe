import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'home_page.dart';
import 'analytics_page.dart';
import 'profile_page.dart';
import 'community_page.dart';
import 'sugar_log.dart';
import 'sugar_log_creation_dialog.dart';
import 'services/biometric_auth_service.dart';
import 'widgets/biometric_setup_modal.dart';
import 'utils/notification_helper.dart';
import 'repositories/sugar_log_repository.dart';
import 'data/models/local_sugar_log.dart';
import 'state/auth_state.dart';
import 'admin_console_page.dart';
import 'emotion.dart';
import 'state/home_view_model.dart';

class MainNavigation extends StatefulWidget {
  final List<SugarLog> logs;
  final int initialIndex;
  const MainNavigation({
    super.key,
    required this.logs,
    this.initialIndex = 0,
  });

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  late int _currentIndex;
  late List<SugarLog> _logs;
  final BiometricAuthService _biometricService = BiometricAuthService();
  int _profilePageKey = 0;
  final SugarLogRepository _logRepository = SugarLogRepository();
  StreamSubscription<List<LocalSugarLog>>? _logSubscription;
  int? _activeUserId;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex < 0 ? 0 : widget.initialIndex;
    _logs = List.from(widget.logs);
    _checkAndShowBiometricPrompt();
  }

  @override
  void didUpdateWidget(covariant MainNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex) {
      _currentIndex = widget.initialIndex < 0 ? 0 : widget.initialIndex;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userId = context.watch<AuthState>().currentUser?.id;
    if (userId != null && userId != _activeUserId) {
      _activeUserId = userId;
      _subscribeToLogs(userId);
    }
  }

  Future<void> _checkAndShowBiometricPrompt() async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    final isAvailable = await _biometricService.isBiometricAvailable();
    if (!isAvailable) return;

    final wasPromptShown = await _biometricService.wasBiometricPromptShown();
    if (wasPromptShown) return;

    final biometrics = await _biometricService.getAvailableBiometrics();
    final biometricType = _biometricService.getBiometricTypeName(biometrics);

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BiometricSetupModal(
        biometricType: biometricType,
        onEnable: () async {
          Navigator.of(context).pop();
          await _enableBiometric();
        },
        onSkip: () async {
          Navigator.of(context).pop();
          await _biometricService.markBiometricPromptShown();
        },
      ),
    );
  }

  Future<void> _enableBiometric() async {
    final authenticated = await _biometricService.authenticate(
      reason: 'Authenticate to enable biometric login',
    );

    if (authenticated) {
      await _biometricService.enableBiometric();
      setState(() {
        _profilePageKey++;
      });
      if (!mounted) return;
      await NotificationHelper.showSuccess(
        context,
        'Biometric authentication enabled successfully!',
      );
    } else {
      await _biometricService.markBiometricPromptShown();
      if (!mounted) return;
      await NotificationHelper.showWarning(
        context,
        'Biometric authentication failed. You can enable it later from your profile.',
      );
    }
  }

  void _subscribeToLogs(int userId) {
    _logSubscription?.cancel();
    _logSubscription =
        _logRepository.watchLogs(userId).listen((localLogs) {
      final mapped = localLogs.map(_mapToUiLog).toList();
      if (mounted) {
        setState(() {
          _logs = mapped;
        });
      }
    });
  }

  SugarLog _mapToUiLog(LocalSugarLog log) {
    final emotionName = log.emotion;
    final emotion = Emotion.values.firstWhere(
      (e) => e.name == emotionName.toUpperCase(),
      orElse: () => Emotion.NEUTRAL,
    );
    return SugarLog(
      id: log.id ?? log.remoteId ?? log.hashCode,
      sugarGrams: log.sugarGrams,
      date: log.date,
      hour: log.hour,
      minute: log.minute,
      productName: log.productName ?? '',
      sugarType: log.sugarType ?? '',
      contextNote: log.contextNote ?? '',
      emotion: emotion,
      location: log.location ?? '',
      wasCraving: log.wasCraving,
      visibility: log.visibility,
    );
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
  void dispose() {
    _logSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthState>();
    final role = authState.currentUser?.role ?? 'USER';
    final canLogSugar = authState.featureFlags.contains('sugar_logs');

    if (role == 'ADMIN') {
      return const Scaffold(
        body: AdminConsolePage(),
      );
    }

    final tabs = <_NavTab>[
      _NavTab(
        label: 'Home',
        icon: Icons.home,
        page: HomePage(logs: _logs),
      ),
      _NavTab(
        label: 'Analytics',
        icon: Icons.bar_chart,
        page: AnalyticsPage(logs: _logs),
      ),
      const _NavTab(
        label: 'Community',
        icon: Icons.emoji_events,
        page: CommunityPage(),
      ),
      _NavTab(
        label: 'Profile',
        icon: Icons.person,
        page: ProfilePage(key: ValueKey(_profilePageKey)),
      ),
    ];

    var currentIndex = _currentIndex;
    final maxIndex = tabs.length - 1;
    if (currentIndex > maxIndex) {
      currentIndex = maxIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _currentIndex = currentIndex;
          });
        }
      });
    }

    final notchIndex =
        canLogSugar ? (tabs.length / 2).floor() : null;

    final navChildren = <Widget>[];
    for (var i = 0; i < tabs.length; i++) {
      if (notchIndex != null && i == notchIndex) {
        navChildren.add(const SizedBox(width: 48));
      }
      final tab = tabs[i];
      final isActive = currentIndex == i;
      final color = isActive
          ? Theme.of(context).colorScheme.primary
          : Colors.grey;
      navChildren.add(
        Expanded(
          child: MaterialButton(
            minWidth: 40,
            padding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            onPressed: () => _onNavTap(i),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(tab.icon, size: 22, color: color),
                const SizedBox(height: 2),
                Text(
                  tab.label,
                  style: TextStyle(fontSize: 11, color: color),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ChangeNotifierProvider(
      create: (_) => HomeViewModel(
        seedLogs: _logs,
      )..initialize(),
      child: Scaffold(
        body: IndexedStack(
          index: currentIndex,
          children: tabs.map((tab) => tab.page).toList(),
        ),
        floatingActionButton: canLogSugar
            ? FloatingActionButton(
                onPressed: _showRegisterModal,
                tooltip: "Register Sugar Intake",
                shape: const CircleBorder(),
                child: const Icon(Icons.add),
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 8,
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: navChildren),
        ),
      ),
    );
  }
}

class _NavTab {
  final String label;
  final IconData icon;
  final Widget page;
  const _NavTab({required this.label, required this.icon, required this.page});
}
