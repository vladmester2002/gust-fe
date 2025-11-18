import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../constants.dart';
import '../data/models/auth_session.dart';
import '../data/models/local_sugar_log.dart';
import '../data/models/local_user.dart';
import '../repositories/auth_repository.dart';
import '../repositories/sugar_log_repository.dart';
import '../services/auth_helper.dart';
import '../services/biometric_auth_service.dart';
import '../services/secure_storage_service.dart';
import '../utils/hash_helper.dart';

class AuthState extends ChangeNotifier {
  AuthState({
    AuthRepository? authRepository,
    SugarLogRepository? logRepository,
    BiometricAuthService? biometricAuthService,
    http.Client? httpClient,
    SecureStorageService? secureStorageService,
  })  : _authRepository = authRepository ?? AuthRepository(),
        _logRepository = logRepository ?? SugarLogRepository(),
        _biometricService = biometricAuthService ?? BiometricAuthService(),
        _client = httpClient ?? http.Client(),
        _secureStorage = secureStorageService ?? SecureStorageService.instance {
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

  LocalUser? _currentUser;
  AuthSession? _session;
  bool _isLoading = false;
  String? _error;
  List<String> _featureFlags = const [];

  LocalUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _error;
  bool get isAuthenticated => _currentUser != null && _session != null;
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
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> loginWithEmail(String email, String password) async {
    if (enableMockAuth) {
      return _runLocalAuth(() => _loginLocally(email, password));
    }
    return _executeAuthCall(
      endpoint: '$baseUrl/api/auth/login',
      body: {'email': email, 'password': password},
      provider: 'EMAIL',
      cachePassword: password,
      offlineFallback: () => _loginLocally(email, password),
    );
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
    return _executeAuthCall(
      endpoint: '$baseUrl/api/auth/register',
      body: {'fullName': fullName, 'email': email, 'password': password},
      provider: 'EMAIL',
      cachePassword: password,
      overrideFullName: fullName,
      offlineFallback: () => _registerLocally(
        fullName: fullName,
        email: email,
        password: password,
      ),
    );
  }

  Future<bool> loginAnonymously() async {
    _setLoading(true);
    try {
      final savedGuest = await AuthHelper.getSavedGuestUser();
      LocalUser? localUser;
      if (savedGuest != null) {
        localUser = await _authRepository.getUserByEmail(savedGuest.email);
      }
      const defaultFeatures = ['sugar_logs'];
      final token = 'anon-${Random().nextInt(_offlineTokenMax)}';
      bool seeded = false;
      if (localUser == null) {
        final anonymousEmail =
            savedGuest?.email ?? 'anon_${DateTime.now().millisecondsSinceEpoch}@gust.app';
        localUser = await _authRepository.persistUserProfile(
          email: anonymousEmail,
          fullName: 'Guest Explorer',
          role: 'ANONYMOUS',
          provider: 'ANONYMOUS',
          biometricEnabled: false,
          rawPassword: token,
          featureFlags: defaultFeatures,
        );
        if (localUser == null) {
          throw Exception('Unable to create anonymous profile');
        }
        await AuthHelper.rememberGuestUser(
          userId: localUser.id!,
          email: anonymousEmail,
        );
        seeded = true;
      } else {
        await AuthHelper.rememberGuestUser(
          userId: localUser.id!,
          email: localUser.email,
        );
      }
      if (seeded) {
        await _hydrateInitialLogs(localUser.id!);
      }
      await _authRepository.persistSession(
        userId: localUser.id!,
        token: token,
        provider: 'ANONYMOUS',
      );
      await _persistSessionMetadata(
        token: token,
        userId: localUser.id!,
        email: localUser.email,
        provider: 'ANONYMOUS',
      );
      final resolvedUser = await _ensureFeatureFlags(localUser);
      _session = await _authRepository.readSession();
      _currentUser = resolvedUser;
      _featureFlags = resolvedUser.featureFlags.isNotEmpty
          ? resolvedUser.featureFlags
          : defaultFeatures;
      _error = null;
      notifyListeners();
      return true;
    } catch (err) {
      _error = err.toString();
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> loginWithGoogle() async {
    _error = 'Google Sign-In is not yet available on web. Please use email/password.';
    notifyListeners();
    return false;
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
    final token = await _secureStorage.readAccessToken();
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

  Future<void> signOut() async {
    await _authRepository.signOut();
    await AuthHelper.clearAuth();
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
      _error = err.toString();
      notifyListeners();
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
      _error = err.toString();
      notifyListeners();
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
    String? _extractString(dynamic value) {
      if (value == null) return null;
      if (value is String && value.isNotEmpty) return value;
      return value.toString();
    }

    Map<String, dynamic>? _extractMap(dynamic source) {
      if (source is Map<String, dynamic>) return source;
      return null;
    }

    int? _asInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is double) return value.toInt();
      return int.tryParse(value.toString());
    }

    String? token = _extractString(payload['token']);
    token ??= _extractString(payload['accessToken']);
    token ??= _extractString(payload['access_token']);
    token ??= _extractString(_extractMap(payload['data'])?['token']);
    token ??= _extractString(_extractMap(payload['data'])?['accessToken']);
    if (token == null || token.isEmpty) {
      throw Exception('Invalid authentication response: missing token');
    }

    final nestedUser =
        _extractMap(payload['user']) ?? _extractMap(_extractMap(payload['data'])?['user']);
    final nestedProfile = _extractMap(payload['profile']);

    final int? remoteId = _asInt(
      payload['userId'] ??
          payload['user_id'] ??
          nestedUser?['id'] ??
          nestedProfile?['id'],
    );

    final emailCandidate = payload['email'] as String? ??
        _extractString(nestedUser?['email']) ??
        _extractString(nestedProfile?['email']) ??
        '';
    final String resolvedEmail = emailCandidate.isNotEmpty ? emailCandidate : '';
    if (resolvedEmail.isEmpty) {
      throw Exception('Invalid authentication response: missing email');
    }

    final fullName = overrideFullName ??
        _extractString(payload['fullName']) ??
        _extractString(nestedUser?['fullName']) ??
        _extractString(nestedUser?['name']) ??
        _extractString(nestedProfile?['fullName']) ??
        resolvedEmail.split('@').first;

    final String role = _extractString(payload['role']) ??
        _extractString(nestedUser?['role']) ??
        _extractString(nestedProfile?['role']) ??
        'USER';

    final int? goal = _asInt(
      payload['dailySugarGoal'] ??
          nestedUser?['dailySugarGoal'] ??
          nestedProfile?['dailySugarGoal'] ??
          nestedUser?['daily_goal'],
    );

    bool _parseBool(dynamic value, {bool fallback = false}) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final lower = value.toLowerCase();
        if (lower == 'true' || lower == '1') return true;
        if (lower == 'false' || lower == '0') return false;
      }
      return fallback;
    }

    final allowPartnerRequests = _parseBool(
      payload['allowPartnerRequests'] ??
          nestedUser?['allowPartnerRequests'] ??
          nestedProfile?['allowPartnerRequests'],
      fallback: true,
    );

    final biometricEnabled = _parseBool(
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
    _error = null;
    notifyListeners();
  }

  Future<void> _hydrateInitialLogs(int userId) async {
    // For now we seed a small sample to prove DB sync works offline.
    final sampleLogs = <LocalSugarLog>[
      LocalSugarLog(
        userId: userId,
        sugarGrams: 15,
        date: DateTime.now(),
        hour: DateTime.now().hour,
        minute: DateTime.now().minute,
        productName: 'Greek Yogurt',
        sugarType: 'Natural',
        contextNote: 'Post-workout snack',
        emotion: 'ENERGIZED',
        wasCraving: false,
        visibility: 'PRIVATE',
        isDirty: false,
      ),
      LocalSugarLog(
        userId: userId,
        sugarGrams: 22,
        date: DateTime.now().subtract(const Duration(days: 1)),
        hour: 15,
        minute: 10,
        productName: 'Protein bar',
        sugarType: 'Added',
        contextNote: 'Afternoon craving, approved for sharing',
        emotion: 'FOCUSED',
        wasCraving: true,
        visibility: 'SHARED_WITH_PARTNER',
        isDirty: false,
      ),
    ];
    await _logRepository.replaceFromRemote(userId, sampleLogs);
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
}
