import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class WarehouseScreen extends StatefulWidget {
  const WarehouseScreen({super.key});

  @override
  State<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends State<WarehouseScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isScanning = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showSuccessDialog(String barcodeValue) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Scan Berhasil'),
          content: Text('Status Updated: $barcodeValue'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() => _isScanning = true);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // warehouse_admlcl.dart
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
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Image.asset(
                      'assets/images/logo.png',
                      height: 40,
                      width: 200,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Aplikasi LCL',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const Text(
                  'Warehouse',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Scanner Container
          Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 80),
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.65,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child:
                    _isScanning
                        ? MobileScanner(
                          controller: _controller,
                          onDetect: (capture) {
                            final barcode = capture.barcodes.firstOrNull;
                            if (barcode != null && barcode.rawValue != null) {
                              setState(() => _isScanning = false);
                              _controller.stop();
                              _showSuccessDialog(barcode.rawValue!);
                            }
                          },
                        )
                        : Center(
                          child: ElevatedButton(
                            onPressed: () => setState(() => _isScanning = true),
                            child: const Text('Scan Lagi'),
                          ),
                        ),
              ),
            ),
          ),

          // Scanner Frame Indicator
          if (_isScanning)
            Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.7,
                height: 100,
                margin: const EdgeInsets.only(bottom: 80),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.red, width: 4),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

          // Tombol back
          Positioned(
            left: 16,
            bottom: 16,
            child: SafeArea(
              child: FloatingActionButton(
                heroTag: 'backButton',
                onPressed: () => Navigator.pop(context),
                child: const Icon(Icons.arrow_back),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
