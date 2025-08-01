import 'package:flutter/material.dart';
import 'itemlpb_warehouse.dart';
import '../login_screen.dart';
import '../../services/auth_service.dart';
import '../../services/warehouse_service.dart';

class MainWarehouse extends StatefulWidget {
  const MainWarehouse({Key? key}) : super(key: key);

  @override
  _MainWarehouseState createState() => _MainWarehouseState();
}

class _MainWarehouseState extends State<MainWarehouse> {
  late AuthService _authService;
  late WarehouseService _warehouseService; // Service baru
  List<Map<String, dynamic>> _lpbList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _warehouseService = WarehouseService(); // Inisialisasi service
    _fetchLPBData();
  }

  Future<void> _fetchLPBData() async {
    setState(() => _isLoading = true);
    try {
      final data = await _warehouseService.getLPBHeaderAll();
      if (data != null) {
        setState(() {
          _lpbList = data;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        // Tampilkan error ke pengguna
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Gagal memuat data LPB')));
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(150.0),
        child: SafeArea(child: _buildCustomAppBar(context)),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildContent(),
    );
  }

  Widget _buildCustomAppBar(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset('assets/images/logo.png', height: 40, width: 200),
                ElevatedButton(
                  onPressed: () async {
                    await _authService.logout();
                    if (!mounted) return;
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Logout'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Aplikasi Kepala Gudang',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            Text(
              'Daftar LPB',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_lpbList.isEmpty) {
      return const Center(child: Text("Tidak ada data LPB"));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _lpbList.length,
      itemBuilder: (context, index) {
        final item = _lpbList[index];

        // Format status text based on received_in value
        String statusText;
        Color statusColor;
        switch (item['received_in']?.toLowerCase()) {
          case 'container':
            statusText = "in Container";
            statusColor = Colors.blue[100]!;
            break;
          case 'warehouse':
            statusText = "in Warehouse";
            statusColor = Colors.green[100]!;
            break;
          default:
            statusText = "Not Processed";
            statusColor = Colors.orange[100]!;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item['no_lpb'] ?? 'No LPB',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Pengirim: ${item['sender'] ?? '-'}',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  'Penerima: ${item['receiver'] ?? '-'}',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Jumlah: ${item['total_item'] ?? '0'} item',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[300],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) =>
                                    ItemLpbWarehouse(noLpb: item['no_lpb']),
                          ),
                        );
                      },
                      child: const Text("Proses"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
