import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class LCLService {
  final AuthService _authService = AuthService();

  // PRODUCTION
  // final String _baseUrl = 'https://api3.ralisa.co.id/index.php/api';
  // DEVELOPMENT
  // final String _baseUrl = 'http://192.168.20.25/ralisa_api/index.php/api';
  final String _baseUrl = 'http://192.168.20.65/ralisa_api/index.php/api';
  // final String _baseUrl = 'http://192.168.20.100/ralisa_api/index.php/api';
  // TESTING
  // final String _baseUrl = 'http://192.168.0.108/ralisa_api/index.php/api';

  Future<List<Map<String, dynamic>>?> getAllContainerNumbers() async {
    final token = await _authService.getValidToken();
    if (token == null) return null;

    final url = Uri.parse('$_baseUrl/getContainerNumberLCL?token=$token');

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
      print('Error getting all container numbers: $e');
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

  String getImageUrl(String imagePath) {
    if (imagePath.isEmpty) return '';
    String base = _baseUrl.replaceAll('/index.php/api', '');
    return '$base/uploads/terima_barang/$imagePath';
  }

  Future<List<Map<String, dynamic>>?> getAllItemSuggestions() async {
    final token = await _authService.getValidToken();
    if (token == null) return null;

    final url = Uri.parse('$_baseUrl/getItemDetail?token=$token');

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
      print('Error getting all item suggestions: $e');
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
          // PASTIKAN selalu return list meski kosong
          return (data['data']['tipe_barang'] as List? ?? [])
              .cast<Map<String, dynamic>>();
        }
      }
      return []; // Return empty list jika error
    } catch (e) {
      print('Error getting item types: $e');
      return []; // Return empty list jika error
    }
  }

  Future<bool> saveLPBDetail({
    required String number_lpb_item,
    required String weight,
    required String height,
    required String length,
    required String width,
    required String nama_barang,
    required String tipe_barang,
    String? barang_id,
    String? container_number,
    String? status,
    String? keterangan,
    File? foto_terima_barang,
    bool deleteExistingFoto = false,
  }) async {
    final token = await _authService.getValidToken();
    if (token == null) {
      print('Token is null!');
      return false;
    }

    final fields = {
      'token': token,
      'number_lpb_item': number_lpb_item.trim(),
      'weight': weight.trim(),
      'height': height.trim(),
      'length': length.trim(),
      'width': width.trim(),
      'nama_barang': nama_barang.trim(),
      'tipe_barang': tipe_barang.trim(),
    };

    if (barang_id != null) {
      fields['barang_id'] = barang_id.trim();
    }
    if (container_number != null) {
      fields['container_number'] = container_number.trim();
    }
    if (status != null) {
      fields['status'] = status;
    }
    if (keterangan != null) {
      fields['keterangan'] = keterangan.trim();
    }

    if (deleteExistingFoto) {
      fields['foto_terima_barang'] = '';
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/store_lpb_detail'),
    )..fields.addAll(fields);

    if (foto_terima_barang != null) {
      final fileStream = http.ByteStream(foto_terima_barang.openRead());
      final fileLength = await foto_terima_barang.length();

      final multipartFile = http.MultipartFile(
        'foto_terima_barang',
        fileStream,
        fileLength,
        filename: foto_terima_barang.path.split('/').last,
      );
      request.files.add(multipartFile);
    }

    print('Sending request with fields: $fields');
    if (foto_terima_barang != null) {
      print('Sending file: ${foto_terima_barang.path}');
    }
    if (deleteExistingFoto) {
      print('Flagging to delete existing photo.');
    }

    try {
      final response = await request.send();
      final resBody = await response.stream.bytesToString();
      if (resBody.trim().startsWith('<!DOCTYPE') ||
          resBody.trim().startsWith('<div')) {
        print('Server returned HTML error: $resBody');
        return false;
      }

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
            tipe_barang: tipe_barang,
            barang_id: barang_id,
            container_number: container_number,
            status: status,
            keterangan: keterangan,
            foto_terima_barang: foto_terima_barang,
            deleteExistingFoto: deleteExistingFoto,
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
    print('numberLpbItem: $numberLpbItem');
    print('containerNumber: $containerNumber');

    try {
      final response = await http.post(
        url,
        body: {
          'token': token,
          'number_lpb_item': numberLpbItem.trim(), // Trim here
          'container_id': containerNumber.trim(), // Trim here
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
