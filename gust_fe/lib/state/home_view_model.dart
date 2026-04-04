import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../constants.dart';
import '../data/models/local_sugar_log.dart';
import '../data/models/local_user.dart';
import '../data/models/sugar_log_event.dart';
import '../repositories/auth_repository.dart';
import '../repositories/sugar_log_repository.dart';
import '../repositories/user_profile_repository.dart';
import '../services/api_service.dart';
import '../services/auth_helper.dart';
import '../services/connectivity_service.dart';
import '../services/sugar_log_stream_service.dart';
import '../services/sync_service.dart';
import '../sugar_log.dart';
import '../emotion.dart';

class HomeViewModel extends ChangeNotifier {
  HomeViewModel({
    AuthRepository? authRepository,
    SugarLogRepository? sugarLogRepository,
    UserProfileRepository? profileRepository,
    SugarLogStreamService? streamService,
    List<SugarLog>? seedLogs,
  })  : _authRepository = authRepository ?? AuthRepository(),
        _logRepository = sugarLogRepository ?? SugarLogRepository(),
        _profileRepository = profileRepository ?? UserProfileRepository(),
        _streamService = streamService ?? SugarLogStreamService(),
        _logs = List<SugarLog>.from(seedLogs ?? const []);

  final AuthRepository _authRepository;
  final SugarLogRepository _logRepository;
  final UserProfileRepository _profileRepository;
  final SugarLogStreamService _streamService;

  LocalUser? _currentUser;
  StreamSubscription<List<LocalSugarLog>>? _localLogsSub;
  StreamSubscription<SugarLogEvent>? _remoteStreamSub;
  StreamSubscription<bool>? _syncSub;
  StreamSubscription<bool>? _offlineSub;
  StreamSubscription<bool>? _connectivitySub;

  List<SugarLog> _logs;
  bool _loading = true;
  bool _refreshing = false;
  bool _syncing = false;
  bool _offline = false;
  bool _isGuest = false;
  String? _error;
  String? _syncMessage;
  String? _fullName;
  int _dailyGoal = 75;
  int _streak = 0;

  List<SugarLog> get logs => _logs;
  bool get isLoading => _loading;
  bool get isRefreshing => _refreshing;
  bool get isSyncing => _syncing;
  bool get isOffline => _offline;
  bool get isGuestMode => _isGuest;
  String? get errorMessage => _error;
  String? get syncMessage => _syncMessage;
  String get fullName => _fullName ?? 'User';
  int get dailyGoal => _dailyGoal;
  int get streak => _streak;

  void clearSyncMessage() {
    _syncMessage = null;
    notifyListeners();
  }

  Future<void> initialize() async {
    await _bootstrap();
  }

  Future<void> refreshAll() async {
    _refreshing = true;
    notifyListeners();
    await Future.wait([
      _loadUserProfile(),
      _loadUserStreak(),
      _syncRemoteLogs(),
    ]);
    _refreshing = false;
    notifyListeners();
  }

  Future<void> _bootstrap() async {
    try {
      _isGuest = await AuthHelper.isGuestSession();
      _currentUser = await _authRepository.getActiveUser();
      await _subscribeToLocalLogs();
      await _loadUserProfile();
      await _loadUserStreak();
      await _loadUserProfile();
      await _loadUserStreak();
      if (!_isGuest) {
        // Just fetch logs, the repository handles the sync logic (Fetch -> Cache)
        // We don't need to manually call API here.
        // However, fetchLogs returns a list, but we are subscribing to the stream.
        // So we just trigger a fetch to update the cache.
        await _logRepository.fetchLogs(userId: _currentUser!.id!);
        await _startStreamSafely();
        
        // Listen to sync status
        _syncSub = SyncService.instance.isSyncing.listen((status) {
          _syncing = status;
          notifyListeners();
        });

        // Listen to offline status
        _offlineSub = ApiService.instance.isOffline.listen((status) {
          if (_offline != status) {
            _offline = status;
            notifyListeners();
          }
        });

        // Listen to connectivity restoration
        ConnectivityService.instance.startMonitoring();
        _connectivitySub = ConnectivityService.instance.onConnectivityRestored.listen((_) {
          print('Connectivity restored, refreshing data...');
          refreshAll();
        });
      }
    } catch (error) {
      _error ??= 'Failed to load dashboard';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _subscribeToLocalLogs() async {
    _localLogsSub?.cancel();
    final userId = _currentUser?.id;
    if (userId == null) {
      return;
    }
    _localLogsSub = _logRepository.watchLogs(userId).listen((entries) {
      _logs = entries.map(_mapLocalLog).toList();
      notifyListeners();
    });
  }

  Future<void> _loadUserProfile() async {
    if (_isGuest) {
      _fullName = _currentUser?.fullName ?? 'Guest User';
      _dailyGoal = _currentUser?.dailySugarGoal ?? _dailyGoal;
      return;
    }
    if (_currentUser?.id == null) return;

    try {
      final profile = await _profileRepository.fetchProfile(_currentUser!.id!);
      if (profile != null) {
        _fullName = profile.fullName;
        _dailyGoal = profile.dailySugarGoal;
        _error = null;
      }
    } catch (error) {
      _error = 'Unable to load profile';
    }
  }

  Future<void> _loadUserStreak() async {
    if (_isGuest) {
      await _computeLocalStreak();
      return;
    }
    if (_currentUser?.id == null) return;

    try {
      _streak = await _profileRepository.fetchStreak(_currentUser!.id!);
      _error = null;
    } catch (error) {
      _error = 'Unable to load streak';
    }
  }

  Future<void> _computeLocalStreak() async {
    final user = _currentUser;
    if (user?.id == null) return;
    final entries = await _logRepository.fetchLogs(userId: user!.id!);
    _streak = _calculateStreak(entries);
  }

  int _calculateStreak(List<LocalSugarLog> logs) {
    if (logs.isEmpty) return 0;
    final dates = logs
        .map((log) => DateTime(log.date.year, log.date.month, log.date.day))
        .toSet();
    var streak = 0;
    var cursor = DateTime.now();
    while (dates.contains(DateTime(cursor.year, cursor.month, cursor.day))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  Future<void> _syncRemoteLogs() async {
    if (_currentUser?.id == null) return;
    try {
      // First, upload any dirty logs to server
      final dirtyCount = (await _logRepository.fetchDirtyLogs(_currentUser!.id!)).length;
      if (dirtyCount > 0) {
        _syncMessage = 'Syncing $dirtyCount change${dirtyCount == 1 ? '' : 's'}...';
        notifyListeners();
      }
      
      await SyncService.instance.syncPendingLogs(_currentUser!.id!);
      
      if (dirtyCount > 0) {
        // Only show sync completion message for guest users
        if (_isGuest) {
          _syncMessage = 'Sync complete! ✓';
          notifyListeners();
          
          // Clear message after 3 seconds
          Future.delayed(const Duration(seconds: 3), () {
            _syncMessage = null;
            notifyListeners();
          });
        }
      }
      
      // Then fetch latest from server to update cache
      await _logRepository.fetchLogs(userId: _currentUser!.id!);
      _error = null;
    } catch (error) {
      // Repository handles offline fallback, but if it throws, it means something else.
      // Or if we want to show a specific message.
      // But fetchLogs returns local data on error, so it shouldn't throw unless DB fails.
      print('Sync logs warning: $error');
      _syncMessage = null;
    }
  }

  void _handleRemoteEvent(SugarLogEvent event) async {
    if (_currentUser?.id == null) return;
    final userId = _currentUser!.id!;
    if (event.isDeletion && event.logId != null) {
      await _logRepository.deleteByRemoteId(event.logId!, userId);
      return;
    }
    if (event.payload != null) {
      final local = _toLocalSugarLog(event.payload!, userId);
      await _logRepository.upsertRemoteLog(local);
    }
  }

  Future<bool> updateDailyGoal(int goal) async {
    if (goal < 1) {
      return false;
    }
    if (_isGuest) {
      final user = _currentUser;
      if (user != null) {
        await _authRepository.persistUserProfile(
          email: user.email,
          fullName: user.fullName,
          role: user.role,
          provider: user.authProvider,
          goal: goal,
          allowPartnerRequests: user.allowPartnerRequests,
          biometricEnabled: user.biometricEnabled,
          featureFlags: user.featureFlags,
        );
        _currentUser = await _authRepository.getActiveUser();
      }
      _dailyGoal = goal;
      notifyListeners();
      return true;
    }

    if (_currentUser?.id == null) {
      _error = 'Not authenticated';
      notifyListeners();
      return false;
    }

    final success = await _profileRepository.updateDailyGoal(_currentUser!.id!, goal);
    if (success) {
      _dailyGoal = goal;
      _error = null;
    } else {
      // Still update locally for offline mode
      _dailyGoal = goal;
      _error = 'Goal saved offline, will sync when online';
    }
    notifyListeners();
    return true;
  }

  Future<void> _startStreamSafely() async {
    _remoteStreamSub ??=
        _streamService.stream.listen(_handleRemoteEvent, onError: (_) {});
    unawaited(_streamService.start().catchError((_) {
      _error ??= 'Live updates unavailable';
      notifyListeners();
    }));
  }

  LocalSugarLog _toLocalSugarLog(SugarLog log, int userId) {
    return LocalSugarLog(
      remoteId: log.id,
      userId: userId,
      sugarGrams: log.sugarGrams,
      date: log.date,
      hour: log.hour,
      minute: log.minute,
      productName: log.productName,
      sugarType: log.sugarType,
      contextNote: log.contextNote,
      emotion: log.emotion.name,
      location: log.location,
      wasCraving: log.wasCraving,
      visibility: log.visibility,
      isDirty: false,
      syncedAt: DateTime.now(),
    );
  }

  SugarLog _mapLocalLog(LocalSugarLog log) {
    final emotionName = log.emotion;
    final emotion = Emotion.values.firstWhere(
      (e) => e.name == emotionName.toUpperCase(),
      orElse: () => Emotion.NEUTRAL,
    );
    return SugarLog(
      id: log.remoteId ?? log.id ?? log.hashCode,
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

  @override
  void dispose() {
    _localLogsSub?.cancel();
    _remoteStreamSub?.cancel();
    _syncSub?.cancel();
    _offlineSub?.cancel();
    _connectivitySub?.cancel();
    ConnectivityService.instance.stopMonitoring();
    unawaited(_streamService.dispose());
    super.dispose();
  }
}
