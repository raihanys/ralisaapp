import 'package:flutter/material.dart';
import 'inbox_pelabuhan.dart';
import 'process_pelabuhan.dart';
import 'archive_pelabuhan.dart';
import '../login_screen.dart';
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/auth_service.dart';
import '../../services/pelabuhan_service.dart';

class MainPelabuhan extends StatefulWidget {
  const MainPelabuhan({Key? key}) : super(key: key);

  @override
  _MainPelabuhanState createState() => _MainPelabuhanState();
}

class _MainPelabuhanState extends State<MainPelabuhan> {
  int _currentIndex = 0;
  List<dynamic> inboxOrders = [];
  List<dynamic> processOrders = [];
  List<dynamic> archiveOrders = [];
  bool _isLoading = true;
  Timer? _timer;
  String? _lastNotifiedOrderId;
  late PelabuhanService _pelabuhanService;
  late AuthService _authService;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _pelabuhanService = PelabuhanService(_authService);
    _initializeNotifications();
    _fetchOrders();
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _fetchOrders();
    });
  }

  Future<void> _initializeNotifications() async {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'order_service_channel',
      'Order Service Channel',
      description: 'This channel is used for order notifications',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    await _pelabuhanService.initializeService();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchOrders() async {
    setState(() => _isLoading = true);

    try {
      final orders = await _pelabuhanService.fetchOrders();

      _checkForNewOrdersNotification(orders);

      orders.sort((a, b) {
        final tglA = a['keluar_pabrik_tgl'] ?? '';
        final jamA = a['keluar_pabrik_jam'] ?? '';
        final tglB = b['keluar_pabrik_tgl'] ?? '';
        final jamB = b['keluar_pabrik_jam'] ?? '';

        final dateTimeA = DateTime.tryParse('$tglA $jamA') ?? DateTime(2000);
        final dateTimeB = DateTime.tryParse('$tglB $jamB') ?? DateTime(2000);
        return dateTimeA.compareTo(dateTimeB);
      });

      final prefs = await SharedPreferences.getInstance();
      final draftStringList = prefs.getStringList('rc_drafts') ?? [];
      final rawDraftOrders = draftStringList.map((e) => jsonDecode(e)).toList();

      final cleanedDraftOrders =
          rawDraftOrders.where((o) {
            final tglRC = (o['tgl_rc_dibuat'] ?? '').toString().trim();
            final jamRC = (o['jam_rc_dibuat'] ?? '').toString().trim();
            final fotoRC = (o['foto_rc'] ?? '').toString().trim();
            final isAllFilled =
                fotoRC.isNotEmpty && tglRC.isNotEmpty && jamRC.isNotEmpty;
            return !isAllFilled;
          }).toList();

      prefs.setStringList(
        'rc_drafts',
        cleanedDraftOrders.map((e) => jsonEncode(e)).toList(),
      );

      final draftSoIds =
          cleanedDraftOrders.map((e) => e['so_id'] as String).toList();

      setState(() {
        inboxOrders =
            orders.where((o) {
              final noRo = (o['no_ro'] ?? '').toString().trim();
              if (noRo.isEmpty) return false;

              final fotoRC = (o['foto_rc'] ?? '').toString().trim();
              final soId = o['so_id'].toString();

              return fotoRC.isEmpty && !draftSoIds.contains(soId);
            }).toList();

        processOrders =
            cleanedDraftOrders.where((o) {
              final noRo = (o['no_ro'] ?? '').toString().trim();
              final tglRC = (o['tgl_rc_dibuat'] ?? '').toString().trim();
              final jamRC = (o['jam_rc_dibuat'] ?? '').toString().trim();
              final soId = o['so_id'].toString();

              if (noRo.isEmpty) return false;

              final isIncomplete = tglRC.isEmpty || jamRC.isEmpty;
              final isAlreadyArchived = orders.any((order) {
                final orderSoId = order['so_id'].toString();
                final fotoDone =
                    (order['foto_rc'] ?? '').toString().trim().isNotEmpty;
                return orderSoId == soId && fotoDone;
              });

              return isIncomplete && !isAlreadyArchived;
            }).toList();

        archiveOrders =
            orders.where((o) {
              final noRo = (o['no_ro'] ?? '').toString().trim();
              if (noRo.isEmpty) return false;

              final fotoRC = (o['foto_rc'] ?? '').toString().trim();
              return fotoRC.isNotEmpty;
            }).toList();

        archiveOrders.sort((b, a) {
          final tglA = a['tgl_rc_dibuat'] ?? '';
          final jamA = a['jam_rc_dibuat'] ?? '';
          final tglB = b['tgl_rc_dibuat'] ?? '';
          final jamB = b['jam_rc_dibuat'] ?? '';

          final dateTimeA = DateTime.tryParse('$tglA $jamA') ?? DateTime(2000);
          final dateTimeB = DateTime.tryParse('$tglB $jamB') ?? DateTime(2000);
          return dateTimeA.compareTo(dateTimeB);
        });

        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching orders: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat data: ${e.toString()}')),
      );
    }
  }

  Future<void> _checkForNewOrdersNotification(List<dynamic> orders) async {
    if (orders.isEmpty) return;

    final newInboxOrders =
        orders.where((order) {
          final fotoRC = (order['foto_rc'] ?? '').toString().trim();
          return fotoRC.isEmpty;
        }).toList();

    if (newInboxOrders.isEmpty) return;

    final newestOrder = newInboxOrders.first;
    final currentOrderId = newestOrder['so_id'].toString();

    if (_lastNotifiedOrderId != currentOrderId) {
      _lastNotifiedOrderId = currentOrderId;
      await _pelabuhanService.showNewOrderNotification(
        orderId: currentOrderId,
        noRo: newestOrder['no_ro'] ?? 'No RO',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(150.0),
        child: SafeArea(child: _buildCustomAppBar(context, _currentIndex)),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : IndexedStack(
                index: _currentIndex,
                children: [
                  InboxPelabuhan(
                    orders: inboxOrders,
                    onOrderUpdated: _fetchOrders,
                  ),
                  ProcessPelabuhan(
                    orders: processOrders,
                    onOrderUpdated: _fetchOrders,
                  ),
                  ArchivePelabuhan(
                    orders: archiveOrders,
                    onOrderUpdated: _fetchOrders,
                  ),
                ],
              ),
      bottomNavigationBar: _buildFloatingNavBar(theme),
    );
  }

  Widget _buildCustomAppBar(BuildContext context, int currentIndex) {
    String title = '';
    switch (currentIndex) {
      case 0:
        title = 'Inbox';
        break;
      case 1:
        title = 'Process';
        break;
      case 2:
        title = 'Archive';
        break;
    }

    return Container(
      decoration: const BoxDecoration(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset('assets/images/logo.png', height: 40, width: 200),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () async {
                    await _authService.logout();
                    if (!mounted) return;
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                  child: const Text('Logout'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Aplikasi Pelabuhan',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingNavBar(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: theme.colorScheme.surface,
          selectedItemColor: theme.colorScheme.primary,
          unselectedItemColor: theme.colorScheme.onSurface.withOpacity(0.6),
          showSelectedLabels: true,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.inbox_outlined),
              activeIcon: Icon(Icons.inbox),
              label: 'Inbox',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.timer_outlined),
              activeIcon: Icon(Icons.timer),
              label: 'Process',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.archive_outlined),
              activeIcon: Icon(Icons.archive),
              label: 'Archive',
            ),
          ],
        ),
      ),
    );
  }
}
