import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class SupirService {
  // final String baseUrl = 'http://192.168.20.65/ralisa_api/index.php/api';
  final String baseUrl = 'https://api3.ralisa.co.id/index.php/api';
  Timer? _timer;

  Future<Map<String, dynamic>> getAttendanceStatus(String token) async {
    try {
      print('🔑 Token yang dikirim: $token');
      final response = await http.get(
        Uri.parse('$baseUrl/get_attendance_driver?token=$token'),
      );

      print('📡 Response status: ${response.statusCode}');
      print('📡 Response body: ${response.body}');

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        if (data['error'] == false) {
          final list = data['data'];
          _startAutoRefresh(token);

          if (list is List && list.isEmpty) {
            return {
              'show_button': true,
              'notes': 'Silakan lakukan absen',
              'statusCode': 200,
            };
          }

          if (list is List && list.isNotEmpty) {
            return {
              'show_button': list[0]['show_button'] == 1,
              'notes': list[0]['notes'] ?? '',
              'statusCode': 200,
            };
          }
        }
        throw Exception(data['message'] ?? 'Gagal mendapatkan status absen');
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error in getAttendanceStatus: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> kirimAbsen({
    required String token,
    required String latitude,
    required String longitude,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/driver_attendance'),
        body: {'token': token, 'latitude': latitude, 'longitude': longitude},
      );

      final data = json.decode(response.body);

      return {
        'success': (response.statusCode == 200 && data['error'] == false),
        'message': data['message'] ?? 'Absen berhasil',
        'statusCode': response.statusCode,
      };
    } catch (e) {
      print('❌ Error in kirimAbsen: $e');
      return {
        'success': false,
        'message': 'Terjadi kesalahan jaringan',
        'statusCode': 500,
      };
    }
  }

  static Future<Map<String, dynamic>> getTaskDriver({
    required String token,
  }) async {
    final url = Uri.parse(
      // 'http://192.168.20.65/ralisa_api/index.php/api/get_task_driver?token=$token',
      'https://api3.ralisa.co.id/index.php/api/get_task_driver?token=$token',
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to fetch task driver');
    }
  }

  static Future<Map<String, dynamic>> sendReady({
    required String token,
    required double longitude,
    required double latitude,
    required String tipeContainer,
    required String truckName,
  }) async {
    final url = Uri.parse(
      // 'http://192.168.20.65/ralisa_api/index.php/api/driver_ready',
      'https://api3.ralisa.co.id/index.php/api/driver_ready',
    );

    final response = await http.post(
      url,
      body: {
        'token': token,
        'longitude': longitude.toString(),
        'latitude': latitude.toString(),
        'tipe_container': tipeContainer,
        'truck_name': truckName,
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to send ready');
    }
  }

  static Future<Map<String, dynamic>> submitArrival({
    required String token,
    required int taskId,
    required double longitude,
    required double latitude,
    required String containerNum,
    required String sealNum1,
  }) async {
    final response = await http.post(
      Uri.parse(
        // 'http://192.168.20.65/ralisa_api/index.php/api/driver_arrival_input',
        'https://api3.ralisa.co.id/index.php/api/driver_arrival_input',
      ),
      body: {
        'token': token,
        'id_task': taskId.toString(),
        'longitude': longitude.toString(),
        'latitude': latitude.toString(),
        'container_num': containerNum,
        'seal_num1': sealNum1,
      },
    );

    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> submitDeparture({
    required String token,
    required int taskId,
    required String departureDate,
    required String departureTime,
    required double longitude,
    required double latitude,
    required String sealNum2,
  }) async {
    final url = Uri.parse(
      // 'http://192.168.20.65/ralisa_api/index.php/api/driver_departure_input',
      'https://api3.ralisa.co.id/index.php/api/driver_departure_input',
    );

    final response = await http.post(
      url,
      body: {
        'token': token,
        'id_task': taskId.toString(),
        'departure_date': departureDate,
        'departure_time': departureTime,
        'longitude': longitude.toString(),
        'latitude': latitude.toString(),
        'seal_num2': sealNum2,
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to submit departure');
    }
  }

  void _startAutoRefresh(String token) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(hours: 1), (_) async {
      print('⏰ Auto-refresh absen …');
      try {
        await getAttendanceStatus(token);
      } catch (_) {}
    });
  }

  void cancelAutoRefresh() {
    _timer?.cancel();
    _timer = null;
  }
}

// === BACKGROUND SERVICE ===
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
void supirOnStart(ServiceInstance service) async {
  final supirService = SupirBackgroundService();
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');
  if (token == null || token.isEmpty) {
    await service.stopSelf();
    return;
  }
  await supirService.checkTaskStatus(service, token);
}

class SupirBackgroundService {
  Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: supirOnStart,
        isForegroundMode: true,
        autoStart: true,
        notificationChannelId: 'supir_channel',
        initialNotificationTitle: 'Ralisa App Service',
        initialNotificationContent: 'Monitoring Progress...',
        foregroundServiceNotificationId: 999,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: supirOnStart,
        onBackground: (_) async => true,
      ),
    );

    await service.startService();
  }

  Future<void> checkTaskStatus(ServiceInstance service, String token) async {
    try {
      final response = await http.get(
        Uri.parse(
          // 'http://192.168.20.65/ralisa_api/index.php/api/get_task_driver?token=$token',
          'https://api3.ralisa.co.id/index.php/api/get_task_driver?token=$token',
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['error'] == false && data['data'].isNotEmpty) {
          final task = data['data'][0];

          final prefs = await SharedPreferences.getInstance();
          final lastFotoRC = prefs.getString('last_foto_rc') ?? '';
          final lastTaskId = prefs.getString('last_task_id') ?? '';

          if ((task['task_assign'] ?? 0) != 0 &&
              (task['arrival_date'] == null || task['arrival_date'] == '-')) {
            await _showNotif('Penugasan Diterima', 'Anda mendapat tugas baru.');
          }

          if ((task['departure_date'] != null &&
                  task['departure_date'] != '-') &&
              (task['departure_time'] != null &&
                  task['departure_time'] != '-') &&
              task['foto_rc_url'] != null &&
              task['foto_rc_url'] != '-' &&
              task['foto_rc_url'].toString() != lastFotoRC) {
            await prefs.setString('last_foto_rc', task['foto_rc_url']);
            await _showNotif('Foto RC Tersedia', 'Dokumen RC telah tersedia.');
          }

          if (task['task_id'].toString() != lastTaskId) {
            await prefs.setString('last_task_id', task['task_id'].toString());
          }
        }
      }
    } catch (e) {
      print('Error in background: $e');
    }
  }

  Future<void> _showNotif(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'supir_channel',
      'Notifikasi Supir',
      channelDescription: 'Notifikasi untuk tugas supir',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );
    final notifDetails = NotificationDetails(android: androidDetails);
    await flutterLocalNotificationsPlugin.show(0, title, body, notifDetails);
  }
}
