import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class WarehouseService {
  final AuthService _authService = AuthService();

  // Gunakan salah satu base URL sesuai kebutuhan
  // PRODUCTION
  // final String _baseUrl = 'https://api3.ralisa.co.id/index.php/api';
  // DEVELOPMENT
  final String _baseUrl = 'http://192.168.20.65/ralisa_api/index.php/api';

  Future<List<Map<String, dynamic>>?> getLPBHeaderAll() async {
    final token = await _authService.getValidToken();
    if (token == null) {
      print('getLPBHeaderAll: Token is null!');
      return null;
    }

    final url = Uri.parse('$_baseUrl/getLPBHeaderAll?token=$token');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == true && data['data'] != null) {
          return List<Map<String, dynamic>>.from(data['data']['item']);
        } else {
          print('API error: ${data['message']}');
        }
      } else if (response.statusCode == 401) {
        final newToken = await _authService.softLoginRefresh();
        if (newToken != null) {
          return getLPBHeaderAll();
        }
      }
      return null;
    } catch (e) {
      print('Error fetching LPB headers: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>?> getLPBItemDetail(String numberLpb) async {
    final token = await _authService.getValidToken();
    if (token == null) {
      print('getLPBItemDetail: Token is null!');
      return null;
    }

    final url = Uri.parse(
      '$_baseUrl/getLPBItem?token=$token&number_lpb=$numberLpb',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == true && data['data'] != null) {
          return List<Map<String, dynamic>>.from(data['data']['item']);
        } else {
          print('API error: ${data['message']}');
        }
      } else if (response.statusCode == 401) {
        final newToken = await _authService.softLoginRefresh();
        if (newToken != null) {
          return getLPBItemDetail(numberLpb);
        }
      }
      return null;
    } catch (e) {
      print('Error fetching LPB item details: $e');
      return null;
    }
  }
}
