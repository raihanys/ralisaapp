import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/lcl_service.dart';

// Model untuk Sugesti Kontainer (bisa ditaruh di file terpisah jika digunakan di banyak tempat)
class ContainerSuggestion {
  final String id;
  final String number;

  ContainerSuggestion({required this.id, required this.number});

  factory ContainerSuggestion.fromJson(Map<String, dynamic> json) {
    return ContainerSuggestion(
      id: json['container_id'] ?? '',
      number: json['container_number'] ?? '',
    );
  }
}

class ReadyToShipScreen extends StatefulWidget {
  const ReadyToShipScreen({super.key});

  @override
  State<ReadyToShipScreen> createState() => _ReadyToShipScreenState();
}

class _ReadyToShipScreenState extends State<ReadyToShipScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isFlashOn = false;
  bool _isLoading = false;
  String? _scannedBarcode;

  final LCLService _lclService = LCLService();
  String? _codeBarang;

  // --- STATE DAN CONTROLLER UNTUK KONTAINER ---
  final TextEditingController _containerSearchController =
      TextEditingController();
  String? _selectedContainerId;
  String? _selectedContainerNumber;
  List<ContainerSuggestion> _containerSuggestions = [];
  bool _isFetchingContainers = false;
  Timer? _containerDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showContainerSelectionModal();
    });
  }

  @override
  void dispose() {
    _clearContainerSelection();
    _controller.dispose();
    _containerSearchController.dispose();
    _containerDebounce?.cancel();
    super.dispose();
  }

  void _showInfoPopup(
    BuildContext context,
    String title,
    String message, {
    VoidCallback? onOkPressed,
  }) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: onOkPressed ?? () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  // --- FUNGSI-FUNGSI BARU UNTUK SELEKSI KONTAINER ---

  Future<void> _clearContainerSelection() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('container_id');
    await prefs.remove('container_number');
  }

  Future<void> _fetchContainerSuggestions(String query) async {
    if (_containerDebounce?.isActive ?? false) _containerDebounce?.cancel();

    _containerDebounce = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      setState(() => _isFetchingContainers = true);

      try {
        final suggestionsData = await _lclService.getContainerNumberLCL(query);
        if (mounted && suggestionsData != null) {
          setState(() {
            _containerSuggestions =
                suggestionsData
                    .map((item) => ContainerSuggestion.fromJson(item))
                    .toList();
          });
        }
      } finally {
        if (mounted) setState(() => _isFetchingContainers = false);
      }
    });
  }

  void _showContainerSelectionModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Pilih Nomor Kontainer'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _containerSearchController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Ketik nomor kontainer',
                      suffixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) {
                      setDialogState(() {
                        _fetchContainerSuggestions(value);
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  _isFetchingContainers
                      ? const CircularProgressIndicator()
                      : SizedBox(
                        height: 200,
                        width: double.maxFinite,
                        child: ListView.builder(
                          itemCount: _containerSuggestions.length,
                          itemBuilder: (context, index) {
                            final suggestion = _containerSuggestions[index];
                            return ListTile(
                              title: Text(suggestion.number),
                              onTap: () async {
                                final prefs =
                                    await SharedPreferences.getInstance();
                                await prefs.setString(
                                  'container_id',
                                  suggestion.id,
                                );
                                await prefs.setString(
                                  'container_number',
                                  suggestion.number,
                                );

                                setState(() {
                                  _selectedContainerId = suggestion.id;
                                  _selectedContainerNumber = suggestion.number;
                                });

                                Navigator.of(dialogContext).pop();
                              },
                            );
                          },
                        ),
                      ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Keluar dari halaman utama
                  },
                  child: const Text('Batal'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _toggleFlash() {
    setState(() {
      _isFlashOn = !_isFlashOn;
      _controller.toggleTorch();
    });
  }

  Future<void> _showConfirmationModal(
    BuildContext context,
    String scannedBarcode,
  ) async {
    if (_isFlashOn) {
      _controller.toggleTorch();
      setState(() => _isFlashOn = false);
    }

    setState(() {
      _isLoading = true;
      _scannedBarcode = scannedBarcode;
    });

    try {
      final lpbData = await _lclService.getLPBInfoDetail(scannedBarcode);
      setState(() => _isLoading = false);

      // Tampilkan popup jika status dari backend adalah false
      if (lpbData == null || lpbData['status'] == false) {
        final message =
            lpbData?['message'] ??
            'Data barang tidak ditemukan atau terjadi kesalahan.';
        _showInfoPopup(
          context,
          'Informasi',
          message,
          onOkPressed: () {
            Navigator.of(context).pop();
            _controller.start();
            _scannedBarcode = null;
          },
        );
        return;
      }

      final data = lpbData['data'] as Map<String, dynamic>;
      _codeBarang = data['code_barang'] ?? '';

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _buildConfirmationDialog(context),
      ).then((_) {
        _controller.start();
        _scannedBarcode = null;
        _codeBarang = null;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showInfoPopup(
        context,
        'Error',
        'Terjadi kesalahan: ${e.toString()}',
        onOkPressed: () {
          Navigator.of(context).pop();
          _controller.start();
          _scannedBarcode = null;
        },
      );
    }
  }

  Widget _buildConfirmationDialog(BuildContext context) {
    return AlertDialog(
      title: const Text('Konfirmasi Update Status'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Kontainer: ${_selectedContainerNumber ?? '...'}'),
          const SizedBox(height: 10),
          Text('Kode Barang: $_codeBarang'),
          const SizedBox(height: 20),
          const Text('Ubah status menjadi Ready to Ship?'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () async {
            // Tutup dialog konfirmasi
            Navigator.pop(context);
            setState(() => _isLoading = true);

            final prefs = await SharedPreferences.getInstance();
            final containerId = prefs.getString('container_id');

            if (containerId == null) {
              _showInfoPopup(
                context,
                'Gagal',
                'ID Kontainer tidak ditemukan. Mohon pilih ulang.',
              );
              setState(() => _isLoading = false);
              return;
            }

            // --- PERUBAHAN PADA SAAT SUBMIT DATA ---
            final result = await _lclService.updateStatusReadyToShip(
              numberLpbItem: _scannedBarcode!,
              containerNumber: containerId,
            );

            setState(() => _isLoading = false);

            final bool success = result['success'];
            final String message = result['message'];

            if (mounted) {
              _showInfoPopup(
                context,
                success ? 'Berhasil' : 'Gagal',
                message,
                onOkPressed: () {
                  Navigator.of(context).pop(); // Tutup popup
                  _controller.start();
                },
              );
            }
          },
          child: const Text('Iya'),
        ),
      ],
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ready to Ship',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'No. Kontainer: ${_selectedContainerNumber ?? '...'}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.blueGrey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
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
                  onDetect: (capture) async {
                    if (_scannedBarcode != null || _selectedContainerId == null)
                      return;
                    final barcode = capture.barcodes.first.rawValue;
                    if (barcode != null) {
                      setState(() => _scannedBarcode = barcode);
                      _controller.stop();
                      await _showConfirmationModal(context, barcode);
                    }
                  },
                ),
              ),
            ),
          ),
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
          if (_isLoading) const Center(child: CircularProgressIndicator()),
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
