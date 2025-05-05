import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/auth_service.dart';
import '../services/pelabuhan_service.dart';

class FormPelabuhanScreen extends StatefulWidget {
  final dynamic order;
  const FormPelabuhanScreen({super.key, required this.order});

  @override
  _FormPelabuhanScreenState createState() => _FormPelabuhanScreenState();
}

class _FormPelabuhanScreenState extends State<FormPelabuhanScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _containerController = TextEditingController();
  final TextEditingController _sealController = TextEditingController();
  final TextEditingController _seal2Controller = TextEditingController();
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  String? _namaPetugas;
  Map<String, dynamic> _databaseData = {};
  bool _isLoading = true;
  bool _isSubmitting = false;
  late PelabuhanService _pelabuhanService;
  late AuthService _authService;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _pelabuhanService = PelabuhanService(_authService);
    _initializeData();
  }

  Future<void> _initializeData() async {
    await Future.wait([
      _loadPetugas(),
      _checkIfAlreadySubmitted(),
      _loadDraftIfAny(),
    ]);
    setState(() => _isLoading = false);
  }

  Future<void> _loadPetugas() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _namaPetugas = prefs.getString('username') ?? 'Tidak diketahui';
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        final file = File(pickedFile.path);
        if (await file.exists()) {
          if (mounted) {
            setState(() {
              _selectedImage = file;
            });
          }
          await _autoSaveDraft();
          if (mounted) {
            showDialog(
              context: context,
              builder:
                  (context) => AlertDialog(
                    content: const Text('Pastikan data telah sesuai'),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: const Text('Iya'),
                      ),
                    ],
                  ),
            );
          }
        } else {
          throw Exception('File tidak ditemukan');
        }
      } else {}
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal memilih gambar: $e')));
      }
    }
  }

  Future<void> _checkIfAlreadySubmitted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? ''; // Get token from storage
      final res = await http.get(
        Uri.parse(
          'http://192.168.20.65/ralisa_api/index.php/api/get_new_salesorder_for_krani_pelabuhan?token=$token',
          // 'https://api3.ralisa.co.id/index.php/api/get_new_salesorder_for_krani_pelabuhan?token=$token',
        ),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final archiveList = data['data'] ?? [];

        final isSubmitted = archiveList.any(
          (item) =>
              item['so_id'].toString() == widget.order['so_id'].toString() &&
              item['foto_rc'] != null &&
              item['foto_rc'].toString().isNotEmpty,
        );

        if (isSubmitted && mounted) {
          final prefs = await SharedPreferences.getInstance();
          final drafts = prefs.getStringList('rc_drafts') ?? [];
          final updated =
              drafts
                  .where((e) => jsonDecode(e)['so_id'] != widget.order['so_id'])
                  .toList();
          await prefs.setStringList('rc_drafts', updated);

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Data ini telah disubmit.')));
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      print('Error checking submission status: $e');
    }
  }

  Future<void> _loadDraftIfAny() async {
    final prefs = await SharedPreferences.getInstance();
    final drafts = prefs.getStringList('rc_drafts') ?? [];
    final existing = drafts.firstWhere(
      (e) => jsonDecode(e)['so_id'] == widget.order['so_id'],
      orElse: () => '',
    );

    if (existing.isNotEmpty) {
      final data = jsonDecode(existing);
      _containerController.text = data['driver_container_num'] ?? '';
      _sealController.text = data['driver_seal_num1'] ?? '';
      _seal2Controller.text = data['driver_seal_num2'] ?? '';
      String fotoPath = data['foto_rc'] ?? '';
      if (fotoPath.isNotEmpty) {
        _selectedImage = File(fotoPath);
      }

      setState(() {
        _databaseData = data;
      });
    } else {
      _containerController.text = widget.order['driver_container_num'] ?? '';
      _sealController.text = widget.order['driver_seal_num1'] ?? '';
      _seal2Controller.text = widget.order['driver_seal_num2'] ?? '';

      setState(() {
        _databaseData = widget.order;
      });
    }
  }

  Future<void> _autoSaveDraft() async {
    if (!mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final drafts = prefs.getStringList('rc_drafts') ?? [];

      final draft = {
        "so_id": widget.order['so_id'],
        "no_ro": widget.order['no_ro'] ?? '',
        "destination_name": widget.order['destination_name'] ?? '',
        "driver_name": widget.order['driver_name'] ?? '',
        "truck_name": widget.order['truck_name'] ?? '',
        "sender_name": widget.order['sender_name'] ?? '',
        "nama_kapal": widget.order['nama_kapal'] ?? '',
        "nomor_voy": widget.order['nomor_voy'] ?? '',
        "nama_pelayaran": widget.order['nama_pelayaran'] ?? '',
        "driver_container_num": _containerController.text.trim(),
        "driver_seal_num1": _sealController.text.trim(),
        "driver_seal_num2": _seal2Controller.text.trim(),
        "foto_rc": _selectedImage?.path ?? "",
        "username": _namaPetugas ?? "Tidak diketahui",
      };

      final updatedDrafts =
          drafts.where((e) {
            try {
              return jsonDecode(e)['so_id'] != widget.order['so_id'];
            } catch (_) {
              return false;
            }
          }).toList();

      updatedDrafts.add(jsonEncode(draft));
      await prefs.setStringList('rc_drafts', updatedDrafts);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal menyimpan draft: $e')));
      }
      print('Error auto-saving draft: $e');
    }
  }

  Future<void> _submitData() async {
    // Lock untuk mencegah multiple submissions
    if (_isSubmitting) return;

    if (!_isAllFieldsFilled() || _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mohon lengkapi semua data terlebih dahulu'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Cek ulang status data sebelum submit
      final isAlreadySubmitted = await _checkSubmissionStatus();
      if (isAlreadySubmitted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Data ini sudah disubmit sebelumnya')),
          );
          Navigator.pop(context, true);
        }
        return;
      }

      bool success = await _pelabuhanService.submitRC(
        soId: widget.order['so_id'].toString(),
        containerNum: _containerController.text.trim(),
        sealNumber: _sealController.text.trim(),
        sealNumber2: _seal2Controller.text.trim(),
        fotoRcPath: _selectedImage!.path,
        username: _namaPetugas ?? "Tidak diketahui",
      );

      if (success) {
        final prefs = await SharedPreferences.getInstance();
        final drafts = prefs.getStringList('rc_drafts') ?? [];
        final updated =
            drafts
                .where((e) => jsonDecode(e)['so_id'] != widget.order['so_id'])
                .toList();
        await prefs.setStringList('rc_drafts', updated);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Data berhasil dikirim')),
          );
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Gagal mengirim data')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi kesalahan: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  // Fungsi baru untuk cek status submission
  Future<bool> _checkSubmissionStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final res = await http.get(
        Uri.parse(
          'http://192.168.20.65/ralisa_api/index.php/api/get_new_salesorder_for_krani_pelabuhan?token=$token',
          // 'https://api3.ralisa.co.id/index.php/api/get_new_salesorder_for_krani_pelabuhan?token=$token',
        ),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final archiveList = data['data'] ?? [];

        return archiveList.any(
          (item) =>
              item['so_id'].toString() == widget.order['so_id'].toString() &&
              item['foto_rc'] != null &&
              item['foto_rc'].toString().isNotEmpty,
        );
      }
      return false;
    } catch (e) {
      print('Error checking submission status: $e');
      return false;
    }
  }

  bool _isAllFieldsFilled() {
    return _containerController.text.trim().isNotEmpty &&
        _sealController.text.trim().isNotEmpty;
  }

  Widget _buildStyledInfoWrap() {
    final items = [
      {
        'label': 'Nomor RO',
        'value': _databaseData['no_ro'] ?? widget.order['no_ro'] ?? '-',
      },
      {
        'label': 'Tujuan',
        'value':
            _databaseData['destination_name'] ??
            widget.order['destination_name'] ??
            '-',
      },
      {
        'label': 'Supir',
        'value':
            _databaseData['driver_name'] ?? widget.order['driver_name'] ?? '-',
      },
      {
        'label': 'Nomor Mobil',
        'value':
            _databaseData['truck_name'] ?? widget.order['truck_name'] ?? '-',
      },
      {
        'label': 'Pabrik',
        'value':
            _databaseData['sender_name'] ?? widget.order['sender_name'] ?? '-',
      },
      {
        'label': 'Kapal',
        'value':
            _databaseData['nama_kapal'] ?? widget.order['nama_kapal'] ?? '-',
      },
      {
        'label': 'Voyage',
        'value': _databaseData['nomor_voy'] ?? widget.order['nomor_voy'] ?? '-',
      },
      {
        'label': 'Pelayaran',
        'value':
            _databaseData['nama_pelayaran'] ??
            widget.order['nama_pelayaran'] ??
            '-',
      },
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children:
          items.map((item) {
            return IntrinsicWidth(
              child: IntrinsicHeight(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item['label']!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item['value']!,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Memuat data...'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _autoSaveDraft();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data disimpan sebagai draft')),
        );
        Navigator.pop(context, true);
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Form Pelabuhan'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              await _autoSaveDraft();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Data disimpan sebagai draft')),
                );
                Navigator.pop(context, true);
              }
            },
          ),
        ),
        body:
            _isLoading
                ? _buildLoadingIndicator()
                : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      children: [
                        _buildStyledInfoWrap(),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _containerController,
                          decoration: const InputDecoration(
                            labelText: 'Nomor Kontainer',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                          onChanged: (_) => _autoSaveDraft(),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _sealController,
                          decoration: const InputDecoration(
                            labelText: 'Nomor Segel 1',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                          onChanged: (_) => _autoSaveDraft(),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _seal2Controller,
                          decoration: const InputDecoration(
                            labelText: 'Nomor Segel 2',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                          onChanged: (_) => _autoSaveDraft(),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: const Text("Pilih Sumber Gambar"),
                                  actions: [
                                    TextButton.icon(
                                      icon: const Icon(Icons.camera_alt),
                                      label: const Text("Kamera"),
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                        _pickImage(ImageSource.camera);
                                      },
                                    ),
                                    TextButton.icon(
                                      icon: const Icon(Icons.image),
                                      label: const Text("Galeri"),
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                        _pickImage(ImageSource.gallery);
                                      },
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Pilih Foto RC'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                            textStyle: const TextStyle(fontSize: 16),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_selectedImage != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder:
                                        (_) => Dialog(
                                          insetPadding: const EdgeInsets.all(
                                            16,
                                          ),
                                          backgroundColor: Colors.transparent,
                                          child: Stack(
                                            children: [
                                              InteractiveViewer(
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  child: Image.file(
                                                    _selectedImage!,
                                                  ),
                                                ),
                                              ),
                                              Positioned(
                                                top: 10,
                                                right: 10,
                                                child: ElevatedButton(
                                                  onPressed:
                                                      () =>
                                                          Navigator.of(
                                                            context,
                                                          ).pop(),
                                                  style: ElevatedButton.styleFrom(
                                                    shape: const CircleBorder(),
                                                    backgroundColor: Colors.red,
                                                    padding: const EdgeInsets.all(
                                                      10,
                                                    ), // Sesuaikan padding sesuai kebutuhan
                                                    minimumSize: const Size(
                                                      40,
                                                      40,
                                                    ), // Set ukuran minimum agar tetap bulat
                                                  ),
                                                  child: const Icon(
                                                    Icons.close,
                                                    color: Colors.white,
                                                    size: 24,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                  );
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    _selectedImage!,
                                    height: 150,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () {
                                    setState(() => _selectedImage = null);
                                    _autoSaveDraft();
                                  },
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  label: const Text(
                                    'Hapus Foto',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ),
                            ],
                          )
                        else
                          const Center(child: Text('Belum ada foto dipilih')),
                        const SizedBox(height: 30),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed:
                                _isSubmitting
                                    ? null
                                    : () {
                                      showDialog(
                                        context: context,
                                        builder:
                                            (context) => AlertDialog(
                                              content: const Text(
                                                'Yakin data telah sesuai?',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed:
                                                      () => Navigator.pop(
                                                        context,
                                                      ),
                                                  child: const Text('Tidak'),
                                                ),
                                                TextButton(
                                                  onPressed: () {
                                                    Navigator.pop(context);
                                                    _submitData();
                                                  },
                                                  child: const Text(
                                                    'Iya, Kirim',
                                                  ),
                                                ),
                                              ],
                                            ),
                                      );
                                    },
                            icon:
                                _isSubmitting
                                    ? const SizedBox(
                                      height: 16,
                                      width: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                    : const Icon(
                                      Icons.send,
                                      color: Colors.white,
                                    ),
                            label: Text(
                              _isSubmitting ? 'Mengirim...' : 'Kirim Data',
                              style: const TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF4C4C),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 14,
                              ),
                              textStyle: const TextStyle(fontSize: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
      ),
    );
  }
}
