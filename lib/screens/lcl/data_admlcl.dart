import 'package:flutter/material.dart';

class DataAdmLCL extends StatelessWidget {
  const DataAdmLCL({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 3 Textbox disabled
            const TextField(
              decoration: InputDecoration(labelText: 'No. LPJ', enabled: false),
            ),
            const SizedBox(height: 16),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Nama Pengirim',
                enabled: false,
              ),
            ),
            const SizedBox(height: 16),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Nama Penerima',
                enabled: false,
              ),
            ),
            const SizedBox(height: 24),

            // Sub judul List Item
            const Text(
              'List Item',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Tabel
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Nama Barang')),
                    DataColumn(label: Text('Tipe Barang')),
                    DataColumn(label: Text('Panjang')),
                    DataColumn(label: Text('Lebar')),
                    DataColumn(label: Text('Tinggi')),
                    DataColumn(label: Text('Volume')),
                    DataColumn(label: Text('Berat')),
                  ],
                  rows: const [
                    DataRow(
                      cells: [
                        DataCell(Text('-')),
                        DataCell(Text('-')),
                        DataCell(Text('-')),
                        DataCell(Text('-')),
                        DataCell(Text('-')),
                        DataCell(Text('-')),
                        DataCell(Text('-')),
                      ],
                    ),
                    // Anda bisa menambahkan lebih banyak baris sesuai kebutuhan
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
