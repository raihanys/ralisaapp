import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class LCLService {
  final AuthService _authService = AuthService();

  // --- BASE URL ---
  // Gunakan salah satu, sesuaikan untuk production atau development.
  // PRODUCTION
  // final String _baseUrl = 'https://api3.ralisa.co.id/index.php/api';
  // DEVELOPMENT
  // final String _baseUrl = 'http://192.168.20.65/ralisa_api/index.php/api';
  final String _baseUrl = 'http://192.168.200.20/ralisa_api/index.php/api';

  Future<List<Map<String, dynamic>>?> getContainerNumberLCL(
    String query,
  ) async {
    final token = await _authService.getValidToken();
    if (token == null) return null;

    // Menggunakan _baseUrl untuk membangun URL
    final url = Uri.parse(
      '$_baseUrl/getContainerNumberLCL?token=$token&container_number=$query',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == true && data['data'] != null) {
          return (data['data']['item'] as List).cast<Map<String, dynamic>>();
        }
      }
      return null;
    } catch (e) {
      print('Error getting container numbers: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getLPBInfoDetail(String numberLpbChild) async {
    final token = await _authService.getValidToken();
    if (token == null) return null;

    // Menggunakan _baseUrl untuk membangun URL
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

  Future<List<Map<String, dynamic>>?> getItemSuggestions(String query) async {
    final token = await _authService.getValidToken();
    if (token == null) return null;

    // Menggunakan _baseUrl untuk membangun URL
    final url = Uri.parse('$_baseUrl/getItemDetail?token=$token&name=$query');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == true && data['data'] != null) {
          return (data['data']['item'] as List).cast<Map<String, dynamic>>();
        }
      }
      return null;
    } catch (e) {
      print('Error getting suggestions: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getTipeBarangList() async {
    final token = await _authService.getValidToken();
    if (token == null) return [];

    // Menggunakan _baseUrl untuk membangun URL
    final url = Uri.parse('$_baseUrl/getDetailTipeBarang?token=$token');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == true && data['data'] != null) {
          return (data['data']['tipe_barang'] as List)
              .cast<Map<String, dynamic>>();
        }
      }
      return [];
    } catch (e) {
      print('Error getting item types: $e');
      return [];
    }
  }

  Future<bool> saveLPBDetail({
    required String number_lpb_item,
    required String weight,
    required String height,
    required String length,
    required String width,
    required String nama_barang,
    required String tipe_barang_id,
    String? id_barang,
    required String processType,
    String? container_number,
  }) async {
    final token = await _authService.getValidToken();
    if (token == null) {
      print('Token is null!');
      return false;
    }

    final fields = {
      'token': token,
      'number_lpb_item': number_lpb_item,
      'weight': weight,
      'height': height,
      'length': length,
      'width': width,
      'nama_barang': nama_barang,
      'tipe_barang': tipe_barang_id,
      'process_type': processType,
    };

    if (id_barang != null) {
      fields['id_barang'] = id_barang;
    }
    if (container_number != null) {
      fields['container_number'] = container_number;
    }

    // Menggunakan _baseUrl untuk membangun URL
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/store_lpb_detail'),
    )..fields.addAll(fields);

    print('Sending request with fields: $fields');

    try {
      final response = await request.send();
      final resBody = await response.stream.bytesToString();
      final data = jsonDecode(resBody);

      if (response.statusCode == 401 ||
          (data['error'] == true && data['message'] == 'Token Not Found')) {
        final newToken = await _authService.softLoginRefresh();
        if (newToken != null) {
          return saveLPBDetail(
            number_lpb_item: number_lpb_item,
            weight: weight,
            height: height,
            length: length,
            width: width,
            nama_barang: nama_barang,
            tipe_barang_id: tipe_barang_id,
            id_barang: id_barang,
            processType: processType,
            container_number: container_number,
          );
        }
      }

      return response.statusCode == 200 && data['status'] == true;
    } catch (e) {
      print('Error saving LPB detail: $e');
      return false;
    }
  }

  Future<bool> updateStatusReadyToShip({
    required String numberLpbItem,
    required String containerNumber,
  }) async {
    final token = await _authService.getValidToken();
    if (token == null) {
      print('updateStatusReadyToShip: Token is null!');
      return false;
    }

    // Menggunakan _baseUrl untuk membangun URL
    final url = Uri.parse('$_baseUrl/update_status_ready_to_ship');

    print('updateStatusReadyToShip parameters:');
    print('  numberLpbItem: $numberLpbItem');
    print('  containerNumber: $containerNumber');

    try {
      final response = await http.post(
        url,
        body: {
          'token': token,
          'number_lpb_item': numberLpbItem,
          'container_number': containerNumber,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('updateStatusReadyToShip API response: $data');
        return data['status'] == true;
      }
      print(
        'updateStatusReadyToShip: Server responded with status code ${response.statusCode}',
      );
      print('Response body: ${response.body}');
      return false;
    } catch (e) {
      print('Error updating status: $e');
      return false;
    }
  }
}
