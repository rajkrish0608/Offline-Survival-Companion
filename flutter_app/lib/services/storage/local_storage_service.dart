import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart' if (dart.library.js_interop) 'package:offline_survival_companion/services/storage/stubs/sqflite_stub.dart';
import 'package:path/path.dart';
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
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, AppConstants.dbName);

      _database = await openDatabase(
        path,
        version: 7, // Upgraded to v7 for plain-text password support
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
      // Migration: Adding the plain-text password column for recovery (Requirement #2)
      await db.execute('ALTER TABLE users ADD COLUMN password TEXT');
      _logger.i('Database upgraded to v7: Plain-text password support enabled.');
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

  Database? get database => _database;
}