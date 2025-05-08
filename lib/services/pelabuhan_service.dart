import 'dart:async';
import 'dart:convert';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'package:http_parser/http_parser.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
void pelabuhanOnStart(ServiceInstance service) async {
  final pelabuhanService = PelabuhanService(AuthService());
  try {
    final token = await pelabuhanService._authService.getValidToken();
    if (token == null) {
      await service.stopSelf();
      return;
    }
    await pelabuhanService._checkForNewOrders(service);
  } catch (e) {
    print('Background service error: $e');
  }
}

class PelabuhanService {
  final AuthService _authService;

  PelabuhanService(this._authService);

  Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: pelabuhanOnStart,
        isForegroundMode: true,
        autoStart: true,
        notificationChannelId: 'order_service_channel',
        initialNotificationTitle: 'Ralisa App Service',
        initialNotificationContent: 'Monitoring Progress...',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: pelabuhanOnStart,
        onBackground: (_) async => true,
      ),
    );

    await service.startService();
  }

  Future<List<dynamic>> fetchOrders() async {
    try {
      final token = await _authService.getToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse(
          'http://192.168.20.65/ralisa_api/index.php/api/get_new_salesorder_for_krani_pelabuhan?token=$token',
          // 'https://api3.ralisa.co.id/index.php/api/get_new_salesorder_for_krani_pelabuhan?token=$token',
        ),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        if (jsonData.containsKey('data') && jsonData['data'] is List) {
          return jsonData['data'];
        }
      }
      return [];
    } catch (e) {
      print('Error fetching orders: $e');
      return [];
    }
  }

  Future<bool> submitRC({
    required String soId,
    required String containerNum,
    required String sealNumber,
    required String sealNumber2,
    required String fotoRcPath,
    required String username,
  }) async {
    try {
      final token = await _authService.getValidToken();
      if (token == null) {
        print('Error: Tidak dapat mendapatkan token valid');
        return false;
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse(
          'http://192.168.20.65/ralisa_api/index.php/api/agent_create_rc',
          // 'https://api3.ralisa.co.id/index.php/api/agent_create_rc',
        ),
      );

      request.fields.addAll({
        'so_id': soId,
        'container_num': containerNum,
        'seal_number': sealNumber,
        'seal_number2': sealNumber2,
        'agent': username,
        'token': token,
      });

      request.files.add(
        await http.MultipartFile.fromPath(
          'foto_rc',
          fotoRcPath,
          contentType: MediaType('image', 'jpeg'),
        ),
      );

      final response = await request.send();
      final resBody = await response.stream.bytesToString();

      print('RC Submit Response Body: $resBody'); // debug

      final data = jsonDecode(resBody);

      if (response.statusCode == 401 || data['error'] == true) {
        final newToken = await _authService.softLoginRefresh();
        if (newToken != null) {
          return submitRC(
            soId: soId,
            containerNum: containerNum,
            sealNumber: sealNumber,
            sealNumber2: sealNumber2,
            fotoRcPath: fotoRcPath,
            username: username,
          );
        }
        return false;
      }
      return response.statusCode == 200 &&
          (data['status'] == true ||
              data['success'] == true ||
              data['error'] == false);
    } catch (e) {
      print('Error submitting RC: $e');
      return false;
    }
  }

  Future<void> _checkForNewOrders(ServiceInstance service) async {
    try {
      final token = await _authService.getValidToken();
      if (token == null) {
        service.invoke('force_relogin');
        return;
      }

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
            final prefs = await SharedPreferences.getInstance();
            // Simpan data order ke shared_preferences
            await prefs.setString('orders', jsonEncode(orders));
            final lastOrderId = prefs.getString('lastOrderId');
            final newOrder = orders.first;
            final currentOrderId = newOrder['so_id'].toString();

            if (currentOrderId != lastOrderId) {
              await prefs.setString('lastOrderId', currentOrderId);
              await showNewOrderNotification(
                orderId: currentOrderId,
                noRo: newOrder['no_ro']?.toString() ?? 'No RO',
              );
            }
          }
        }
      }
    } catch (e) {
      print('Error in _checkForNewOrders: $e');
      // Tambahkan logika untuk menangani kesalahan, misalnya,
      // - Mencoba lagi setelah beberapa waktu
      // - Mengirimkan laporan kesalahan ke server
      // - Menghentikan layanan jika kesalahan tidak dapat diperbaiki
    }
  }

  Future<void> showNewOrderNotification({
    required String orderId,
    required String noRo,
  }) async {
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'order_service_channel',
          'Order Service Channel',
          channelDescription: 'New order notifications from background service',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          icon: '@mipmap/ic_launcher',
          ledOnMs: 1000,
          ledOffMs: 500,
          ticker: 'Data RO Baru Masuk!',
          fullScreenIntent: true,
          styleInformation: BigTextStyleInformation(
            'Nomor RO: $noRo',
            contentTitle: 'Data RO Baru Masuk!',
            htmlFormatContentTitle: true,
          ),
        );

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      0,
      'Data RO Baru Masuk!',
      'Nomor RO: $noRo',
      platformDetails,
      payload: 'order_$orderId',
    );
  }
}
