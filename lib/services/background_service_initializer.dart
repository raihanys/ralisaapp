import 'package:shared_preferences/shared_preferences.dart';
import '../services/pelabuhan_service.dart';
import '../services/supir_service.dart';
import '../services/auth_service.dart';
import 'package:flutter/material.dart';

Future<void> initializeRoleBasedService(BuildContext context) async {
  // Tambahkan BuildContext
  final prefs = await SharedPreferences.getInstance();
  final role = prefs.getString('role') ?? '';

  print('Role: $role'); // Tambahkan log untuk mencetak role

  if (role == '3') {
    print(
      'Initializing PelabuhanService',
    ); // Tambahkan log sebelum inisialisasi
    await PelabuhanService(AuthService()).initializeService();
    print('PelabuhanService initialized'); // Tambahkan log setelah inisialisasi
  } else if (role == '1') {
    print(
      'Initializing SupirBackgroundService',
    ); // Tambahkan log sebelum inisialisasi
    await SupirBackgroundService().initializeService();
    print(
      'SupirBackgroundService initialized',
    ); // Tambahkan log setelah inisialisasi
  }
}
