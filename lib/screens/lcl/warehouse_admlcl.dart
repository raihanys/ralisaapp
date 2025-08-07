import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import '../../services/lcl_service.dart';

// Model disertakan langsung di sini untuk kemudahan
class ItemSuggestion {
  final String id;
  final String originalName; // Store the full original name
  final String packaging; // First word
  final String cleanedName; // Second word onwards
  final String type;

  ItemSuggestion({
    required this.id,
    required this.originalName,
    required this.packaging,
    required this.cleanedName,
    required this.type,
  });

  factory ItemSuggestion.fromJson(Map<String, dynamic> json) {
    String fullNamaBarang = (json['nama_barang'] ?? '').toString().trim();
    String firstWord = '';
    String restOfName = fullNamaBarang;

    int firstSpaceIndex = fullNamaBarang.indexOf(' ');
    if (firstSpaceIndex != -1) {
      firstWord = fullNamaBarang.substring(0, firstSpaceIndex).trim();
      restOfName = fullNamaBarang.substring(firstSpaceIndex + 1).trim();
    } else {
      // If no space, the whole string is the "first word" (packaging)
      firstWord = fullNamaBarang;
      restOfName = ''; // No rest of the name
    }

    return ItemSuggestion(
      id: (json['id_barang'] ?? '').toString().trim(),
      originalName: fullNamaBarang,
      packaging: firstWord,
      cleanedName: restOfName,
      type: (json['tipe_barang'] ?? '').toString().trim(),
    );
  }
}

class WarehouseScreen extends StatefulWidget {
  const WarehouseScreen({super.key});

  @override
  State<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends State<WarehouseScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isFlashOn = false;
  bool _isLoading = false;
  String? _scannedBarcode;

  final LCLService _lclService = LCLService();

  // Controllers
  final TextEditingController _noLpbController = TextEditingController();
  final TextEditingController _kodebarangController = TextEditingController();
  final TextEditingController _urutanbarangController = TextEditingController();
  final TextEditingController _totalbarangController = TextEditingController();
  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _panjangController = TextEditingController();
  final TextEditingController _lebarController = TextEditingController();
  final TextEditingController _tinggiController = TextEditingController();
  final TextEditingController _volumeController = TextEditingController();
  final TextEditingController _beratController = TextEditingController();

  List<ItemSuggestion> _itemSuggestions = [];
  bool _isFetchingSuggestions = false;
  bool _isSuggestionBoxVisible = false;

  List<Map<String, dynamic>> _tipeBarangList = [];
  bool _isLoadingTipe = false;

  String? _selectedTipeId;
  String? _selectedBarangId;
  bool _isNamaFromSuggestion = false;

  final FocusNode _namaFocusNode = FocusNode();
  Timer? _suggestionHideTimer;

  List<ItemSuggestion> _allItems = [];

  // NEW: State variables for packaging
  String? _selectedPackaging;
  // DIUBAH: Daftar kemasan yang diizinkan secara manual
  final List<String> _allowedPackagingTypes = [
    'Dus',
    'Pack',
    'Ball',
    'Peti',
    'Jerigen',
    'Drum',
    'Roll',
    'Ikat',
    'Batang',
  ];
  List<String> _uniquePackagingTypes = [];

  FocusNode _panjangFocusNode = FocusNode();
  FocusNode _lebarFocusNode = FocusNode();
  FocusNode _tinggiFocusNode = FocusNode();
  FocusNode _beratFocusNode = FocusNode();

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadAllItems();
    _loadTipeBarang();
    // Inisialisasi _uniquePackagingTypes dengan daftar yang diizinkan
    _uniquePackagingTypes = _allowedPackagingTypes;
  }

  @override
  void dispose() {
    _controller.dispose();
    _noLpbController.dispose();
    _kodebarangController.dispose();
    _urutanbarangController.dispose();
    _totalbarangController.dispose();
    _namaController.dispose();
    _panjangController.dispose();
    _lebarController.dispose();
    _tinggiController.dispose();
    _volumeController.dispose();
    _beratController.dispose();
    _panjangFocusNode.dispose();
    _lebarFocusNode.dispose();
    _tinggiFocusNode.dispose();
    _beratFocusNode.dispose();
    _namaFocusNode.dispose();
    _suggestionHideTimer?.cancel();
    super.dispose();
  }

  // --- SEMUA FUNGSI HELPER DARI INPUT_DATA_ADMLCL.DART DICOPY KE SINI ---

  void _hitungVolume() {
    final double? panjang = double.tryParse(_panjangController.text.trim());
    final double? lebar = double.tryParse(_lebarController.text.trim());
    final double? tinggi = double.tryParse(_tinggiController.text.trim());

    if (panjang != null && lebar != null && tinggi != null) {
      double volume = panjang * lebar * tinggi / 1000000;
      _volumeController.text = volume.toStringAsFixed(
        3,
      ); // 3 angka di belakang koma
    } else {
      _volumeController.text = '0.000';
    }
  }

  void _toggleFlash() {
    setState(() {
      _isFlashOn = !_isFlashOn;
      _controller.toggleTorch();
    });
  }

  Future<void> _loadAllItems() async {
    setState(() => _isFetchingSuggestions = true);
    final itemsData = await _lclService.getAllItemSuggestions();
    if (itemsData != null) {
      setState(() {
        _allItems =
            itemsData.map((item) => ItemSuggestion.fromJson(item)).toList();
        // DIUBAH: _uniquePackagingTypes sudah diinisialisasi di initState dengan _allowedPackagingTypes
        // Tidak perlu diekstrak dari _allItems lagi jika ingin fixed list.
      });
    }
    setState(() => _isFetchingSuggestions = false);
  }

  void _filterItemSuggestions(String query) {
    List<ItemSuggestion> currentFilterPool = _allItems;

    // 1. Filter by selected packaging first
    if (_selectedPackaging != null && _selectedPackaging!.isNotEmpty) {
      currentFilterPool =
          currentFilterPool
              .where(
                (item) =>
                    item.packaging.toLowerCase() ==
                    _selectedPackaging!.toLowerCase(),
              )
              .toList();
    }

    // 2. Then filter by the query on cleanedName (second word onwards)
    // Adjust minimum query length as needed
    if (query.length < 3 &&
        (_selectedPackaging == null || _selectedPackaging!.isEmpty)) {
      // Adjusted condition
      setState(() {
        _itemSuggestions = [];
        _isSuggestionBoxVisible = false;
      });
      return;
    }

    final filtered =
        currentFilterPool.where((item) {
          return item.cleanedName.toLowerCase().contains(query.toLowerCase());
        }).toList();

    setState(() {
      _itemSuggestions = filtered;
      _isSuggestionBoxVisible =
          filtered.isNotEmpty; // Only show if there are suggestions
    });
  }

  Future<void> _loadTipeBarang() async {
    setState(() => _isLoadingTipe = true);
    try {
      _tipeBarangList = await _lclService.getTipeBarangList();
    } catch (e) {
      // handle error
    } finally {
      if (mounted) setState(() => _isLoadingTipe = false);
    }
  }

  Future<void> _showInputModal(
    BuildContext context,
    String scannedBarcode,
  ) async {
    if (_isFlashOn) {
      _controller.toggleTorch();
      setState(() => _isFlashOn = false);
    }

    setState(() {
      _isLoading = true;
      _itemSuggestions = [];
      _isSuggestionBoxVisible = false;
      _selectedTipeId = null; // Reset to null
      _selectedBarangId = null;
      _isNamaFromSuggestion = false;
      _selectedPackaging = null; // Reset packaging
      _formKey.currentState?.reset();
    });

    try {
      final lpbData = await _lclService.getLPBInfoDetail(scannedBarcode);
      setState(() => _isLoading = false);

      if (lpbData == null || lpbData['data'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data LPB tidak ditemukan')),
        );
        _controller.start();
        _scannedBarcode = null;
        return;
      }

      final data = lpbData['data'] as Map<String, dynamic>;

      _noLpbController.text = (data['nomor_lpb'] ?? '').toString().trim();
      _kodebarangController.text =
          (data['code_barang'] ?? '').toString().trim();
      _urutanbarangController.text =
          (data['number_item'] ?? '').toString().trim();
      _totalbarangController.text =
          (data['total_barang'] ?? '').toString().trim();

      // Parse the full name from scan to separate packaging and cleaned name
      String fullScannedName = (data['nama_barang'] ?? '').toString().trim();
      String scannedPackaging = '';
      String scannedCleanedName = fullScannedName;

      int firstSpaceIndex = fullScannedName.indexOf(' ');
      if (firstSpaceIndex != -1) {
        scannedPackaging = fullScannedName.substring(0, firstSpaceIndex).trim();
        scannedCleanedName =
            fullScannedName.substring(firstSpaceIndex + 1).trim();
      } else {
        scannedPackaging = fullScannedName;
        scannedCleanedName = '';
      }

      _namaController.text = scannedCleanedName; // Show only the cleaned name
      _panjangController.text = (data['length'] ?? 0).toString().trim();
      _lebarController.text = (data['width'] ?? 0).toString().trim();
      _tinggiController.text = (data['height'] ?? 0).toString().trim();
      _beratController.text = (data['weight'] ?? 0).toString().trim();
      _hitungVolume();

      setState(() {
        _selectedBarangId = data['id_barang']?.toString().trim();
        _isNamaFromSuggestion =
            true; // Set this true because name comes from scan
        // Set packaging from scan, ensure it's one of the allowed types or null
        _selectedPackaging =
            _allowedPackagingTypes.contains(scannedPackaging)
                ? scannedPackaging
                : null;
      });

      // DIUBAH: Perbaiki logic pemilihan Tipe Barang
      final String tipeBarangNameFromScan =
          (data['tipe_barang'] ?? '').toString().trim();
      if (tipeBarangNameFromScan.isNotEmpty && _tipeBarangList.isNotEmpty) {
        // Cari tipe barang berdasarkan NAMA, lalu ambil ID-nya
        final matchingTipe = _tipeBarangList.firstWhere(
          (tipe) =>
              (tipe['name'] ?? '').toString().trim().toLowerCase() ==
              tipeBarangNameFromScan
                  .toLowerCase(), // Tambah toLowerCase() untuk case-insensitive
          orElse: () => <String, dynamic>{},
        );

        if (matchingTipe.isNotEmpty) {
          setState(() {
            _selectedTipeId = (matchingTipe['tipe_id'] ?? '').toString().trim();
          });
        } else {
          // Jika tidak ada kecocokan nama, set _selectedTipeId ke null
          setState(() {
            _selectedTipeId = null;
          });
        }
      } else {
        // Jika tipeBarangNameFromScan kosong atau _tipeBarangList kosong, set _selectedTipeId ke null
        setState(() {
          _selectedTipeId = null;
        });
      }

      showMaterialModalBottomSheet(
        context: context,
        isDismissible: false,
        enableDrag: false,
        builder: (context) => _buildInputModal(context),
      ).whenComplete(() {
        _scannedBarcode = null;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      _controller.start();
      _scannedBarcode = null;
    }
  }

  Widget _buildInputModal(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() => _isSuggestionBoxVisible = false);
        FocusScope.of(context).unfocus();
      },
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                        if (mounted) {
                          _controller.start(); // Aktifkan scanner kembali
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildReadOnlyField('No. LPB', _noLpbController),
                const SizedBox(height: 10),
                _buildReadOnlyField('Kode Barang', _kodebarangController),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(flex: 1, child: Container()),
                    Expanded(
                      flex: 1,
                      child: _buildReadOnlyField(
                        'Urutan',
                        _urutanbarangController,
                        textAlign: TextAlign.center,
                        fontSize: 18, // Ukuran font diperbesar
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text(
                        '/',
                        style: TextStyle(
                          fontSize: 24,
                        ), // Diperbesar dari 20 ke 24
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: _buildReadOnlyField(
                        'Total',
                        _totalbarangController,
                        textAlign: TextAlign.center,
                        fontSize: 18, // Ukuran font diperbesar
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // NEW: Kemasan Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedPackaging,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    // DIUBAH: Hapus filled dan fillColor
                    labelText: 'Kemasan',
                    border: OutlineInputBorder(),
                  ),
                  hint: const Text('Pilih Kemasan'),
                  items:
                      _uniquePackagingTypes.map((packaging) {
                        return DropdownMenuItem<String>(
                          value: packaging,
                          child: Text(packaging),
                        );
                      }).toList(),
                  onChanged: (String? newValue) {
                    // DIUBAH: Always enabled
                    setState(() {
                      _selectedPackaging = newValue;
                      _filterItemSuggestions(
                        _namaController.text,
                      ); // Re-filter suggestions based on new packaging
                      // Clear existing item selection if packaging changes and it's not from scan
                      if (!_isNamaFromSuggestion) {
                        _selectedBarangId = null;
                        _selectedTipeId = null;
                      }
                    });
                  },
                  validator:
                      (value) =>
                          (value == null || value.isEmpty)
                              ? 'Pilih kemasan barang'
                              : null,
                ),
                const SizedBox(height: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _namaController,
                      enabled: true, // DIUBAH: Always enabled
                      onChanged: (value) {
                        _filterItemSuggestions(value);
                        setState(() {
                          _isNamaFromSuggestion = false;
                          _selectedBarangId = null;
                          _selectedTipeId = null;
                        });
                      },
                      decoration: const InputDecoration(
                        // DIUBAH: Hapus filled dan fillColor
                        labelText: 'Nama Barang',
                        border: OutlineInputBorder(),
                      ),
                      validator:
                          (value) =>
                              (value == null || value.isEmpty)
                                  ? 'Nama Barang tidak boleh kosong'
                                  : null,
                    ),
                    if (_isSuggestionBoxVisible) _buildItemSuggestionList(),
                  ],
                ),
                const SizedBox(height: 10),
                _isLoadingTipe
                    ? const Center(child: CircularProgressIndicator())
                    : DropdownButtonFormField<String>(
                      value: _selectedTipeId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        // DIUBAH: Hapus filled dan fillColor
                        labelText: 'Tipe Barang',
                        border: OutlineInputBorder(),
                      ),
                      hint: const Text('Pilih Tipe'),
                      items:
                          _tipeBarangList.map((tipe) {
                            return DropdownMenuItem<String>(
                              value: (tipe['tipe_id'] ?? '').toString().trim(),
                              child: Text(
                                (tipe['name'] ?? 'Tanpa Nama')
                                    .toString()
                                    .trim(),
                              ),
                            );
                          }).toList(),
                      onChanged: (String? newValue) {
                        // DIUBAH: Always enabled
                        setState(() => _selectedTipeId = newValue);
                      },
                      validator:
                          (value) =>
                              (value == null || value.isEmpty)
                                  ? 'Pilih tipe barang'
                                  : null,
                    ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _panjangController,
                        focusNode: _panjangFocusNode,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) {
                          FocusScope.of(context).requestFocus(_lebarFocusNode);
                        },
                        decoration: const InputDecoration(
                          labelText: 'Panjang (cm)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _hitungVolume(),
                        validator:
                            (v) =>
                                (v == null ||
                                        v.isEmpty ||
                                        double.tryParse(v.trim()) == null)
                                    ? 'Angka valid'
                                    : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _lebarController,
                        focusNode: _lebarFocusNode,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) {
                          FocusScope.of(context).requestFocus(_tinggiFocusNode);
                        },
                        decoration: const InputDecoration(
                          labelText: 'Lebar (cm)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _hitungVolume(),
                        validator:
                            (v) =>
                                (v == null ||
                                        v.isEmpty ||
                                        double.tryParse(v.trim()) == null)
                                    ? 'Angka valid'
                                    : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _tinggiController,
                        focusNode: _tinggiFocusNode,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) {
                          FocusScope.of(context).requestFocus(_beratFocusNode);
                        },
                        decoration: const InputDecoration(
                          labelText: 'Tinggi (cm)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _hitungVolume(),
                        validator:
                            (v) =>
                                (v == null ||
                                        v.isEmpty ||
                                        double.tryParse(v.trim()) == null)
                                    ? 'Angka valid'
                                    : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _beratController,
                  focusNode: _beratFocusNode,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Berat (kg)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator:
                      (v) =>
                          (v == null ||
                                  v.isEmpty ||
                                  double.tryParse(v.trim()) == null)
                              ? 'Angka valid'
                              : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _volumeController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Volume (m³)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      setState(() => _isLoading = true);
                      try {
                        String namaBarangToSend;
                        if (_isNamaFromSuggestion &&
                            _selectedBarangId != null) {
                          // If selected from suggestions, reconstruct original name from the stored ItemSuggestion
                          final selectedItem = _allItems.firstWhere(
                            (element) => element.id == _selectedBarangId,
                          );
                          namaBarangToSend = selectedItem.originalName;
                        } else {
                          // If user typed, combine selected packaging and typed cleaned name
                          // Ensure packaging is selected if not from suggestion
                          if (_selectedPackaging == null ||
                              _selectedPackaging!.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Mohon pilih kemasan barang.'),
                              ),
                            );
                            setState(() => _isLoading = false);
                            return;
                          }
                          namaBarangToSend =
                              '${_selectedPackaging!} ${_namaController.text}'
                                  .trim();
                        }

                        final success = await _lclService.saveLPBDetail(
                          number_lpb_item: _kodebarangController.text.trim(),
                          weight: _beratController.text.trim(),
                          height: _tinggiController.text.trim(),
                          length: _panjangController.text.trim(),
                          width: _lebarController.text.trim(),
                          nama_barang: namaBarangToSend,
                          tipe_barang_id: _selectedTipeId!,
                          barang_id: _selectedBarangId,
                        );

                        if (mounted) {
                          Navigator.of(context).pop();

                          showDialog(
                            context: context,
                            builder:
                                (context) => AlertDialog(
                                  title: Text(success ? 'Berhasil' : 'Gagal'),
                                  content: Text(
                                    success
                                        ? 'Data berhasil disimpan ke Warehouse'
                                        : 'Gagal menyimpan data',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed:
                                          () =>
                                              Navigator.of(
                                                context,
                                              ).pop(), // tutup popup
                                      child: const Text('OK'),
                                    ),
                                  ],
                                ),
                          ).then((_) {
                            if (mounted) {
                              _controller
                                  .start(); // Aktifkan scanner setelah dialog tertutup
                            }
                          });
                        }
                      } catch (e) {
                        if (mounted) {
                          showDialog(
                            context: context,
                            builder:
                                (context) => AlertDialog(
                                  title: const Text('Error'),
                                  content: Text(
                                    'Terjadi kesalahan: ${e.toString()}',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed:
                                          () =>
                                              Navigator.of(
                                                context,
                                              ).pop(), // tutup popup
                                      child: const Text('OK'),
                                    ),
                                  ],
                                ),
                          ).then((_) {
                            if (mounted) {
                              _controller
                                  .start(); // Aktifkan scanner setelah dialog tertutup
                            }
                          });
                        }
                      } finally {
                        if (mounted) setState(() => _isLoading = false);
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child:
                      _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Simpan Data'),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(
    String label,
    TextEditingController controller, {
    TextAlign textAlign = TextAlign.left,
    double fontSize = 14,
  }) {
    return TextFormField(
      controller: controller,
      textAlign: textAlign,
      style: TextStyle(fontSize: fontSize), // Tambahkan style untuk font size
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.grey[200],
      ),
      readOnly: true,
    );
  }

  Widget _buildItemSuggestionList() {
    return Container(
      margin: const EdgeInsets.only(top: 4.0),
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child:
          _isFetchingSuggestions
              ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(),
                ),
              )
              : ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _itemSuggestions.length,
                itemBuilder: (context, index) {
                  final item = _itemSuggestions[index];
                  return ListTile(
                    dense: true,
                    title: Text(item.cleanedName), // Display cleaned name
                    subtitle: Text(
                      '${item.packaging} - ${item.type}',
                    ), // Display packaging and type for clarity
                    onTap: () {
                      setState(() {
                        _namaController.text = item.cleanedName;
                        _selectedBarangId = item.id;
                        _selectedPackaging =
                            item.packaging; // Set packaging from selected item

                        // Cari tipe barang berdasarkan NAMA, lalu ambil ID-nya
                        final matchingTipe = _tipeBarangList.firstWhere(
                          (tipe) =>
                              (tipe['name'] ?? '')
                                  .toString()
                                  .trim()
                                  .toLowerCase() ==
                              item.type
                                  .trim()
                                  .toLowerCase(), // Tambah toLowerCase()
                          orElse: () => <String, dynamic>{},
                        );

                        if (matchingTipe.isNotEmpty) {
                          _selectedTipeId =
                              (matchingTipe['tipe_id'] ?? '').toString().trim();
                        } else {
                          _selectedTipeId =
                              null; // Set to null if no matching ID found
                        }

                        _isNamaFromSuggestion = true;
                        _isSuggestionBoxVisible = false;
                      });

                      // Delay kecil untuk unfocus agar keyboard dan suggestion benar-benar tertutup
                      Future.delayed(const Duration(milliseconds: 100), () {
                        FocusScope.of(context).unfocus();
                      });
                    },
                  );
                },
              ),
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
                  'Warehouse', // Judul diubah
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                    if (_scannedBarcode != null) return;
                    final barcode = capture.barcodes.first.rawValue;
                    if (barcode != null) {
                      setState(() => _scannedBarcode = barcode);
                      _controller.stop();
                      await _showInputModal(context, barcode);
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
