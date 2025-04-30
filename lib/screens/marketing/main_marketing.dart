import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../login_screen.dart';

class MainMarketing extends StatelessWidget {
  const MainMarketing({super.key});

  void _logout(BuildContext context) async {
    await AuthService().logout();

    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Marketing"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: const Center(child: Text("Halaman Marketing")),
    );
  }
}
