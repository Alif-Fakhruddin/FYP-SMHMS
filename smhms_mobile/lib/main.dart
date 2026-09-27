import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// ==========================================
// TETAPAN IP LAPTOP / BACKEND FLASK
// ==========================================
// Ganti IP di bawah dengan IP IPv4 Laptop anda (cth: 192.168.1.15)
// Gunakan 10.0.2.2 jika anda menggunakan Android Emulator
const String backendBaseUrl = 'http://172.20.235.48:5000/api';
const String apiKey = 'SMHMS_SECRET_API_KEY_2026';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SMHMSApp());
}

class SMHMSApp extends StatelessWidget {
  const SMHMSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SMHMS Mobile App',
      theme: ThemeData(
        primarySwatch: Colors.red,
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Instance Keselamatan & Notifikasi
  final LocalAuthentication _auth = LocalAuthentication();
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Tetapan Data & Status
  bool _isLoading = true;
  bool _isAuthenticated = false;
  String _statusHazard = 'NORMAL';
  
  // Data Masa Nyata untuk Graf (Senarai FlSpot)
  final List<FlSpot> _gasReadings = [];
  int _timeStep = 0;
  Timer? _dataTimer;

  @override
  void initState() {
    super.initState();
    _initNotifications();

    // Pengambilan data sensor sebenar dari Flask Backend setiap 3 saat
    _dataTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _fetchRealtimeData();
    });

    // Nyahaktifkan loading Shimmer awal selepas 2 saat
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _dataTimer?.cancel();
    super.dispose();
  }

  // 1. Inisialisasi Notifikasi Tempatan secara Selamat
  Future<void> _initNotifications() async {
    try {
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings settings =
          InitializationSettings(android: androidSettings);
      await _notificationsPlugin.initialize(settings);

      // Minta kebenaran notifikasi untuk Android 13+
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();
      }
    } catch (e) {
      debugPrint('Ralat Inisialisasi Notifikasi: $e');
    }
  }

  // Hantar Notifikasi Bahaya Pop-up
  Future<void> _triggerDangerAlert(double value) async {
    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'smhms_alert_channel',
        'SMHMS Hazard Notification',
        importance: Importance.max,
        priority: Priority.high,
        color: Colors.red,
      );
      const NotificationDetails details = NotificationDetails(android: androidDetails);

      await _notificationsPlugin.show(
        1,
        '⚠️ AMARAN BAHAYA: TAHAP GAS TINGGI!',
        'Bacaan sensor gas semasa (${value.toStringAsFixed(1)} PPM) melepasi had selamat!',
        details,
      );
    } catch (e) {
      debugPrint('Ralat Menghantar Notifikasi: $e');
    }
  }

  // 2. Pengambilan Data Sensor Sebenar dari Python Flask API (Disertai Try-Catch)
  Future<void> _fetchRealtimeData() async {
    final String url = '$backendBaseUrl/sensor?api_key=$apiKey';

    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['status'] == 'success' && mounted) {
          final data = result['data'];
          double newGasReading = (data['gas_level'] ?? 0).toDouble();
          String hazardState = data['status_hazard'] ?? 'NORMAL';

          setState(() {
            _timeStep++;
            _statusHazard = hazardState;
            _gasReadings.add(FlSpot(_timeStep.toDouble(), newGasReading));

            // Simpan 10 bacaan terkini sahaja di graf supaya tidak terlalu padat
            if (_gasReadings.length > 10) {
              _gasReadings.removeAt(0);
            }
          });

          // Pemicu notifikasi jika status DANGER atau bacaan gas > 75 PPM
          if (hazardState == 'DANGER' || newGasReading > 75) {
            _triggerDangerAlert(newGasReading);
          }
        }
      }
    } catch (e) {
      // Tangkap ralat rangkaian secara senyap tanpa menyebabkan aplikasi crash
      debugPrint('Ralat Rangkaian Sensor: $e');
    }
  }

  // 3. Imbasan Cap Jari (Biometrics)
  Future<void> _authenticateBiometrics() async {
    bool authenticated = false;
    try {
      bool canCheck = await _auth.canCheckBiometrics;
      bool isSupported = await _auth.isDeviceSupported();

      if (canCheck && isSupported) {
        authenticated = await _auth.authenticate(
          localizedReason: 'Imbas cap jari anda untuk membuka Kawalan Pentadbir (Admin)',
          options: const AuthenticationOptions(
            stickyAuth: true,
            biometricOnly: true,
          ),
        );
      }
    } catch (e) {
      debugPrint('Ralat Biometrik: $e');
    }

    if (mounted) {
      setState(() {
        _isAuthenticated = authenticated;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authenticated
              ? 'Akses Cap Jari Disahkan!'
              : 'Gagal Mengesahkan Cap Jari'),
          backgroundColor: authenticated ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    double currentReading =
        _gasReadings.isNotEmpty ? _gasReadings.last.y : 0.0;
    bool isDanger = _statusHazard == 'DANGER' || currentReading > 75;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SMHMS Real-Time Portal'),
        backgroundColor: isDanger ? Colors.red : Colors.blueGrey[900],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAlignment.start,
          children: [
            // Status Semasa Kad
            _buildStatusHeader(currentReading, isDanger),

            const SizedBox(height: 20),
            const Text(
              'Graf Masa Nyata (MQ Gas Sensor)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            // 4. Graf Masa Nyata ATAU Shimmer Loading
            _isLoading
                ? _buildShimmerChart()
                : _buildRealtimeLineChart(isDanger),

            const SizedBox(height: 25),
            const Text(
              'Kawalan Aplikasi',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            // Butang Pengesahan Biometrik
            ElevatedButton.icon(
              onPressed: _authenticateBiometrics,
              icon: const Icon(Icons.fingerprint),
              label: Text(_isAuthenticated
                  ? 'Mod Admin: Aktif'
                  : 'Sahkan Cap Jari (Admin Lock)'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor:
                    _isAuthenticated ? Colors.green : Colors.blueGrey[800],
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget Kad Status
  Widget _buildStatusHeader(double reading, bool isDanger) {
    return Card(
      color: isDanger ? Colors.red[100] : Colors.green[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(
          isDanger ? Icons.warning_amber : Icons.check_circle_outline,
          color: isDanger ? Colors.red : Colors.green,
          size: 40,
        ),
        title: Text(
          isDanger ? 'STATUS: DANGER' : 'STATUS: NORMAL',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDanger ? Colors.red : Colors.green[900],
          ),
        ),
        subtitle: Text('Bacaan Terkini: ${reading.toStringAsFixed(1)} PPM'),
      ),
    );
  }

  // Widget Graf Masa Nyata (fl_chart)
  Widget _buildRealtimeLineChart(bool isDanger) {
    return Container(
      height: 220,
      padding: const EdgeInsets.only(right: 18, left: 10, top: 24, bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: true),
          titlesData: const FlTitlesData(
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: true),
          minY: 0,
          maxY: 100,
          lineBarsData: [
            LineChartBarData(
              spots: _gasReadings,
              isCurved: true,
              color: isDanger ? Colors.red : Colors.blue,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: isDanger
                    ? Colors.red.withOpacity(0.2)
                    : Colors.blue.withOpacity(0.2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget Shimmer Loading untuk Graf
  Widget _buildShimmerChart() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}