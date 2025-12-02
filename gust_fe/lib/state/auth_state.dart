import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../constants.dart';
import '../data/models/auth_session.dart';
import '../data/models/local_sugar_log.dart';
import '../data/models/local_user.dart';
import '../repositories/auth_repository.dart';
import '../repositories/sugar_log_repository.dart';
import '../services/auth_helper.dart';
import '../services/biometric_auth_service.dart';
import '../services/firebase_auth_service.dart';
import '../services/secure_storage_service.dart';
import '../services/sync_service.dart';
import '../utils/hash_helper.dart';

class AuthState extends ChangeNotifier {
  AuthState({
    AuthRepository? authRepository,
    SugarLogRepository? logRepository,
    BiometricAuthService? biometricAuthService,
    http.Client? httpClient,
    SecureStorageService? secureStorageService,
    FirebaseAuthService? firebaseAuthService,
  })  : _authRepository = authRepository ?? AuthRepository(),
        _logRepository = logRepository ?? SugarLogRepository(),
        _biometricService = biometricAuthService ?? BiometricAuthService(),
        _client = httpClient ?? http.Client(),
        _secureStorage = secureStorageService ?? SecureStorageService.instance,
        _firebaseAuthService = firebaseAuthService ?? FirebaseAuthService() {
    _authRepository.watchActiveUser().listen((user) {
      _currentUser = user;
      _featureFlags = user?.featureFlags ?? [];
      notifyListeners();
    });
  }

  static const List<String> _defaultOfflineFeatures = <String>[
    'sugar_logs',
    'analytics',
    'community',
  ];
  static const int _offlineTokenMax = 0x3fffffff; // safe for web Random.nextInt
  static const String _adminEmail = 'admin@gust.app';
  static const String _adminPassword = 'GustAdmin!23';
  static const String _adminName = 'GUST Admin';

  final AuthRepository _authRepository;
  final SugarLogRepository _logRepository;
  final BiometricAuthService _biometricService;
  final http.Client _client;
  final SecureStorageService _secureStorage;
  final FirebaseAuthService _firebaseAuthService;

  LocalUser? _currentUser;
  AuthSession? _session;
  bool _isLoading = false;
  bool _isLocked = false;
  String? _error;
  List<String> _featureFlags = const [];

  LocalUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _error;
  bool get isAuthenticated => _currentUser != null && _session != null && !_isLocked;
  List<String> get featureFlags => _featureFlags;
  AuthSession? get session => _session;

  Future<void> hydrate() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _seedAdminAccount();
      _session = await _authRepository.readSession();
      _currentUser = await _authRepository.getActiveUser();
      _featureFlags = _currentUser?.featureFlags ?? [];
      
      // Debug logging
      if (kDebugMode) {
        print('=== HYDRATE DEBUG ===');
        print('Current User: ${_currentUser?.email}');
        print('Session exists: ${_session != null}');
        print('User biometricEnabled (DB): ${_currentUser?.biometricEnabled}');
      }
      
      // If user has biometric enabled, lock the app on startup
      if (_currentUser != null && _currentUser!.biometricEnabled) {
        _isLocked = true;
        if (kDebugMode) {
          print('Setting _isLocked = true (biometric enabled)');
        }
      } else {
        if (kDebugMode) {
          print('NOT locking app - biometric disabled or no user');
        }
      }
      
      if (kDebugMode) {
        print('Final _isLocked state: $_isLocked');
        print('isAuthenticated will return: ${_currentUser != null && _session != null && !_isLocked}');
        print('===================');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
      if (_currentUser?.id != null) {
        // Trigger background sync on app start
        SyncService.instance.syncPendingLogs(_currentUser!.id!);
      }
    }
  }

  Future<bool> hasCachedToken() async {
    final token = await _secureStorage.readAccessToken();
    return token != null;
  }

  Future<bool> loginWithEmail(String email, String password) async {
    if (enableMockAuth) {
      return _runLocalAuth(() => _loginLocally(email, password));
    }
    try {
      final result = await _firebaseAuthService.signInWithEmail(
        email: email,
        password: password,
      );
      return await _executeAuthCall(
        endpoint: '$baseUrl/api/auth/social-login',
        body: {
          'provider': 'EMAIL',
          'idToken': result.idToken,
        },
        provider: 'EMAIL',
      );
    } catch (err) {
      _captureError(err);
      return false;
    }
  }

  Future<bool> registerWithEmail({
    required String fullName,
    required String email,
    required String password,
  }) async {
    if (enableMockAuth) {
      return _runLocalAuth(
        () => _registerLocally(
          fullName: fullName,
          email: email,
          password: password,
        ),
      );
    }
    try {
      final result = await _firebaseAuthService.registerWithEmail(
        email: email,
        password: password,
      );
      return await _executeAuthCall(
        endpoint: '$baseUrl/api/auth/social-login',
        body: {
          'provider': 'EMAIL',
          'idToken': result.idToken,
          'fullName': fullName,
        },
        provider: 'EMAIL',
        overrideFullName: fullName,
      );
    } catch (err) {
      _captureError(err);
      return false;
    }
  }

  Future<bool> loginAnonymously() async {
    _setLoading(true);
    try {
      // Check if we already have a guest user stored locally
      final existingGuestUser = await _authRepository.getGuestUser();
      
      if (existingGuestUser != null) {
        // Reuse existing guest account
        print('Reusing existing guest user: ${existingGuestUser.email}');
        _currentUser = existingGuestUser;
        
        final token = 'guest_token_${existingGuestUser.id}';
        
        // Create a local session for the guest user
        await _authRepository.saveSession(
          userId: existingGuestUser.id!,
          provider: 'ANONYMOUS',
          token: token,
        );
        
        // Store session metadata for AuthHelper
        await _persistSessionMetadata(
          token: token,
          userId: existingGuestUser.id!,
          email: existingGuestUser.email,
          provider: 'ANONYMOUS',
        );
        
        // Save biometric token for guest users (enables biometric login)
        await _biometricService.saveUserEmail(existingGuestUser.email);
        await _biometricService.saveAuthToken(token);
        if (existingGuestUser.biometricEnabled) {
          await _biometricService.enableBiometric();
        }
        
        // Read the session back to populate _session
        _session = await _authRepository.getActiveSession();
        _featureFlags = existingGuestUser.featureFlags;
        _isLocked = false;
        _error = null;
        
        notifyListeners();
        return true;
      }
      
      // No existing guest user, create a new one
      print('Creating new guest user');
      // Direct backend call for guest/anonymous session
      return await _executeAuthCall(
        endpoint: '$baseUrl/api/auth/anonymous',
        body: {
          'displayName': 'Guest User',
        },
        provider: 'ANONYMOUS',
        overrideFullName: 'Guest User',
      );
    } catch (err) {
      _captureError(
        err,
        fallbackMessage: 'Unable to start a guest session right now.',
      );
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> loginWithGoogle() async {
    try {
      final result = await _firebaseAuthService.signInWithGoogle();
      return await _executeAuthCall(
        endpoint: '$baseUrl/api/auth/social-login',
        body: {
          'provider': 'GOOGLE',
          'idToken': result.idToken,
        },
        provider: 'GOOGLE',
        overrideFullName: result.displayName,
      );
    } catch (err) {
      _captureError(err);
      return false;
    }
  }

  Future<bool> loginWithYahoo() async {
    try {
      final result = await _firebaseAuthService.signInWithYahoo();
      return await _executeAuthCall(
        endpoint: '$baseUrl/api/auth/social-login',
        body: {
          'provider': 'YAHOO',
          'idToken': result.idToken,
        },
        provider: 'YAHOO',
        overrideFullName: result.displayName,
      );
    } catch (err) {
      _captureError(err);
      return false;
    }
  }

  Future<bool> loginWithGoogleDev({
    required String email,
    String? fullName,
  }) async {
    final normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty) {
      _error = 'An email address is required to continue with Google.';
      notifyListeners();
      return false;
    }
    final normalizedName = fullName?.trim();
    final builder = StringBuffer('dev-$normalizedEmail');
    if (normalizedName != null && normalizedName.isNotEmpty) {
      builder.write('|$normalizedName');
    }
    return _executeAuthCall(
      endpoint: '$baseUrl/api/auth/social-login',
      body: {
        'provider': 'GOOGLE',
        'idToken': builder.toString(),
      },
      provider: 'GOOGLE',
      overrideFullName: normalizedName,
    );
  }

  Future<bool> loginWithBiometrics() async {
    final isEnabled = await _biometricService.isBiometricAvailable();
    if (!isEnabled) {
      _error = 'Biometric authentication not available on this device';
      notifyListeners();
      return false;
    }
    final authenticated = await _biometricService.authenticate();
    if (!authenticated) {
      _error = 'Biometric authentication failed';
      notifyListeners();
      return false;
    }
    
    // Get token from biometric service (uses secure storage internally)
    final token = await _biometricService.getAuthToken();
    final session = await _authRepository.readSession();
    final user = await _authRepository.getActiveUser();
    if (token == null || session == null || user == null) {
      _error = 'No cached session found. Please login once with password.';
      notifyListeners();
      return false;
    }
    _session = session;
    _currentUser = user;
    _featureFlags = user.featureFlags;
    _isLocked = false;
    _error = null;
    notifyListeners();
    return true;
  }

  Future<void> togglePartnerRequests(bool allow) async {
    await _authRepository.updatePartnerPreference(allow);
    final refreshed = await _authRepository.getActiveUser();
    _currentUser = refreshed;
    notifyListeners();
  }

  Future<void> enableBiometrics() async {
    final user = _currentUser;
    if (user == null) {
      if (kDebugMode) {
        print('enableBiometrics: No current user, aborting');
      }
      return;
    }
    
    if (kDebugMode) {
      print('=== ENABLE BIOMETRICS DEBUG ===');
      print('Current user before update: ${user.email}');
      print('Current biometricEnabled before: ${user.biometricEnabled}');
    }
    
    await _authRepository.persistUserProfile(
      email: user.email,
      fullName: user.fullName,
      role: user.role,
      provider: user.authProvider,
      goal: user.dailySugarGoal,
      allowPartnerRequests: user.allowPartnerRequests,
      biometricEnabled: true,  // <<< Setting to TRUE
      featureFlags: user.featureFlags,
    );
    
    if (kDebugMode) {
      print('Database update complete, fetching refreshed user...');
    }
    
    final refreshed = await _authRepository.getActiveUser();
    
    if (kDebugMode) {
      print('Refreshed user biometricEnabled: ${refreshed?.biometricEnabled}');
      print('================================');
    }
    
    _currentUser = refreshed;
    notifyListeners();
  }

  Future<void> signOut() async {
    // Clear biometric token first (needs user_email from prefs)
    await _biometricService.clearAuthToken();
    
    final provider = await AuthHelper.getProvider();
    await _authRepository.signOut();
    await AuthHelper.clearAuth();
    if (provider != 'ANONYMOUS') {
      await _firebaseAuthService.signOut();
    }
    _currentUser = null;
    _session = null;
    _featureFlags = const [];
    notifyListeners();
  }

  Future<bool> _runLocalAuth(Future<bool> Function() operation) async {
    _setLoading(true);
    try {
      return await operation();
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> _executeAuthCall({
    required String endpoint,
    required Map<String, dynamic> body,
    required String provider,
    String? cachePassword,
    String? overrideFullName,
    Future<bool> Function()? offlineFallback,
  }) async {
    _setLoading(true);
    try {
      final response = await _client.post(
        Uri.parse(endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) {
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        await _storeAuthResponse(
          payload,
          provider: provider,
          passwordOverride: cachePassword,
          overrideFullName: overrideFullName,
        );
        return true;
      } else if (offlineFallback != null) {
        return await _runOfflineFallback(offlineFallback);
      } else {
        _error = _parseError(response);
        notifyListeners();
        return false;
      }
    } catch (err) {
      if (offlineFallback != null) {
        return await _runOfflineFallback(offlineFallback);
      }
      _captureError(err);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> _runOfflineFallback(
    Future<bool> Function() fallback,
  ) async {
    try {
      return await fallback();
    } catch (err) {
      _captureError(err);
      return false;
    }
  }

  Future<void> _persistSessionMetadata({
    required String token,
    required int userId,
    required String email,
    required String provider,
  }) {
    return AuthHelper.storeSession(
      token: token,
      userId: userId,
      email: email,
      provider: provider,
    );
  }

  Future<bool> _loginLocally(String email, String password) async {
    final existing = await _authRepository.getUserByEmail(email);
    if (existing == null || existing.passwordHash == null) {
      _error = 'Invalid email or password';
      notifyListeners();
      return false;
    }
    final isValid = HashHelper.verifyPassword(password, existing.passwordHash!);
    if (!isValid) {
      _error = 'Invalid email or password';
      notifyListeners();
      return false;
    }
    return _completeLocalSession(existing, provider: existing.authProvider);
  }

  Future<bool> _registerLocally({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final existing = await _authRepository.getUserByEmail(email);
    if (existing != null) {
      _error = 'An account with this email already exists';
      notifyListeners();
      return false;
    }
    final created = await _authRepository.persistUserProfile(
      email: email,
      fullName: fullName,
      role: 'USER',
      provider: 'EMAIL',
      rawPassword: password,
      featureFlags: _defaultOfflineFeatures,
    );
    if (created?.id == null) {
      _error = 'Unable to create local profile';
      notifyListeners();
      return false;
    }
    await _hydrateInitialLogs(created!.id!);
    return _completeLocalSession(created, provider: 'EMAIL');
  }

  Future<bool> _completeLocalSession(
    LocalUser user, {
    required String provider,
    bool biometricAllowed = false,
  }) async {
    if (user.id == null) {
      _error = 'Local profile is missing an identifier';
      notifyListeners();
      return false;
    }
    final resolvedUser = await _ensureFeatureFlags(user);
    final token = _generateLocalToken();
    await _authRepository.persistSession(
      userId: resolvedUser.id!,
      token: token,
      provider: provider,
      biometricAllowed: biometricAllowed || resolvedUser.biometricEnabled,
    );
    await _persistSessionMetadata(
      token: token,
      userId: resolvedUser.id!,
      email: resolvedUser.email,
      provider: provider,
    );
    await _biometricService.saveUserEmail(resolvedUser.email);
    await _biometricService.saveAuthToken(token);
    if (biometricAllowed || resolvedUser.biometricEnabled) {
      await _biometricService.enableBiometric();
    }
    _session = await _authRepository.readSession();
    _currentUser = resolvedUser;
    _featureFlags = resolvedUser.featureFlags.isNotEmpty
        ? resolvedUser.featureFlags
        : _defaultOfflineFeatures;
    _error = null;
    notifyListeners();
    return true;
  }

  Future<LocalUser> _ensureFeatureFlags(LocalUser user) async {
    if (user.featureFlags.isNotEmpty) {
      return user;
    }
    final updated = await _authRepository.persistUserProfile(
      email: user.email,
      fullName: user.fullName,
      role: user.role,
      provider: user.authProvider,
      goal: user.dailySugarGoal,
      allowPartnerRequests: user.allowPartnerRequests,
      biometricEnabled: user.biometricEnabled,
      featureFlags: _defaultOfflineFeatures,
    );
    return updated ?? user.copyWith(featureFlags: _defaultOfflineFeatures);
  }

  String _generateLocalToken() {
    final random = Random();
    return 'local-${DateTime.now().millisecondsSinceEpoch}-${random.nextInt(_offlineTokenMax)}';
  }

  Future<void> _seedAdminAccount() async {
    final existing = await _authRepository.getUserByEmail(_adminEmail);
    if (existing != null) return;
    await _authRepository.persistUserProfile(
      email: _adminEmail,
      fullName: _adminName,
      role: 'ADMIN',
      provider: 'EMAIL',
      rawPassword: _adminPassword,
      featureFlags: _defaultOfflineFeatures,
    );
  }

  Future<void> _storeAuthResponse(
    Map<String, dynamic> payload, {
    required String provider,
    bool biometricAllowed = false,
    String? passwordOverride,
    String? overrideFullName,
  }) async {
    String? extractString(dynamic value) {
      if (value == null) return null;
      if (value is String && value.isNotEmpty) return value;
      return value.toString();
    }

    Map<String, dynamic>? extractMap(dynamic source) {
      if (source is Map<String, dynamic>) return source;
      return null;
    }

    int? asInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is double) return value.toInt();
      return int.tryParse(value.toString());
    }

    String? token = extractString(payload['token']);
    token ??= extractString(payload['accessToken']);
    token ??= extractString(payload['access_token']);
    token ??= extractString(extractMap(payload['data'])?['token']);
    token ??= extractString(extractMap(payload['data'])?['accessToken']);
    if (token == null || token.isEmpty) {
      throw Exception('Invalid authentication response: missing token');
    }

    final nestedUser = extractMap(payload['user']) ??
        extractMap(extractMap(payload['data'])?['user']);
    final nestedProfile = extractMap(payload['profile']);

    final int? remoteId = asInt(
      payload['userId'] ??
          payload['user_id'] ??
          nestedUser?['id'] ??
          nestedProfile?['id'],
    );

    final emailCandidate = payload['email'] as String? ??
        extractString(nestedUser?['email']) ??
        extractString(nestedProfile?['email']) ??
        '';
    final String resolvedEmail =
        emailCandidate.isNotEmpty ? emailCandidate : '';
    if (resolvedEmail.isEmpty) {
      throw Exception('Invalid authentication response: missing email');
    }

    final fullName = overrideFullName ??
        extractString(payload['fullName']) ??
        extractString(nestedUser?['fullName']) ??
        extractString(nestedUser?['name']) ??
        extractString(nestedProfile?['fullName']) ??
        resolvedEmail.split('@').first;

    final String role = extractString(payload['role']) ??
        extractString(nestedUser?['role']) ??
        extractString(nestedProfile?['role']) ??
        'USER';

    final int? goal = asInt(
      payload['dailySugarGoal'] ??
          nestedUser?['dailySugarGoal'] ??
          nestedProfile?['dailySugarGoal'] ??
          nestedUser?['daily_goal'],
    );

    bool parseBool(dynamic value, {bool fallback = false}) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final lower = value.toLowerCase();
        if (lower == 'true' || lower == '1') return true;
        if (lower == 'false' || lower == '0') return false;
      }
      return fallback;
    }

    final allowPartnerRequests = parseBool(
      payload['allowPartnerRequests'] ??
          nestedUser?['allowPartnerRequests'] ??
          nestedProfile?['allowPartnerRequests'],
      fallback: true,
    );

    final biometricEnabled = parseBool(
      payload['biometricEnabled'] ??
          nestedUser?['biometricEnabled'] ??
          nestedProfile?['biometricEnabled'],
    );

    final dynamic featuresSource =
        payload['availableFeatures'] ?? nestedUser?['availableFeatures'] ?? [];
    final List<String> features = featuresSource is List
        ? featuresSource.map((e) => e.toString()).toList()
        : const [];
    final List<String> normalizedFeatures =
        features.isNotEmpty ? features : _defaultOfflineFeatures;

    final persistedUser = await _authRepository.persistUserProfile(
      email: resolvedEmail,
      fullName: fullName,
      role: role,
      remoteId: remoteId,
      goal: goal,
      allowPartnerRequests: allowPartnerRequests,
      biometricEnabled: biometricEnabled || biometricAllowed,
      provider: provider,
      rawPassword: passwordOverride ?? token,
      featureFlags: normalizedFeatures,
    );
    
    print('Auth Response Role: $role');

    if (persistedUser?.id == null) {
      throw Exception('Unable to persist local user profile');
    }

    // hydrate sugar logs for the user on first login
    await _hydrateInitialLogs(persistedUser!.id!);

    await _authRepository.persistSession(
      userId: persistedUser.id!,
      token: token,
      provider: provider,
      biometricAllowed: biometricAllowed || biometricEnabled,
    );
    
    // Trigger sync after login
    SyncService.instance.syncPendingLogs(persistedUser.id!);

    await _persistSessionMetadata(
      token: token,
      userId: persistedUser.id!,
      email: resolvedEmail,
      provider: provider,
    );
    await _biometricService.saveUserEmail(resolvedEmail);
    await _biometricService.saveAuthToken(token);
    if (biometricAllowed || biometricEnabled) {
      await _biometricService.enableBiometric();
    }

    _session = await _authRepository.readSession();
    _currentUser = persistedUser;
    _featureFlags = normalizedFeatures;
    _isLocked = false;
    _error = null;
    notifyListeners();
  }


  Future<void> _hydrateInitialLogs(int userId) async {
    // No seed data - users start with a clean slate
    await _logRepository.replaceFromRemote(userId, []);
  }

  String _parseError(http.Response response) {
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return decoded['message'] as String? ??
          'Request failed with status ${response.statusCode}';
    } catch (_) {
      return 'Request failed with status ${response.statusCode}';
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _captureError(
    Object err, {
    String? fallbackMessage,
  }) {
    if (kDebugMode) {
      debugPrint('AuthState error: $err');
    }
    _error = _friendlyErrorMessage(err, fallbackMessage: fallbackMessage);
    if (kDebugMode) {
      debugPrint('AuthState friendly error message: $_error');
    }
    notifyListeners();
  }

  String _friendlyErrorMessage(
    Object err, {
    String? fallbackMessage,
  }) {
    // Check for network connectivity errors first
    if (err is SocketException) {
      return 'No internet connection detected. Please check your network connection and try again.';
    }
    
    if (err is PlatformException) {
      final platformMessage = _friendlyPlatformException(err);
      if (platformMessage.isNotEmpty) {
        return platformMessage;
      }
    }
    
    // Check for Firebase authentication errors
    final raw = err.toString().toLowerCase();
    
    // Firebase auth error codes
    if (raw.contains('user-not-found') || raw.contains('wrong-password') || 
        raw.contains('invalid-credential') || raw.contains('invalid-email')) {
      return 'Invalid email or password. Please check your credentials and try again.';
    }
    
    if (raw.contains('user-disabled')) {
      return 'This account has been disabled. Please contact support.';
    }
    
    if (raw.contains('email-already-in-use')) {
      return 'An account with this email already exists.';
    }
    
    if (raw.contains('weak-password')) {
      return 'Password is too weak. Please choose a stronger password.';
    }
    
    if (raw.contains('network-request-failed')) {
      return 'Network error. Please check your connection and try again.';
    }
    
    // Check for common network error messages in string
    if (raw.contains('socketexception') || 
        raw.contains('xmlhttprequest error') ||
        raw.contains('no route to host') ||
        raw.contains('network is unreachable') ||
        raw.contains('failed host lookup') ||
        raw.contains('connection refused') ||
        raw.contains('connection timed out') ||
        raw.contains('software caused connection abort')) {
      return 'Unable to connect to the server. Please check your internet connection and try again.';
    }
    
    final rawOriginal = err.toString();
    if (rawOriginal.isNotEmpty) {
      const prefix = 'Exception: ';
      if (rawOriginal.startsWith(prefix)) {
        return rawOriginal.substring(prefix.length).trim();
      }
      return rawOriginal;
    }
    return fallbackMessage ?? 'Something went wrong. Please try again.';
  }

  String _friendlyPlatformException(PlatformException err) {
    final code = err.code.toLowerCase();
    final message = err.message ?? '';
    final details = err.details?.toString() ?? '';
    if (code.contains('sign_in')) {
      if (code.contains('canceled') || code == 'popup-closed-by-user') {
        return 'Sign-in was cancelled. Please try again.';
      }
      if (message.contains('10:') || details.contains('10')) {
        return 'Google sign-in isn\'t fully configured for this build yet. Please use email sign-in for now.';
      }
      return 'Unable to complete sign-in. Please try again in a moment or use email instead.';
    }
    if (code == 'popup-closed-by-user' || code == 'web-context-cancelled') {
      return 'Sign-in was cancelled.';
    }
    if (code.contains('network')) {
      return 'We couldn\'t reach the authentication service. Check your internet connection and try again.';
    }
    if (code == 'notavailable' || code == 'not_available') {
      return 'This feature is not available on your device.';
    }
    if (code == 'notenrolled') {
      return 'No biometric data is enrolled on this device.';
    }
    if (code == 'lockedout' || code == 'permanentlylockedout') {
      return 'Biometric authentication is temporarily locked. Please use your password.';
    }
    return message.isNotEmpty
        ? message
        : (details.isNotEmpty
            ? details
            : 'A device-level error occurred. Please try again.');
  }
}
