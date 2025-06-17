import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

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
  MobileScannerController cameraController = MobileScannerController();
  bool _isScanComplete = false;

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
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Data barang berhasil disimpan'),
                        ),
                      );
                      _resetForm();
                      _startScanning();
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

  void _resetForm() {
    _namaBarangController.clear();
    _tipeBarangController.clear();
    _panjangController.clear();
    _lebarController.clear();
    _tinggiController.clear();
    _beratController.clear();
    setState(() {
      _volume = '0';
      _isScanComplete = false;
    });
  }

  void _startScanning() {
    setState(() {
      _isScanComplete = false;
    });
    cameraController.start();
  }

  void _stopScanning() {
    cameraController.stop();
  }

  @override
  void dispose() {
    cameraController.dispose();
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
      body:
          _isScanComplete
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                children: [
                  MobileScanner(
                    controller: cameraController,
                    onDetect: (capture) {
                      final List<Barcode> barcodes = capture.barcodes;
                      if (barcodes.isNotEmpty) {
                        _stopScanning();
                        setState(() {
                          _isScanComplete = true;
                        });
                        _showInputModal();
                      }
                    },
                  ),
                  Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      margin: const EdgeInsets.only(top: 40),
                      padding: const EdgeInsets.all(8),
                      color: Colors.black.withOpacity(0.4),
                      child: const Text(
                        'Scan Barcode Barang',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      width: 350,
                      height: 150,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.red, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
    );
  }
}
