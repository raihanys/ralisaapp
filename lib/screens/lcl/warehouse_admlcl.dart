import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import '../../services/lcl_service.dart';

// Model disertakan langsung di sini untuk kemudahan
class ItemSuggestion {
  final String id;
  final String name;
  final String type;

  ItemSuggestion({required this.id, required this.name, required this.type});

  factory ItemSuggestion.fromJson(Map<String, dynamic> json) {
    return ItemSuggestion(
      id: json['id_barang'] ?? '',
      name: json['nama_barang'] ?? '',
      type: json['tipe_barang'] ?? '',
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
  Timer? _debounce;
  bool _isSuggestionBoxVisible = false;

  List<Map<String, dynamic>> _tipeBarangList = [];
  bool _isLoadingTipe = false;

  String? _selectedTipeId;
  String? _selectedBarangId;
  bool _isNamaFromSuggestion = false;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadTipeBarang();
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
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
    super.dispose();
  }

  // --- SEMUA FUNGSI HELPER DARI INPUT_DATA_ADMLCL.DART DICOPY KE SINI ---

  void _hitungVolume() {
    final double? panjang = double.tryParse(_panjangController.text);
    final double? lebar = double.tryParse(_lebarController.text);
    final double? tinggi = double.tryParse(_tinggiController.text);

    if (panjang != null && lebar != null && tinggi != null) {
      _volumeController.text = (panjang * lebar * tinggi / 1000000)
          .toStringAsFixed(2);
    } else {
      _volumeController.text = '0';
    }
  }

  void _toggleFlash() {
    setState(() {
      _isFlashOn = !_isFlashOn;
      _controller.toggleTorch();
    });
  }

  Future<void> _fetchItemSuggestions(String query) async {
    if (_debounce?.isActive ?? false) _debounce?.cancel();

    if (query.length < 3) {
      setState(() {
        _itemSuggestions = [];
        _isSuggestionBoxVisible = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() {
        _isFetchingSuggestions = true;
        _isSuggestionBoxVisible = true;
      });

      try {
        final suggestionsData = await _lclService.getItemSuggestions(query);
        if (mounted && suggestionsData != null) {
          setState(() {
            _itemSuggestions =
                suggestionsData
                    .map((item) => ItemSuggestion.fromJson(item))
                    .toList();
          });
        } else {
          if (mounted) setState(() => _itemSuggestions = []);
        }
      } catch (e) {
        if (mounted) setState(() => _itemSuggestions = []);
      } finally {
        if (mounted) setState(() => _isFetchingSuggestions = false);
      }
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
      _selectedTipeId = null;
      _selectedBarangId = null;
      _isNamaFromSuggestion = false;
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

      _noLpbController.text = data['nomor_lpb'] ?? '';
      _kodebarangController.text = data['code_barang'] ?? '';
      _urutanbarangController.text = data['number_item'] ?? '';
      _totalbarangController.text = data['total_barang'] ?? '';
      _namaController.text = data['nama_barang'] ?? '';
      _panjangController.text = (data['length'] ?? 0).toString();
      _lebarController.text = (data['width'] ?? 0).toString();
      _tinggiController.text = (data['height'] ?? 0).toString();
      _beratController.text = (data['weight'] ?? 0).toString();
      _hitungVolume();

      final String tipeBarangFromScan = data['tipe_barang'] ?? '';
      if (tipeBarangFromScan.isNotEmpty && _tipeBarangList.isNotEmpty) {
        final matchingTipe = _tipeBarangList.firstWhere(
          (tipe) => tipe['name'] == tipeBarangFromScan,
          orElse: () => <String, dynamic>{},
        );

        if (matchingTipe.isNotEmpty) {
          setState(() {
            _selectedTipeId = matchingTipe['tipe_id'];
            _isNamaFromSuggestion = true;
          });
        }
      }

      showMaterialModalBottomSheet(
        context: context,
        isDismissible: false,
        enableDrag: false,
        builder: (context) => _buildInputModal(context),
      ).whenComplete(() {
        _controller.start();
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
                      'Input Data Barang (Warehouse)',
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
                _buildReadOnlyField('No. LPB', _noLpbController),
                const SizedBox(height: 10),
                _buildReadOnlyField('Kode Barang', _kodebarangController),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(flex: 1, child: Container()),
                    Expanded(
                      flex: 2,
                      child: _buildReadOnlyField(
                        'Urutan',
                        _urutanbarangController,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text('/', style: TextStyle(fontSize: 20)),
                    ),
                    Expanded(
                      flex: 2,
                      child: _buildReadOnlyField(
                        'Total',
                        _totalbarangController,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _namaController,
                      decoration: const InputDecoration(
                        labelText: 'Nama Barang',
                        border: OutlineInputBorder(),
                        hintText: 'Ketik min. 3 karakter',
                      ),
                      onChanged: (value) {
                        setState(() {
                          _isNamaFromSuggestion = false;
                          _selectedTipeId = null;
                          _selectedBarangId = null;
                        });

                        if (value.length >= 3) {
                          _fetchItemSuggestions(value);
                        } else {
                          setState(() => _isSuggestionBoxVisible = false);
                        }
                      },
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
                      decoration: InputDecoration(
                        labelText: 'Tipe Barang',
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor:
                            _isNamaFromSuggestion ? Colors.grey[200] : null,
                      ),
                      hint: const Text('Pilih Tipe'),
                      items:
                          _tipeBarangList.map((tipe) {
                            return DropdownMenuItem<String>(
                              value: tipe['tipe_id'],
                              child: Text(tipe['name'] ?? 'Tanpa Nama'),
                            );
                          }).toList(),
                      onChanged:
                          _isNamaFromSuggestion
                              ? null
                              : (String? newValue) {
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
                                        double.tryParse(v) == null)
                                    ? 'Angka valid'
                                    : null,
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
                        validator:
                            (v) =>
                                (v == null ||
                                        v.isEmpty ||
                                        double.tryParse(v) == null)
                                    ? 'Angka valid'
                                    : null,
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
                        validator:
                            (v) =>
                                (v == null ||
                                        v.isEmpty ||
                                        double.tryParse(v) == null)
                                    ? 'Angka valid'
                                    : null,
                      ),
                    ),
                  ],
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
                const SizedBox(height: 10),
                TextFormField(
                  controller: _beratController,
                  decoration: const InputDecoration(
                    labelText: 'Berat (kg)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator:
                      (v) =>
                          (v == null || v.isEmpty || double.tryParse(v) == null)
                              ? 'Angka valid'
                              : null,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      setState(() => _isLoading = true);
                      try {
                        final success = await _lclService.saveLPBDetail(
                          number_lpb_item: _kodebarangController.text,
                          weight: _beratController.text,
                          height: _tinggiController.text,
                          length: _panjangController.text,
                          width: _lebarController.text,
                          nama_barang: _namaController.text,
                          tipe_barang_id: _selectedTipeId!,
                          id_barang: _selectedBarangId,
                          processType: 'warehouse',
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
                                      child: Text('OK'),
                                    ),
                                  ],
                                ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          showDialog(
                            context: context,
                            builder:
                                (context) => AlertDialog(
                                  title: Text('Error'),
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
                                      child: Text('OK'),
                                    ),
                                  ],
                                ),
                          );
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

  Widget _buildReadOnlyField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
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
        boxShadow: [
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
                    title: Text(item.name),
                    subtitle: Text(item.type),
                    onTap: () {
                      setState(() {
                        _namaController.text = item.name;
                        _selectedBarangId = item.id;

                        final matchingTipe = _tipeBarangList.firstWhere(
                          (tipe) => tipe['name'] == item.type,
                          orElse: () => <String, dynamic>{},
                        );

                        if (matchingTipe.isNotEmpty) {
                          _selectedTipeId = matchingTipe['tipe_id'];
                        } else {
                          _selectedTipeId = null;
                        }

                        _isNamaFromSuggestion = true;
                        _isSuggestionBoxVisible = false;
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
