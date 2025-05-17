import 'package:flutter/material.dart';

class TugasSupirScreen extends StatelessWidget {
  final bool isLoading;
  final Map<String, dynamic>? taskData;
  final bool isWaitingAssignment;
  final bool isLoadingButton;
  final bool isSubmittingArrival;
  final TextEditingController truckNameController;
  final TextEditingController containerNumController;
  final TextEditingController sealNum1Controller;
  final TextEditingController sealNum2Controller;
  final String? selectedTipeContainer;
  final ValueChanged<String?> onTipeContainerChanged;
  final VoidCallback onReadyPressed;
  final VoidCallback onArrivalPressed;
  final VoidCallback onDeparturePressed;
  final VoidCallback onPortArrivalPressed;
  final Function({bool containerAndSeal1, bool seal2}) onSaveDraft;

  const TugasSupirScreen({
    Key? key,
    required this.isLoading,
    required this.taskData,
    required this.isWaitingAssignment,
    required this.isLoadingButton,
    required this.isSubmittingArrival,
    required this.truckNameController,
    required this.containerNumController,
    required this.sealNum1Controller,
    required this.sealNum2Controller,
    required this.selectedTipeContainer,
    required this.onTipeContainerChanged,
    required this.onReadyPressed,
    required this.onArrivalPressed,
    required this.onDeparturePressed,
    required this.onPortArrivalPressed,
    required this.onSaveDraft,
  }) : super(key: key);

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
  Widget build(BuildContext context) {
    if (isLoading || taskData == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final showReadyButton = taskData?['queue'] == 0;
    final taskAssign = taskData?['task_assign'] ?? 0;
    final arrivalDate = taskData?['arrival_date'];
    final departureDate = taskData?['departure_date'];
    final departureTime = taskData?['departure_time'];
    final fotoRC = taskData?['foto_rc_url'];

    // Menunggu penugasan
    if (isWaitingAssignment && taskAssign == 0) {
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
                                padding: const EdgeInsets.all(10),
                                minimumSize: const Size(40, 40),
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
                onPressed: onPortArrivalPressed,
                child: const Text('Sampai Pelabuhan'),
              ),
            ),
          ],
        ),
      );
    }

    // Kalau sudah dapat tugas dan SUDAH SAMPAI PABRIK
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
            _buildTaskInfoRow('Nomor SO', taskData?['so_number']),
            _buildTaskInfoRow('Nomor RO', taskData?['no_ro']),
            _buildTaskInfoRow(
              'Tgl/Jam Stuffing',
              '${taskData?['pickup_date']} ${taskData?['pickup_time_request']}',
            ),
            _buildTaskInfoRow('Customer', taskData?['company']),
            _buildTaskInfoRow('Pelayaran', taskData?['nama_pelayaran']),
            _buildTaskInfoRow('Tujuan', taskData?['nama_kota_tujuan']),
            _buildTaskInfoRow('Nopol', taskData?['truck_name']),
            _buildTaskInfoRow('Uang Jalan', taskData?['uang_jalan']),
            _buildTaskInfoRow('Uang Komisi', taskData?['uang_komisi']),
            _buildTaskInfoRow('Lokasi Stuffing', taskData?['sender_office']),
            _buildTaskInfoRow('Nomor Container', taskData?['container_num']),
            _buildTaskInfoRow('Nomor Seal 1', taskData?['seal_num1']),
            const SizedBox(height: 24),
            TextField(
              controller: sealNum2Controller,
              onChanged: (value) => onSaveDraft(seal2: true),
              decoration: const InputDecoration(
                hintText: 'Masukkan Seal Number 2 (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onDeparturePressed,
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
            _buildTaskInfoRow('Nomor SO', taskData?['so_number']),
            _buildTaskInfoRow('Nomor RO', taskData?['no_ro']),
            _buildTaskInfoRow(
              'Tgl/Jam Stuffing',
              '${taskData?['pickup_date']} ${taskData?['pickup_time_request']}',
            ),
            _buildTaskInfoRow('Customer', taskData?['company']),
            _buildTaskInfoRow('Pelayaran', taskData?['nama_pelayaran']),
            _buildTaskInfoRow('Tujuan', taskData?['nama_kota_tujuan']),
            _buildTaskInfoRow('Nopol', taskData?['truck_name']),
            _buildTaskInfoRow('Uang Jalan', taskData?['uang_jalan']),
            _buildTaskInfoRow('Uang Komisi', taskData?['uang_komisi']),
            _buildTaskInfoRow('Lokasi Stuffing', taskData?['sender_office']),
            const SizedBox(height: 24),
            const Text('Container Number', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            TextField(
              controller: containerNumController,
              onChanged: (value) => onSaveDraft(containerAndSeal1: true),
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
              controller: sealNum1Controller,
              onChanged: (value) => onSaveDraft(containerAndSeal1: true),
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
                onPressed: isSubmittingArrival ? null : onArrivalPressed,
                child:
                    isSubmittingArrival
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
              value: selectedTipeContainer,
              items:
                  ['10', '20'].map((value) {
                    return DropdownMenuItem(value: value, child: Text(value));
                  }).toList(),
              onChanged: onTipeContainerChanged,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Truck Name', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            TextField(
              controller: truckNameController,
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
                onPressed: isLoadingButton ? null : onReadyPressed,
                child:
                    isLoadingButton
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
