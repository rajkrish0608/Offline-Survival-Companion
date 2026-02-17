import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive/hive.dart';
import 'package:offline_survival_companion/core/constants/app_constants.dart';
import 'dart:io';

class LocalStorageService {
  late Database _database;
  late Box<dynamic> _vaultBox;
  late Box<dynamic> _settingsBox;
  late Box<dynamic> _cacheBox;
  late Box<dynamic> _syncBox;
  bool _initialized = false;

  Future<void> initialize() async {
    try {
      // Initialize SQLite
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, AppConstants.dbName);

      _database = await openDatabase(
        path,
        version: 1,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );

      // Enable WAL mode for concurrent access
      // Enable WAL mode for concurrent access
      try {
        await _database.execute('PRAGMA journal_mode=WAL');
      } catch (e) {
        print('Failed to enable WAL mode: $e');
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

  Future<void> _onCreate(Database db, int version) async {
    // Users & Authentication
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        email TEXT UNIQUE,
        name TEXT,
        phone TEXT,
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

    // Create FTS5 index for search
    await db.execute('''
      CREATE VIRTUAL TABLE first_aid_fts USING fts5(
        title,
        content,
        category,
        content=first_aid_articles,
        content_rowid=rowid
      )
    ''');

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
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle schema migrations here
  }

  // ==================== User Operations ====================

  Future<void> saveUser(Map<String, dynamic> user) async {
    await _database.insert('users', {
      ...user,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getUser(String userId) async {
    final results = await _database.query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
    );
    return results.isNotEmpty ? results.first : null;
  }

  // ==================== Emergency Contacts ====================

  Future<void> addEmergencyContact(Map<String, dynamic> contact) async {
    await _database.insert(
      'emergency_contacts',
      contact,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getEmergencyContacts(String userId) async {
    return await _database.query(
      'emergency_contacts',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'is_primary DESC, created_at ASC',
    );
  }

  Future<void> deleteEmergencyContact(String contactId) async {
    await _database.delete(
      'emergency_contacts',
      where: 'id = ?',
      whereArgs: [contactId],
    );
  }

  // ==================== Offline Packs ====================

  Future<void> savePack(Map<String, dynamic> pack) async {
    await _database.insert(
      'offline_packs',
      pack,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getDownloadedPacks() async {
    return await _database.query(
      'offline_packs',
      where: 'downloaded = ?',
      whereArgs: [1],
    );
  }

  Future<void> deletePack(String packId) async {
    await _database.delete(
      'offline_packs',
      where: 'id = ?',
      whereArgs: [packId],
    );
  }

  // ==================== First Aid ====================

  Future<void> saveFirstAidArticle(Map<String, dynamic> article) async {
    await _database.insert(
      'first_aid_articles',
      article,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> searchFirstAid(String query) async {
    return await _database.rawQuery(
      '''
      SELECT a.* FROM first_aid_articles a
      WHERE a.id IN (
        SELECT rowid FROM first_aid_fts WHERE first_aid_fts MATCH ?
      )
    ''',
      ['$query*'],
    );
  }

  Future<List<Map<String, dynamic>>> getFirstAidByCategory(
    String category,
  ) async {
    return await _database.query(
      'first_aid_articles',
      where: 'category = ?',
      whereArgs: [category],
    );
  }

  // ==================== Vault Operations ====================

  Future<void> saveVaultDocument(Map<String, dynamic> doc) async {
    await _database.insert(
      'vault_documents',
      doc,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getVaultDocuments(String userId) async {
    return await _database.query(
      'vault_documents',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
  }

  Future<void> deleteVaultDocument(String docId) async {
    await _database.delete(
      'vault_documents',
      where: 'id = ?',
      whereArgs: [docId],
    );
  }

  // ==================== QR Codes ====================

  Future<void> saveQRCode(Map<String, dynamic> qrCode) async {
    await _database.insert(
      'qr_codes',
      qrCode,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getQRCodes(String userId) async {
    return await _database.query(
      'qr_codes',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
  }

  // ==================== Hive Operations ====================

  Future<void> saveSetting(String key, dynamic value) async {
    await _settingsBox.put(key, value);
  }

  dynamic getSetting(String key) => _settingsBox.get(key);

  Future<void> removeSettings(List<String> keys) async {
    for (String key in keys) {
      await _settingsBox.delete(key);
    }
  }

  // ==================== Sync Operations ====================

  Future<void> addPendingChange(
    String tableName,
    String recordId,
    String operation,
    String data,
  ) async {
    await _database.insert('pending_changes', {
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
    return await _database.query(
      'pending_changes',
      where: 'synced = ?',
      whereArgs: [0],
    );
  }

  Future<void> markChangeAsSynced(String changeId) async {
    await _database.update(
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

  // ==================== Cleanup ====================

  Future<void> close() async {
    await _database.close();
    await _vaultBox.close();
    await _settingsBox.close();
    await _cacheBox.close();
    await _syncBox.close();
  }

  bool get isInitialized => _initialized;
  Database get database => _database;
}
