import 'dart:async';
import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/pelabuhan/main_pelabuhan.dart';
import 'screens/marketing/main_marketing.dart';
import 'screens/trucking/main_trucking.dart';
import 'screens/supir/main_supir.dart';
import './services/auth_service.dart';
import './services/background_services/background_service_initializer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './services/background_services/unified_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final authService = AuthService();

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi notifikasi
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) async {
      final payload = response.payload;

      if (payload != null) {
        final prefs = await SharedPreferences.getInstance();
        final role = prefs.getString('role');

        // Beri sedikit delay untuk memastikan navigator siap
        await Future.delayed(const Duration(milliseconds: 300));

        // Navigasi berdasarkan role dan payload
        if (role == '1') {
          // Supir
          navigatorKey.currentState?.pushNamedAndRemoveUntil(
            '/driver-task',
            (route) => false,
          );
        } else if (role == '3') {
          // Pelabuhan
          navigatorKey.currentState?.pushNamedAndRemoveUntil(
            '/pelabuhan-inbox',
            (route) => false,
          );
        }
      }
    },
  );

  // Initialize service sebelum running app
  _initializeService().then((_) => runApp(MyApp()));
}

Future<void> _initializeService() async {
  final prefs = await SharedPreferences.getInstance();
  final role = prefs.getString('role');
  if (role == '1' || role == '3') {
    await UnifiedBackgroundService().initializeService(role: role!);
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle changes
    if (state == AppLifecycleState.resumed) {
      // App kembali aktif
    } else if (state == AppLifecycleState.paused) {
      // App di background
    }
  }

  Future<Widget> _getStartScreen() async {
    final authService = AuthService();

    final isLoggedIn = await authService.isLoggedIn();
    final token = await authService.getValidToken();

    if (isLoggedIn && token != null) {
      await initializeBackgroundService();

      final role = await authService.getRole();
      if (role != null) {
        switch (role.toLowerCase()) {
          case '1': // Driver
            return const MainSupir();
          case '3': // Pelabuhan
            return const MainPelabuhan();
          case 'marketing':
            return const MainMarketing();
          case 'trucking':
            return const MainTrucking();
        }
      }
    }

    return const LoginScreen();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ralisa Mobile App',
      navigatorKey: navigatorKey,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF4C4C),
          brightness: Brightness.light,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      routes: {
        '/driver-task': (context) => const MainSupir(initialTabIndex: 1),
        '/pelabuhan-inbox':
            (context) => const MainPelabuhan(initialTabIndex: 0),
      },
      home: FutureBuilder(
        future: _getStartScreen(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return snapshot.data!;
          }
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        },
      ),
    );
  }
}
