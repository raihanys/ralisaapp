import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
// import 'package:device_info_plus/device_info_plus.dart';

class AuthService {
  final String baseUrl = 'http://192.168.20.65/ralisa_api/index.php/api/login';
  // final String baseUrl = 'https://api3.ralisa.co.id/index.php/api/login';

  // Future<String> _getDeviceImei() async {
  //   final deviceInfo = DeviceInfoPlugin();
  //   final androidInfo = await deviceInfo.androidInfo;
  //   return androidInfo.id;
  // }

  Future<Map<String, dynamic>?> login({
    required String username,
    required String password,
  }) async {
    // --- START: BLOK KODE UNTUK FORCE LOGIN ---
    // Tentukan username dan password khusus untuk force login
    // if (username == 'adminlcl' && password == '12345678') {
    //   print('--- Melakukan Force Login Lokal untuk Admin LCL ---');
    //   final prefs = await SharedPreferences.getInstance();

    //   // Simulasikan data login yang berhasil
    //   await prefs.setBool('isLoggedIn', true); //
    //   await prefs.setString('username', username); //
    //   await prefs.setString('password', password); //
    //   await prefs.setString('role', '4'); // Role untuk Admin LCL
    //   await prefs.setString('version', '1.0'); //
    //   await prefs.setString('token', 'dummy-local-token-for-admin-lcl'); //

    //   print('Force Login Berhasil. Navigasi ke Halaman Admin LCL.');
    //   // Kembalikan Map yang tidak null untuk menandakan login berhasil
    //   return {'status': 'success', 'message': 'Local force login'};
    // }
    // --- END: BLOK KODE UNTUK FORCE LOGIN ---

    final imei = 'ac9ba078-0a12-45ad-925b-2d761ad9770f';
    // final imei = await _getDeviceImei();

    // Try Driver login (type 1) with version 2.7
    final driverResult = await _attemptLogin(
      username: username,
      password: password,
      type: '1',
      version: '2.7',
      imei: imei,
    );

    if (driverResult != null) {
      return driverResult;
    }

    // Try Pelabuhan login (type 3) with version 1.0
    final pelabuhanResult = await _attemptLogin(
      username: username,
      password: password,
      type: '3',
      version: '1.0',
      imei: imei,
    );

    return pelabuhanResult;
  }

  Future<Map<String, dynamic>?> _attemptLogin({
    required String username,
    required String password,
    required String version,
    required String type,
    required String imei,
  }) async {
    try {
      final body = {
        'username': username,
        'password': password,
        'version': version,
        'type': type,
        'imei': imei,
        'firebase': 'dummy_token',
      };

      print('Attempting login with version: $version, type: $type');

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
          await prefs.setString('role', type);
          await prefs.setString('version', version);
          await prefs.setString('token', user['token'] ?? '');

          print('Login success with type: $type, version: $version');
          return user;
        } else {
          print('Login failed: ${data['message']}');
        }
      } else {
        print('HTTP error: ${res.statusCode} - ${res.body}');
      }
    } catch (e) {
      print('Error during login attempt: $e');
    }

    return null;
  }

  Future<void> logout() async {
    try {
      // Hentikan background service dengan cara yang benar
      final service = FlutterBackgroundService();
      service.invoke('stopService');

      // Hapus semua data login
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      print("Logout berhasil, service dihentikan dan data dibersihkan.");
    } catch (e) {
      print("Gagal logout: $e");
    }
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
      return null;
    }
  }
}
