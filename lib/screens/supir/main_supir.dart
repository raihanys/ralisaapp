import 'package:flutter/material.dart';
import '../login_screen.dart';
import '../../services/auth_service.dart';
import 'absen_supir.dart';
import 'tugas_supir.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../../services/background_services/unified_background_service.dart';

class MainSupir extends StatefulWidget {
  final int initialTabIndex;
  const MainSupir({Key? key, this.initialTabIndex = 0}) : super(key: key);

  @override
  State<MainSupir> createState() => _MainSupirState();
}

class _MainSupirState extends State<MainSupir> {
  int _currentIndex = 0;
  late AuthService _authService;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;
    _authService = AuthService();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(seconds: 1));
      final service = FlutterBackgroundService();
      if (!await service.isRunning()) {
        await UnifiedBackgroundService().initializeService(
          role: await _authService.getRole() ?? '1',
        );
      }
    });
  }

  final List<String> _titles = ['Absen', 'Tugas'];
  final List<Widget> _pages = [
    const AbsenSupirScreen(),
    const TugasSupirScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(150.0),
        child: SafeArea(child: _buildCustomAppBar(context, _currentIndex)),
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: _buildFloatingNavBar(theme),
    );
  }

  Widget _buildCustomAppBar(BuildContext context, int currentIndex) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Image.asset('assets/images/logo.png', height: 40, width: 200),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder:
                            (context) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                      );

                      // Perform logout
                      await _authService.logout();

                      if (!mounted) return;
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                      );
                    },
                    child: const Text('Logout'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Aplikasi Supir',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          Text(
            _titles[currentIndex],
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingNavBar(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: theme.colorScheme.surface,
          selectedItemColor: theme.colorScheme.primary,
          unselectedItemColor: theme.colorScheme.onSurface.withOpacity(0.6),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.access_time_outlined),
              activeIcon: Icon(Icons.access_time),
              label: 'Absen',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.assignment_outlined),
              activeIcon: Icon(Icons.assignment),
              label: 'Tugas',
            ),
          ],
        ),
      ),
    );
  }
}
