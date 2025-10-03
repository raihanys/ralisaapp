import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/lcl_service.dart';

// Model untuk Sugesti Kontainer
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
  // --- NEW ---: State to check if a container has been selected.
  bool _isContainerSelected = false;

  List<ContainerSuggestion> _allContainers = [];

  String? _currentLpbHeader;
  int _totalItemsInLpb = 0;
  // Using a Set ensures we only store unique barcode scans
  final Set<String> _scannedLpbItems = {};

  String _getLpbHeader(String fullBarcode) {
    int lastSlashIndex = fullBarcode.lastIndexOf('/');
    if (lastSlashIndex != -1) {
      return fullBarcode.substring(0, lastSlashIndex);
    }
    return fullBarcode; // Fallback if format is unexpected
  }

  @override
  void initState() {
    super.initState();
    _initContainers();
  }

  @override
  void dispose() {
    _clearContainerSelection();
    _controller.dispose();
    _containerSearchController.dispose();
    super.dispose();
  }

  // --- FUNGSI-FUNGSI BARU UNTUK SELEKSI KONTAINER ---

  Future<void> _clearContainerSelection() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('container_id');
    await prefs.remove('container_number');
  }

  Future<void> _loadAllContainers() async {
    setState(() => _isFetchingContainers = true);
    final containersData = await _lclService.getAllContainerNumbers();
    if (containersData != null) {
      setState(() {
        _allContainers =
            containersData
                .map((item) => ContainerSuggestion.fromJson(item))
                .toList();
      });
    }
    setState(() => _isFetchingContainers = false);
  }

  Future<void> _initContainers() async {
    await _loadAllContainers();
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showContainerSelectionModal();
      });
    }
  }

  void _filterContainerSuggestions(String query, StateSetter dialogSetState) {
    List<ContainerSuggestion> filtered;
    if (query.isEmpty) {
      filtered = _allContainers;
    } else {
      filtered =
          _allContainers.where((container) {
            return container.number.toLowerCase().contains(query.toLowerCase());
          }).toList();
    }

    // Gunakan dialogSetState untuk update UI di dalam dialog
    dialogSetState(() {
      _containerSuggestions = filtered;
    });
  }

  void _showContainerSelectionModal() {
    // PENTING: Atur state awal suggestions SEBELUM dialog tampil
    // Ini untuk mengatasi masalah "muter-muter"
    setState(() {
      _containerSuggestions = _allContainers;
      _containerSearchController.clear();
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // <-- setDialogState ini akan kita pakai
            return AlertDialog(
              title: const Text('Pilih Nomor Kontainer'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _containerSearchController,
                    onChanged: (value) {
                      // Panggil fungsi yang sudah diubah dan berikan setDialogState
                      _filterContainerSuggestions(value, setDialogState);
                    },
                    decoration: const InputDecoration(
                      labelText: 'Cari nomor kontainer...',
                      suffixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Kondisi loading sekarang akan selalu false saat dialog dibuka karena data sudah siap
                  // jadi CircularProgressIndicator tidak akan terjebak lagi.
                  _isFetchingContainers
                      ? const Center(child: CircularProgressIndicator())
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
                                  _isContainerSelected = true;
                                });

                                Navigator.of(dialogContext).pop();
                              },
                            );
                          },
                        ),
                      ),
                ],
              ),
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

  void _showErrorDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false, // Wajib tekan tombol untuk menutup
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Tutup dialog
                if (mounted) {
                  _scannedBarcode = null;
                  _controller.start(); // Aktifkan lagi scanner
                }
              },
            ),
          ],
        );
      },
    );
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

      if (lpbData == null || lpbData['data'] == null) {
        _showErrorDialog(
          context,
          'Data Tidak Ditemukan',
          'Data barang tidak ditemukan',
        );
        return;
      }

      final data = lpbData['data'] as Map<String, dynamic>;

      final String lpbHeader = _getLpbHeader(scannedBarcode);
      final int totalItems =
          int.tryParse(data['total_barang']?.toString() ?? '0') ?? 0;

      // Check if this is a new LPB header
      if (lpbHeader != _currentLpbHeader) {
        print("New LPB detected. Resetting tracking.");
        setState(() {
          _currentLpbHeader = lpbHeader;
          _totalItemsInLpb = totalItems;
          _scannedLpbItems.clear(); // Reset for the new LPB
        });
      }

      final int status = int.tryParse(data['status']?.toString() ?? '0') ?? 0;
      if (status != 4) {
        _showErrorDialog(
          context,
          'Status Tidak Valid',
          'Status barang tidak valid untuk proses ini.',
        );
        return; // Hentikan proses jika status tidak valid
      }

      _codeBarang = data['code_barang'] ?? '';

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _buildConfirmationDialog(context),
      );

      // Hapus ini karena sudah dihandle di dalam _buildConfirmationDialog
      // _controller.start();
      _scannedBarcode = null;
      _codeBarang = null;
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorDialog(context, 'Error', 'Terjadi kesalahan: ${e.toString()}');
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
          onPressed: () {
            Navigator.pop(context);
            if (mounted) {
              _controller
                  .start(); // Aktifkan scanner setelah dialog konfirmasi dibatalkan
            }
          },
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () async {
            setState(() => _isLoading = true);

            final prefs = await SharedPreferences.getInstance();
            final containerId = prefs.getString('container_id');

            if (containerId == null) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(
                    const SnackBar(
                      content: Text(
                        'ID Kontainer tidak ditemukan. Mohon pilih ulang.',
                      ),
                    ),
                  )
                  .closed
                  .then((_) {
                    if (mounted) {
                      _controller
                          .start(); // Aktifkan scanner setelah snackbar tertutup
                    }
                  });
              setState(() => _isLoading = false);
              Navigator.pop(context);
              return;
            }

            if (_scannedBarcode == null) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Barcode barang tidak ditemukan. Mohon scan ulang.',
                      ),
                    ),
                  )
                  .closed
                  .then((_) {
                    if (mounted) {
                      _controller
                          .start(); // Aktifkan scanner setelah snackbar tertutup
                    }
                  });
              setState(() => _isLoading = false);
              Navigator.pop(context);
              return;
            }

            try {
              final String currentBarcode = _scannedBarcode!;

              final success = await _lclService.updateStatusReadyToShip(
                numberLpbItem: currentBarcode,
                containerNumber: containerId,
              );

              if (mounted) {
                Navigator.pop(context);

                if (success) {
                  _scannedLpbItems.add(currentBarcode);
                }

                if (success &&
                    _scannedLpbItems.length >= _totalItemsInLpb &&
                    _totalItemsInLpb > 0) {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder:
                        (context) => AlertDialog(
                          title: const Text('LPB Selesai'),
                          content: Text(
                            'Semua $_totalItemsInLpb barang untuk LPB $_currentLpbHeader telah berhasil di-ship.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _currentLpbHeader = null;
                                  _totalItemsInLpb = 0;
                                  _scannedLpbItems.clear();
                                });
                                Navigator.of(context).pop();
                                if (mounted) {
                                  // Aktifkan scanner setelah dialog selesai tertutup
                                  _controller.start();
                                }
                              },
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                  );
                } else {
                  // Belum selesai, tampilkan pesan sukses/gagal standar
                  showDialog(
                    context: context,
                    builder:
                        (context) => AlertDialog(
                          title: Text(success ? 'Berhasil' : 'Gagal'),
                          content: Text(
                            success
                                ? 'Status berhasil diubah ke Ready to Ship. Sisa ${_totalItemsInLpb - _scannedLpbItems.length} barang lagi.'
                                : 'Gagal mengubah status',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                if (mounted) {
                                  _controller
                                      .start(); // Aktifkan scanner setelah dialog status tertutup
                                }
                              },
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                  );
                }
              }
            } catch (e) {
              if (mounted) {
                Navigator.pop(context); // Tutup dialog konfirmasi jika error
                showDialog(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                        title: const Text('Error'),
                        content: Text('Terjadi kesalahan: ${e.toString()}'),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              if (mounted) {
                                _controller
                                    .start(); // Aktifkan scanner setelah dialog error tertutup
                              }
                            },
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                );
              }
            } finally {
              if (mounted) setState(() => _isLoading = false);
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
                    Text(
                      'Shipping in : ${_selectedContainerNumber ?? '...'}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
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
                // --- UPDATED ---: Conditionally show the scanner or a placeholder text.
                child:
                    _isContainerSelected
                        ? MobileScanner(
                          controller: _controller,
                          onDetect: (capture) async {
                            if (_scannedBarcode != null ||
                                _selectedContainerId == null) {
                              return;
                            }
                            final barcode = capture.barcodes.first.rawValue;
                            if (barcode != null) {
                              setState(() => _scannedBarcode = barcode);
                              _controller.stop();
                              await _showConfirmationModal(context, barcode);
                            }
                          },
                        )
                        : const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Text(
                              'Pilih nomor kontainer untuk mengaktifkan pemindai.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
              ),
            ),
          ),
          // --- UPDATED ---: Only show the red border if the scanner is active.
          if (_isContainerSelected)
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
