import 'package:flutter/material.dart';
import '../../services/warehouse_service.dart';
import '../../services/auth_service.dart';

class ItemLpbWarehouse extends StatefulWidget {
  final String noLpb;

  const ItemLpbWarehouse({Key? key, required this.noLpb}) : super(key: key);

  @override
  _ItemLpbWarehouseState createState() => _ItemLpbWarehouseState();
}

class _ItemLpbWarehouseState extends State<ItemLpbWarehouse> {
  late AuthService _authService;
  late WarehouseService _warehouseService;
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  TextEditingController _notesController = TextEditingController();
  List<bool> _checkedItems = [];

  @override
  void initState() {
    super.initState();
    _warehouseService = WarehouseService();
    _authService = AuthService();
    _fetchItems();
  }

  Future<void> _fetchItems() async {
    setState(() => _isLoading = true);
    try {
      final items = await _warehouseService.getLPBItemDetail(widget.noLpb);
      setState(() {
        _items = items ?? [];
        _checkedItems =
            _items.map((item) {
              final length =
                  double.tryParse(item['length']?.toString() ?? '0') ?? 0;
              final width =
                  double.tryParse(item['width']?.toString() ?? '0') ?? 0;
              final height =
                  double.tryParse(item['height']?.toString() ?? '0') ?? 0;
              final weight =
                  double.tryParse(item['weight']?.toString() ?? '0') ?? 0;
              return length > 0 && width > 0 && height > 0 && weight > 0;
            }).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat detail: ${e.toString()}')),
      );
    }
  }

  Future<void> _processData() async {
    // Cek minimal ada 1 item yang dipilih
    if (!_checkedItems.contains(true)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih minimal 1 item terlebih dahulu')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final token = await _authService.getValidToken();

    if (token == null) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Token tidak valid, silakan login ulang')),
      );
      return;
    }

    bool success = true;
    final notes = _notesController.text;

    // Kumpulkan ID barang yang dicentang
    final List<String> selectedIds = [];
    for (int i = 0; i < _items.length; i++) {
      if (_checkedItems[i]) {
        final barangId = _items[i]['tt_barang_id']?.toString();
        if (barangId == null || barangId.isEmpty) {
          debugPrint("ID barang kosong untuk index $i");
          success = false;
        } else {
          selectedIds.add(barangId);
        }
      }
    }

    // PERBAIKAN: Pindahkan panggilan bulk update ke LUAR loop
    if (selectedIds.isNotEmpty) {
      // Sesuaikan format data dengan kebutuhan backend
      final List<Map<String, dynamic>> payloadData =
          selectedIds.map((id) {
            return {"id": int.tryParse(id) ?? 0}; // Konversi ke integer
          }).toList();

      final result = await _warehouseService.updateBulkStatusConfirmed(
        token: token,
        numberLpbItem: widget.noLpb, // Gunakan parameter yang benar
        data: payloadData, // Kirim data dalam format yang diminta
        notes: notes,
      );

      if (!result) success = false;
    }

    setState(() => _isLoading = false);

    if (success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Data berhasil diproses')));
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Beberapa item gagal diproses')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(
          150.0,
        ), // 1. Ubah tinggi menjadi 150
        child: SafeArea(
          child: Container(
            decoration: const BoxDecoration(),
            child: Padding(
              // 2. Sesuaikan padding vertikal
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/logo.png',
                        height: 40,
                        width: 200,
                      ),
                      // Biarkan kosong untuk menyamakan tata letak
                      const SizedBox(width: 48),
                    ],
                  ),
                  const SizedBox(height: 24), // 3. Tambah spasi vertikal
                  Text(
                    'Aplikasi Kepala Gudang',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  Text(
                    'Detail LPB: ${widget.noLpb}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Table Title
                    const Text(
                      'Daftar Barang',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Data Table with vertical scroll
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: Table(
                            columnWidths: const {
                              0: FixedColumnWidth(40),
                              1: FixedColumnWidth(120),
                              2: FixedColumnWidth(40),
                              3: FixedColumnWidth(40),
                              4: FixedColumnWidth(40),
                              5: FixedColumnWidth(60),
                              6: FixedColumnWidth(60),
                              7: FixedColumnWidth(60),
                            },
                            border: TableBorder.all(
                              color: Colors.grey.shade300,
                              width: 1,
                            ),
                            children: [
                              // Header
                              TableRow(
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                ),
                                children: const [
                                  _HeaderCell('No'),
                                  _HeaderCell('Kode Barang', alignLeft: true),
                                  _HeaderCell('P'),
                                  _HeaderCell('L'),
                                  _HeaderCell('T'),
                                  _HeaderCell('Berat'),
                                  _HeaderCell('✓'),
                                  _HeaderCell('+'),
                                ],
                              ),

                              // Data rows
                              ...List.generate(_items.length, (index) {
                                final item = _items[index];
                                return TableRow(
                                  decoration: BoxDecoration(
                                    color:
                                        index.isEven
                                            ? Colors.white
                                            : Colors.grey.shade50,
                                  ),
                                  children: [
                                    _BodyCell('${index + 1}'),
                                    _BodyCell(
                                      item['barang_kode'] ?? '-',
                                      alignLeft: true,
                                    ),
                                    _BodyCell(
                                      item['length']?.toString() ?? '-',
                                    ),
                                    _BodyCell(item['width']?.toString() ?? '-'),
                                    _BodyCell(
                                      item['height']?.toString() ?? '-',
                                    ),
                                    _BodyCell(
                                      item['weight']?.toString() ?? '-',
                                    ),
                                    Center(
                                      child: Checkbox(
                                        value: _checkedItems[index],
                                        onChanged: (value) {
                                          setState(
                                            () => _checkedItems[index] = value!,
                                          );
                                        },
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8.0,
                                      ), // atur sesuai selera
                                      child: Align(
                                        alignment: Alignment.center,
                                        child: ElevatedButton(
                                          onPressed: () {
                                            final code =
                                                item['barang_kode'] ?? '';
                                            if (code.isNotEmpty) {
                                              setState(() {
                                                if (_notesController
                                                    .text
                                                    .isNotEmpty) {
                                                  _notesController.text += ', ';
                                                }
                                                _notesController.text += code;
                                              });
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            minimumSize: Size.zero,
                                            tapTargetSize:
                                                MaterialTapTargetSize
                                                    .shrinkWrap,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                          child: const Text(
                                            '+',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Notes section
                    const SizedBox(height: 20),
                    const Text(
                      'Catatan:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Tambahkan catatan...',
                      ),
                    ),

                    // Action Buttons
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context, false),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('Kembali'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _processData,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[300],
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child:
                                _isLoading
                                    ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : const Text('Proses'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.text, {this.alignLeft = false});
  final String text;
  final bool alignLeft;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(8.0),
    child: Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.bold),
      textAlign: alignLeft ? TextAlign.left : TextAlign.center,
    ),
  );
}

class _BodyCell extends StatelessWidget {
  const _BodyCell(this.text, {this.alignLeft = false});
  final String text;
  final bool alignLeft;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(8.0),
    child: Text(text, textAlign: alignLeft ? TextAlign.left : TextAlign.center),
  );
}
