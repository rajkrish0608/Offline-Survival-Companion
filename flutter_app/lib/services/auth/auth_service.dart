import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:offline_survival_companion/core/constants/app_constants.dart';

class AuthService {
  final SharedPreferences _prefs;
  final Logger _logger = Logger();

  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'current_user';

  Map<String, dynamic>? _currentUser;
  String? _token;

  AuthService(this._prefs) {
    _loadSession();
  }

  void _loadSession() {
    final userJson = _prefs.getString(_userKey);
    _token = _prefs.getString(_tokenKey);
    if (userJson != null && _token != null) {
      _currentUser = jsonDecode(userJson);
      _logger.i('Session restored for: ${_currentUser!['email']}');
    }
  }

  Map<String, dynamic>? get currentUser => _currentUser;
  String? get token => _token;
  bool get isAuthenticated => _currentUser != null && _token != null;

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          'phone': phone ?? '',
        }),
      ).timeout(AppConstants.apiTimeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        _token = data['token'];
        _currentUser = data['user'];
        await _prefs.setString(_tokenKey, _token!);
        await _prefs.setString(_userKey, jsonEncode(_currentUser));
        _logger.i('User registered: $email');
        return true;
      } else {
        _logger.w('Registration failed: ${data['message']}');
        return false;
      }
    } catch (e) {
      _logger.e('Registration error: $e');
      return false;
    }
  }

  Future<bool> login({required String email, required String password}) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      ).timeout(AppConstants.apiTimeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        _token = data['token'];
        _currentUser = data['user'];
        await _prefs.setString(_tokenKey, _token!);
        await _prefs.setString(_userKey, jsonEncode(_currentUser));
        _logger.i('User logged in: $email');
        return true;
      } else {
        _logger.w('Login failed: ${data['message']}');
        return false;
      }
    } catch (e) {
      _logger.e('Login error: $e');
      return false;
    }
  }

  Future<void> logout() async {
    try {
      if (_token != null) {
        await http.post(
          Uri.parse('${AppConstants.apiBaseUrl}/auth/logout'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_token',
          },
        ).timeout(const Duration(seconds: 5));
      }
    } catch (_) {
      // Ignore logout API errors — clear local session regardless
    }
    _currentUser = null;
    _token = null;
    await _prefs.remove(_tokenKey);
    await _prefs.remove(_userKey);
    _logger.i('User logged out');
  }
}