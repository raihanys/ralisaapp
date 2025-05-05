import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import '../../../services/supir_service.dart';

class TugasSupirScreen extends StatefulWidget {
  const TugasSupirScreen({Key? key}) : super(key: key);

  @override
  State<TugasSupirScreen> createState() => _TugasSupirScreenState();
}

class _TugasSupirScreenState extends State<TugasSupirScreen> {
  final TextEditingController _truckNameController = TextEditingController();
  final TextEditingController _containerNumController = TextEditingController();
  final TextEditingController _sealNum1Controller = TextEditingController();
  final TextEditingController _sealNum2Controller = TextEditingController();
  String? _selectedTipeContainer;
  bool _isLoadingButton = false;
  bool _isWaitingAssignment = false;
  bool _isSubmittingArrival = false;
  Timer? _timer;
  Map<String, dynamic>? _taskData;

  Widget _buildTaskInfoRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value?.toString() ?? '-',
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchTaskData();
    _startPolling();
    _loadDraftData();
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _fetchTaskData();
    });
  }

  Future<void> _fetchTaskData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final response = await SupirService.getTaskDriver(token: token);
      if (response['error'] == false && response['data'].isNotEmpty) {
        final task = response['data'][0];

        setState(() {
          _taskData = task;
        });
      }
    } catch (e) {
      debugPrint('Fetch Task Error: \$e');
    }
  }

  Future<void> _loadDraftData() async {
    final prefs = await SharedPreferences.getInstance();
    _containerNumController.text = prefs.getString('draft_container_num') ?? '';
    _sealNum1Controller.text = prefs.getString('draft_seal_num1') ?? '';
    _sealNum2Controller.text = prefs.getString('draft_seal_num2') ?? '';
  }

  Future<void> _saveDraftData({
    bool containerAndSeal1 = false,
    bool seal2 = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (containerAndSeal1) {
      await prefs.setString(
        'draft_container_num',
        _containerNumController.text,
      );
      await prefs.setString('draft_seal_num1', _sealNum1Controller.text);
    }
    if (seal2) {
      await prefs.setString('draft_seal_num2', _sealNum2Controller.text);
    }
  }

  Future<void> _sendReady() async {
    if (_selectedTipeContainer == null || _truckNameController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Lengkapi semua field')));
      return;
    }

    setState(() {
      _isLoadingButton = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final response = await SupirService.sendReady(
        token: token,
        longitude: position.longitude,
        latitude: position.latitude,
        tipeContainer: _selectedTipeContainer!,
        truckName: _truckNameController.text,
      );

      if (response['error'] == false) {
        setState(() {
          _isWaitingAssignment = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ready dikirim, menunggu tugas...')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal Ready: ${response['message']}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() {
        _isLoadingButton = false;
      });
    }
  }

  Future<void> _submitArrival() async {
    if (_containerNumController.text.isEmpty ||
        _sealNum1Controller.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Lengkapi semua field')));
      return;
    }

    setState(() {
      _isSubmittingArrival = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final response = await SupirService.submitArrival(
        token: token,
        taskId: _taskData?['task_id'],
        longitude: position.longitude,
        latitude: position.latitude,
        containerNum: _containerNumController.text,
        sealNum1: _sealNum1Controller.text,
      );

      if (response['error'] == false) {
        await prefs.remove('draft_container_num');
        await prefs.remove('draft_seal_num1');

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Berhasil Sampai Pabrik')));

        await _fetchTaskData();
        setState(() {});
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: ${response['message']}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() {
        _isSubmittingArrival = false;
      });
    }
  }

  Future<void> _sendDeparture() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final now = DateTime.now();
      final departureDate =
          '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';
      final departureTime =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      final response = await SupirService.submitDeparture(
        token: token,
        taskId: _taskData?['task_id'],
        departureDate: departureDate,
        departureTime: departureTime,
        longitude: position.longitude,
        latitude: position.latitude,
        sealNum2: _sealNum2Controller.text,
      );

      if (response['error'] == false) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Berhasil keluar pabrik')));

        await _fetchTaskData();
        setState(() {});
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal keluar: ${response['message']}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  void dispose() {
    _truckNameController.dispose();
    _containerNumController.dispose();
    _sealNum1Controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_taskData == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final showReadyButton = _taskData?['queue'] == 0;
    final taskAssign = _taskData?['task_assign'] ?? 0;
    final arrivalDate = _taskData?['arrival_date'];
    final departureDate = _taskData?['departure_date'];
    final departureTime = _taskData?['departure_time'];
    final fotoRC = _taskData?['foto_rc_url'];

    // Kalau masih belum dapat tugas, tampilkan "Menunggu penugasan"
    if (_isWaitingAssignment && taskAssign == 0) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Menunggu penugasan...'),
          ],
        ),
      );
    }

    // Setelah Departure tapi RC BELUM tersedia
    if (departureDate != null &&
        departureDate != '-' &&
        departureTime != null &&
        departureTime != '-' &&
        (fotoRC == null || fotoRC == '-')) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Menunggu RC...'),
          ],
        ),
      );
    }

    // Setelah Departure, tampilkan foto RC dan tombol "Sampai Pelabuhan"
    if (departureDate != null &&
        departureDate != '-' &&
        departureTime != null &&
        departureTime != '-' &&
        fotoRC != null &&
        fotoRC != '-') {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Foto RC',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    return Dialog(
                      insetPadding: const EdgeInsets.all(16),
                      backgroundColor: Colors.transparent,
                      child: Stack(
                        children: [
                          InteractiveViewer(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                fotoRC,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder:
                                    (context, error, stackTrace) =>
                                        const Center(
                                          child: Text('Gagal memuat gambar'),
                                        ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 10,
                            right: 10,
                            child: ElevatedButton(
                              onPressed: () => Navigator.of(context).pop(),
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
                    );
                  },
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  fotoRC,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (context, error, stackTrace) =>
                          const Text('Gagal memuat gambar'),
                ),
              ),
            ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  // TODO: Panggil API Sampai Pelabuhan (nanti ditentukan endpointnya)
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Berhasil sampai pelabuhan')),
                  );
                },
                child: const Text('Sampai Pelabuhan'),
              ),
            ),
          ],
        ),
      );
    }

    // Kalau sudah dapat tugas dan SUDAH SAMPAI PABRIK (arrival_date != null dan tidak kosong)
    if (taskAssign != 0 && arrivalDate != null && arrivalDate != '-') {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            const Text(
              'Detail Tugas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _buildTaskInfoRow('Nomor SO', _taskData?['so_number']),
            _buildTaskInfoRow('Nomor RO', _taskData?['no_ro']),
            _buildTaskInfoRow(
              'Tgl/Jam Stuffing',
              '${_taskData?['pickup_date']} ${_taskData?['pickup_time_request']}',
            ),
            _buildTaskInfoRow('Customer', _taskData?['company']),
            _buildTaskInfoRow('Pelayaran', _taskData?['nama_pelayaran']),
            _buildTaskInfoRow('Tujuan', _taskData?['nama_kota_tujuan']),
            _buildTaskInfoRow('Nopol', _taskData?['truck_name']),
            _buildTaskInfoRow('Uang Jalan', _taskData?['uang_jalan']),
            _buildTaskInfoRow('Uang Komisi', _taskData?['uang_komisi']),
            _buildTaskInfoRow('Lokasi Stuffing', _taskData?['sender_office']),
            _buildTaskInfoRow('Nomor Container', _taskData?['container_num']),
            _buildTaskInfoRow('Nomor Seal 1', _taskData?['seal_num1']),
            const SizedBox(height: 24),
            TextField(
              controller: _sealNum2Controller,
              onChanged: (value) => _saveDraftData(seal2: true),
              decoration: const InputDecoration(
                hintText: 'Masukkan Seal Number 2 (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _sendDeparture,
              child: const Text('Keluar Pabrik'),
            ),
          ],
        ),
      );
    }

    // Kalau sudah dapat tugas tapi BELUM sampai pabrik
    if (taskAssign != 0) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Detail Tugas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _buildTaskInfoRow('Nomor SO', _taskData?['so_number']),
            _buildTaskInfoRow('Nomor RO', _taskData?['no_ro']),
            _buildTaskInfoRow(
              'Tgl/Jam Stuffing',
              '${_taskData?['pickup_date']} ${_taskData?['pickup_time_request']}',
            ),
            _buildTaskInfoRow('Customer', _taskData?['company']),
            _buildTaskInfoRow('Pelayaran', _taskData?['nama_pelayaran']),
            _buildTaskInfoRow('Tujuan', _taskData?['nama_kota_tujuan']),
            _buildTaskInfoRow('Nopol', _taskData?['truck_name']),
            _buildTaskInfoRow('Uang Jalan', _taskData?['uang_jalan']),
            _buildTaskInfoRow('Uang Komisi', _taskData?['uang_komisi']),
            _buildTaskInfoRow('Lokasi Stuffing', _taskData?['sender_office']),
            const SizedBox(height: 24),
            const Text('Container Number', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            TextField(
              controller: _containerNumController,
              onChanged: (value) => _saveDraftData(),
              decoration: const InputDecoration(
                hintText: 'Masukkan Nomor Container',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Seal Number 1', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            TextField(
              controller: _sealNum1Controller,
              onChanged: (value) => _saveDraftData(),
              decoration: const InputDecoration(
                hintText: 'Masukkan Seal Number 1',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmittingArrival ? null : _submitArrival,
                child:
                    _isSubmittingArrival
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Sampai Pabrik'),
              ),
            ),
          ],
        ),
      );
    }

    // Kalau belum ready
    if (showReadyButton) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tipe Container', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedTipeContainer,
              items:
                  ['10', '20'].map((value) {
                    return DropdownMenuItem(value: value, child: Text(value));
                  }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedTipeContainer = value;
                });
              },
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Truck Name', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            TextField(
              controller: _truckNameController,
              decoration: const InputDecoration(
                hintText: 'Masukkan Nama Truk',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoadingButton ? null : _sendReady,
                child:
                    _isLoadingButton
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Ready'),
              ),
            ),
          ],
        ),
      );
    }

    return const Center(child: Text('Tidak ada tugas saat ini'));
  }
}
