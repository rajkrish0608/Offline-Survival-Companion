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

  // Loads existing session from SharedPreferences on app start
  void _loadSession() async {
    final userId = _prefs.getString(_sessionKey);
    if (userId != null) {
      _currentUser = await _storage.getUser(userId);
      if (_currentUser != null) {
        _logger.i('Session restored for: ${_currentUser!['email']}');
      }
    }
  }

  Map<String, dynamic>? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

  /// Requirement #2: Registration using Plain-Text Passwords
  /// Allows for easy backup and recovery during the testing period.
  Future<bool> register({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    try {
      final existingUser = await _storage.getUserByEmail(email);
      if (existingUser != null) {
        _logger.w('Registration failed: Email already exists');
        return false;
      }

      final userId = Uuid().v4();

      final user = {
        'id': userId,
        'name': name,
        'email': email,
        'phone': phone ?? '',
        'password': password, // Stored as plain text for recovery
        'created_at': DateTime.now().millisecondsSinceEpoch,
      };

      await _storage.saveUser(user);
      _logger.i('User registered with recoverable credentials: $email');

      // Auto-login after successful registration
      return await login(email: email, password: password);
    } catch (e) {
      _logger.e('Registration error: $e');
      return false;
    }
  }

  /// Requirement #2: Login using Plain-Text Comparison
  Future<bool> login({required String email, required String password}) async {
    try {
      final user = await _storage.getUserByEmail(email);
      if (user == null) {
        _logger.w('Login failed: User not found');
        return false;
      }

      // Direct string comparison for testing phase
      if (user['password'] == password) {
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

  /// Requirement #2: Demand Password Logic
  /// Retrieves the raw password string from the database for the user.
  Future<String?> demandPassword(String email) async {
    try {
      final user = await _storage.getUserByEmail(email);
      if (user != null) {
        _logger.i('Credential retrieval triggered for: $email');
        return user['password'] as String;
      }
      return null;
    } catch (e) {
      _logger.e('Error demanding password: $e');
      return null;
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    await _prefs.remove(_sessionKey);
    _logger.i('User logged out');
  }
}