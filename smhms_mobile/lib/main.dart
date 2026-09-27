import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shimmer/shimmer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SMHMSApp());
}

class SMHMSApp extends StatelessWidget {
  const SMHMSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SMHMS - Bahaya & Keselamatan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E88E5),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/main': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return MainNavigationWrapper(
            username: args?['username'] ?? 'Pengguna',
            role: args?['role'] ?? 'user',
          );
        },
      },
    );
  }
}

// ==========================================
// 1. SKRIN LOG MASUK (LOGIN PAGE)
// ==========================================
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final LocalAuthentication _auth = LocalAuthentication();

  bool _isLoading = false;
  String _statusMessage = '';

  final String baseUrl = 'http://172.20.235.48:5000/api';

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _statusMessage = 'Sila masukkan nama pengguna dan kata laluan.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Sedang menyambung ke pelayan...';
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          Navigator.pushReplacementNamed(
            context,
            '/main',
            arguments: {
              'username': data['username'] ?? username,
              'role': data['role'] ?? 'user',
            },
          );
        }
      } else {
        final data = jsonDecode(response.body);
        setState(() {
          _statusMessage = data['message'] ?? 'Log masuk gagal. Semak maklumat anda.';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Gagal menyambung ke pelayan. Sila pastikan backend sedang berjalan.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _authenticateBiometric() async {
    try {
      bool canCheckBiometrics = await _auth.canCheckBiometrics;
      bool isDeviceSupported = await _auth.isDeviceSupported();

      if (canCheckBiometrics && isDeviceSupported) {
        bool authenticated = await _auth.authenticate(
          localizedReason: 'Gunakan cap jari untuk log masuk ke SMHMS',
          options: const AuthenticationOptions(biometricOnly: true),
        );

        if (authenticated && mounted) {
          Navigator.pushReplacementNamed(
            context,
            '/main',
            arguments: {
              'username': 'Pengguna Biometrik',
              'role': 'user',
            },
          );
        }
      } else {
        setState(() {
          _statusMessage = 'Biometrik tidak disokong pada peranti ini.';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Ralat Biometrik: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shield_outlined, size: 90, color: Color(0xFF1E88E5)),
                  const SizedBox(height: 16),
                  const Text(
                    'SMHMS Access Portal',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Sistem Pemantauan Bahaya & Keselamatan',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Pengguna',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Kata Laluan',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E88E5),
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Log Masuk', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  IconButton(
                    iconSize: 48,
                    icon: const Icon(Icons.fingerprint, color: Color(0xFF1E88E5)),
                    onPressed: _authenticateBiometric,
                    tooltip: 'Log Masuk Biometrik',
                  ),
                  const SizedBox(height: 16),
                  if (_statusMessage.isNotEmpty)
                    Text(
                      _statusMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _statusMessage.contains('berjaya') ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 2. NAVIGASI UTAMA (BOTTOM NAV & DRAWER)
// ==========================================
class MainNavigationWrapper extends StatefulWidget {
  final String username;
  final String role;

  const MainNavigationWrapper({
    super.key,
    required this.username,
    required this.role,
  });

  @override
  State<MainNavigationWrapper> createState() => _MainNavigationWrapperState();
}

class _MainNavigationWrapperState extends State<MainNavigationWrapper> {
  int _currentIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      DashboardPage(username: widget.username, role: widget.role),
      const AnalyticsPage(),
      const HistoryPage(),
      const SettingsPage(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: NavigationDrawer(
        onDestinationSelected: (index) {
          Navigator.pop(context); // Tutup drawer
          setState(() {
            _currentIndex = index;
          });
        },
        selectedIndex: _currentIndex,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(widget.username, style: const TextStyle(fontWeight: FontWeight.bold)),
            accountEmail: Text('Peranan: ${widget.role.toUpperCase()}'),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, color: Color(0xFF1E88E5), size: 40),
            ),
            decoration: const BoxDecoration(color: Color(0xFF1E88E5)),
          ),
          const NavigationDrawerDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: Text('Dashboard Utama'),
          ),
          const NavigationDrawerDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: Text('Analisis & Graf'),
          ),
          const NavigationDrawerDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: Text('Log Rekod Amaran'),
          ),
          const NavigationDrawerDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: Text('Tetapan Sistem'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Log Keluar', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: 'Analisis',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Sejarah',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Tetapan',
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 3. SKRIN DASHBOARD UTAMA
// ==========================================
class DashboardPage extends StatefulWidget {
  final String username;
  final String role;

  const DashboardPage({super.key, required this.username, required this.role});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  bool _isLoadingData = true;
  double _temperature = 0.0;
  double _gasLevel = 0.0;
  bool _flameDetected = false;
  Timer? _timer;

  final String baseUrl = 'http://10.0.2.2:5000/api';

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _fetchSensorData();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _fetchSensorData();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _initNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _notificationsPlugin.initialize(initSettings);
  }

  Future<void> _showHazardNotification(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'hazard_channel',
      'Amaran Bahaya',
      importance: Importance.max,
      priority: Priority.high,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);
    await _notificationsPlugin.show(0, title, body, notificationDetails);
  }

  Future<void> _fetchSensorData() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/sensor-data'))
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _temperature = (data['temperature'] ?? 28.0).toDouble();
          _gasLevel = (data['gas_level'] ?? 150.0).toDouble();
          _flameDetected = data['flame_detected'] ?? false;
          _isLoadingData = false;
        });

        if (_flameDetected || _temperature > 50.0 || _gasLevel > 400.0) {
          _showHazardNotification('AMARAN BAHAYA!', 'Sensor mengesan potensi bahaya di premis anda.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingData = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('SMHMS - ${widget.username}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/login');
            },
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchSensorData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isLoadingData)
                Shimmer.fromColors(
                  baseColor: Colors.grey[300]!,
                  highlightColor: Colors.grey[100]!,
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    color: Colors.white,
                  ),
                )
              else
                _buildStatusBanner(),

              const SizedBox(height: 20),
              const Text(
                'Status Sensor Semasa',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _buildSensorCard(
                      'Suhu',
                      '$_temperature °C',
                      Icons.thermostat,
                      _temperature > 40 ? Colors.red : Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSensorCard(
                      'Gas (MQ-2)',
                      '$_gasLevel PPM',
                      Icons.air,
                      _gasLevel > 300 ? Colors.red : Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildSensorCard(
                'Pengesan Api',
                _flameDetected ? 'API DIKESAN!' : 'Selamat',
                Icons.local_fire_department,
                _flameDetected ? Colors.red : Colors.blue,
              ),

              const SizedBox(height: 24),
              const Text(
                'Graf Suhu (24 Jam)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              SizedBox(
                height: 200,
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: true),
                    titlesData: const FlTitlesData(show: true),
                    borderData: FlBorderData(show: true),
                    lineBarsData: [
                      LineChartBarData(
                        spots: [
                          const FlSpot(0, 25),
                          const FlSpot(1, 27),
                          const FlSpot(2, 26),
                          FlSpot(3, _temperature),
                        ],
                        isCurved: true,
                        color: Colors.blue,
                        barWidth: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBanner() {
    bool isDanger = _flameDetected || _temperature > 50 || _gasLevel > 400;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDanger ? Colors.red[100] : Colors.green[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDanger ? Colors.red : Colors.green),
      ),
      child: Row(
        children: [
          Icon(
            isDanger ? Icons.warning_amber_rounded : Icons.check_circle_outline,
            color: isDanger ? Colors.red : Colors.green,
            size: 36,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isDanger ? 'AMARAN BAHAYA!' : 'Sistem Dalam Keadaan Selamat',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDanger ? Colors.red[900] : Colors.green[900],
                  ),
                ),
                Text(
                  isDanger
                      ? 'Tindakan segera diperlukan di premis.'
                      : 'Semua bacaan sensor berada pada paras normal.',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, size: 36, color: color),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 4. SKRIN ANALISIS & GRAF (ANALYTICS)
// ==========================================
class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analisis & Trend Sensor')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            const Text(
              'Trend Bacaan Gas (MQ-2)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: const [
                        FlSpot(0, 120),
                        FlSpot(1, 140),
                        FlSpot(2, 135),
                        FlSpot(3, 160),
                        FlSpot(4, 150),
                      ],
                      isCurved: true,
                      color: Colors.green,
                      barWidth: 3,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Taburan Ringkasan Bahaya',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Card(
              child: ListTile(
                leading: Icon(Icons.warning, color: Colors.amber),
                title: Text('Amaran Suhu Tinggi'),
                trailing: Text('3 kali minggu ini'),
              ),
            ),
            const Card(
              child: ListTile(
                leading: Icon(Icons.local_fire_department, color: Colors.red),
                title: Text('Pemicuan Pengesan Api'),
                trailing: Text('0 kali'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 5. SKRIN SEJARAH & REKOD LOG (HISTORY)
// ==========================================
class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> logs = [
      {
        'title': 'Sistem Normal',
        'desc': 'Semua sensor berjalan dengan baik.',
        'time': 'Hari ini, 10:30 AM',
        'type': 'info'
      },
      {
        'title': 'Amaran Kebocoran Gas',
        'desc': 'Gas MQ-2 melebihi paras 350 PPM.',
        'time': 'Semalam, 04:15 PM',
        'type': 'warning'
      },
      {
        'title': 'Log Masuk Biometrik',
        'desc': 'Pengguna log masuk melalui cap jari.',
        'time': '25 Sep, 08:00 AM',
        'type': 'info'
      },
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Sejarah Log Amaran')),
      body: ListView.builder(
        itemCount: logs.length,
        itemBuilder: (context, index) {
          final log = logs[index];
          bool isWarning = log['type'] == 'warning';
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: ListTile(
              leading: Icon(
                isWarning ? Icons.warning : Icons.info,
                color: isWarning ? Colors.red : Colors.blue,
              ),
              title: Text(log['title']!, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${log['desc']}\n${log['time']}'),
              isThreeLine: true,
            ),
          );
        },
      ),
    );
  }
}

// ==========================================
// 6. SKRIN TETAPAN (SETTINGS)
// ==========================================
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _enableNotifications = true;
  bool _enableBiometrics = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tetapan Sistem')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Notifikasi Pop-up Amaran'),
            subtitle: const Text('Terima notifikasi serta-merta apabila bahaya dikesan'),
            value: _enableNotifications,
            onChanged: (val) {
              setState(() {
                _enableNotifications = val;
              });
            },
          ),
          SwitchListTile(
            title: const Text('Pengesahan Biometrik'),
            subtitle: const Text('Benarkan log masuk menggunakan cap jari'),
            value: _enableBiometrics,
            onChanged: (val) {
              setState(() {
                _enableBiometrics = val;
              });
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Versi Aplikasi'),
            subtitle: const Text('SMHMS v1.0.0 (FYP Project)'),
          ),
        ],
      ),
    );
  }
}