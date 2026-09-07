import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_service.dart';
import 'vpn_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RyzerApp());
}

class RyzerApp extends StatelessWidget {
  const RyzerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RyzerDNS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A10),
        fontFamily: 'Vazirmatn',
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  bool _isLoggedIn = false;
  String? _token;
  String _username = 'کاربر گرامی';
  String _planExpires = 'در حال بررسی...';
  bool _isExpired = false;

  bool _isConnected = false;
  bool _isLoading = false;
  int _pingMs = 45;

  String _primaryDns = '87.248.145.40';
  String _secondaryDns = '46.8.102.223';

  late AnimationController _pulseController;

  final _userController = TextEditingController();
  final _passController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _initApp();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _initApp() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('auth_token');
    final savedUser = prefs.getString('saved_username');

    if (savedToken != null && savedToken.isNotEmpty) {
      setState(() {
        _isLoggedIn = true;
        _token = savedToken;
        _username = savedUser ?? 'کاربر گرامی';
      });
      _refreshProfile();
    }

    final config = await ApiService.getRemoteConfig();
    setState(() {
      _primaryDns = config['primary_dns'] ?? _primaryDns;
      _secondaryDns = config['secondary_dns'] ?? _secondaryDns;
    });

    _refreshPing();
  }

  Future<void> _refreshProfile() async {
    if (_token == null) return;
    final res = await ApiService.getProfile(_token!);
    if (res['success'] == true && res['data'] != null) {
      final data = res['data'];
      final days = data['days_left'] ?? 0;
      final isExp = data['is_expired'] == true || days <= 0;

      setState(() {
        _isExpired = isExp;
        _planExpires = isExp ? 'اشتراک منقضی شده' : '$days روز باقیمانده';
        _username = data['username'] ?? _username;
      });
    }
  }

  Future<void> _refreshPing() async {
    final p = await VpnManager.measurePing(_primaryDns);
    if (p != null && mounted) {
      setState(() => _pingMs = p);
    }
  }

  Future<void> _handleLogin() async {
    final u = _userController.text.trim();
    final p = _passController.text;
    if (u.isEmpty || p.isEmpty) {
      _showModal('خطای ورودی', 'لطفاً نام کاربری و رمز عبور را وارد فرمایید.');
      return;
    }

    setState(() => _isLoading = true);
    final res = await ApiService.login(u, p);
    setState(() => _isLoading = false);

    if (res['success'] == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', res['token']);
      await prefs.setString('saved_username', u);

      setState(() {
        _isLoggedIn = true;
        _token = res['token'];
        _username = u;
      });
      _refreshProfile();
    } else {
      _showModal('خطای ورود', res['message'] ?? 'ورود ناموفق بود.');
    }
  }

  Future<void> _handleLogout() async {
    if (_isConnected) {
      await VpnManager.stopVpn();
      setState(() => _isConnected = false);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    setState(() {
      _isLoggedIn = false;
      _token = null;
    });
  }

  Future<void> _toggleConnect() async {
    if (_isExpired) {
      _showModal(
        'پایان اشتراک',
        'اشتراک RyzerDNS شما به پایان رسیده است. جهت تمدید اشتراک و دسترسی به شبکه به وب‌سایت مراجعه نمایید.',
        actionText: 'ورود به وب‌سایت',
        onAction: () => launchUrl(Uri.parse('https://ryzerdns.ir/panel'), mode: LaunchMode.externalApplication),
      );
      return;
    }

    setState(() => _isLoading = true);

    if (!_isConnected) {
      if (_token != null) {
        await ApiService.registerIp(_token!);
      }
      final ok = await VpnManager.startVpn(primaryDns: _primaryDns, secondaryDns: _secondaryDns);
      setState(() {
        _isConnected = ok;
        _isLoading = false;
      });
      _refreshPing();
    } else {
      await VpnManager.stopVpn();
      setState(() {
        _isConnected = false;
        _isLoading = false;
      });
      _refreshPing();
    }
  }

  void _showModal(String title, String message, {String? actionText, VoidCallback? onAction}) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF10101C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF222235), width: 1.2),
          ),
          title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          content: Text(message, style: const TextStyle(color: Color(0xFF8E8EA8), fontSize: 12.5, height: 1.6)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('بستن', style: TextStyle(color: Color(0xFF8E8EA8))),
            ),
            if (actionText != null && onAction != null)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF3B5C),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  onAction();
                },
                child: Text(actionText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }

  void _showAbout() {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF0E0E18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF222235), width: 1),
          ),
          title: const Center(
            child: Text('درباره رایزر دی‌ان‌اس', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('نسخه 1.0.0', style: TextStyle(color: Color(0xFFFF3B5C), fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text(
                'سامانه هوشمند Ryzer DNS جهت بهینه‌سازی مسیرهای شبکه، کاهش پینگ و دسترسی پایدار به بازی‌ها و سرویس‌های بین‌المللی.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF8E8EA8), fontSize: 11.5, height: 1.6),
              ),
              const SizedBox(height: 16),
              _buildLinkCard('وب‌سایت رسمی', 'ryzerdns.ir', 'https://ryzerdns.ir'),
              _buildLinkCard('کانال تلگرام', '@RyzerDns', 'https://t.me/ryzerdns'),
              _buildLinkCard('ربات تلگرام', '@RyzerDnsBot', 'https://t.me/ryzerdnsbot'),
            ],
          ),
          actions: [
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('بستن', style: TextStyle(color: Color(0xFF8E8EA8))),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildLinkCard(String title, String subtitle, String url) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        borderRadius: BorderRadius.circular(10),
        splashColor: const Color(0x33FF3B5C),
        highlightColor: const Color(0x22FF3B5C),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: const Color(0xFF141422),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF26263A)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFFFF3B5C),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Column(
              children: [
                // 1. Header with Official Syne Logotype
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.info_outline, color: Color(0xFF8E8EA8), size: 22),
                          onPressed: _showAbout,
                        ),
                        if (_isLoggedIn)
                          IconButton(
                            icon: const Icon(Icons.logout, color: Color(0xFFFF3B5C), size: 20),
                            onPressed: _handleLogout,
                          ),
                      ],
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        RichText(
                          text: const TextSpan(
                            style: TextStyle(
                              fontFamily: 'Syne',
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              height: 1.0,
                            ),
                            children: [
                              TextSpan(text: 'RYZER', style: TextStyle(color: Colors.white)),
                              TextSpan(text: 'DNS', style: TextStyle(color: Color(0xFFFF3B5C))),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Image.asset(
                          'assets/nav-logo.png',
                          width: 38,
                          height: 38,
                          fit: BoxFit.contain,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // 2. Main Content (Login or Dashboard)
                Expanded(
                  child: _isLoggedIn ? _buildDashboard() : _buildLoginCard(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginCard() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFF10101C),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF222235)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('ورود به حساب کاربری', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 18),
            TextField(
              controller: _userController,
              decoration: InputDecoration(
                hintText: 'نام کاربری یا ایمیل',
                hintStyle: const TextStyle(color: Color(0xFF55556B), fontSize: 12),
                filled: true,
                fillColor: const Color(0xFF141424),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passController,
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'کلمه عبور',
                hintStyle: const TextStyle(color: Color(0xFF55556B), fontSize: 12),
                filled: true,
                fillColor: const Color(0xFF141424),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF3B5C),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isLoading ? null : _handleLogin,
                child: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('ورود', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5)),
              ),
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: () => launchUrl(Uri.parse('https://ryzerdns.ir/panel'), mode: LaunchMode.externalApplication),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text('حساب کاربری ندارید؟ ', style: TextStyle(color: Color(0xFF8E8EA8), fontSize: 11.5)),
                    Text('ثبت‌نام در وب‌سایت', style: TextStyle(color: Color(0xFFFF3B5C), fontSize: 11.5, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Top Profile Glass Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF12121E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF222235)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _planExpires,
                style: TextStyle(
                  color: _isExpired ? const Color(0xFFFF3B5C) : const Color(0xFF00E676),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  Text(_username, style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0x26FF3B5C),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFFF3B5C)),
                    ),
                    child: const Text('PRO', style: TextStyle(color: Color(0xFFFF3B5C), fontSize: 10, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Center Power Button
        Column(
          children: [
            GestureDetector(
              onTap: _isLoading ? null : _toggleConnect,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final glowColor = _isConnected ? const Color(0xFF00E676) : const Color(0xFFFF3B5C);
                  return Container(
                    width: 154,
                    height: 154,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF10101C),
                      border: Border.all(color: glowColor, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: glowColor.withOpacity(_isConnected ? 0.35 + (_pulseController.value * 0.15) : 0.25),
                          blurRadius: 28,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.power_settings_new,
                            color: glowColor,
                            size: 42,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _isConnected ? 'قطع اتصال' : 'اتصال',
                            style: TextStyle(color: glowColor, fontSize: 13.5, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isConnected ? 'اتصال ایمن برقرار است' : 'آماده اتصال',
              style: const TextStyle(color: Color(0xFF8E8EA8), fontSize: 12),
            ),
          ],
        ),

        // Bottom Ping and Footer
        Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF12121E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF222235)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        '$_pingMs ms',
                        style: const TextStyle(
                          color: Color(0xFF00E676),
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () async {
                            setState(() => _pingMs = 0);
                            await _refreshPing();
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.refresh, color: Color(0xFF8E8EA8), size: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Text('تاخیر سرور (Ping)', style: TextStyle(color: Color(0xFF8E8EA8), fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildFooterLink('وب‌سایت', 'https://ryzerdns.ir'),
                const Text('  •  ', style: TextStyle(color: Color(0xFF33334A))),
                _buildFooterLink('کانال تلگرام', 'https://t.me/ryzerdns'),
                const Text('  •  ', style: TextStyle(color: Color(0xFF33334A))),
                _buildFooterLink('پشتیبانی', 'https://t.me/ryzerdnsbot'),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFooterLink(String label, String url) {
    return InkWell(
      onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: Text(label, style: const TextStyle(color: Color(0xFF7A7A95), fontSize: 11.5, fontWeight: FontWeight.w600)),
    );
  }
}
