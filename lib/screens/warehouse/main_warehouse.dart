import 'package:flutter/material.dart';
import 'itemlpb_warehouse.dart';
import '../login_screen.dart';
import '../../services/auth_service.dart';
import '../../services/warehouse_service.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

class MainWarehouse extends StatefulWidget {
  const MainWarehouse({Key? key}) : super(key: key);

  @override
  _MainWarehouseState createState() => _MainWarehouseState();
}

class _MainWarehouseState extends State<MainWarehouse> {
  late AuthService _authService;
  late WarehouseService _warehouseService;
  List<Map<String, dynamic>> _lpbList = [];
  bool _isLoading = true;

  final RefreshController _refreshController = RefreshController(
    initialRefresh: false,
  );
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredLpbList = [];

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _warehouseService = WarehouseService();
    _fetchLPBData();
  }

  Future<void> _fetchLPBData() async {
    setState(() => _isLoading = true);
    try {
      final data = await _warehouseService.getLPBHeaderAll();
      setState(() {
        _lpbList = data ?? [];
        _filteredLpbList = _lpbList;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

  void _onRefresh() async {
    await _fetchLPBData();
    _refreshController.refreshCompleted();
  }

  void _filterList(String query) {
    if (_lpbList.isEmpty) return;

    setState(() {
      if (query.isEmpty) {
        _filteredLpbList = _lpbList; // Tampilkan semua data saat query kosong
      } else {
        _filteredLpbList =
            _lpbList.where((item) {
              final noLpb = item['no_lpb']?.toString().toLowerCase() ?? '';
              final sender = item['sender']?.toString().toLowerCase() ?? '';
              final receiver = item['receiver']?.toString().toLowerCase() ?? '';
              return noLpb.contains(query.toLowerCase()) ||
                  sender.contains(query.toLowerCase()) ||
                  receiver.contains(query.toLowerCase());
            }).toList();
      }
    });
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
              : Column(
                children: [
                  // PULL TO REFRESH CONTENT
                  Expanded(
                    child: SmartRefresher(
                      controller: _refreshController,
                      onRefresh: _onRefresh,
                      child: _buildContent(),
                    ),
                  ),
                ],
              ),
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Aplikasi Kepala Gudang',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      Text(
                        'Daftar LPB',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Cari LPB...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      suffixIcon:
                          _searchController.text.isNotEmpty
                              ? IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                onPressed: () {
                                  _searchController.clear();
                                  _filterList('');
                                },
                              )
                              : null,
                    ),
                    onChanged: _filterList,
                  ),
                ),
              ],
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
      itemCount: _filteredLpbList.length,
      itemBuilder: (context, index) {
        final item = _filteredLpbList[index];

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
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item['no_lpb'] ?? 'No LPB',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          fontSize: 10,
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
                        ).then((shouldRefresh) {
                          if (shouldRefresh == true) {
                            _fetchLPBData(); // Refresh data setelah kembali
                          }
                        });
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
