import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:device_info_plus/device_info_plus.dart';

class AuthService {
  // final String baseUrl = 'http://192.168.20.65/ralisa_api/index.php/api/login';
  final String baseUrl = 'https://api3.ralisa.co.id/index.php/api/login';

  // Future<String> _getDeviceImei() async {
  //   final deviceInfo = DeviceInfoPlugin();
  //   final androidInfo = await deviceInfo.androidInfo;
  //   return androidInfo.id;
  // }

  Future<Map<String, dynamic>?> login({
    required String username,
    required String password,
  }) async {
    final imei = 'ac9ba078-0a12-45ad-925b-2d761ad9770f';
    // final imei = await _getDeviceImei();
    final _loginConfigs = [
      {
        'role': '3', // Pelabuhan
        'versions': ['1.0'],
      },
      // {
      //   'role': '1', // Driver
      //   'versions': ['2.7'],
      // },
      // {
      //   'role': 'marketing',
      //   'versions': ['1.0'],
      // },
      // {
      //   'role': 'trucking',
      //   'versions': ['1.0'],
      // },
    ];

    for (final config in _loginConfigs) {
      final role = config['role'] as String;

      for (final version in config['versions'] as List<String>) {
        try {
          final body = {
            'username': username,
            'password': password,
            'type': role,
            // 'version': version,
            'imei': imei,
            'firebase': 'dummy_token',
          };

          print('Attempting: role=$role, version=$version');

          final res = await http
              .post(
                Uri.parse(baseUrl),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode(body),
              )
              .timeout(const Duration(seconds: 5));

          if (res.statusCode == 200) {
            final data = jsonDecode(res.body);
            if (data['error'] == false && data['data'] != null) {
              final user = data['data'];
              final prefs = await SharedPreferences.getInstance();

              await prefs.setBool('isLoggedIn', true);
              await prefs.setString('username', username);
              await prefs.setString('password', password);
              await prefs.setString('role', role);
              // await prefs.setString('version', version);
              await prefs.setString('token', user['token'] ?? '');

              print('Login success with role: $role, version: $version');
              return user;
            }
          }
          print('Attempt failed: ${res.statusCode} - ${res.body}');
        } catch (e) {
          print('Error during attempt: $e');
          continue;
        }
      }
    }
    print('All login attempts failed');
    return null;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('role');
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }

  Future<void> saveAuthData(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    await prefs.setString('token_saved_at', DateTime.now().toIso8601String());
  }

  Future<String?> getValidToken() async {
    final currentToken = await getToken();
    if (currentToken == null) return null;

    if (await isTokenValid()) {
      return currentToken;
    }

    return await softLoginRefresh();
  }

  Future<bool> isTokenValid() async {
    final prefs = await SharedPreferences.getInstance();
    final savedAt = prefs.getString('token_saved_at');
    if (savedAt == null) return false;

    final tokenAge = DateTime.now().difference(DateTime.parse(savedAt));
    return tokenAge.inHours < 12;
  }

  Future<String?> softLoginRefresh() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('username');
    final password = prefs.getString('password');

    if (username == null || password == null) return null;

    try {
      final result = await login(username: username, password: password);
      return result?['token'];
    } catch (e) {
      print('Error refreshing token: $e');
      return null;
    }
  }
}
