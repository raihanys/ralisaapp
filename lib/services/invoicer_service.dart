import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class InvoicerService {
  final AuthService authService;
  // PRODUCTION
  // final String _baseUrl = 'https://api3.ralisa.co.id/index.php/api';
  // DEVELOPMENT
  // final String _baseUrl = 'http://192.168.20.25/ralisa_api/index.php/api';
  final String _baseUrl = 'http://192.168.20.65/ralisa_api/index.php/api';
  // final String _baseUrl = 'http://192.168.20.100/ralisa_api/index.php/api';
  // TESTING
  // final String _baseUrl = 'http://192.168.0.108/ralisa_api/index.php/api';

  InvoicerService(this.authService);

  Future<http.Response> _handleRequest(
    Future<http.Response> Function(String token) requestFunction,
  ) async {
    String? token = await authService.getValidToken();
    if (token == null) throw Exception('Token not available');

    var response = await requestFunction(token);

    if (response.statusCode == 401) {
      print("Token expired, attempting to refresh...");
      final newToken = await authService.softLoginRefresh();
      if (newToken != null) {
        print("Token refreshed successfully. Retrying request...");
        response = await requestFunction(newToken);
      } else {
        throw Exception('Failed to refresh token. Please log in again.');
      }
    }

    return response;
  }

  Future<List<dynamic>> fetchInvoices(String typeInvoice) async {
    try {
      final response = await _handleRequest((token) {
        final uri = Uri.parse('$_baseUrl/getInvoiceAll').replace(
          queryParameters: {'token': token, 'type_invoice': typeInvoice},
        );
        return http
            .get(uri, headers: {'Content-Type': 'application/json'})
            .timeout(const Duration(seconds: 15));
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Handle berbagai format response
        if (data['status'] == true || data['error'] == false) {
          // Jika data ada dan tidak kosong
          if (data['data'] != null) {
            if (data['data'] is List) {
              return data['data'];
            } else {
              return [];
            }
          } else {
            return [];
          }
        } else {
          return [];
        }
      } else if (response.statusCode == 404) {
        print('Endpoint not found (404), returning empty list');
        return [];
      } else {
        throw Exception('HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('timed out') ||
          e.toString().contains('Connection') ||
          e.toString().contains('404')) {
        print('Network error, returning empty list: $e');
        return [];
      }
      print('Error fetching invoices: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> fetchInvoiceDetail(String invoiceId) async {
    try {
      final response = await _handleRequest((token) {
        // UBAH INI: dari POST ke GET dengan query parameters
        final uri = Uri.parse(
          '$_baseUrl/getInvoiceDetail',
        ).replace(queryParameters: {'token': token, 'invoice_id': invoiceId});
        return http
            .get(uri, headers: {'Content-Type': 'application/json'})
            .timeout(const Duration(seconds: 15));
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == true && data['data'] != null) {
          return data['data'];
        } else {
          throw Exception('Failed to fetch invoice detail: ${data['message']}');
        }
      } else {
        throw Exception('HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching invoice detail: $e');
      rethrow;
    }
  }

  Future<bool> updateInvoiceStatus({
    required String invoiceId,
    required String paymentType,
    String? paymentAmount,
    String? paymentDifference,
    String? paymentNotes,
  }) async {
    try {
      final response = await _handleRequest((token) {
        Map<String, dynamic> payload = {
          'invoice_id': int.parse(invoiceId),
          'payment_type': int.parse(paymentType),
        };

        if (paymentAmount != null) {
          payload['payment_amount'] = int.parse(
            paymentAmount.replaceAll('.', ''),
          );
        }

        if (paymentDifference != null) {
          payload['is_diff'] = int.parse(paymentDifference);
        }
        if (paymentNotes != null && paymentNotes.isNotEmpty) {
          payload['notes'] = paymentNotes;
        }

        return http
            .post(
              Uri.parse('$_baseUrl/update_status_invoice'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'token': token, 'data': payload}),
            )
            .timeout(const Duration(seconds: 15));
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'] == true;
      } else {
        throw Exception('HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating invoice status: $e');
      rethrow;
    }
  }

  Future<List<dynamic>> fetchCSTAll(String typeInvoice) async {
    try {
      final response = await _handleRequest((token) {
        final uri = Uri.parse('$_baseUrl/getCSTAll').replace(
          queryParameters: {'token': token, 'type_invoice': typeInvoice},
        );
        return http
            .get(uri, headers: {'Content-Type': 'application/json'})
            .timeout(const Duration(seconds: 15));
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Handle berbagai format response
        if (data['status'] == true || data['error'] == false) {
          // Jika data ada dan tidak kosong
          if (data['data'] != null) {
            if (data['data'] is List) {
              return data['data'];
            } else {
              return [];
            }
          } else {
            return [];
          }
        } else {
          return [];
        }
      } else if (response.statusCode == 404) {
        print('Endpoint CST not found (404), returning empty list');
        return [];
      } else {
        throw Exception('HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('timed out') ||
          e.toString().contains('Connection') ||
          e.toString().contains('404')) {
        print('Network error CST, returning empty list: $e');
        return [];
      }
      print('Error fetching CST: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> fetchCSTDetail(String shipId) async {
    try {
      final response = await _handleRequest((token) {
        final uri = Uri.parse(
          '$_baseUrl/getCSTDetail',
        ).replace(queryParameters: {'token': token, 'ship_id': shipId});
        return http
            .get(uri, headers: {'Content-Type': 'application/json'})
            .timeout(const Duration(seconds: 15));
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == true && data['data'] != null) {
          return data['data'];
        } else {
          throw Exception('Failed to fetch CST detail: ${data['message']}');
        }
      } else {
        throw Exception('HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching CST detail: $e');
      rethrow;
    }
  }

  Future<bool> updateCSTStatus({
    required String shipId,
    required String paymentType,
    String? paymentAmount,
    String? paymentDifference,
    String? paymentNotes,
  }) async {
    try {
      final response = await _handleRequest((token) {
        Map<String, dynamic> payload = {
          'ship_id': int.parse(shipId),
          'payment_type': int.parse(paymentType),
        };

        if (paymentAmount != null) {
          payload['payment_amount'] = int.parse(
            paymentAmount.replaceAll('.', ''),
          );
        }

        if (paymentDifference != null) {
          payload['is_diff'] = int.parse(paymentDifference);
        }
        if (paymentNotes != null && paymentNotes.isNotEmpty) {
          payload['notes'] = paymentNotes;
        }

        return http
            .post(
              Uri.parse('$_baseUrl/update_status_cst'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'token': token, 'data': payload}),
            )
            .timeout(const Duration(seconds: 15));
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'] == true;
      } else {
        throw Exception('HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating CST status: $e');
      rethrow;
    }
  }
}
