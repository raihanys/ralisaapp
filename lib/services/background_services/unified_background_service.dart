import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  service.on('stop').listen((event) {
    service.stopSelf();
  });

  final prefs = await SharedPreferences.getInstance();
  final role = prefs.getString('role') ?? '';
  final token = prefs.getString('token') ?? '';

  if (token.isEmpty) {
    await service.stopSelf();
    return;
  }

  final unifiedService = UnifiedBackgroundService();

  if (role == '1') {
    // Supir
    await unifiedService._checkTaskStatus(service, token);
  } else if (role == '3') {
    // Pelabuhan
    await unifiedService._checkForNewOrders(service);
  }
}

class UnifiedBackgroundService {
  bool _isInitialized = false;

  Future<void> initializeService({required String role}) async {
    if (_isInitialized) return;

    final service = FlutterBackgroundService();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'ralisa_service_channel',
      'Ralisa Service',
      description: 'Background service notifications',
      importance: Importance.max,
    );

    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        isForegroundMode: true,
        autoStart: true,
        notificationChannelId: 'ralisa_service_channel',
        initialNotificationTitle:
            role == '1' ? 'Ralisa Supir' : 'Ralisa Pelabuhan',
        initialNotificationContent:
            role == '1' ? 'Memantau Tugas...' : 'Memantau Order Baru...',
        foregroundServiceNotificationId: 777,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: (_) async => true,
      ),
    );

    _isInitialized = true;

    if (!await service.isRunning()) {
      await service.startService();
    }
  }

  // Fungsi untuk pelabuhan
  Future<void> _checkForNewOrders(ServiceInstance service) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      if (token.isEmpty) return;

      final response = await http.get(
        Uri.parse(
          'http://192.168.20.65/ralisa_api/index.php/api/get_new_salesorder_for_krani_pelabuhan?token=$token',
          // 'https://api3.ralisa.co.id/index.php/api/get_new_salesorder_for_krani_pelabuhan?token=$token',
        ),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        if (jsonData.containsKey('data') && jsonData['data'] is List) {
          final List<dynamic> orders = jsonData['data'];
          if (orders.isNotEmpty) {
            final newOrder = orders.first;
            final currentOrderId = newOrder['so_id'].toString();
            final lastOrderId = prefs.getString('lastOrderId');

            if (currentOrderId != lastOrderId) {
              await prefs.setString('lastOrderId', currentOrderId);
              await _showNotification(
                title: 'Data RO Baru Masuk!',
                body: 'Nomor RO: ${newOrder['no_ro']?.toString() ?? 'No RO'}',
                payload: 'order_$currentOrderId',
                role: '3',
              );
            }
          }
        }
      }
    } catch (e) {
      print('Error in background (pelabuhan): $e');
    }
  }

  // Fungsi untuk supir
  Future<void> _checkTaskStatus(ServiceInstance service, String token) async {
    try {
      final response = await http.get(
        Uri.parse(
          'http://192.168.20.65/ralisa_api/index.php/api/get_task_driver?token=$token',
          // 'https://api3.ralisa.co.id/index.php/api/get_task_driver?token=$token',
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
            await _showNotification(
              title: 'Penugasan Diterima',
              body: 'Anda mendapat tugas baru.',
              role: '1',
            );
          }

          if ((task['departure_date'] != null &&
                  task['departure_date'] != '-') &&
              (task['departure_time'] != null &&
                  task['departure_time'] != '-') &&
              task['foto_rc_url'] != null &&
              task['foto_rc_url'] != '-' &&
              task['foto_rc_url'].toString() != lastFotoRC) {
            await prefs.setString('last_foto_rc', task['foto_rc_url']);
            await _showNotification(
              title: 'Foto RC Tersedia',
              body: 'Dokumen RC telah tersedia.',
              role: '1',
            );
          }

          if (task['task_id'].toString() != lastTaskId) {
            await prefs.setString('last_task_id', task['task_id'].toString());
          }
        }
      }
    } catch (e) {
      print('Error in background (supir): $e');
    }
  }

  // Fungsi notifikasi umum
  Future<void> _showNotification({
    required String title,
    required String body,
    String? payload,
    required String role,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'ralisa_service_channel',
      'Notifikasi Ralisa',
      channelDescription: 'Notifikasi untuk aplikasi Ralisa',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true,
      icon: '@mipmap/ic_launcher',
      ticker: 'ticker',
    );

    final notifDetails = NotificationDetails(android: androidDetails);
    final actualPayload =
        payload ?? (role == '1' ? 'driver-task' : 'pelabuhan-inbox');
    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      notifDetails,
      payload: actualPayload,
    );
  }
}
