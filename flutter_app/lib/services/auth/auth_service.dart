import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:offline_survival_companion/services/storage/local_storage_service.dart';
import 'package:uuid/uuid.dart';

class AuthService {
  final LocalStorageService _storage;
  final SharedPreferences _prefs;
  final Logger _logger = Logger();

  static const String _sessionKey = 'current_user_id';
  Map<String, dynamic>? _currentUser;

  AuthService(this._storage, this._prefs) {
    _loadSession();
  }

  void _loadSession() async {
    final userId = _prefs.getString(_sessionKey);
    if (userId != null) {
      _currentUser = await _storage.getUser(userId);
    }
  }

  Map<String, dynamic>? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

  String _hashPassword(String password) {
    // Basic SHA-256 hash. In production with a backend, use bcrypt/argon2.
    // For local SQLite storage, this prevents plain-text storage.
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final existingUser = await _storage.getUserByEmail(email);
      if (existingUser != null) {
        _logger.w('Registration failed: Email already exists');
        return false;
      }

      final userId = const Uuid().v4();
      final hashedPassword = _hashPassword(password);

      final user = {
        'id': userId,
        'name': name,
        'email': email,
        'password_hash': hashedPassword,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      };

      await _storage.saveUser(user);
      _logger.i('User registered securely: $email');

      // Auto-login after registration
      return await login(email: email, password: password);
    } catch (e) {
      _logger.e('Registration error: $e');
      return false;
    }
  }

  Future<bool> login({required String email, required String password}) async {
    try {
      final user = await _storage.getUserByEmail(email);
      if (user == null) {
        _logger.w('Login failed: User not found');
        return false;
      }

      final hashedPassword = _hashPassword(password);
      if (user['password_hash'] == hashedPassword) {
        _currentUser = user;
        await _prefs.setString(_sessionKey, user['id'] as String);
        _logger.i('User logged in: $email');
        return true;
      } else {
        _logger.w('Login failed: Incorrect password');
        return false;
      }
    } catch (e) {
      _logger.e('Login error: $e');
      return false;
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    await _prefs.remove(_sessionKey);
    _logger.i('User logged out');
  }
}
