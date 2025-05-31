import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

class ArchivePelabuhan extends StatelessWidget {
  final List<dynamic> orders;
  final Function onOrderUpdated;
  final RefreshController _refreshController;

  ArchivePelabuhan({
    // Removed 'const' from constructor
    Key? key,
    required this.orders,
    required this.onOrderUpdated,
  }) : _refreshController = RefreshController(),
       super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (orders.isEmpty) {
      return Center(
        child: Text(
          "Tidak ada data",
          style: theme.textTheme.titleMedium!.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SmartRefresher(
            controller: _refreshController,
            enablePullDown: true,
            enablePullUp: false,
            header: CustomHeader(
              builder: (BuildContext context, RefreshStatus? mode) {
                Widget body;
                if (mode == RefreshStatus.idle) {
                  body = Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.arrow_downward,
                        color: Theme.of(context).primaryColor,
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Tarik ke bawah untuk refresh",
                        style: TextStyle(color: Theme.of(context).primaryColor),
                      ),
                    ],
                  );
                } else if (mode == RefreshStatus.refreshing) {
                  body = Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Memuat data archive...",
                        style: TextStyle(color: Theme.of(context).primaryColor),
                      ),
                    ],
                  );
                } else {
                  body = Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.arrow_upward,
                        color: Theme.of(context).primaryColor,
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Lepaskan untuk refresh",
                        style: TextStyle(color: Theme.of(context).primaryColor),
                      ),
                    ],
                  );
                }
                return Container(height: 50, child: Center(child: body));
              },
            ),
            onRefresh: () async {
              await onOrderUpdated();
              _refreshController.refreshCompleted();
            },
            child: ListView.builder(
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                final roNumber = order['no_ro'] ?? '-';
                final user = order['agent'];

                final rawDate = order['tgl_rc_dibuat'];
                final rawTime = order['jam_rc_dibuat'];

                String formattedDate = '-';
                String formattedTime = '-';

                if (rawDate != null) {
                  final parsedDate = DateTime.tryParse(rawDate);
                  if (parsedDate != null) {
                    formattedDate = DateFormat('dd/MM/yyyy').format(parsedDate);
                  }
                }

                if (rawTime != null) {
                  try {
                    final parsedTime = DateFormat('HH:mm:ss').parse(rawTime);
                    formattedTime = DateFormat('HH:mm').format(parsedTime);
                  } catch (_) {}
                }

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
                      'Nomor RO: $roNumber',
                      style: theme.textTheme.titleMedium,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Tanggal RC Diproses: $formattedDate',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              size: 16,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Jam RC Diproses: $formattedTime',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Diproses oleh: $user',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
