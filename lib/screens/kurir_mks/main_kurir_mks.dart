import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/kurir_mks_service.dart';
import '../../services/auth_service.dart';
import '../login_screen.dart';

class KurirMksScreen extends StatefulWidget {
  const KurirMksScreen({super.key});

  @override
  State<KurirMksScreen> createState() => _KurirMksScreenState();
}

class _KurirMksScreenState extends State<KurirMksScreen> {
  final MobileScannerController _controller = MobileScannerController();
  final KurirMksService _kurirMksService = KurirMksService();
  final AuthService _authService = AuthService();

  bool _isFlashOn = false;
  bool _isLoading = false;
  String? _scannedBarcode;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _logout(BuildContext context) async {
    await _authService.logout();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _toggleFlash() {
    setState(() {
      _isFlashOn = !_isFlashOn;
      _controller.toggleTorch();
    });
  }

  Future<void> _handleScannedBarcode(String barcode) async {
    // Hentikan scanner sementara dan tunjukkan loading
    _controller.stop();
    setState(() {
      _isLoading = true;
      _scannedBarcode = barcode;
    });

    // Panggil service untuk mendapatkan detail barang
    final lpbData = await _kurirMksService.getLPBInfoDetail(barcode);
    setState(() => _isLoading = false);

    if (!mounted) return;

    if (lpbData == null || lpbData['data'] == null) {
      _showErrorDialog(context, 'Gagal', 'Data barang tidak ditemukan');
      return;
    }

    final data = lpbData['data'] as Map<String, dynamic>;

    // --- KONDISI BARU YANG DITAMBAHKAN ---
    // Cek apakah status barang valid untuk pengiriman
    if (data['status'] != '8') {
      _showErrorDialog(
        context,
        'Status Tidak Valid',
        'Status barang tidak valid untuk proses Pengiriman.',
      );
      return; // Hentikan proses jika status tidak valid
    }
    // --- AKHIR DARI KONDISI BARU ---

    await _showConfirmationDialog(data);
  }

  // --- FUNGSI BARU UNTUK MENAMPILKAN POPUP ERROR ---
  Future<void> _showErrorDialog(
    BuildContext context,
    String title,
    String message,
  ) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _restartScanner(); // Restart scanner setelah dialog error ditutup
                },
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  Future<void> _showConfirmationDialog(Map<String, dynamic> data) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Text('Konfirmasi Pengiriman'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No. LPB: ${data['nomor_lpb'] ?? '...'}'),
                const SizedBox(height: 8),
                Text('${data['code_barang'] ?? '...'}'),
                const SizedBox(height: 8),
                Text('Pengirim: ${data['sender_company'] ?? '...'}'),
                const SizedBox(height: 8),
                Text('Penerima: ${data['receiver_company'] ?? '...'}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _restartScanner();
                },
                child: const Text('Batal'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _updateStatus();
                },
                child: const Text('Iya'),
              ),
            ],
          ),
    );
  }

  Future<void> _updateStatus() async {
    setState(() => _isLoading = true);
    final success = await _kurirMksService.updateStatusToCustomer(
      _scannedBarcode!,
    );
    setState(() => _isLoading = false);

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false, // Dialog tidak bisa ditutup dengan tap di luar
      builder:
          (context) => AlertDialog(
            title: Text(success ? 'Berhasil' : 'Gagal'),
            content: Text(
              success
                  ? 'Status barang berhasil diperbarui.'
                  : 'Gagal memperbarui status barang. Coba lagi.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _restartScanner();
                },
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  void _restartScanner() {
    if (mounted) {
      _scannedBarcode = null;
      _controller.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(150.0),
        child: SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Image.asset(
                      'assets/images/logo.png',
                      height: 40,
                      width: 200,
                    ),
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
                  'Aplikasi Kurir Makassar',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const Text(
                  'Scan Pengiriman',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Tampilan Kamera Scanner
          Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 80),
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.8,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: MobileScanner(
                  controller: _controller,
                  onDetect: (capture) {
                    if (_scannedBarcode != null) return;
                    final barcode = capture.barcodes.first.rawValue;
                    if (barcode != null) {
                      _handleScannedBarcode(barcode);
                    }
                  },
                ),
              ),
            ),
          ),
          // Garis Merah di Tengah
          Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.6,
              height: MediaQuery.of(context).size.width * 0.6,
              margin: const EdgeInsets.only(bottom: 80),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.red, width: 4),
              ),
            ),
          ),
          // Indikator Loading
          if (_isLoading) const Center(child: CircularProgressIndicator()),
          // Tombol Flash
          Positioned(
            right: 16,
            bottom: 16,
            child: SafeArea(
              child: FloatingActionButton(
                heroTag: 'flashButton',
                onPressed: _toggleFlash,
                child: Icon(_isFlashOn ? Icons.flash_off : Icons.flash_on),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
