import 'dart:async';

import 'api_service.dart';

/// Service to monitor network connectivity and notify when connection is restored
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  static ConnectivityService get instance => _instance;

  ConnectivityService._internal();

  final _restorationController = StreamController<bool>.broadcast();
  StreamSubscription<bool>? _offlineSub;
  bool _wasOffline = false;

  /// Stream that emits true when network connectivity is restored (offline -> online)
  Stream<bool> get onConnectivityRestored => _restorationController.stream;

  /// Start monitoring network state
  void startMonitoring() {
    _offlineSub?.cancel();
    _offlineSub = ApiService.instance.isOffline.listen((isOffline) {
      // Detect transition from offline to online
      if (_wasOffline && !isOffline) {
        print('Network connectivity restored!');
        _restorationController.add(true);
      }
      _wasOffline = isOffline;
    });
  }

  /// Stop monitoring
  void stopMonitoring() {
    _offlineSub?.cancel();
    _offlineSub = null;
  }

  void dispose() {
    stopMonitoring();
    _restorationController.close();
  }
}
