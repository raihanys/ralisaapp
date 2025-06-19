import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class InputDataScreen extends StatefulWidget {
  const InputDataScreen({super.key});

  @override
  State<InputDataScreen> createState() => _InputDataScreenState();
}

class _InputDataScreenState extends State<InputDataScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isScanning = true;
  String? _scannedBarcode;

  // Controllers for the text fields in the modal
  final TextEditingController _noLpbController = TextEditingController();
  final TextEditingController _kodebarangController = TextEditingController();
  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _tipeController = TextEditingController();
  final TextEditingController _panjangController = TextEditingController();
  final TextEditingController _lebarController = TextEditingController();
  final TextEditingController _tinggiController = TextEditingController();
  final TextEditingController _beratController = TextEditingController();

  // For volume calculation display
  String _volume = '0';

  final _formKey = GlobalKey<FormState>(); // Key for form validation

  @override
  void dispose() {
    _controller.dispose();
    _noLpbController.dispose();
    _kodebarangController.dispose();
    _namaController.dispose();
    _tipeController.dispose();
    _panjangController.dispose();
    _lebarController.dispose();
    _tinggiController.dispose();
    _beratController.dispose();
    super.dispose();
  }

  void _hitungVolume() {
    final double? panjang = double.tryParse(_panjangController.text);
    final double? lebar = double.tryParse(_lebarController.text);
    final double? tinggi = double.tryParse(_tinggiController.text);

    if (panjang != null && lebar != null && tinggi != null) {
      setState(() {
        _volume = (panjang * lebar * tinggi).toStringAsFixed(2);
      });
    } else {
      setState(() {
        _volume = '0';
      });
    }
  }

  void _showInputModal(BuildContext context) {
    // Clear previous input when showing the modal
    _noLpbController.clear();
    _kodebarangController.clear();
    _namaController.clear();
    _tipeController.clear();
    _panjangController.clear();
    _lebarController.clear();
    _tinggiController.clear();
    _beratController.clear();
    _volume = '0'; // Reset volume display

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: SingleChildScrollView(
            child: Form(
              // Wrap with Form for validation
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                        onPressed: () {
                          Navigator.pop(context);
                          setState(() {
                            _isScanning = true;
                            _scannedBarcode = null;
                          });
                          _controller.start();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _noLpbController,
                    decoration: const InputDecoration(
                      labelText: 'No. LPB',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      // Add validator
                      if (value == null || value.isEmpty) {
                        return 'No. LPB tidak boleh kosong';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _kodebarangController,
                    decoration: const InputDecoration(
                      labelText: 'Kode Barang',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      // Add validator
                      if (value == null || value.isEmpty) {
                        return 'Kode Barang tidak boleh kosong';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _namaController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Barang',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      // Add validator
                      if (value == null || value.isEmpty) {
                        return 'Nama Barang tidak boleh kosong';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _tipeController,
                    decoration: const InputDecoration(
                      labelText: 'Tipe Barang',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      // Add validator
                      if (value == null || value.isEmpty) {
                        return 'Tipe Barang tidak boleh kosong';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _panjangController,
                          decoration: const InputDecoration(
                            labelText: 'Panjang (cm)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => _hitungVolume(),
                          validator: (value) {
                            // Add validator
                            if (value == null ||
                                value.isEmpty ||
                                double.tryParse(value) == null) {
                              return 'Masukkan angka';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _lebarController,
                          decoration: const InputDecoration(
                            labelText: 'Lebar (cm)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => _hitungVolume(),
                          validator: (value) {
                            // Add validator
                            if (value == null ||
                                value.isEmpty ||
                                double.tryParse(value) == null) {
                              return 'Masukkan angka';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _tinggiController,
                          decoration: const InputDecoration(
                            labelText: 'Tinggi (cm)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => _hitungVolume(),
                          validator: (value) {
                            // Add validator
                            if (value == null ||
                                value.isEmpty ||
                                double.tryParse(value) == null) {
                              return 'Masukkan angka';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Volume (cm³)',
                      border: const OutlineInputBorder(),
                      hintText: _volume, // Display calculated volume
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _beratController,
                    decoration: const InputDecoration(
                      labelText: 'Berat (kg)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      // Add validator
                      if (value == null ||
                          value.isEmpty ||
                          double.tryParse(value) == null) {
                        return 'Masukkan angka';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      if (_formKey.currentState?.validate() ?? false) {
                        // All fields are valid, proceed to save data
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Data berhasil disimpan'),
                          ),
                        );
                        setState(() {
                          _isScanning = true;
                          _scannedBarcode = null;
                        });
                        _controller.start();
                      }
                    },
                    child: const Text('Simpan Data'),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
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
                  'Input Data',
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
                            if (capture.barcodes.isNotEmpty && _isScanning) {
                              setState(() {
                                _isScanning = false;
                                _scannedBarcode =
                                    capture.barcodes.first.rawValue;
                              });
                              _controller.stop();
                              _showInputModal(context);
                            }
                          },
                        )
                        : Center(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() => _isScanning = true);
                              _controller.start();
                            },
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
