import 'package:flutter/material.dart';
import 'detail_monitoring_admlcl.dart';
import '../login_screen.dart';
import '../../services/auth_service.dart';
import '../../services/lcl_service.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

class MonitoringAdmLCL extends StatefulWidget {
  const MonitoringAdmLCL({Key? key}) : super(key: key);

  @override
  _MonitoringAdmLCLState createState() => _MonitoringAdmLCLState();
}

class _MonitoringAdmLCLState extends State<MonitoringAdmLCL> {
  late AuthService _authService;
  late LCLService _lclService;
  List<Map<String, dynamic>> _lpbList = [];
  bool _isLoading = true;
  String? _username;

  final RefreshController _refreshController = RefreshController(
    initialRefresh: false,
  );
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredLpbList = [];

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _lclService = LCLService();
    _fetchUsernameAndData();
  }

  // Fungsi baru untuk mengambil username lalu data lpb
  Future<void> _fetchUsernameAndData() async {
    _username = await _authService.getUsername();
    _fetchLPBData();
  }

  Future<void> _fetchLPBData() async {
    setState(() => _isLoading = true);
    try {
      // Pastikan username sudah didapat
      if (_username == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal mendapatkan username!')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final allData = await _lclService.getLPBHeaderAll();

      if (allData != null) {
        final filteredData =
            allData.where((item) {
              final petugas = item['petugas']?.toString().toLowerCase() ?? '';
              return petugas == _username!.toLowerCase();
            }).toList();

        if (mounted) {
          setState(() {
            _lpbList = filteredData;
            _filteredLpbList = _lpbList;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _lpbList = [];
            _filteredLpbList = [];
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
        _filteredLpbList = _lpbList;
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
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Aplikasi LCL',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      Text(
                        'Monitoring Scan LPB',
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

  Widget _buildInfoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filteredLpbList.isEmpty) {
      return const Center(child: Text("Tidak ada data LPB untuk Anda"));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredLpbList.length,
      itemBuilder: (context, index) {
        final item = _filteredLpbList[index];

        String statusText;
        Color statusColor;
        if (item['container_id'] == null) {
          statusText = "Warehouse";
          statusColor = Colors.green[100]!;
        } else {
          statusText = "Container";
          statusColor = Colors.blue[100]!;
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
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
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
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          fontSize: 12,
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
                const SizedBox(height: 12),
                Text(
                  'Petugas: ${item['petugas'] ?? '-'}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: [
                          _buildInfoChip(
                            'QTY',
                            '${item['total_item'] ?? '0'} item',
                          ),
                          _buildInfoChip(
                            'Berat',
                            '${item['weight'] ?? '0'} kg',
                          ),
                          _buildInfoChip(
                            'Volume',
                            '${item['volume'] ?? '0'} m3',
                          ),
                        ],
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
                                (context) => DetailMonitoringAdmLCL(
                                  noLpb: item['no_lpb'],
                                  totalQty: '${item['total_item'] ?? '0'} item',
                                  totalWeight: '${item['weight'] ?? '0'} kg',
                                  totalVolume: '${item['volume'] ?? '0'} m3',
                                ),
                          ),
                        ).then((shouldRefresh) {
                          if (shouldRefresh == true) {
                            _fetchLPBData();
                          }
                        });
                      },
                      child: const Text("View"),
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
