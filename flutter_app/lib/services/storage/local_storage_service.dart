import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart' if (dart.library.js_interop) 'package:offline_survival_companion/services/storage/stubs/sqflite_stub.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive/hive.dart';
import 'package:logger/logger.dart';
import 'package:offline_survival_companion/core/constants/app_constants.dart';
import 'dart:io' if (dart.library.js_interop) 'package:offline_survival_companion/services/storage/stubs/io_stub.dart';

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

  Future<void> initialize() async {
    if (kIsWeb) {
      _logger.i('Running on Web: Bypassing LocalStorage initialization.');
      _initialized = true;
      return;
    }
    try {
      // Initialize SQLite
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, AppConstants.dbName);

      _database = await openDatabase(
        path,
        version: 6,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );

      // Enable WAL mode for concurrent access
      // Note: SQLite on some platforms returns "not an error" as a success string — that is OK.
      try {
        await _database!.execute('PRAGMA journal_mode=WAL');
      } catch (e) {
        _logger.w('WAL mode not available: $e');
      }

      // Initialize Hive boxes
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
    // Users & Authentication
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        email TEXT UNIQUE,
        name TEXT,
        phone TEXT,
        password_hash TEXT,
        created_at INTEGER,
        updated_at INTEGER
      )
    ''');

    // Emergency Contacts
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

    // Offline Packs
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

    // Downloaded Content
    await db.execute('''
      CREATE TABLE downloaded_content (
        id TEXT PRIMARY KEY,
        pack_id TEXT NOT NULL,
        content_type TEXT,
        file_name TEXT,
        file_path TEXT,
        size_bytes INTEGER,
        created_at INTEGER,
        FOREIGN KEY (pack_id) REFERENCES offline_packs(id)
      )
    ''');

    // First Aid Database
    await db.execute('''
      CREATE TABLE first_aid_articles (
        id TEXT PRIMARY KEY,
        category TEXT NOT NULL,
        title TEXT NOT NULL,
        content TEXT,
        symptoms TEXT,
        treatment TEXT,
        precautions TEXT,
        severity TEXT,
        created_at INTEGER
      )
    ''');

    // Create FTS5 index for search (optional - not available on all platforms)
    try {
      await db.execute('''
        CREATE VIRTUAL TABLE first_aid_fts USING fts5(
          title,
          content,
          category,
          content=first_aid_articles,
          content_rowid=rowid
        )
      ''');
      _fts5Available = true;
    } catch (e) {
      _logger.w('FTS5 not available, falling back to LIKE-based search');
      _fts5Available = false;
    }

    // Document Metadata (Vault)
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

    // QR Codes Storage
    await db.execute('''
      CREATE TABLE qr_codes (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        data TEXT NOT NULL,
        image_path TEXT,
        category TEXT,
        label TEXT,
        created_at INTEGER,
        FOREIGN KEY (user_id) REFERENCES users(id)
      )
    ''');

    // Saved Web Pages
    await db.execute('''
      CREATE TABLE saved_web_pages (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        title TEXT,
        url TEXT,
        content TEXT,
        html_path TEXT,
        created_at INTEGER,
        FOREIGN KEY (user_id) REFERENCES users(id)
      )
    ''');

    // Sync Metadata
    await db.execute('''
      CREATE TABLE sync_metadata (
        id TEXT PRIMARY KEY,
        table_name TEXT NOT NULL,
        last_sync INTEGER,
        vector_clock TEXT
      )
    ''');

    // Custom Map POIs
    await db.execute('''
      CREATE TABLE map_pois (
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

    // Survival Routes
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

    // Breadcrumb Points
    await db.execute('''
      CREATE TABLE breadcrumb_points (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        route_id TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        timestamp INTEGER,
        FOREIGN KEY (route_id) REFERENCES survival_routes(id) ON DELETE CASCADE
      )
    ''');

    // Crowdsourced Safety Pins
    await db.execute('''
      CREATE TABLE safety_pins (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        category TEXT NOT NULL,
        description TEXT,
        is_synced INTEGER DEFAULT 0,
        created_at INTEGER,
        FOREIGN KEY (user_id) REFERENCES users(id)
      )
    ''');

    // Pending Changes (Outbox Pattern)
    await db.execute('''
      CREATE TABLE pending_changes (
        id TEXT PRIMARY KEY,
        table_name TEXT NOT NULL,
        record_id TEXT,
        operation TEXT,
        data TEXT,
        created_at INTEGER,
        synced INTEGER
      )
    ''');

    // SOS Archives (immutable legal record)
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

    // Activity Logs (for feature analytics)
    await db.execute('''
      CREATE TABLE activity_logs (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        feature TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id)
      )
    ''');

    // Create indexes
    await db.execute(
      'CREATE INDEX idx_emergency_contacts_user ON emergency_contacts(user_id)',
    );
    await db.execute(
      'CREATE INDEX idx_vault_documents_user ON vault_documents(user_id)',
    );
    await db.execute('CREATE INDEX idx_qr_codes_user ON qr_codes(user_id)');
    await db.execute(
      'CREATE INDEX idx_saved_web_pages_user ON saved_web_pages(user_id)',
    );
    await db.execute(
      'CREATE INDEX idx_offline_packs_region ON offline_packs(region_id)',
    );
    await db.execute(
      'CREATE INDEX idx_pending_changes_synced ON pending_changes(synced)',
    );
    await db.execute(
      'CREATE INDEX idx_safety_pins_user ON safety_pins(user_id)',
    );
    await db.execute(
      'CREATE INDEX idx_safety_pins_synced ON safety_pins(is_synced)',
    );
    await db.execute(
      'CREATE INDEX idx_sos_archives_user ON sos_archives(user_id)',
    );
    await db.execute(
      'CREATE INDEX idx_activity_logs_feature ON activity_logs(feature)',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE map_pois (
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
    }
    if (oldVersion < 3) {
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
        CREATE TABLE breadcrumb_points (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          route_id TEXT NOT NULL,
          latitude REAL NOT NULL,
          longitude REAL NOT NULL,
          timestamp INTEGER,
          FOREIGN KEY (route_id) REFERENCES survival_routes(id) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE safety_pins (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          latitude REAL NOT NULL,
          longitude REAL NOT NULL,
          category TEXT NOT NULL,
          description TEXT,
          is_synced INTEGER DEFAULT 0,
          created_at INTEGER,
          FOREIGN KEY (user_id) REFERENCES users(id)
        )
      ''');
      await db.execute(
        'CREATE INDEX idx_safety_pins_user ON safety_pins(user_id)',
      );
      await db.execute(
        'CREATE INDEX idx_safety_pins_synced ON safety_pins(is_synced)',
      );
    }
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sos_archives (
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
        CREATE TABLE IF NOT EXISTS activity_logs (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          feature TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          FOREIGN KEY (user_id) REFERENCES users(id)
        )
      ''');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_sos_archives_user ON sos_archives(user_id)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_activity_logs_feature ON activity_logs(feature)');
    }
    if (oldVersion < 6) {
      await db.execute('ALTER TABLE users ADD COLUMN password_hash TEXT');
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
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getUser(String userId) async {
    _ensureDatabaseReady();
    final results = await _database!.query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    _ensureDatabaseReady();
    final results = await _database!.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<String> getOrCreateDefaultUser() async {
    _ensureDatabaseReady();
    final users = await _database!.query('users', limit: 1);
    
    if (users.isNotEmpty) {
      return users.first['id'] as String;
    }

    final id = 'local_user_${DateTime.now().millisecondsSinceEpoch}';
    await saveUser({
      'id': id,
      'name': 'Local User',
      'email': 'local@example.com',
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    
    return id;
  }

  // ==================== Emergency Contacts ====================

  Future<void> addEmergencyContact(Map<String, dynamic> contact) async {
    _ensureDatabaseReady();
    await _database!.insert(
      'emergency_contacts',
      contact,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getEmergencyContacts(String userId) async {
    _ensureDatabaseReady();
    return await _database!.query(
      'emergency_contacts',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'is_primary DESC, created_at ASC',
    );
  }

  Future<void> deleteEmergencyContact(String contactId) async {
    _ensureDatabaseReady();
    await _database!.delete(
      'emergency_contacts',
      where: 'id = ?',
      whereArgs: [contactId],
    );
  }

  // ==================== Offline Packs ====================

  Future<void> savePack(Map<String, dynamic> pack) async {
    _ensureDatabaseReady();
    await _database!.insert(
      'offline_packs',
      pack,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getDownloadedPacks() async {
    _ensureDatabaseReady();
    return await _database!.query(
      'offline_packs',
      where: 'downloaded = ?',
      whereArgs: [1],
    );
  }

  Future<void> deletePack(String packId) async {
    _ensureDatabaseReady();
    await _database!.delete(
      'offline_packs',
      where: 'id = ?',
      whereArgs: [packId],
    );
  }

  // ==================== First Aid ====================

  Future<void> saveFirstAidArticle(Map<String, dynamic> article) async {
    _ensureDatabaseReady();
    await _database!.insert(
      'first_aid_articles',
      article,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> searchFirstAid(String query) async {
    _ensureDatabaseReady();
    if (_fts5Available) {
      return await _database!.rawQuery(
        '''
        SELECT a.* FROM first_aid_articles a
        WHERE a.id IN (
          SELECT rowid FROM first_aid_fts WHERE first_aid_fts MATCH ?
        )
      ''',
        ['$query*'],
      );
    } else {
      // Fallback to LIKE-based search when FTS5 is not available
      final likeQuery = '%$query%';
      return await _database!.query(
        'first_aid_articles',
        where: 'title LIKE ? OR content LIKE ? OR category LIKE ?',
        whereArgs: [likeQuery, likeQuery, likeQuery],
      );
    }
  }

  Future<List<Map<String, dynamic>>> getFirstAidByCategory(
    String category,
  ) async {
    _ensureDatabaseReady();
    return await _database!.query(
      'first_aid_articles',
      where: 'category = ?',
      whereArgs: [category],
    );
  }

  // ==================== Vault Operations ====================

  Future<void> saveVaultDocument(Map<String, dynamic> doc) async {
    _ensureDatabaseReady();
    await _database!.insert(
      'vault_documents',
      doc,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getVaultDocuments(String userId) async {
    _ensureDatabaseReady();
    return await _database!.query(
      'vault_documents',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
  }

  Future<void> deleteVaultDocument(String docId) async {
    _ensureDatabaseReady();
    await _database!.delete(
      'vault_documents',
      where: 'id = ?',
      whereArgs: [docId],
    );
  }

  // ==================== QR Codes ====================

  Future<void> saveQRCode(Map<String, dynamic> qrCode) async {
    _ensureDatabaseReady();
    await _database!.insert(
      'qr_codes',
      qrCode,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getQRCodes(String userId) async {
    _ensureDatabaseReady();
    return await _database!.query(
      'qr_codes',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
  }

  // ==================== POI Operations ====================

  Future<void> savePOI(Map<String, dynamic> poi) async {
    _ensureDatabaseReady();
    await _database!.insert(
      'map_pois',
      poi,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getPOIs(String userId) async {
    _ensureDatabaseReady();
    return await _database!.query(
      'map_pois',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
  }

  Future<void> deletePOI(String poiId) async {
    _ensureDatabaseReady();
    await _database!.delete(
      'map_pois',
      where: 'id = ?',
      whereArgs: [poiId],
    );
  }

  // ==================== Route Operations ====================

  Future<void> saveRoute(Map<String, dynamic> route) async {
    _ensureDatabaseReady();
    await _database!.insert(
      'survival_routes',
      route,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> addBreadcrumbPoint(Map<String, dynamic> point) async {
    _ensureDatabaseReady();
    await _database!.insert(
      'breadcrumb_points',
      point,
    );
  }

  Future<List<Map<String, dynamic>>> getRoutes(String userId) async {
    _ensureDatabaseReady();
    return await _database!.query(
      'survival_routes',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'start_time DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getRoutePoints(String routeId) async {
    _ensureDatabaseReady();
    return await _database!.query(
      'breadcrumb_points',
      where: 'route_id = ?',
      whereArgs: [routeId],
      orderBy: 'timestamp ASC',
    );
  }

  Future<void> updateRoute(String routeId, Map<String, dynamic> data) async {
    _ensureDatabaseReady();
    await _database!.update(
      'survival_routes',
      data,
      where: 'id = ?',
      whereArgs: [routeId],
    );
  }

  Future<void> deleteRoute(String routeId) async {
    _ensureDatabaseReady();
    await _database!.delete(
      'survival_routes',
      where: 'id = ?',
      whereArgs: [routeId],
    );
  }

  // ==================== Safety Pin Operations ====================

  Future<void> saveSafetyPin(Map<String, dynamic> pin) async {
    _ensureDatabaseReady();
    await _database!.insert(
      'safety_pins',
      pin,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getSafetyPins() async {
    _ensureDatabaseReady();
    return await _database!.query(
      'safety_pins',
      orderBy: 'created_at DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getUnsyncedSafetyPins() async {
    _ensureDatabaseReady();
    return await _database!.query(
      'safety_pins',
      where: 'is_synced = ?',
      whereArgs: [0],
    );
  }

  Future<void> markSafetyPinSynced(String pinId) async {
    _ensureDatabaseReady();
    await _database!.update(
      'safety_pins',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [pinId],
    );
  }

  Future<void> deleteSafetyPin(String pinId) async {
    _ensureDatabaseReady();
    await _database!.delete(
      'safety_pins',
      where: 'id = ?',
      whereArgs: [pinId],
    );
  }

  // ==================== Hive Operations ====================

  Future<void> saveSetting(String key, dynamic value) async {
    if (kIsWeb) {
      _webSettings[key] = value;
      return;
    }
    if (_settingsBox == null) {
      throw Exception('Settings storage not initialized');
    }
    await _settingsBox!.put(key, value);
  }

  dynamic getSetting(String key) {
    if (kIsWeb) return _webSettings[key];
    if (_settingsBox == null) return null;
    return _settingsBox!.get(key);
  }

  Future<void> removeSettings(List<String> keys) async {
    if (_settingsBox == null) return;
    for (String key in keys) {
      await _settingsBox!.delete(key);
    }
  }

  // ==================== Sync Operations ====================

  Future<void> addPendingChange(
    String tableName,
    String recordId,
    String operation,
    String data,
  ) async {
    _ensureDatabaseReady();
    await _database!.insert('pending_changes', {
      'id': '${tableName}_${recordId}_${DateTime.now().millisecondsSinceEpoch}',
      'table_name': tableName,
      'record_id': recordId,
      'operation': operation,
      'data': data,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'synced': 0,
    });
  }

  Future<List<Map<String, dynamic>>> getPendingChanges() async {
    _ensureDatabaseReady();
    return await _database!.query(
      'pending_changes',
      where: 'synced = ?',
      whereArgs: [0],
    );
  }

  Future<void> markChangeAsSynced(String changeId) async {
    _ensureDatabaseReady();
    await _database!.update(
      'pending_changes',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [changeId],
    );
  }

  // ==================== File Operations ====================

  Future<Directory> getVaultDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final vaultDir = Directory('${appDir.path}/${AppConstants.vaultPath}');
    if (!await vaultDir.exists()) {
      await vaultDir.create(recursive: true);
    }
    return vaultDir;
  }

  Future<Directory> getMapsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final mapsDir = Directory('${appDir.path}/${AppConstants.mapsPath}');
    if (!await mapsDir.exists()) {
      await mapsDir.create(recursive: true);
    }
    return mapsDir;
  }

  Future<Directory> getCacheDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${appDir.path}/${AppConstants.cachePath}');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  // ==================== SOS Archives ====================

  Future<void> archiveSosMessage({
    required String id,
    required String userId,
    required String fullMessage,
    required double lat,
    required double lng,
  }) async {
    if (kIsWeb) return;
    _ensureDatabaseReady();
    await _database!.insert(
      'sos_archives',
      {
        'id': id,
        'user_id': userId,
        'full_message': fullMessage,
        'lat': lat,
        'lng': lng,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<Map<String, dynamic>>> getSosArchives(String userId) async {
    _ensureDatabaseReady();
    return await _database!.query(
      'sos_archives',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'timestamp DESC',
    );
  }

  // ==================== Activity Logs ====================

  Future<void> logActivity({
    required String id,
    required String userId,
    required String feature,
  }) async {
    if (kIsWeb) return;
    _ensureDatabaseReady();
    await _database!.insert('activity_logs', {
      'id': id,
      'user_id': userId,
      'feature': feature,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // ==================== Admin Analytics ====================

  /// Returns aggregated KPIs only — no individual tracking data.
  Future<Map<String, dynamic>> getAdminAnalytics() async {
    _ensureDatabaseReady();
    final since24h =
        DateTime.now().subtract(const Duration(hours: 24)).millisecondsSinceEpoch;

    // KPI 1: Total SOS events in last 24 hours
    final sosResult = await _database!.rawQuery(
      'SELECT COUNT(*) as count FROM sos_archives WHERE timestamp >= ?',
      [since24h],
    );
    final totalSosToday = (sosResult.first['count'] as int?) ?? 0;

    // KPI 2: Most used feature (returns feature id with highest count)
    final featureResult = await _database!.rawQuery(
      '''
      SELECT feature, COUNT(*) as cnt
      FROM activity_logs
      GROUP BY feature
      ORDER BY cnt DESC
      LIMIT 1
      ''',
    );
    final topFeature = featureResult.isNotEmpty
        ? (featureResult.first['feature'] as String? ?? '—')
        : '—';

    // KPI 3: Average survival mode session duration (ms)
    final survivalResult = await _database!.rawQuery(
      '''
      SELECT AVG(end_time - start_time) as avg_duration
      FROM survival_routes
      WHERE end_time IS NOT NULL AND end_time > start_time
      ''',
    );
    final avgDuration = survivalResult.isNotEmpty
        ? survivalResult.first['avg_duration']
        : null;

    // KPI 4: Unique active devices in last 24 hours
    final devicesResult = await _database!.rawQuery(
      '''
      SELECT COUNT(DISTINCT user_id) as count
      FROM activity_logs
      WHERE created_at >= ?
      ''',
      [since24h],
    );
    final activeDevices = (devicesResult.first['count'] as int?) ?? 0;

    return {
      'total_sos_today': totalSosToday,
      'top_feature': topFeature,
      'avg_survival_duration_ms': avgDuration,
      'active_devices': activeDevices,
    };
  }

  // ==================== Admin Vault Review ====================

  /// Returns all vault documents joined with user name — for admin use only.
  Future<List<Map<String, dynamic>>> getVaultDocumentsAdmin() async {
    _ensureDatabaseReady();
    return await _database!.rawQuery(
      '''
      SELECT v.*, u.name as owner_username
      FROM vault_documents v
      LEFT JOIN users u ON v.user_id = u.id
      ORDER BY v.created_at DESC
      ''',
    );
  }

  /// Returns all users (id, name, email only — no sensitive data).
  Future<List<Map<String, dynamic>>> getUsersAll() async {
    _ensureDatabaseReady();
    return await _database!.query(
      'users',
      columns: ['id', 'name', 'email'],
      orderBy: 'name ASC',
    );
  }

  // ==================== Cleanup ====================

  Future<void> close() async {
    await _database?.close();
    await _vaultBox?.close();
    await _settingsBox?.close();
    await _cacheBox?.close();
    await _syncBox?.close();
  }

  bool get isInitialized => _initialized;
  Database? get database => _database;
}
