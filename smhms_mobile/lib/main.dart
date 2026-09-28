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

  final String baseUrl = 'https://tamper-neon-stays.ngrok-free.dev/api';

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
      if (mounted) {
        setState(() {
          _statusMessage = 'Gagal menyambung ke pelayan. Sila pastikan backend sedang berjalan.';
        });
      }
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
      ProfilePage(username: widget.username, role: widget.role),
      const SettingsPage(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: NavigationDrawer(
        onDestinationSelected: (index) {
          Navigator.pop(context);
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
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: Text('Profil Pengguna'),
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
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
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
// 3. SKRIN DASHBOARD UTAMA (PARAS AIR & GRAF AIR)
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
  double _waterLevel = 0.0;
  double _gasLevel = 0.0;
  bool _flameDetected = false;
  String _statusHazard = 'NORMAL';

  final List<FlSpot> _waterReadings = [];
  int _timeStep = 0;
  Timer? _timer;

  final String baseUrl = 'https://tamper-neon-stays.ngrok-free.dev/api';

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _fetchSensorData();
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
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
          .get(Uri.parse('$baseUrl/sensor?api_key=SMHMS_SECRET_API_KEY_2026'))
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['status'] == 'success' && mounted) {
          final data = result['data'];
          double newWaterLevel = (data['water_level'] ?? 0.0).toDouble();
          double newGasLevel = (data['gas_level'] ?? 0.0).toDouble();
          bool newFlame = (data['fire_detected'] == 1);
          String newHazard = data['status_hazard'] ?? 'NORMAL';

          setState(() {
            _waterLevel = newWaterLevel;
            _gasLevel = newGasLevel;
            _flameDetected = newFlame;
            _statusHazard = newHazard;
            _isLoadingData = false;

            _timeStep++;
            _waterReadings.add(FlSpot(_timeStep.toDouble(), _waterLevel));
            if (_waterReadings.length > 10) {
              _waterReadings.removeAt(0);
            }
          });

          if (_statusHazard == 'DANGER' || _flameDetected) {
            _showHazardNotification('AMARAN BAHAYA!', 'Sistem SMHMS mengesan bahaya aktif di premis.');
          }
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
                      'Paras Jarak Air',
                      '$_waterLevel cm',
                      Icons.water,
                      _waterLevel <= 10.0 ? Colors.red : Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSensorCard(
                      'Gas / Asap',
                      '$_gasLevel PPM',
                      Icons.air,
                      _gasLevel > 2500 ? Colors.red : Colors.green,
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
                'Graf Paras Air Masa Nyata (cm)',
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
                        spots: _waterReadings.isEmpty
                            ? [const FlSpot(0, 0)]
                            : _waterReadings,
                        isCurved: true,
                        color: Colors.blue,
                        barWidth: 4,
                        dotData: const FlDotData(show: true),
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
    bool isDanger = _statusHazard == 'DANGER' || _flameDetected;
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
              'Ringkasan Amaran System',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Card(
              child: ListTile(
                leading: Icon(Icons.water_damage, color: Colors.blue),
                title: Text('Amaran Paras Air'),
                trailing: Text('Aktif'),
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
// 5. SKRIN SEJARAH & REKOD LOG (HISTORY DINAMIK)
// ==========================================
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final String baseUrl = 'https://tamper-neon-stays.ngrok-free.dev/api';
  List<dynamic> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/sensor-logs'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _logs = data['logs'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sejarah Log Amaran')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? const Center(child: Text('Tiada rekod amaran dijumpai.'))
              : RefreshIndicator(
                  onRefresh: _fetchLogs,
                  child: ListView.builder(
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      final log = _logs[index];
                      bool isDanger = log['status_hazard'] == 'DANGER';
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: ListTile(
                          leading: Icon(
                            isDanger ? Icons.warning : Icons.info,
                            color: isDanger ? Colors.red : Colors.blue,
                          ),
                          title: Text('Status: ${log['status_hazard']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Jarak: ${log['water_level']} cm | Gas: ${log['gas_level']} PPM\nMasa: ${log['created_at'] ?? 'Baru Sahaja'}'),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

// ==========================================
// 6. SKRIN PROFIL PENGGUNA (PROFILE PAGE)
// ==========================================
class ProfilePage extends StatelessWidget {
  final String username;
  final String role;

  const ProfilePage({super.key, required this.username, required this.role});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil Pentadbir')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 50,
              backgroundColor: Color(0xFF1E88E5),
              child: Icon(Icons.person, size: 60, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text(
              username,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text(
              'Peranan: ${role.toUpperCase()}',
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 32),
            Card(
              child: ListTile(
                leading: const Icon(Icons.shield),
                title: const Text('Akses Sistem'),
                subtitle: Text(role == 'admin' ? 'Akses Penuh Pentadbir' : 'Akses Pemantauan'),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.verified_user),
                title: const Text('Status Akaun'),
                subtitle: const Text('Aktif & Disahkan'),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/login');
                },
                icon: const Icon(Icons.logout),
                label: const Text('Log Keluar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 7. SKRIN TETAPAN (SETTINGS)
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
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Versi Aplikasi'),
            subtitle: Text('SMHMS v1.0.0 (FYP Project)'),
          ),
        ],
      ),
    );
  }
}