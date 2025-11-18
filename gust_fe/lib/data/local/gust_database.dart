import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../models/auth_session.dart';
import '../models/local_sugar_log.dart';
import '../models/local_user.dart';

class GustDatabase {
  GustDatabase._internal();

  static final GustDatabase instance = GustDatabase._internal();
  static const _dbName = 'gust_local.db';
  static const _dbVersion = 1;

  Database? _database;
  AuthSession? _cachedSession;

  final bool _useMemory = kIsWeb;
  final Map<int, LocalUser> _memoryUsers = <int, LocalUser>{};
  final Map<int, List<LocalSugarLog>> _memoryLogsByUser =
      <int, List<LocalSugarLog>>{};
  AuthSession? _memorySession;
  int _userAutoId = 0;
  int _logAutoId = 0;
  SharedPreferences? _webPrefs;
  bool _webStoreLoaded = false;
  static const _webUsersKey = 'gust_web_users_v1';
  static const _webMetaKey = 'gust_web_meta_v1';

  final StreamController<LocalUser?> _activeUserController =
      StreamController<LocalUser?>.broadcast();
  final Map<int, StreamController<List<LocalSugarLog>>> _logControllers =
      <int, StreamController<List<LocalSugarLog>>>{};

  Future<Database> get database async {
    if (_useMemory) {
      throw UnsupportedError('In-memory mode does not expose a sqflite database');
    }
    if (_database != null) {
      return _database!;
    }
    _database = await _openDatabase();
    return _database!;
  }

  Future<Database> _openDatabase() async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createSchema,
    );
  }

  Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id INTEGER,
        email TEXT UNIQUE NOT NULL,
        full_name TEXT NOT NULL,
        role TEXT DEFAULT 'USER',
        auth_provider TEXT DEFAULT 'EMAIL',
        password_hash TEXT,
        daily_sugar_goal INTEGER,
        feature_flags TEXT,
        allow_partner_requests INTEGER DEFAULT 1,
        biometric_enabled INTEGER DEFAULT 0,
        last_sync_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE auth_sessions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        access_token TEXT NOT NULL,
        refresh_token TEXT,
        provider TEXT,
        created_at TEXT,
        expires_at TEXT,
        biometric_allowed INTEGER DEFAULT 0,
        FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE sugar_logs(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id INTEGER,
        user_id INTEGER NOT NULL,
        sugar_grams INTEGER NOT NULL,
        date TEXT NOT NULL,
        hour INTEGER NOT NULL,
        minute INTEGER NOT NULL,
        product_name TEXT,
        sugar_type TEXT,
        context_note TEXT,
        emotion TEXT,
        location TEXT,
        was_craving INTEGER DEFAULT 0,
        visibility TEXT DEFAULT 'PRIVATE',
        is_dirty INTEGER DEFAULT 1,
        synced_at TEXT,
        FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE partner_links(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        owner_user_id INTEGER NOT NULL,
        partner_user_id INTEGER NOT NULL,
        module TEXT NOT NULL,
        status TEXT NOT NULL,
        updated_at TEXT,
        UNIQUE(owner_user_id, partner_user_id, module)
      )
    ''');
  }

  Future<LocalUser?> upsertUser(
    LocalUser user, {
    bool emitActive = true,
  }) async {
    if (_useMemory) {
      await _ensureWebStoreLoaded();
      final entry = _findUserEntryByEmail(user.email);
      final id = entry?.key ?? ++_userAutoId;
      final stored = user.copyWith(id: id);
      _memoryUsers[id] = stored;
      await _persistWebUsers();
      await _persistWebMeta();
      if (emitActive) {
        _activeUserController.add(stored);
      }
      return stored;
    }

    final db = await database;
    final data = user.toMap();
    data.remove('id');
    final existing =
        await db.query('users', where: 'email = ?', whereArgs: [user.email]);
    int userId;
    if (existing.isEmpty) {
      userId = await db.insert(
        'users',
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      userId = existing.first['id'] as int;
      await db.update(
        'users',
        data,
        where: 'id = ?',
        whereArgs: [userId],
      );
    }
    final stored = await getUserById(userId);
    if (emitActive) {
      _activeUserController.add(stored);
    }
    return stored;
  }

  Future<LocalUser?> getUserByEmail(String email) async {
    if (_useMemory) {
      await _ensureWebStoreLoaded();
      return _findUserEntryByEmail(email)?.value;
    }

    final db = await database;
    final rows = await db.query('users', where: 'email = ?', whereArgs: [email]);
    if (rows.isEmpty) return null;
    final row = rows.first;
    final user = _safeUserFromRow(row);
    if (user == null) {
      await _purgeCorruptUser(row);
    }
    return user;
  }

  Future<LocalUser?> getUserById(int id) async {
    if (_useMemory) {
      await _ensureWebStoreLoaded();
      return _memoryUsers[id];
    }

    final db = await database;
    final rows = await db.query('users', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final user = _safeUserFromRow(rows.first);
    if (user == null) {
      await db.delete('users', where: 'id = ?', whereArgs: [id]);
    }
    return user;
  }

  Future<List<LocalUser>> getAllUsers() async {
    if (_useMemory) {
      await _ensureWebStoreLoaded();
      return _memoryUsers.values.toList();
    }
    final db = await database;
    final rows = await db.query('users', orderBy: 'full_name ASC');
    final result = <LocalUser>[];
    for (final row in rows) {
      final user = _safeUserFromRow(row);
      if (user != null) {
        result.add(user);
      } else {
        await _purgeCorruptUser(row);
      }
    }
    return result;
  }

  Future<LocalUser?> updateUserRole(int userId, String role) async {
    if (_useMemory) {
      await _ensureWebStoreLoaded();
      final user = _memoryUsers[userId];
      if (user == null) return null;
      final updated = user.copyWith(role: role);
      _memoryUsers[userId] = updated;
      await _persistWebUsers();
      return updated;
    }
    final db = await database;
    await db.update(
      'users',
      {'role': role},
      where: 'id = ?',
      whereArgs: [userId],
    );
    return getUserById(userId);
  }

  Stream<LocalUser?> watchActiveUser() => _activeUserController.stream;

  Future<AuthSession?> getActiveSession() async {
    if (_useMemory) {
      _cachedSession ??= _memorySession;
      final user =
          _cachedSession != null ? await getUserById(_cachedSession!.userId) : null;
      _activeUserController.add(user);
      return _cachedSession;
    }

    if (_cachedSession != null) {
      return _cachedSession;
    }
    final db = await database;
    final rows = await db.query(
      'auth_sessions',
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final session = _safeSessionFromRow(rows.first);
    if (session == null) {
      await db.delete('auth_sessions');
      _cachedSession = null;
      _activeUserController.add(null);
      return null;
    }
    _cachedSession = session;
    final user = await getUserById(_cachedSession!.userId);
    _activeUserController.add(user);
    return _cachedSession;
  }

  Future<void> saveSession(AuthSession session) async {
    if (_useMemory) {
      _memorySession = session;
      _cachedSession = session;
      final user = await getUserById(session.userId);
      _activeUserController.add(user);
      return;
    }

    final db = await database;
    await db.delete('auth_sessions');
    await db.insert('auth_sessions', session.toMap());
    _cachedSession = session;
    final user = await getUserById(session.userId);
    _activeUserController.add(user);
  }

  Future<void> clearSession() async {
    if (_useMemory) {
      _memorySession = null;
      _cachedSession = null;
      _activeUserController.add(null);
      return;
    }

    final db = await database;
    await db.delete('auth_sessions');
    _cachedSession = null;
    _activeUserController.add(null);
  }

  Future<int> insertSugarLog(LocalSugarLog log) async {
    if (_useMemory) {
      final id = log.id ?? ++_logAutoId;
      final logWithId = log.copyWith(id: id);
      final list = _memoryLogsByUser.putIfAbsent(log.userId, () => <LocalSugarLog>[]);
      final index = list.indexWhere((element) => element.id == id);
      if (index >= 0) {
        list[index] = logWithId;
      } else {
        list.add(logWithId);
      }
      await _emitLogs(log.userId);
      return id;
    }

    final db = await database;
    final id = await db.insert(
      'sugar_logs',
      log.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _emitLogs(log.userId);
    return id;
  }

  Future<void> updateSugarLog(LocalSugarLog log) async {
    if (log.id == null) {
      await insertSugarLog(log);
      return;
    }
    if (_useMemory) {
      final logs = _memoryLogsByUser.putIfAbsent(
        log.userId,
        () => <LocalSugarLog>[],
      );
      final index = logs.indexWhere((entry) => entry.id == log.id);
      if (index >= 0) {
        logs[index] = log;
      } else {
        logs.add(log);
      }
      await _emitLogs(log.userId);
      return;
    }

    final db = await database;
    final data = log.toMap();
    final id = data.remove('id');
    await db.update(
      'sugar_logs',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
    await _emitLogs(log.userId);
  }

  Future<void> replaceLogs(int userId, List<LocalSugarLog> logs) async {
    if (_useMemory) {
      final replaced = <LocalSugarLog>[];
      for (final log in logs) {
        final id = log.id ?? ++_logAutoId;
        _logAutoId = id > _logAutoId ? id : _logAutoId;
        replaced.add(log.copyWith(id: id));
      }
      _memoryLogsByUser[userId] = replaced;
      await _emitLogs(userId);
      return;
    }

    final db = await database;
    final batch = db.batch();
    batch.delete('sugar_logs', where: 'user_id = ?', whereArgs: [userId]);
    for (final log in logs) {
      batch.insert('sugar_logs', log.toMap());
    }
    await batch.commit(noResult: true);
    await _emitLogs(userId);
  }

  Future<List<LocalSugarLog>> fetchLogs({
    required int userId,
    bool sharedOnly = false,
  }) async {
    if (_useMemory) {
      final logs = List<LocalSugarLog>.from(
        _memoryLogsByUser[userId] ?? const <LocalSugarLog>[],
      );
      final filtered = sharedOnly
          ? logs.where((log) => log.visibility == 'SHARED_WITH_PARTNER').toList()
          : logs;
      filtered.sort((a, b) {
        final dateCompare = b.date.compareTo(a.date);
        if (dateCompare != 0) return dateCompare;
        final hourCompare = b.hour.compareTo(a.hour);
        if (hourCompare != 0) return hourCompare;
        return b.minute.compareTo(a.minute);
      });
      return filtered;
    }

    final db = await database;
    final where = sharedOnly ? 'user_id = ? AND visibility = ?' : 'user_id = ?';
    final whereArgs = sharedOnly
        ? [userId, 'SHARED_WITH_PARTNER']
        : [userId];
    final rows = await db.query(
      'sugar_logs',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'date DESC, hour DESC, minute DESC',
    );
    return rows.map(LocalSugarLog.fromMap).toList();
  }

  Stream<List<LocalSugarLog>> watchLogs(int userId) {
    return _logControllers
        .putIfAbsent(
          userId,
          () {
            final controller =
                StreamController<List<LocalSugarLog>>.broadcast();
            unawaited(_emitLogs(userId, controller: controller));
            return controller;
          },
        )
        .stream;
  }

  Future<void> deleteLog(int logId, int userId) async {
    if (_useMemory) {
      final logs = _memoryLogsByUser[userId];
      logs?.removeWhere((log) => log.id == logId);
      await _emitLogs(userId);
      return;
    }

    final db = await database;
    await db.delete('sugar_logs', where: 'id = ?', whereArgs: [logId]);
    await _emitLogs(userId);
  }

  Future<void> markLogsSynced(List<int> localIds) async {
    if (localIds.isEmpty) return;
    if (_useMemory) {
      final now = DateTime.now();
      for (final entry in _memoryLogsByUser.entries) {
        final updated = entry.value.map((log) {
          if (log.id != null && localIds.contains(log.id)) {
            return log.copyWith(isDirty: false, syncedAt: now);
          }
          return log;
        }).toList();
        _memoryLogsByUser[entry.key] = updated;
      }
      return;
    }

    final db = await database;
    final now = DateTime.now().toIso8601String();
    final batch = db.batch();
    for (final id in localIds) {
      batch.update(
        'sugar_logs',
        {'is_dirty': 0, 'synced_at': now},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<int> countSugarLogs() async {
    if (_useMemory) {
      return _memoryLogsByUser.values.fold<int>(
        0,
        (sum, logs) => sum + logs.length,
      );
    }
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as total FROM sugar_logs');
    return (result.first['total'] as int?) ?? 0;
  }

  Future<double> averageSugarIntake() async {
    if (_useMemory) {
      final allLogs = _memoryLogsByUser.values.expand((logs) => logs).toList();
      if (allLogs.isEmpty) return 0;
      final total =
          allLogs.fold<int>(0, (sum, log) => sum + log.sugarGrams);
      return total / allLogs.length;
    }
    final db = await database;
    final result = await db.rawQuery(
        'SELECT AVG(sugar_grams) as avgSugar FROM sugar_logs');
    final value = result.first['avgSugar'];
    if (value == null) return 0;
    return (value as num).toDouble();
  }

  Future<void> updatePartnerPreference(int userId, bool allow) async {
    if (_useMemory) {
      await _ensureWebStoreLoaded();
      final user = _memoryUsers[userId];
      if (user != null) {
        _memoryUsers[userId] = user.copyWith(allowPartnerRequests: allow);
        await _persistWebUsers();
        _activeUserController.add(_memoryUsers[userId]);
      }
      return;
    }

    final db = await database;
    await db.update(
      'users',
      {'allow_partner_requests': allow ? 1 : 0},
      where: 'id = ?',
      whereArgs: [userId],
    );
    final user = await getUserById(userId);
    _activeUserController.add(user);
  }

  Future<void> _emitLogs(int userId,
      {StreamController<List<LocalSugarLog>>? controller}) async {
    final logs = await fetchLogs(userId: userId);
    final target = controller ?? _logControllers[userId];
    target?.add(logs);
  }

  Future<void> dispose() async {
    await _activeUserController.close();
    for (final controller in _logControllers.values) {
      await controller.close();
    }
    _logControllers.clear();
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  LocalUser? _safeUserFromRow(Map<String, dynamic> row) {
    try {
      return LocalUser.fromMap(row);
    } catch (error, stackTrace) {
      debugPrint('Failed to hydrate cached user row: $error\n$stackTrace');
      return null;
    }
  }

  Future<void> _purgeCorruptUser(Map<String, dynamic> row) async {
    if (_useMemory) return;
    final id = row['id'] as int?;
    if (id == null) return;
    try {
      final db = await database;
      await db.delete('users', where: 'id = ?', whereArgs: [id]);
    } catch (error) {
      debugPrint('Failed to purge corrupt user row $id: $error');
    }
  }

  AuthSession? _safeSessionFromRow(Map<String, dynamic> row) {
    try {
      return AuthSession.fromMap(row);
    } catch (error, stackTrace) {
      debugPrint('Failed to hydrate cached session row: $error\n$stackTrace');
      return null;
    }
  }

  MapEntry<int, LocalUser>? _findUserEntryByEmail(String email) {
    for (final entry in _memoryUsers.entries) {
      if (entry.value.email.toLowerCase() == email.toLowerCase()) {
        return entry;
      }
    }
    return null;
  }

  Future<void> _ensureWebStoreLoaded() async {
    if (!_useMemory || _webStoreLoaded) return;
    _webPrefs ??= await SharedPreferences.getInstance();
    final usersJson = _webPrefs!.getString(_webUsersKey);
    if (usersJson != null && usersJson.isNotEmpty) {
      final list = jsonDecode(usersJson) as List<dynamic>;
      for (final entry in list) {
        if (entry is! Map) continue;
        final map = Map<String, dynamic>.from(entry);
        final user = _safeUserFromRow(map);
        if (user == null) {
          continue;
        }
        final id = user.id ?? ++_userAutoId;
        _memoryUsers[id] = user.copyWith(id: id);
        if (_userAutoId < id) {
          _userAutoId = id;
        }
      }
    }
    final metaJson = _webPrefs!.getString(_webMetaKey);
    if (metaJson != null && metaJson.isNotEmpty) {
      final map = jsonDecode(metaJson) as Map<String, dynamic>;
      _userAutoId = map['userAutoId'] as int? ?? _userAutoId;
      _logAutoId = map['logAutoId'] as int? ?? _logAutoId;
    }
    _webStoreLoaded = true;
  }

  Future<void> _persistWebUsers() async {
    if (!_useMemory) return;
    await _ensureWebStoreLoaded();
    final list = _memoryUsers.values.map((user) => user.toMap()).toList();
    await _webPrefs?.setString(_webUsersKey, jsonEncode(list));
  }

  Future<void> _persistWebMeta() async {
    if (!_useMemory) return;
    await _ensureWebStoreLoaded();
    await _webPrefs?.setString(
      _webMetaKey,
      jsonEncode({
        'userAutoId': _userAutoId,
        'logAutoId': _logAutoId,
      }),
    );
  }
}
