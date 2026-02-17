class AppConstants {
  // App Info
  static const String appName = 'Offline Survival Companion';
  static const String appVersion = '1.0.0';

  // Storage
  static const String dbName = 'offline_survival.db';
  static const String vaultBoxName = 'vault_box';
  static const String settingsBoxName = 'settings_box';
  static const String cacheBoxName = 'cache_box';
  static const String syncBoxName = 'sync_box';

  // Vault
  static const String vaultPath = 'vault';
  static const String documentsPath = 'documents';
  static const String mapsPath = 'maps';
  static const String cachePath = 'cache';

  // Encryption
  static const int encryptionKeySize = 256; // bits
  static const int pbkdf2Iterations = 100000;
  static const int gcmNonceLength = 96; // bits

  // Emergency
  static const int sosDefaultDuration = 3000; // milliseconds
  static const int sosLocationUpdateInterval = 60000; // milliseconds
  static const int maxEmergencyContacts = 5;
  static const int minEmergencyContacts = 1;

  // Battery
  static const double lowBatteryThreshold = 0.15; // 15%

  // Sync
  static const int syncRetryDelayMs = 1000;
  static const int syncMaxRetries = 5;
  static const int syncTimeout = 30000; // milliseconds

  // Maps
  static const double mapDefaultZoom = 12.0;
  static const double mapMaxZoom = 18.0;
  static const double mapMinZoom = 2.0;

  // Permissions
  static const List<String> requiredPermissions = ['LOCATION', 'STORAGE'];

  static const List<String> optionalPermissions = ['SMS', 'CAMERA', 'CALL_LOG'];

  // API
  static const String apiBaseUrl = 'https://api.offline-survival.app';
  static const Duration apiTimeout = Duration(seconds: 30);

  // Features
  static const bool enableBiometric = true;
  static const bool enableOfflineMap = true;
  static const bool enableDocumentVault = true;
  static const bool enableEmergencyMode = true;
  static const bool enableAutoSync = true;
}
