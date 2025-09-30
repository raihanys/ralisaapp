import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/auth_service.dart';
import '../../services/invoicer_service.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:intl/intl.dart';

class NonPpnInvoicer extends StatefulWidget {
  final String? invoicingCode;

  const NonPpnInvoicer({Key? key, required this.invoicingCode})
    : super(key: key);

  @override
  State<NonPpnInvoicer> createState() => _NonPpnInvoicerState();
}

class _NonPpnInvoicerState extends State<NonPpnInvoicer> {
  final AuthService _authService = AuthService();
  late InvoicerService _invoicerService;
  final RefreshController _refreshController = RefreshController();

  List<dynamic> _cstList = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _invoicerService = InvoicerService(_authService);
    _loadCST();
  }

  Future<void> _loadCST() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final typeInvoice = widget.invoicingCode ?? '0';
      final cstData = await _invoicerService.fetchCSTAll(typeInvoice);

      setState(() {
        _cstList = cstData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _showCSTDetailModal(Map<String, dynamic> cst) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (context) => CSTDetailModal(
            cst: cst,
            invoicingCode: widget.invoicingCode,
            onSave: _handleSaveCST,
          ),
    );
  }

  Future<void> _handleSaveCST({
    required String shipId,
    required String paymentType,
    String? paymentAmount,
    String? paymentDifference,
    String? paymentNotes,
  }) async {
    try {
      final success = await _invoicerService.updateCSTStatus(
        shipId: shipId,
        paymentType: paymentType,
        paymentAmount: paymentAmount,
        paymentDifference: paymentDifference,
        paymentNotes: paymentNotes,
      );

      if (success) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('CST berhasil diproses')));
        Navigator.pop(context);
        await _loadCST();
      } else {
        throw Exception('Failed to update CST');
      }
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Gagal'),
            content: Text('Gagal memproses CST: $e'),
            actions: <Widget>[
              TextButton(
                child: const Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Error: $_errorMessage',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadCST, child: const Text('Coba Lagi')),
          ],
        ),
      );
    }

    return SmartRefresher(
      controller: _refreshController,
      enablePullDown: true,
      enablePullUp: false,
      onRefresh: () async {
        await _loadCST();
        _refreshController.refreshCompleted();
      },
      child:
          _cstList.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 16),
                    Text(
                      "Tidak ada tagihan Non PPN untuk di-proses",
                      style: theme.textTheme.titleMedium!.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              )
              : ListView.builder(
                itemCount: _cstList.length,
                itemBuilder: (context, index) {
                  final cst = _cstList[index];
                  final shipNumber = cst['ship_number'] ?? '-';
                  final clientName = cst['name'] ?? '-';
                  final total = cst['total'] ?? '0';
                  final cstDate = cst['tanggal_invoice'] ?? '-';

                  // Format currency
                  final formatter = NumberFormat.currency(
                    locale: 'id_ID',
                    symbol: 'Rp. ',
                    decimalDigits: 0,
                  );
                  final formattedTotal = formatter.format(
                    int.tryParse(total) ?? 0,
                  );

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      title: Text(
                        '$shipNumber',
                        style: theme.textTheme.titleMedium,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'kepada: $clientName',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                'Total: $formattedTotal',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                'Tanggal: $cstDate',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () => _showCSTDetailModal(cst),
                        child: const Text("Proses"),
                      ),
                    ),
                  );
                },
              ),
    );
  }
}

// Formatter untuk input currency (sama dengan PPN)
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Hapus semua karakter non-digit
    String cleanText = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    if (cleanText.isEmpty) {
      return const TextEditingValue();
    }

    // Format ke currency
    final number = int.parse(cleanText);
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: '',
      decimalDigits: 0,
    );
    String formattedText = formatter.format(number);

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}

class CSTDetailModal extends StatefulWidget {
  final Map<String, dynamic> cst;
  final String? invoicingCode;
  final Function({
    required String shipId,
    required String paymentType,
    String? paymentAmount,
    String? paymentDifference,
    String? paymentNotes,
  })
  onSave;

  const CSTDetailModal({
    Key? key,
    required this.cst,
    required this.invoicingCode,
    required this.onSave,
  }) : super(key: key);

  @override
  State<CSTDetailModal> createState() => _CSTDetailModalState();
}

class _CSTDetailModalState extends State<CSTDetailModal> {
  String? _selectedPaymentType;
  final TextEditingController _amountController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _cstDetail;
  bool _showAmountField = false;

  // Variabel untuk selisih
  String? _selectedDifference;
  bool _showNotesField = false;
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCSTDetail();

    // Set nilai default amount dengan format currency
    final total = widget.cst['total'] ?? '0';
    if (total.isNotEmpty) {
      final formatter = NumberFormat.currency(
        locale: 'id_ID',
        symbol: '',
        decimalDigits: 0,
      );
      final formattedTotal = formatter.format(int.tryParse(total) ?? 0);
      _amountController.text = formattedTotal.trim();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadCSTDetail() async {
    try {
      final authService = AuthService();
      final invoicerService = InvoicerService(authService);
      final detail = await invoicerService.fetchCSTDetail(
        widget.cst['ship_id'].toString(),
      );
      setState(() {
        _cstDetail = detail;
      });
    } catch (e) {
      print('Error loading CST detail: $e');
      setState(() {
        _cstDetail = widget.cst;
      });
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Kesalahan'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _handleSave() {
    if (_selectedPaymentType == null) {
      _showErrorDialog('Pilih metode pembayaran terlebih dahulu');
      return;
    }

    if (_selectedPaymentType == '1' && _amountController.text.isEmpty) {
      _showErrorDialog('Masukkan jumlah pembayaran');
      return;
    }

    if (_selectedPaymentType == '1' && _selectedDifference == null) {
      _showErrorDialog('Pilih status selisih pembayaran');
      return;
    }

    // Validasi jika tunai dan ada selisih, notes harus diisi
    if (_selectedPaymentType == '1' &&
        _selectedDifference == '1' &&
        _notesController.text.isEmpty) {
      _showErrorDialog('Harap isi keterangan selisih');
      return;
    }

    // Validasi jika ada selisih, jumlah bayar tidak boleh sama dengan total
    if (_selectedPaymentType == '1' && _selectedDifference == '1') {
      final totalAmountString = widget.cst['total']?.toString() ?? '0';
      final totalAmount = int.tryParse(totalAmountString) ?? 0;

      final paymentAmountString = _amountController.text.replaceAll('.', '');
      final paymentAmount = int.tryParse(paymentAmountString) ?? 0;

      if (paymentAmount == totalAmount) {
        _showErrorDialog(
          'Jumlah pembayaran tidak boleh sama dengan total tagihan jika memilih opsi "Selisih".',
        );
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    widget
        .onSave(
          shipId: widget.cst['ship_id'].toString(),
          paymentType: _selectedPaymentType!,
          paymentAmount:
              _selectedPaymentType == '1'
                  ? _amountController.text.replaceAll('.', '')
                  : null,
          paymentDifference:
              _selectedPaymentType == '1' ? _selectedDifference : null,
          paymentNotes:
              _selectedPaymentType == '1' && _selectedDifference == '1'
                  ? _notesController.text
                  : null,
        )
        .catchError((error) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Error: $error')));
          }
        })
        .whenComplete(() {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cst = _cstDetail ?? widget.cst;

    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp. ',
      decimalDigits: 0,
    );
    final formattedTotal = formatter.format(
      int.tryParse(cst['total'] ?? '0') ?? 0,
    );

    final List<Map<String, String>> paymentOptions = [];
    if (widget.invoicingCode != '1') {
      paymentOptions.add({'value': '1', 'label': 'Tunai'});
    }
    paymentOptions.add({'value': '2', 'label': 'Transfer'});

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.80,
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Judul dan tombol close
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Proses CST',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      shape: const CircleBorder(),
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.all(10),
                      minimumSize: const Size(40, 40),
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Konten yang bisa di-scroll
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow('No. CST', cst['ship_number'] ?? '-'),
                      _buildDetailRow('Kepada', cst['name'] ?? '-'),
                      _buildDetailRow('Kota Client', cst['city_client'] ?? '-'),
                      _buildDetailRow('Total Tagihan', formattedTotal),
                      _buildDetailRow('Tanggal', cst['tanggal_invoice'] ?? '-'),
                      const SizedBox(height: 20),

                      Text(
                        'Metode Pembayaran',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: _selectedPaymentType,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Pilih Metode Pembayaran',
                          border: OutlineInputBorder(),
                        ),
                        items:
                            paymentOptions.map<DropdownMenuItem<String>>((
                              option,
                            ) {
                              return DropdownMenuItem<String>(
                                value: option['value'],
                                child: Text(option['label']!),
                              );
                            }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedPaymentType = newValue;
                            _showAmountField = newValue == '1';
                            if (newValue != '1') {
                              _selectedDifference = null;
                              _showNotesField = false;
                              _notesController.clear();
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 15),

                      // Field Amount hanya untuk Tunai
                      if (_showAmountField && widget.invoicingCode != '1') ...[
                        TextFormField(
                          controller: _amountController,
                          decoration: const InputDecoration(
                            labelText: 'Jumlah Pembayaran',
                            border: OutlineInputBorder(),
                            prefixText: 'Rp. ',
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [CurrencyInputFormatter()],
                        ),
                        const SizedBox(height: 15),

                        DropdownButtonFormField<String>(
                          value: _selectedDifference,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Selisih Pembayaran',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: '0', child: Text('Tidak')),
                            DropdownMenuItem(
                              value: '1',
                              child: Text('Selisih'),
                            ),
                          ],
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedDifference = newValue;
                              _showNotesField = newValue == '1';
                              if (!_showNotesField) {
                                _notesController.clear();
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 15),

                        if (_showNotesField)
                          TextFormField(
                            controller: _notesController,
                            decoration: const InputDecoration(
                              labelText: 'Keterangan Selisih',
                              border: OutlineInputBorder(),
                              hintText: 'Jelaskan alasan selisih pembayaran...',
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child:
                      _isLoading
                          ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : const Text('Submit'),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const Text(': '),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
