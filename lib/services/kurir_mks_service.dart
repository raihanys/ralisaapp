import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class KurirMksService {
  final AuthService _authService = AuthService();

  // PRODUCTION
  // final String _baseUrl = 'https://api3.ralisa.co.id/index.php/api';
  // DEVELOPMENT
  // final String _baseUrl = 'http://192.168.20.25/ralisa_api/index.php/api';
  final String _baseUrl = 'http://192.168.20.65/ralisa_api/index.php/api';
  // final String _baseUrl = 'http://192.168.20.100/ralisa_api/index.php/api';
  // TESTING
  // final String _baseUrl = 'http://192.168.0.108/ralisa_api/index.php/api';

  Future<Map<String, dynamic>?> getLPBInfoDetail(String numberLpbChild) async {
    final token = await _authService.getValidToken();
    if (token == null) return null;

    final url = Uri.parse(
      '$_baseUrl/getLPBInfoDetail?token=$token&number_lpb_child=$numberLpbChild',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  Future<bool> updateStatusToCustomer(String numberLpbItem) async {
    final token = await _authService.getValidToken();
    if (token == null) return false;

    final url = Uri.parse('$_baseUrl/update_status_item_to_customer');

    final payload = {
      'token': token,
      'data': {'number_lpb_item': numberLpbItem},
    };

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      // Berhasil jika status code 200
      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        return responseBody['status'] == true;
      } else {
        print('Failed to update status: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error on updateStatusToCustomer: $e');
      return false;
    }
  }
}
