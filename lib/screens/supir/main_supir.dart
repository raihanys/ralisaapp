import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../login_screen.dart';
import '../../services/auth_service.dart';
import 'absen_supir.dart';
import 'tugas_supir.dart';
import '../../services/supir_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class MainSupir extends StatefulWidget {
  const MainSupir({Key? key}) : super(key: key);

  @override
  State<MainSupir> createState() => _MainSupirState();
}

class _MainSupirState extends State<MainSupir> with WidgetsBindingObserver {
  int _currentIndex = 0;
  late AuthService _authService;
  late SupirService _supirService;
  Timer? _taskPollingTimer;
  Timer? _locationUpdateTimer;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Data untuk Absen
  bool _isLoadingAbsen = false;
  bool _showAbsenButton = false;
  String _statusText = '';
  String _errorMessageAbsen = '';
  String _latitude = '0';
  String _longitude = '0';

  // Data untuk Tugas
  bool _isLoadingTugas = false;
  bool _isLoadingButton = false;
  bool _isSubmittingArrival = false;
  Map<String, dynamic>? _taskData;
  bool _isWaitingAssignment = false;
  final TextEditingController _truckNameController = TextEditingController();
  final TextEditingController _containerNumController = TextEditingController();
  final TextEditingController _sealNum1Controller = TextEditingController();
  final TextEditingController _sealNum2Controller = TextEditingController();
  String? _selectedTipeContainer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authService = AuthService();
    _supirService = SupirService(_authService);
    _initializeNotifications();
    _initializeServices();
    _startBackgroundProcesses();
  }

  @override
  void dispose() {
    _taskPollingTimer?.cancel();
    _locationUpdateTimer?.cancel();
    _truckNameController.dispose();
    _containerNumController.dispose();
    _sealNum1Controller.dispose();
    _sealNum2Controller.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadAbsenStatus();
      _fetchTaskData();
    }
  }

  Future<void> _initializeNotifications() async {
    final status = await Permission.notification.request();
    if (!status.isGranted) {
      print('Notification permission not granted');
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    await flutterLocalNotificationsPlugin.initialize(
      InitializationSettings(android: initializationSettingsAndroid),
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        if (response.payload?.startsWith('task_') ?? false) {
          setState(() => _currentIndex = 1);
          await _fetchTaskData();
        }
      },
    );
  }

  void _initializeServices() async {
    await SupirBackgroundService(_authService).initializeService();
    _loadDraftData();
  }

  void _startBackgroundProcesses() {
    // Polling tugas setiap 30 detik
    _taskPollingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _fetchTaskData();
    });

    // Update lokasi setiap 30 detik
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _getCurrentLocation();
    });

    // Load data awal
    _loadAbsenStatus();
    _fetchTaskData();
    _getCurrentLocation();
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

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() {
          _latitude = position.latitude.toString();
          _longitude = position.longitude.toString();
        });
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  Future<void> _loadAbsenStatus() async {
    if (mounted) {
      setState(() {
        _isLoadingAbsen = true;
        _errorMessageAbsen = '';
      });
    }

    try {
      final response = await _supirService.getAttendanceStatus();

      if (mounted) {
        setState(() {
          _showAbsenButton = response['show_button'] == true;
          _statusText = response['notes'];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessageAbsen = 'Gagal memuat status: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingAbsen = false);
      }
    }
  }

  Future<void> _fetchTaskData() async {
    if (mounted) {
      setState(() {
        _isLoadingTugas = true;
      });
    }

    try {
      final response = await _supirService.getTaskDriver();

      if (response['error'] == false && response['data'].isNotEmpty) {
        final task = response['data'][0];

        if (mounted) {
          setState(() {
            _taskData = task;
            _isWaitingAssignment =
                (task['task_assign'] ?? 0) != 0 &&
                (task['arrival_date'] == null || task['arrival_date'] == '-');
          });
        }
      }
    } catch (e) {
      debugPrint('Fetch Task Error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingTugas = false);
      }
    }
  }

  Future<void> _handleAbsen() async {
    if (mounted) {
      setState(() {
        _isLoadingAbsen = true;
        _errorMessageAbsen = '';
      });
    }

    try {
      final result = await _supirService.kirimAbsen(
        latitude: _latitude,
        longitude: _longitude,
      );

      if (result['success'] == true) {
        await _loadAbsenStatus();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(result['message'])));
        }
      } else if (mounted) {
        setState(() {
          _errorMessageAbsen = result['message'];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessageAbsen = 'Terjadi kesalahan: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingAbsen = false);
      }
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
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final response = await _supirService.sendReady(
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
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final response = await _supirService.submitArrival(
        taskId: _taskData?['task_id'],
        longitude: position.longitude,
        latitude: position.latitude,
        containerNum: _containerNumController.text,
        sealNum1: _sealNum1Controller.text,
      );

      if (response['error'] == false) {
        final prefs = await SharedPreferences.getInstance();
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
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final now = DateTime.now();
      final departureDate =
          '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';
      final departureTime =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      final response = await _supirService.submitDeparture(
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

  Future<void> _handlePortArrival() async {
    setState(() {
      _isLoadingButton = true;
    });

    try {
      // Implement your port arrival logic here
      // Example:
      // final response = await _supirService.submitPortArrival(...);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Berhasil sampai pelabuhan')),
      );
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

  final List<String> _titles = ['Absen', 'Tugas'];

  List<Widget> _buildPages() {
    return [
      AbsenSupirScreen(
        isLoading: _isLoadingAbsen,
        showButton: _showAbsenButton,
        statusText: _statusText,
        errorMessage: _errorMessageAbsen,
        latitude: _latitude,
        longitude: _longitude,
        onAbsenPressed: _handleAbsen,
      ),
      TugasSupirScreen(
        isLoading: _isLoadingTugas,
        taskData: _taskData,
        isWaitingAssignment: _isWaitingAssignment,
        isLoadingButton: _isLoadingButton,
        isSubmittingArrival: _isSubmittingArrival,
        truckNameController: _truckNameController,
        containerNumController: _containerNumController,
        sealNum1Controller: _sealNum1Controller,
        sealNum2Controller: _sealNum2Controller,
        selectedTipeContainer: _selectedTipeContainer,
        onTipeContainerChanged: (value) {
          setState(() {
            _selectedTipeContainer = value;
          });
        },
        onReadyPressed: _sendReady,
        onArrivalPressed: _submitArrival,
        onDeparturePressed: _sendDeparture,
        onPortArrivalPressed: _handlePortArrival,
        onSaveDraft: _saveDraftData,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(150.0),
        child: SafeArea(child: _buildCustomAppBar(context, _currentIndex)),
      ),
      body: IndexedStack(index: _currentIndex, children: _buildPages()),
      bottomNavigationBar: _buildFloatingNavBar(theme),
    );
  }

  Widget _buildCustomAppBar(BuildContext context, int currentIndex) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Image.asset('assets/images/logo.png', height: 40, width: 200),
              Row(
                children: [
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
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Aplikasi Supir',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          Text(
            _titles[currentIndex],
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
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
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.access_time_outlined),
              activeIcon: Icon(Icons.access_time),
              label: 'Absen',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.assignment_outlined),
              activeIcon: Icon(Icons.assignment),
              label: 'Tugas',
            ),
          ],
        ),
      ),
    );
  }
}
