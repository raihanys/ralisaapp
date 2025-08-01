import 'package:flutter/material.dart';
import '../../services/warehouse_service.dart';

class ItemLpbWarehouse extends StatefulWidget {
  final String noLpb;

  const ItemLpbWarehouse({Key? key, required this.noLpb}) : super(key: key);

  @override
  _ItemLpbWarehouseState createState() => _ItemLpbWarehouseState();
}

class _ItemLpbWarehouseState extends State<ItemLpbWarehouse> {
  late WarehouseService _warehouseService;
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  TextEditingController _notesController = TextEditingController();
  List<bool> _checkedItems = [];

  @override
  void initState() {
    super.initState();
    _warehouseService = WarehouseService();
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
                                    Center(
                                      child: IconButton(
                                        icon: const Icon(Icons.add, size: 18),
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
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Batal'),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () {
                            // TODO: proses data
                          },
                          child: const Text('Proses'),
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
