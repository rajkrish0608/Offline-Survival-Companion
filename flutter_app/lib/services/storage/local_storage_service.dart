import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart' if (dart.library.js_interop) 'package:offline_survival_companion/services/storage/stubs/sqflite_stub.dart';
import 'package:path/path.dart';
import 'package:hive/hive.dart';
import 'package:logger/logger.dart';
import 'package:offline_survival_companion/core/constants/app_constants.dart';
import 'dart:io' if (dart.library.js_interop) 'package:offline_survival_companion/services/storage/stubs/io_stub.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class LocalStorageService {
  Database? _database;
  Box<dynamic>? _vaultBox;
  Box<dynamic>? _settingsBox;
  Box<dynamic>? _cacheBox;
  Box<dynamic>? _syncBox;
  final Map<String, dynamic> _webSettings = {};
  bool _initialized = false;
  bool _fts5Available = false;
  final Logger _logger = Logger();

  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (kIsWeb) {
      _logger.i('Running on Web: Bypassing LocalStorage initialization.');
      _initialized = true;
      return;
    }
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, AppConstants.dbName);

      _database = await openDatabase(
        path,
        version: 8, // Upgraded to v8 for new tables (sync, tracking, settings, pois, safety_pins)
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );

      try {
        await _database!.execute('PRAGMA journal_mode=WAL');
      } catch (e) {
        _logger.w('WAL mode not available: $e');
      }

      _vaultBox = await Hive.openBox(AppConstants.vaultBoxName);
      _settingsBox = await Hive.openBox(AppConstants.settingsBoxName);
      _cacheBox = await Hive.openBox(AppConstants.cacheBoxName);
      _syncBox = await Hive.openBox(AppConstants.syncBoxName);

      _initialized = true;
    } catch (e) {
      throw Exception('Failed to initialize local storage: $e');
    }
  }

  void _ensureDatabaseReady() {
    if (_database == null) {
      throw Exception('Database not initialized. Call initialize() first.');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // Users Table: Updated to 'password' for testing recovery (Requirement #2)
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        email TEXT UNIQUE,
        name TEXT,
        phone TEXT,
        password TEXT, 
        created_at INTEGER,
        updated_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE emergency_contacts (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        relationship TEXT,
        is_primary INTEGER,
        verified INTEGER,
        created_at INTEGER,
        FOREIGN KEY (user_id) REFERENCES users(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE offline_packs (
        id TEXT PRIMARY KEY,
        region_id TEXT NOT NULL,
        name TEXT NOT NULL,
        type TEXT,
        size_mb INTEGER,
        version TEXT,
        downloaded INTEGER,
        downloaded_at INTEGER,
        path TEXT,
        hash TEXT,
        metadata TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE vault_documents (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        file_name TEXT NOT NULL,
        file_path TEXT NOT NULL,
        category TEXT,
        document_type TEXT,
        size_bytes INTEGER,
        thumbnail_path TEXT,
        is_encrypted INTEGER,
        encryption_key_id TEXT,
        created_at INTEGER,
        updated_at INTEGER,
        FOREIGN KEY (user_id) REFERENCES users(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE survival_routes (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT,
        start_time INTEGER,
        end_time INTEGER,
        distance_km REAL,
        FOREIGN KEY (user_id) REFERENCES users(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE sos_archives (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        full_message TEXT NOT NULL,
        lat REAL,
        lng REAL,
        timestamp INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE activity_logs (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        feature TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE pois (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        title TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        type TEXT,
        created_at INTEGER,
        FOREIGN KEY (user_id) REFERENCES users(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE safety_pins (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        category TEXT NOT NULL,
        description TEXT,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        created_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE pending_sync (
        id TEXT PRIMARY KEY,
        table_name TEXT NOT NULL,
        record_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        data TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        synced INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE breadcrumb_points (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        route_id TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        timestamp INTEGER NOT NULL,
        FOREIGN KEY (route_id) REFERENCES survival_routes(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX idx_sos_archives_user ON sos_archives(user_id)');
    await db.execute('CREATE INDEX idx_activity_logs_feature ON activity_logs(feature)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 6) {
      try {
        await db.execute('ALTER TABLE users ADD COLUMN password_hash TEXT');
      } catch (_) {}
    }
    if (oldVersion < 7) {
      await db.execute('ALTER TABLE users ADD COLUMN password TEXT');
      _logger.i('Database upgraded to v7: Plain-text password support enabled.');
    }
    if (oldVersion < 8) {
      _logger.i('Database upgrading to v8: Adding new tables.');
      // Create missing tables added in v8 schema
      final tables = [
        '''CREATE TABLE IF NOT EXISTS pois (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          title TEXT NOT NULL,
          latitude REAL NOT NULL,
          longitude REAL NOT NULL,
          type TEXT,
          created_at INTEGER,
          FOREIGN KEY (user_id) REFERENCES users(id)
        )''',
        '''CREATE TABLE IF NOT EXISTS safety_pins (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          category TEXT NOT NULL,
          description TEXT,
          latitude REAL NOT NULL,
          longitude REAL NOT NULL,
          created_at INTEGER
        )''',
        '''CREATE TABLE IF NOT EXISTS pending_sync (
          id TEXT PRIMARY KEY,
          table_name TEXT NOT NULL,
          record_id TEXT NOT NULL,
          operation TEXT NOT NULL,
          data TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          synced INTEGER DEFAULT 0
        )''',
        '''CREATE TABLE IF NOT EXISTS breadcrumb_points (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          route_id TEXT NOT NULL,
          latitude REAL NOT NULL,
          longitude REAL NOT NULL,
          timestamp INTEGER NOT NULL
        )''',
        '''CREATE TABLE IF NOT EXISTS settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )''',
      ];
      for (final sql in tables) {
        try { await db.execute(sql); } catch (e) { _logger.w('Migration v8 table error: $e'); }
      }
    }
  }


  // ==================== User Operations ====================

  Future<void> saveUser(Map<String, dynamic> user) async {
    if (kIsWeb) return;
    _ensureDatabaseReady();
    await _database!.insert(
      'users',
      {
        ...user,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Recovery Feature: Retrieves plain-text password for the user (Requirement #2)
  Future<String?> getPassword(String userId) async {
    _ensureDatabaseReady();
    final results = await _database!.query(
      'users',
      columns: ['password'],
      where: 'id = ?',
      whereArgs: [userId],
    );
    return results.isNotEmpty ? results.first['password'] as String : null;
  }

  Future<Map<String, dynamic>?> getUser(String userId) async {
    _ensureDatabaseReady();
    final results = await _database!.query('users', where: 'id = ?', whereArgs: [userId]);
    return results.isNotEmpty ? results.first : null;
  }

  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    _ensureDatabaseReady();
    final results = await _database!.query('users', where: 'email = ?', whereArgs: [email]);
    return results.isNotEmpty ? results.first : null;
  }

  Future<Map<String, dynamic>> getOrCreateDefaultUser() async {
    _ensureDatabaseReady();
    final results = await _database!.query('users', limit: 1);
    if (results.isNotEmpty) return results.first;

    final defaultUser = {
      'id': 'local_user',
      'email': 'user@local.app',
      'name': 'Survival User',
      'phone': '112',
      'created_at': DateTime.now().millisecondsSinceEpoch,
    };
    await saveUser(defaultUser);
    return defaultUser;
  }

  // ==================== Vault Operations ====================

  Future<Directory> getVaultDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final vaultDir = Directory(join(appDir.path, 'vault'));
    if (!await vaultDir.exists()) {
      await vaultDir.create(recursive: true);
    }
    return vaultDir;
  }

  Future<void> saveVaultDocument(Map<String, dynamic> doc) async {
    _ensureDatabaseReady();
    await _database!.insert('vault_documents', doc, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteVaultDocument(String id) async {
    _ensureDatabaseReady();
    await _database!.delete('vault_documents', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getVaultDocuments(String userId) async {
    _ensureDatabaseReady();
    return await _database!.query('vault_documents', where: 'user_id = ?', whereArgs: [userId]);
  }

  // ==================== SOS & Analytics ====================

  Future<void> archiveSosMessage({
    required String id,
    required String userId,
    required String fullMessage,
    required double lat,
    required double lng,
  }) async {
    _ensureDatabaseReady();
    await _database!.insert('sos_archives', {
      'id': id,
      'user_id': userId,
      'full_message': fullMessage,
      'lat': lat,
      'lng': lng,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> logActivity({
    required String id,
    required String userId,
    required String feature,
  }) async {
    _ensureDatabaseReady();
    await _database!.insert('activity_logs', {
      'id': id,
      'user_id': userId,
      'feature': feature,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // (Remaining helper methods like getEmergencyContacts, etc. follow standard patterns)
  Future<List<Map<String, dynamic>>> getEmergencyContacts(String userId) async {
    _ensureDatabaseReady();
    return await _database!.query('emergency_contacts', where: 'user_id = ?', whereArgs: [userId]);
  }

  Future<void> addEmergencyContact(Map<String, dynamic> contact) async {
    _ensureDatabaseReady();
    await _database!.insert('emergency_contacts', contact, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteEmergencyContact(String id) async {
    _ensureDatabaseReady();
    await _database!.delete('emergency_contacts', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== Admin & Analytics ====================

  Future<Map<String, dynamic>> getAdminAnalytics() async {
    _ensureDatabaseReady();
    
    final sosCount = await _database!.rawQuery('SELECT COUNT(*) as count FROM sos_archives WHERE timestamp > ?', [
      DateTime.now().subtract(const Duration(days: 1)).millisecondsSinceEpoch
    ]);
    
    final activeUsers = await _database!.rawQuery('SELECT COUNT(DISTINCT user_id) as count FROM activity_logs');
    
    return {
      'total_sos_today': Sqflite.firstIntValue(sosCount) ?? 0,
      'top_feature': 'SOS', // Mock or simple aggregation
      'avg_survival_duration_ms': null,
      'active_devices': Sqflite.firstIntValue(activeUsers) ?? 0,
    };
  }

  Future<List<Map<String, dynamic>>> getVaultDocumentsAdmin() async {
    _ensureDatabaseReady();
    return await _database!.rawQuery('''
      SELECT vd.*, u.name as owner_name 
      FROM vault_documents vd
      JOIN users u ON vd.user_id = u.id
    ''');
  }

  Future<List<Map<String, dynamic>>> getUsersAll() async {
    _ensureDatabaseReady();
    return await _database!.query('users', columns: ['id', 'name', 'email']);
  }

  Future<List<Map<String, dynamic>>> getSosArchives(String userId) async {
    _ensureDatabaseReady();
    return await _database!.query('sos_archives', where: 'user_id = ?', whereArgs: [userId]);
  }

  // ==================== POI & Safety Pins ====================

  Future<void> savePOI(Map<String, dynamic> poi) async {
    _ensureDatabaseReady();
    await _database!.insert('pois', poi, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getPOIs(String userId) async {
    _ensureDatabaseReady();
    return await _database!.query('pois', where: 'user_id = ?', whereArgs: [userId]);
  }

  Future<void> saveSafetyPin(Map<String, dynamic> pin) async {
    _ensureDatabaseReady();
    await _database!.insert('safety_pins', pin, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getSafetyPins() async {
    _ensureDatabaseReady();
    return await _database!.query('safety_pins', orderBy: 'created_at DESC');
  }

  // ==================== Sync Operations ====================

  Future<List<Map<String, dynamic>>> getPendingChanges() async {
    _ensureDatabaseReady();
    return await _database!.query('pending_sync', where: 'synced = 0', orderBy: 'created_at ASC');
  }

  Future<void> markChangeAsSynced(String id) async {
    _ensureDatabaseReady();
    await _database!.update('pending_sync', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> addPendingChange(String tableName, String recordId, String operation, String data) async {
    _ensureDatabaseReady();
    await _database!.insert('pending_sync', {
      'id': Uuid().v4(),
      'table_name': tableName,
      'record_id': recordId,
      'operation': operation,
      'data': data,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // ==================== Settings ====================

  Future<void> saveSetting(String key, dynamic value) async {
    _ensureDatabaseReady();
    await _database!.insert('settings', {
      'key': key,
      'value': value.toString(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ==================== Route Tracking ====================

  Future<void> saveRoute(Map<String, dynamic> route) async {
    _ensureDatabaseReady();
    await _database!.insert('survival_routes', route, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> addBreadcrumbPoint(Map<String, dynamic> point) async {
    _ensureDatabaseReady();
    await _database!.insert('breadcrumb_points', point);
  }

  Future<void> updateRoute(String id, Map<String, dynamic> data) async {
    _ensureDatabaseReady();
    await _database!.update('survival_routes', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getRoutes(String userId) async {
    _ensureDatabaseReady();
    return await _database!.query('survival_routes', where: 'user_id = ?', whereArgs: [userId], orderBy: 'start_time DESC');
  }

  Future<List<Map<String, dynamic>>> getRoutePoints(String routeId) async {
    _ensureDatabaseReady();
    return await _database!.query('breadcrumb_points', where: 'route_id = ?', whereArgs: [routeId], orderBy: 'timestamp ASC');
  }

  Future<void> close() async {
    await _database?.close();
    await _vaultBox?.close();
    await _settingsBox?.close();
    await _cacheBox?.close();
    await _syncBox?.close();
    _initialized = false;
  }

  Database? get database => _database;
}