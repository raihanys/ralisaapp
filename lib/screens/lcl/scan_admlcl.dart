import 'package:flutter/material.dart';

class ScanAdmLCL extends StatefulWidget {
  const ScanAdmLCL({super.key});

  @override
  State<ScanAdmLCL> createState() => _ScanAdmLCLState();
}

class _ScanAdmLCLState extends State<ScanAdmLCL> {
  // Controller untuk form
  final TextEditingController _namaBarangController = TextEditingController();
  final TextEditingController _tipeBarangController = TextEditingController();
  final TextEditingController _panjangController = TextEditingController();
  final TextEditingController _lebarController = TextEditingController();
  final TextEditingController _tinggiController = TextEditingController();
  final TextEditingController _beratController = TextEditingController();
  String _volume = '0';
  bool _isScanning = false;

  // Fungsi untuk menghitung volume
  void _hitungVolume() {
    try {
      double panjang = double.tryParse(_panjangController.text) ?? 0;
      double lebar = double.tryParse(_lebarController.text) ?? 0;
      double tinggi = double.tryParse(_tinggiController.text) ?? 0;
      double volume = panjang * lebar * tinggi;
      setState(() {
        _volume = volume.toStringAsFixed(2);
      });
    } catch (e) {
      setState(() {
        _volume = '0';
      });
    }
  }

  // Fungsi untuk mensimulasikan scan barcode
  void _simulateBarcodeScan() async {
    setState(() {
      _isScanning = true;
    });

    // Simulasi proses scanning (3 detik)
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    setState(() {
      _isScanning = false;
    });

    // Tampilkan modal input
    _showInputModal();
  }

  // Fungsi untuk menampilkan modal
  void _showInputModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Input Data Barang',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _namaBarangController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Barang',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _tipeBarangController,
                    decoration: const InputDecoration(
                      labelText: 'Tipe Barang',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _panjangController,
                          decoration: const InputDecoration(
                            labelText: 'Panjang (cm)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => _hitungVolume(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _lebarController,
                          decoration: const InputDecoration(
                            labelText: 'Lebar (cm)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => _hitungVolume(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _tinggiController,
                          decoration: const InputDecoration(
                            labelText: 'Tinggi (cm)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => _hitungVolume(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Volume (m³)',
                      border: const OutlineInputBorder(),
                      suffixText: _volume,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _beratController,
                    decoration: const InputDecoration(
                      labelText: 'Berat (Kg)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      // Simpan data dan tutup modal
                      Navigator.pop(context);
                      // Reset form
                      _namaBarangController.clear();
                      _tipeBarangController.clear();
                      _panjangController.clear();
                      _lebarController.clear();
                      _tinggiController.clear();
                      _beratController.clear();
                      setState(() {
                        _volume = '0';
                      });
                      // Tampilkan snackbar konfirmasi
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Data barang berhasil disimpan'),
                        ),
                      );
                    },
                    child: const Text('Simpan'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _namaBarangController.dispose();
    _tipeBarangController.dispose();
    _panjangController.dispose();
    _lebarController.dispose();
    _tinggiController.dispose();
    _beratController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isScanning)
              Column(
                children: [
                  const Icon(
                    Icons.qr_code_scanner,
                    size: 100,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Scanning Barcode...',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 20),
                  CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isScanning = false;
                      });
                    },
                    child: const Text('Cancel Scan'),
                  ),
                ],
              )
            else
              ElevatedButton.icon(
                onPressed: _simulateBarcodeScan,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 16,
                  ),
                ),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text(
                  'Scan Barcode',
                  style: TextStyle(fontSize: 18),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
