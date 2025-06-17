import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../login_screen.dart';
import 'scan_admlcl.dart';
import 'data_admlcl.dart';

class MainLCL extends StatefulWidget {
  const MainLCL({super.key});

  @override
  State<MainLCL> createState() => _MainLCLState();
}

class _MainLCLState extends State<MainLCL> {
  int _currentIndex = 0;
  final AuthService _authService = AuthService();
  final List<String> _titles = ['Scan', 'Data'];

  final List<Widget> _pages = [const ScanAdmLCL(), const DataAdmLCL()];

  void _logout(BuildContext context) async {
    await _authService.logout();
    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      // Menggunakan AppBar kustom yang sama seperti di main_supir.dart
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(150.0),
        child: SafeArea(child: _buildCustomAppBar(context, _currentIndex)),
      ),
      // IndexedStack untuk menjaga state setiap tab
      body: IndexedStack(index: _currentIndex, children: _pages),
      // Menggunakan Bottom Nav Bar kustom yang sama
      bottomNavigationBar: _buildFloatingNavBar(theme),
    );
  }

  // Widget AppBar kustom yang diadaptasi dari main_supir.dart
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
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => _logout(context),
                child: const Text('Logout'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Aplikasi Admin LCL', // Diubah dari 'Aplikasi Supir'
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          Text(
            _titles[currentIndex], // Judul dinamis sesuai tab yang aktif
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // Widget Bottom Nav Bar kustom yang diadaptasi dari main_supir.dart
  Widget _buildFloatingNavBar(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
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
              icon: Icon(Icons.qr_code_scanner_outlined),
              activeIcon: Icon(Icons.qr_code_scanner),
              label: 'Scan', // Tab pertama
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.list_alt_outlined),
              activeIcon: Icon(Icons.list_alt),
              label: 'Data', // Tab kedua
            ),
          ],
        ),
      ),
    );
  }
}
