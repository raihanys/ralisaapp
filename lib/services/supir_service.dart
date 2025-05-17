import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
void supirOnStart(ServiceInstance service) async {
  final supirService = SupirBackgroundService(AuthService());

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  try {
    final token = await supirService._authService.getValidToken();
    if (token == null) {
      await service.stopSelf();
      return;
    }
    await supirService.checkTaskStatus(service, token);
  } catch (e) {
    print('Background service error: $e');
  }
}

class SupirService {
  final AuthService _authService;
  final String _baseUrl = 'http://192.168.20.65/ralisa_api/index.php/api';
  // final String _baseUrl = 'https://api3.ralisa.co.id/index.php/api';
  Timer? _timer;

  SupirService(this._authService) {
    _initializeNotifications();
  }

  // Centralized API endpoints
  String get _attendanceStatusUrl => '$_baseUrl/get_attendance_driver';
  String get _attendanceSubmitUrl => '$_baseUrl/driver_attendance';
  String get _taskDriverUrl => '$_baseUrl/get_task_driver';
  String get _driverReadyUrl => '$_baseUrl/driver_ready';
  String get _driverArrivalUrl => '$_baseUrl/driver_arrival_input';
  String get _driverDepartureUrl => '$_baseUrl/driver_departure_input';

  Future<void> _initializeNotifications() async {
    final status = await Permission.notification.request();
    if (!status.isGranted) {
      print('Notification permission not granted');
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    await flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(android: initializationSettingsAndroid),
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        if (response.payload != null) {
          // Handle notification tap if needed
        }
      },
    );

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'supir_channel',
      'Supir Notifications',
      description: 'Channel for driver task notifications',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  Future<Map<String, dynamic>> getAttendanceStatus() async {
    try {
      final token = await _authService.getValidToken();
      if (token == null) throw Exception('Token not available');

      final response = await http.get(
        Uri.parse('$_attendanceStatusUrl?token=$token'),
      );

      print('📡 Response status: ${response.statusCode}');
      print('📡 Response body: ${response.body}');

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        if (data['error'] == false) {
          final list = data['data'];
          _startAutoRefresh();

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
    required String latitude,
    required String longitude,
  }) async {
    try {
      final token = await _authService.getValidToken();
      if (token == null) throw Exception('Token not available');

      final response = await http.post(
        Uri.parse(_attendanceSubmitUrl),
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

  Future<Map<String, dynamic>> getTaskDriver() async {
    try {
      final token = await _authService.getValidToken();
      if (token == null) throw Exception('Token not available');

      final response = await http.get(
        Uri.parse('$_taskDriverUrl?token=$token'),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to fetch task driver');
      }
    } catch (e) {
      print('❌ Error in getTaskDriver: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> sendReady({
    required double longitude,
    required double latitude,
    required String tipeContainer,
    required String truckName,
  }) async {
    try {
      final token = await _authService.getValidToken();
      if (token == null) throw Exception('Token not available');

      final response = await http.post(
        Uri.parse(_driverReadyUrl),
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
    } catch (e) {
      print('❌ Error in sendReady: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> submitArrival({
    required int taskId,
    required double longitude,
    required double latitude,
    required String containerNum,
    required String sealNum1,
  }) async {
    try {
      final token = await _authService.getValidToken();
      if (token == null) throw Exception('Token not available');

      final response = await http.post(
        Uri.parse(_driverArrivalUrl),
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
    } catch (e) {
      print('❌ Error in submitArrival: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> submitDeparture({
    required int taskId,
    required String departureDate,
    required String departureTime,
    required double longitude,
    required double latitude,
    required String sealNum2,
  }) async {
    try {
      final token = await _authService.getValidToken();
      if (token == null) throw Exception('Token not available');

      final response = await http.post(
        Uri.parse(_driverDepartureUrl),
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
    } catch (e) {
      print('❌ Error in submitDeparture: $e');
      rethrow;
    }
  }

  Future<void> checkTaskStatus(ServiceInstance service, String token) async {
    try {
      final task = await _fetchTask(token);
      if (task != null) {
        await _checkAndShowNewTaskNotification(task);
        await _checkAndShowRcReadyNotification(task);
      }
    } catch (e) {
      print('Error in checkTaskStatus: $e');
    }
  }

  Future<Map<String, dynamic>?> _fetchTask(String token) async {
    final response = await http.get(Uri.parse('$_taskDriverUrl?token=$token'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['error'] == false && data['data'].isNotEmpty) {
        return data['data'][0];
      }
    }
    return null;
  }

  Future<void> _checkAndShowNewTaskNotification(
    Map<String, dynamic> task,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final lastTaskId = prefs.getString('last_task_id');
    final taskAssign = task['task_assign'] ?? 0;

    if (taskAssign != 0 &&
        (task['arrival_date'] == null || task['arrival_date'] == '-')) {
      if (lastTaskId != task['task_id'].toString()) {
        await _showNotification(
          id: 1,
          title: 'Tugas Baru',
          body: 'Anda mendapatkan tugas baru!',
          payload: 'task_${task['task_id']}',
        );
        await prefs.setString('last_task_id', task['task_id'].toString());
      }
    }
  }

  Future<void> _checkAndShowRcReadyNotification(
    Map<String, dynamic> task,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final lastRcUrl = prefs.getString('last_rc_url');
    final fotoRcUrl = task['foto_rc_url'];

    if (fotoRcUrl != null && fotoRcUrl != '-') {
      if (lastRcUrl != fotoRcUrl) {
        await _showNotification(
          id: 2,
          title: 'RC Tersedia',
          body: 'Foto RC sudah tersedia.',
          payload: 'rc_${task['task_id']}',
        );
        await prefs.setString('last_rc_url', fotoRcUrl);
      }
    }
  }

  Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'supir_channel',
          'Supir Notifications',
          channelDescription: 'Channel for driver task notifications',
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'ticker',
          playSound: true,
          enableVibration: true,
        );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      platformDetails,
      payload: payload,
    );
  }

  void _startAutoRefresh() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(hours: 1), (_) async {
      print('⏰ Auto-refresh absen ...');
      try {
        await getAttendanceStatus();
      } catch (_) {}
    });
  }

  void cancelAutoRefresh() {
    _timer?.cancel();
    _timer = null;
  }
}

class SupirBackgroundService {
  final AuthService _authService;
  final String _baseUrl = 'http://192.168.20.65/ralisa_api/index.php/api';
  // final String _baseUrl = 'https://api3.ralisa.co.id/index.php/api';

  String get _taskDriverUrl => '$_baseUrl/get_task_driver';

  SupirBackgroundService(this._authService);

  Future<void> initializeService() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'supir_channel',
      'Supir Service',
      description: 'Notifikasi untuk tugas supir',
      importance: Importance.max,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

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
        Uri.parse('$_taskDriverUrl?token=$token'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['error'] == false && data['data'].isNotEmpty) {
          final task = data['data'][0];
          await _handleTaskNotifications(task);
        }
      }
    } catch (e) {
      print('Error in background: $e');
    }
  }

  Future<void> _handleTaskNotifications(Map<String, dynamic> task) async {
    final prefs = await SharedPreferences.getInstance();
    final lastTaskId = prefs.getString('last_task_id') ?? '';

    // New task notification
    if ((task['task_assign'] ?? 0) != 0 &&
        (task['arrival_date'] == null || task['arrival_date'] == '-') &&
        task['task_id'].toString() != lastTaskId) {
      await _showNotification(
        title: 'Penugasan Diterima',
        body: 'Anda mendapat tugas baru.',
        payload: 'task_${task['task_id']}',
      );
      await prefs.setString('last_task_id', task['task_id'].toString());
    }

    // RC available notification
    final lastFotoRC = prefs.getString('last_foto_rc') ?? '';
    if (task['foto_rc_url'] != null &&
        task['foto_rc_url'] != '-' &&
        task['foto_rc_url'].toString() != lastFotoRC) {
      await _showNotification(
        title: 'Foto RC Tersedia',
        body: 'Dokumen RC telah tersedia.',
        payload: 'rc_${task['task_id']}',
      );
      await prefs.setString('last_foto_rc', task['foto_rc_url']);
    }
  }

  Future<void> _showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'supir_channel',
          'Supir Notifications',
          channelDescription: 'Notifikasi untuk tugas supir',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      platformDetails,
      payload: payload,
    );
  }
}
