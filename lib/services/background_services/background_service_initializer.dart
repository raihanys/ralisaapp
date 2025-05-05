import 'package:shared_preferences/shared_preferences.dart';
import './unified_background_service.dart';

Future<void> initializeBackgroundService() async {
  final prefs = await SharedPreferences.getInstance();
  final role = prefs.getString('role') ?? '';
  final token = prefs.getString('token') ?? '';

  if (token.isNotEmpty) {
    await UnifiedBackgroundService().initializeService(role: role);
  }
}
