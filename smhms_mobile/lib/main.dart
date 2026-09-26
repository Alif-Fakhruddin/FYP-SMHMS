import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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
  
  // Data Masa Nyata untuk Graf (Senarai FlSpot)
  final List<FlSpot> _gasReadings = [];
  int _timeStep = 0;
  Timer? _dataTimer;

  @override
  void initState() {
    super.initState();
    _initNotifications();

    // Simulasi kemasukan data sensor dari Flask/Firebase setiap 2 saat
    _dataTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _fetchRealtimeData();
    });

    // Hentikan loading Shimmer selepas 3 saat
    Future.delayed(const Duration(seconds: 3), () {
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

  // 1. Inisialisasi Notifikasi
  Future<void> _initNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings settings =
        InitializationSettings(android: androidSettings);
    await _notificationsPlugin.initialize(settings);
  }

  // Hantar Notifikasi Bahaya
  Future<void> _triggerDangerAlert(double value) async {
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
  }

  // 2. Simulasi/Pengambilan Data Sensor Masa Nyata
  void _fetchRealtimeData() {
    // Nota: Di sini anda boleh menggantikan titik ini dengan pembacaan API HTTP dari Flask/Firebase
    double newReading = Random().nextDouble() * 100; // Penjanaan nilai rawak (0 - 100)

    if (mounted) {
      setState(() {
        _timeStep++;
        _gasReadings.add(FlSpot(_timeStep.toDouble(), newReading));

        // Simpan 10 bacaan terkini sahaja di graf supaya tidak padat
        if (_gasReadings.length > 10) {
          _gasReadings.removeAt(0);
        }
      });
    }

    // Pemicu notifikasi jika bacaan melebihi 75 PPM (DANGER)
    if (newReading > 75) {
      _triggerDangerAlert(newReading);
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
    bool isDanger = currentReading > 75;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SMHMS Real-Time Portal'),
        backgroundColor: isDanger ? Colors.red : Colors.blueGrey[900],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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