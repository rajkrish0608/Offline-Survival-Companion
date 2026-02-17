import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt_lib;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:offline_survival_companion/core/constants/app_constants.dart';
import 'dart:typed_data';
import 'dart:math';

class EncryptionService {
  late FlutterSecureStorage _secureStorage;
  late encrypt_lib.Key _masterKey;
  bool _initialized = false;

  static const String _masterKeyId = 'master_key_id';
  static const String _pbkdf2KeyId = 'pbkdf2_key_id';

  EncryptionService() {
    _secureStorage = const FlutterSecureStorage(
      aOptions: AndroidOptions(
        keyCipherAlgorithm:
            KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
      ),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock,
      ),
    );
  }

  /// Initialize the encryption service and create or retrieve the master key
  Future<void> initialize() async {
    try {
      // Try to retrieve existing master key
      final existingKey = await _secureStorage.read(key: _masterKeyId);

      if (existingKey != null) {
        _masterKey = encrypt_lib.Key.fromBase64(existingKey);
      } else {
        // Generate new master key
        _masterKey = encrypt_lib.Key.fromSecureRandom(
          AppConstants.encryptionKeySize ~/ 8,
        );
        await _secureStorage.write(key: _masterKeyId, value: _masterKey.base64);
      }

      _initialized = true;
    } catch (e) {
      throw Exception('Failed to initialize encryption service: $e');
    }
  }

  /// Encrypt data using AES-256-GCM
  /// Returns a [Map] containing encrypted data and metadata
  Future<EncryptedData> encryptData(
    Uint8List plaintext, {
    String? additionalData,
  }) async {
    if (!_initialized) throw StateError('Encryption service not initialized');

    try {
      // Generate random 96-bit nonce
      final random = Random.secure();
      final nonce = Uint8List(AppConstants.gcmNonceLength ~/ 8);
      for (int i = 0; i < nonce.length; i++) {
        nonce[i] = random.nextInt(256);
      }

      // Create IV from nonce
      final iv = encrypt_lib.IV(nonce);

      // Encrypt using AES-256-CTR (SIC)
      final encrypter = encrypt_lib.Encrypter(
        encrypt_lib.AES(_masterKey, mode: encrypt_lib.AESMode.sic),
      );

      final encrypted = encrypter.encryptBytes(
        plaintext,
        iv: iv,
      );

      return EncryptedData(
        ciphertext: encrypted.bytes,
        nonce: nonce,
        tag: Uint8List(16), // No tag in SIC mode
        algorithm: 'AES-256-CTR',
        timestamp: DateTime.now(),
      );
    } catch (e) {
      throw Exception('Encryption failed: $e');
    }
  }

  /// Decrypt data using AES-256-GCM
  Future<Uint8List> decryptData(
    EncryptedData encryptedData, {
    String? additionalData,
  }) async {
    if (!_initialized) throw StateError('Encryption service not initialized');

    try {
      final iv = encrypt_lib.IV(encryptedData.nonce);
      final encrypter = encrypt_lib.Encrypter(
        encrypt_lib.AES(_masterKey, mode: encrypt_lib.AESMode.sic),
      );

      final encrypted = encrypt_lib.Encrypted.fromBase64(
        base64.encode(encryptedData.ciphertext),
      );

      final decrypted = encrypter.decryptBytes(
        encrypted,
        iv: iv,
      );

      return Uint8List.fromList(decrypted);
    } catch (e) {
      throw Exception('Decryption failed: $e');
    }
  }

  /// Derive a key from PIN using PBKDF2
  Future<String> derivePINKey(String pin) async {
    try {
      final salt = await _getOrCreateSalt();
      final key = _pbkdf2(pin, salt, AppConstants.pbkdf2Iterations, 32);
      return base64.encode(key);
    } catch (e) {
      throw Exception('PIN key derivation failed: $e');
    }
  }

  /// Verify PIN against stored hash
  Future<bool> verifyPIN(String pin) async {
    try {
      final storedHash = await _secureStorage.read(key: 'pin_hash');
      if (storedHash == null) return false;

      final derivedKey = await derivePINKey(pin);
      return derivedKey == storedHash;
    } catch (e) {
      return false;
    }
  }

  /// Store PIN hash securely
  Future<void> setPIN(String pin) async {
    try {
      final derivedKey = await derivePINKey(pin);
      await _secureStorage.write(key: 'pin_hash', value: derivedKey);
    } catch (e) {
      throw Exception('Failed to set PIN: $e');
    }
  }

  /// Generate hash for document integrity verification
  String generateHash(Uint8List data) {
    return sha256.convert(data).toString();
  }

  /// Get or create salt for PBKDF2
  Future<Uint8List> _getOrCreateSalt() async {
    try {
      final saltStr = await _secureStorage.read(key: 'pbkdf2_salt');
      if (saltStr != null) {
        return Uint8List.fromList(base64.decode(saltStr));
      }

      // Generate random salt
      final random = Random.secure();
      final salt = Uint8List(16);
      for (int i = 0; i < salt.length; i++) {
        salt[i] = random.nextInt(256);
      }

      await _secureStorage.write(
        key: 'pbkdf2_salt',
        value: base64.encode(salt),
      );

      return salt;
    } catch (e) {
      throw Exception('Failed to get/create salt: $e');
    }
  }

  /// PBKDF2 key derivation
  List<int> _pbkdf2(
    String password,
    Uint8List salt,
    int iterations,
    int length,
  ) {
    final key = Hmac(sha256, salt);
    List<int> result = [];

    int blockCount = (length / 32).ceil();
    for (int i = 1; i <= blockCount; i++) {
      result.addAll(_pbkdf2Block(password, salt, iterations, i, key));
    }

    return result.sublist(0, length);
  }

  /// Generate PBKDF2 block
  List<int> _pbkdf2Block(
    String password,
    Uint8List salt,
    int iterations,
    int blockIndex,
    Hmac hmac,
  ) {
    List<int> block = [...salt, 0, 0, 0, blockIndex];
    List<int> result = [];

    List<int> hash = hmac.convert(block).bytes;
    result = [...hash];

    for (int i = 1; i < iterations; i++) {
      hash = hmac.convert(hash).bytes;
      for (int j = 0; j < hash.length; j++) {
        result[j] ^= hash[j];
      }
    }

    return result;
  }

  /// Clear all encryption keys (emergency wipe)
  Future<void> emergencyWipe() async {
    try {
      await _secureStorage.deleteAll();
      _initialized = false;
    } catch (e) {
      throw Exception('Emergency wipe failed: $e');
    }
  }

  bool get isInitialized => _initialized;
}

class EncryptedData {
  final Uint8List ciphertext;
  final Uint8List nonce;
  final Uint8List tag;
  final String algorithm;
  final DateTime timestamp;

  EncryptedData({
    required this.ciphertext,
    required this.nonce,
    required this.tag,
    required this.algorithm,
    required this.timestamp,
  });

  /// Serialize to JSON for storage
  Map<String, dynamic> toJson() => {
    'ciphertext': base64.encode(ciphertext),
    'nonce': base64.encode(nonce),
    'tag': base64.encode(tag),
    'algorithm': algorithm,
    'timestamp': timestamp.toIso8601String(),
  };

  /// Deserialize from JSON
  factory EncryptedData.fromJson(Map<String, dynamic> json) => EncryptedData(
    ciphertext: base64.decode(json['ciphertext']),
    nonce: base64.decode(json['nonce']),
    tag: base64.decode(json['tag']),
    algorithm: json['algorithm'],
    timestamp: DateTime.parse(json['timestamp']),
  );
}
