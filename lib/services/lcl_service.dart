import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class LCLService {
  final AuthService _authService = AuthService();

  Future<Map<String, dynamic>?> getLPBInfoDetail(String numberLpbChild) async {
    final token = await _authService.getValidToken();
    if (token == null) return null;

    final url = Uri.parse(
      'http://192.168.20.65/ralisa_api/index.php/api/getLPBInfoDetail?token=$token&number_lpb_child=$numberLpbChild',
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

    final url = Uri.parse(
      'http://192.168.20.65/ralisa_api/index.php/api/getItemDetail?token=$token&name=$query',
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
      print('Error getting suggestions: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getTipeBarangList() async {
    final token = await _authService.getValidToken();
    if (token == null) return [];

    final url = Uri.parse(
      'http://192.168.20.65/ralisa_api/index.php/api/getDetailTipeBarang?token=$token',
    );

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

  // --- PERUBAHAN UTAMA DI FUNGSI INI ---
  Future<bool> saveLPBDetail({
    required String number_lpb_item,
    required String weight,
    required String height,
    required String length,
    required String width,
    required String nama_barang,
    required String tipe_barang_id, // Mengirim ID tipe barang
    String? id_barang, // Mengirim ID barang jika ada (opsional)
  }) async {
    final token = await _authService.getValidToken();
    if (token == null) {
      print('Token is null!');
      return false;
    }

    // Buat map untuk fields
    final fields = {
      'token': token,
      'number_lpb_item': number_lpb_item,
      'weight': weight,
      'height': height,
      'length': length,
      'width': width,
      'nama_barang':
          nama_barang, // Tetap kirim nama barang (untuk input manual)
      'tipe_barang':
          tipe_barang_id, // Parameter API-nya 'tipe_barang', kita isi dengan ID
    };

    // Jika id_barang ada (bukan null), tambahkan ke fields
    if (id_barang != null) {
      fields['id_barang'] = id_barang;
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse(
        'http://192.168.20.65/ralisa_api/index.php/api/store_lpb_detail',
      ),
    )..fields.addAll(fields);

    print('Sending request with fields: $fields');

    try {
      final response = await request.send();
      final resBody = await response.stream.bytesToString();
      final data = jsonDecode(resBody);

      print('Response status: ${response.statusCode}');
      print('Response body: $resBody');

      // Logika refresh token tetap sama
      if (response.statusCode == 401 ||
          (data['error'] == true && data['message'] == 'Token Not Found')) {
        print('Token invalid, attempting refresh...');
        final newToken = await _authService.softLoginRefresh();
        if (newToken != null) {
          print('Retrying with new token...');
          // Panggil ulang dengan parameter yang sama
          return saveLPBDetail(
            number_lpb_item: number_lpb_item,
            weight: weight,
            height: height,
            length: length,
            width: width,
            nama_barang: nama_barang,
            tipe_barang_id: tipe_barang_id,
            id_barang: id_barang,
          );
        }
      }

      print('Response status: ${response.statusCode}');
      print('Response body: $resBody');
      print('Error flag: ${data['error']}');
      print('Message: ${data['message']}');

      return response.statusCode == 200 && data['status'] == true;
    } catch (e) {
      print('Error saving LPB detail: $e');
      return false;
    }
  }
}
