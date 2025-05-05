import 'dart:async';
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'package:http_parser/http_parser.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

class PelabuhanService {
  final AuthService _authService;

  PelabuhanService(this._authService);

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

      print('RC Submit Response Body: $resBody');

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
}
