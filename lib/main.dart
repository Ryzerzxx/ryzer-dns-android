import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_service.dart';
import 'vpn_manager.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0A0A10),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
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
        scaffoldBackgroundColor: const Color(0xFF060608),
        fontFamily: 'Vazirmatn',
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF3B5C),
          surface: Color(0xFF0E0E14),
        ),
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
  bool _isConnected = false;
  bool _isConnecting = false;
  int? _pingMs;
  bool _isMeasuringPing = false;
  String? _userToken;
  Map<String, dynamic>? _userData;
  Timer? _statusTimer;
  Timer? _pingTimer;
  late AnimationController _pulseController;
  int _currentNavIndex = 0; // 0: Home, 1: Plans, 2: Settings

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _loadStoredSession();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _pingTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadStoredSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('ryzer_user_token');
    if (token != null && token.isNotEmpty) {
      setState(() => _userToken = token);
      await _refreshUserProfile();
    }
    _refreshPing();
    _pingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_isConnected) _refreshPing();
    });
  }

  Future<void> _refreshUserProfile() async {
    if (_userToken == null) return;
    final res = await ApiService.getProfile(_userToken!);
    if (res['success'] == true && res['data'] != null) {
      if (mounted) {
        setState(() => _userData = res['data']);
      }
    }
  }

  Future<void> _refreshPing() async {
    if (_isMeasuringPing) return;
    setState(() => _isMeasuringPing = true);
    final ping = await VpnManager.measurePing('87.248.145.40');
    if (mounted) {
      setState(() {
        _pingMs = ping;
        _isMeasuringPing = false;
      });
    }
  }

  Future<void> _toggleConnection() async {
    if (_userToken == null) {
      _showAuthModal();
      return;
    }

    if (_isConnecting) return;

    if (_isConnected) {
      setState(() => _isConnecting = true);
      await VpnManager.stopVpn();
      setState(() {
        _isConnected = false;
        _isConnecting = false;
      });
      _showToast('ارتباط با RyzerDNS قطع شد.');
    } else {
      setState(() => _isConnecting = true);
      final registered = await ApiService.registerIp(_userToken!);
      if (!registered) {
        setState(() => _isConnecting = false);
        _showToast('ثبت آی‌پی با خطا مواجه شد. اشتراک خود را بررسی نمایید.');
        return;
      }

      final success = await VpnManager.startVpn(
        primaryDns: '87.248.145.40',
        secondaryDns: '46.8.102.223',
      );

      setState(() {
        _isConnected = success;
        _isConnecting = false;
      });

      if (success) {
        _showToast('سرویس هوشمند RyzerDNS متصل شد.');
        _refreshPing();
      } else {
        _showToast('اجازه اتصال VPN در سیستم تایید نشد.');
      }
    }
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF14141E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFFFF3B5C), width: 0.8),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 🔐 AUTH MODAL (Login, Register with OTP, Google Auth)
  // ══════════════════════════════════════════════════════════════════════════
  void _showAuthModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const AuthModalSheet(),
    ).then((_) => _loadStoredSession());
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 📱 BUILD UI
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: IndexedStack(
                  index: _currentNavIndex,
                  children: [
                    _buildHomeTab(),
                    _buildPlansTab(),
                    _buildSettingsTab(),
                  ],
                ),
              ),
              _buildBottomNav(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x1AFFFFFF))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Image.asset('assets/nav-logo.png', height: 32, fit: BoxFit.contain),
              const SizedBox(width: 8),
              RichText(
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: 'RYZER',
                      style: TextStyle(fontFamily: 'Syne', fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
                    ),
                    TextSpan(
                      text: 'DNS',
                      style: TextStyle(fontFamily: 'Syne', fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFFFF3B5C), letterSpacing: -0.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_userToken != null && _userData != null)
            InkWell(
              onTap: () => setState(() => _currentNavIndex = 2),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0x14FF3B5C),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0x4DFF3B5C)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person, size: 14, color: Color(0xFFFF3B5C)),
                    const SizedBox(width: 6),
                    Text(
                      _userData!['display_name'] ?? _userData!['username'] ?? 'حساب من',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ],
                ),
              ),
            )
          else
            ElevatedButton(
              onTap: _showAuthModal,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF3B5C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: const Text('ورود / ثبت‌نام', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ⚡️ TAB 1: HOME & CONNECT
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildHomeTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          _buildSubscriptionCard(),
          const SizedBox(height: 36),
          _buildPowerButton(),
          const SizedBox(height: 36),
          _buildPingAndStatusRow(),
          const SizedBox(height: 24),
          _buildQuickActionsRow(),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard() {
    if (_userToken == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF0E0E14),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x1AFFFFFF)),
        ),
        child: Column(
          children: [
            const Text(
              'جهت استفاده از خدمات هوشمند، وارد حساب خود شوید.',
              style: TextStyle(fontSize: 13, color: Color(0xFFA0A0B0)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onTap: _showAuthModal,
              icon: const Icon(Icons.login, size: 16, color: Color(0xFFFF3B5C)),
              label: const Text('ورود سریع یا ایجاد حساب', style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFFF3B5C)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      );
    }

    final tier = (_userData?['plan_tier'] ?? 'PRO').toString().toUpperCase();
    final remaining = _userData?['remaining_text'] ?? 'در حال بررسی...';
    final isExpired = _userData?['is_expired'] == true;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isExpired ? const Color(0x4DFF3B5C) : const Color(0x3300E676)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isExpired ? const Color(0x1AFF3B5C) : const Color(0x1A00E676),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isExpired ? const Color(0xFFFF3B5C) : const Color(0xFF00E676)),
                    ),
                    child: Text(
                      'پلن $tier',
                      style: TextStyle(
                        fontFamily: 'Syne',
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isExpired ? const Color(0xFFFF3B5C) : const Color(0xFF00E676),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isExpired ? 'اشتراک به اتمام رسیده' : 'سرویس فعال',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                remaining,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isExpired ? const Color(0xFFFF3B5C) : const Color(0xFFA0A0B0),
                ),
              ),
            ],
          ),
          ElevatedButton(
            onTap: () => setState(() => _currentNavIndex = 1),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0x1AFF3B5C),
              foregroundColor: const Color(0xFFFF3B5C),
              side: const BorderSide(color: Color(0xFFFF3B5C)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Text('تمدید / ارتقا', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildPowerButton() {
    return GestureDetector(
      onTap: _toggleConnection,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (ctx, child) {
          final glow = _isConnected ? (_pulseController.value * 15 + 15) : 0.0;
          return Container(
            width: 170,
            height: 170,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isConnected ? const Color(0xFF0A1410) : const Color(0xFF140A0D),
              border: Border.all(
                color: _isConnected ? const Color(0xFF00E676) : const Color(0xFFFF3B5C),
                width: 3.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: _isConnected ? const Color(0x6600E676) : const Color(0x33FF3B5C),
                  blurRadius: glow + 10,
                  spreadRadius: glow / 3,
                ),
              ],
            ),
            child: Center(
              child: _isConnecting
                  ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.power_settings_new_rounded,
                          size: 58,
                          color: _isConnected ? const Color(0xFF00E676) : const Color(0xFFFF3B5C),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _isConnected ? 'متصل' : 'اتصال',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: _isConnected ? const Color(0xFF00E676) : Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPingAndStatusRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x1AFFFFFF)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt, color: Color(0xFF00E676), size: 18),
              const SizedBox(width: 6),
              Text(
                _pingMs != null ? '$_pingMs ms' : 'سنجش...',
                style: const TextStyle(fontFamily: 'Syne', fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF00E676)),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: _refreshPing,
                child: const Icon(Icons.refresh, size: 16, color: Color(0xFFA0A0B0)),
              ),
            ],
          ),
          Container(width: 1, height: 24, color: const Color(0x1AFFFFFF)),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isConnected ? const Color(0xFF00E676) : const Color(0xFFFF3B5C),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _isConnected ? 'مسیر اختصاصی گیم' : 'سرویس غیرفعال',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            icon: Icons.speed,
            title: 'خرید اشتراک',
            subtitle: 'پلن Pro و Plus',
            onTap: () => setState(() => _currentNavIndex = 1),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            icon: Icons.tune,
            title: 'تنظیمات حساب',
            subtitle: 'تغییر رمز و مشخصات',
            onTap: () => setState(() => _currentNavIndex = 2),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0E0E14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x1AFFFFFF)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFFFF3B5C), size: 22),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFFA0A0B0))),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 💎 TAB 2: PLANS & IN-APP PURCHASE
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildPlansTab() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        const Text(
          'پلن‌های تجاری و اشتراک RyzerDNS',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
        ),
        const SizedBox(height: 4),
        const Text(
          'کاهش پینگ، رفع تحریم بازی‌ها و حذف پکت‌لاس با گیت‌وی مستقیم',
          style: TextStyle(fontSize: 12, color: Color(0xFFA0A0B0)),
        ),
        const SizedBox(height: 20),
        _buildPlanCard(
          tier: 'pro',
          title: 'پلن PRO (ویژه گیمینگ و تحریم‌شکن)',
          features: [
            'تونل پرسرعت اختصاصی US Yamux',
            'پشتیبانی کامل FC 26, Valorant, Warzone, The Finals',
            'ترافیک نامحدود و اولویت ۱۰۰٪ سرورها',
            'تک کاربره همزمان (ثبت آی‌پی هوشمند)',
          ],
          price1m: '۱۴۹,۰۰۰ تومان',
          price3m: '۴۴۷,۰۰۰ تومان',
          isPro: true,
        ),
        const SizedBox(height: 18),
        _buildPlanCard(
          tier: 'plus',
          title: 'پلن PLUS (اقتصادی)',
          features: [
            'رفع تحریم وب‌سایت‌ها و استورها',
            'پینگ بهینه با سرورهای اشتراکی',
            'پشتیبانی لانچرهای استیم و اپیک',
          ],
          price1m: '۸۹,۰۰۰ تومان',
          price3m: '۲۶۷,۰۰۰ تومان',
          isPro: false,
        ),
      ],
    );
  }

  Widget _buildPlanCard({
    required String tier,
    required String title,
    required List<String> features,
    required String price1m,
    required String price3m,
    required bool isPro,
  }) {
    final borderColor = isPro ? const Color(0xFFFF3B5C) : const Color(0x33FFFFFF);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: isPro ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: Colors.white)),
              if (isPro)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B5C),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('پیشنهادی', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
            ],
          ),
          const SizedBox(height: 14),
          ...features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, size: 14, color: Color(0xFF00E676)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(f, style: const TextStyle(fontSize: 12, color: Color(0xFFD0D0E0)))),
                  ],
                ),
              )),
          const Divider(color: Color(0x1AFFFFFF), height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onTap: () => _handlePurchasePlan(tier, 1, price1m),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0x4DFFFFFF)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: Column(
                    children: [
                      const Text('۱ ماهه', style: TextStyle(fontSize: 11, color: Color(0xFFA0A0B0))),
                      const SizedBox(height: 2),
                      Text(price1m, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onTap: () => _handlePurchasePlan(tier, 3, price3m),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPro ? const Color(0xFFFF3B5C) : const Color(0x33FFFFFF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    elevation: 0,
                  ),
                  child: Column(
                    children: [
                      const Text('۳ ماهه', style: TextStyle(fontSize: 11, color: Colors.white70)),
                      const SizedBox(height: 2),
                      Text(price3m, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handlePurchasePlan(String tier, int months, String priceText) async {
    if (_userToken == null) {
      _showAuthModal();
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF0E0E14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0x33FFFFFF)),
          ),
          title: const Text('تایید پیش‌فاکتور خرید', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('پلن انتخابی: ${tier.toUpperCase()} ($months ماهه)', style: const TextStyle(fontSize: 13, color: Colors.white70)),
              const SizedBox(height: 6),
              Text('مبلغ اشتراک: $priceText', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF00E676))),
              const SizedBox(height: 12),
              const Text(
                'پس از تایید، به درگاه شاپرک زرین‌پال منتقل خواهید شد و اشتراک فوراً فعال می‌گردد.',
                style: TextStyle(fontSize: 11.5, color: Color(0xFFA0A0B0), height: 1.6),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('انصراف', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF3B5C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('انتقال به درگاه پرداخت'),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    _showToast('در حال صدور فاکتور و اتصال به درگاه...');
    final res = await ApiService.requestPayment(
      token: _userToken!,
      planTier: tier,
      durationMonths: months,
    );

    if (res['success'] == true && res['payment_url'] != null) {
      final url = Uri.parse(res['payment_url']);
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      _showToast(res['message'] ?? 'خطا در ایجاد درگاه پرداخت.');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ⚙️ TAB 3: ACCOUNT & SETTINGS
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildSettingsTab() {
    if (_userToken == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 48, color: Color(0xFFA0A0B0)),
            const SizedBox(height: 12),
            const Text('ابتدا وارد حساب کاربری خود شوید.', style: TextStyle(fontSize: 14, color: Colors.white70)),
            const SizedBox(height: 14),
            ElevatedButton(
              onTap: _showAuthModal,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF3B5C)),
              child: const Text('ورود به حساب'),
            ),
          ],
        ),
      );
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        const Text('مشخصات حساب کاربری', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
        const SizedBox(height: 14),
        _buildSettingsItem(
          icon: Icons.person_outline,
          title: 'نام کاربری',
          value: _userData?['username'] ?? '...',
          onTap: () => _showEditProfileDialog(target: 'username'),
        ),
        _buildSettingsItem(
          icon: Icons.email_outlined,
          title: 'آدرس ایمیل',
          value: _userData?['email'] ?? 'ثبت نشده',
          onTap: () => _showEditProfileDialog(target: 'email'),
        ),
        _buildSettingsItem(
          icon: Icons.vpn_key_outlined,
          title: 'رمز عبور',
          value: 'تغییر رمز حساب',
          onTap: () => _showEditProfileDialog(target: 'password'),
        ),
        _buildSettingsItem(
          icon: Icons.card_giftcard,
          title: 'کد رفرال شما',
          value: _userData?['referral_code'] ?? '...',
          onTap: () {
            final code = _userData?['referral_code'] ?? '';
            if (code.isNotEmpty) {
              Clipboard.setData(ClipboardData(text: code));
              _showToast('کد رفرال کپی شد: $code');
            }
          },
        ),
        const SizedBox(height: 24),
        const Text('عملیات حساب', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white70)),
        const SizedBox(height: 10),
        ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          tileColor: const Color(0xFF0E0E14),
          leading: const Icon(Icons.logout, color: Color(0xFFFF3B5C)),
          title: const Text('خروج از حساب کاربری', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFFF3B5C))),
          onTap: _handleLogout,
        ),
      ],
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x1AFFFFFF)),
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFFFF3B5C), size: 20),
        title: Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFFA0A0B0))),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_forward_ios, size: 12, color: Color(0x66FFFFFF)),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  void _showEditProfileDialog({required String target}) {
    final textController = TextEditingController();
    final otpController = TextEditingController();
    String? challengeId;
    bool otpSent = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: const Color(0xFF0E0E14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0x33FFFFFF)),
              ),
              title: Text(
                target == 'username' ? 'تغییر نام کاربری' : (target == 'email' ? 'تغییر آدرس ایمیل' : 'تنظیم رمز عبور جدید'),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!otpSent) ...[
                    TextField(
                      controller: textController,
                      obscureText: target == 'password',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: target == 'username' ? 'نام کاربری جدید' : (target == 'email' ? 'ایمیل جدید' : 'رمز عبور حداقل ۸ کاراکتر'),
                        hintStyle: const TextStyle(color: Color(0x66FFFFFF), fontSize: 12),
                        filled: true,
                        fillColor: const Color(0xFF14141E),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      ),
                    ),
                  ] else ...[
                    const Text('کد تایید ۶ رقمی ارسال شده را وارد فرمایید:', style: TextStyle(fontSize: 12, color: Color(0xFFA0A0B0))),
                    const SizedBox(height: 10),
                    TextField(
                      controller: otpController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontFamily: 'Syne', fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 4, color: Colors.white),
                      decoration: InputDecoration(
                        hintText: '123456',
                        filled: true,
                        fillColor: const Color(0xFF14141E),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('انصراف', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!otpSent) {
                      final val = textController.text.trim();
                      if (val.isEmpty) return;
                      final res = await ApiService.requestProfileChange(
                        token: _userToken!,
                        newUsername: target == 'username' ? val : null,
                        newEmail: target == 'email' ? val : null,
                        newPassword: target == 'password' ? val : null,
                      );
                      if (res['success'] == true) {
                        if (res['direct'] == true) {
                          Navigator.pop(ctx);
                          _showToast('نام کاربری با موفقیت به‌روز شد.');
                          _refreshUserProfile();
                        } else {
                          setDialogState(() {
                            otpSent = true;
                            challengeId = res['challenge_id'];
                          });
                          _showToast('کد تایید به ایمیل شما ارسال شد.');
                        }
                      } else {
                        _showToast(res['message'] ?? 'خطا در ثبت درخواست.');
                      }
                    } else {
                      final otp = otpController.text.trim();
                      if (otp.length < 6 || challengeId == null) return;
                      final res = await ApiService.confirmProfileChange(
                        token: _userToken!,
                        challengeId: challengeId!,
                        otp: otp,
                      );
                      if (res['success'] == true) {
                        Navigator.pop(ctx);
                        _showToast('اطلاعات با موفقیت به‌روزرسانی شد.');
                        _refreshUserProfile();
                      } else {
                        _showToast(res['message'] ?? 'کد تایید اشتباه است.');
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF3B5C)),
                  child: Text(otpSent ? 'تایید نهایی' : 'ارسال کد تایید'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('ryzer_user_token');
    await VpnManager.stopVpn();
    setState(() {
      _userToken = null;
      _userData = null;
      _isConnected = false;
      _currentNavIndex = 0;
    });
    _showToast('از حساب کاربری خارج شدید.');
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A10),
        border: Border(top: BorderSide(color: Color(0x1AFFFFFF))),
      ),
      child: BottomNavigationBar(
        currentIndex: _currentNavIndex,
        onTap: (idx) => setState(() => _currentNavIndex = idx),
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: const Color(0xFFFF3B5C),
        unselectedItemColor: const Color(0x66FFFFFF),
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.bolt), label: 'اتصال'),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_bag_outlined), label: 'پلن‌ها'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: 'تنظیمات'),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 🔐 AUTH MODAL SHEET (Tabs: Login, Register with OTP, Google Auth)
// ══════════════════════════════════════════════════════════════════════════════
class AuthModalSheet extends StatefulWidget {
  const AuthModalSheet({super.key});

  @override
  State<AuthModalSheet> createState() => _AuthModalSheetState();
}

class _AuthModalSheetState extends State<AuthModalSheet> {
  bool _isLoginTab = true;

  // Login Controllers
  final _loginUserCtrl = TextEditingController();
  final _loginPassCtrl = TextEditingController();

  // Register Controllers
  final _regUserCtrl = TextEditingController();
  final _regEmailCtrl = TextEditingController();
  final _regPassCtrl = TextEditingController();
  final _regRefCtrl = TextEditingController();
  final _regOtpCtrl = TextEditingController();

  bool _isLoading = false;
  bool _otpSent = false;
  String? _errorMsg;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF0E0E14),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: Color(0x33FFFFFF))),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0x33FFFFFF), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() {
                        _isLoginTab = true;
                        _errorMsg = null;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: _isLoginTab ? const Color(0xFFFF3B5C) : Colors.transparent, width: 2)),
                        ),
                        child: Text(
                          'ورود به حساب',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _isLoginTab ? Colors.white : Colors.white54),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() {
                        _isLoginTab = false;
                        _errorMsg = null;
                        _otpSent = false;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: !_isLoginTab ? const Color(0xFFFF3B5C) : Colors.transparent, width: 2)),
                        ),
                        child: Text(
                          'ثبت‌نام جدید',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: !_isLoginTab ? Colors.white : Colors.white54),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_errorMsg != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: const Color(0x1AFF3B5C),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0x4DFF3B5C)),
                  ),
                  child: Text(_errorMsg!, style: const TextStyle(fontSize: 12, color: Color(0xFFFF3B5C)), textAlign: TextAlign.center),
                ),
              if (_isLoginTab) _buildLoginForm() else _buildRegisterForm(),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Expanded(child: Divider(color: Color(0x1AFFFFFF))),
                  Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('یا احراز هویت با', style: TextStyle(fontSize: 11, color: Colors.white38))),
                  Expanded(child: Divider(color: Color(0x1AFFFFFF))),
                ],
              ),
              const SizedBox(height: 14),
              _buildGoogleAuthButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      children: [
        _buildTextField(_loginUserCtrl, 'نام کاربری یا ایمیل', Icons.person_outline),
        const SizedBox(height: 12),
        _buildTextField(_loginPassCtrl, 'رمز عبور', Icons.lock_outline, isPassword: true),
        const SizedBox(height: 18),
        _buildSubmitButton('ورود به حساب کاربری', _handleLogin),
      ],
    );
  }

  Widget _buildRegisterForm() {
    if (!_otpSent) {
      return Column(
        children: [
          _buildTextField(_regUserCtrl, 'نام کاربری دلخواه', Icons.person_outline),
          const SizedBox(height: 10),
          _buildTextField(_regEmailCtrl, 'آدرس ایمیل معتبر', Icons.email_outlined, keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 10),
          _buildTextField(_regPassCtrl, 'رمز عبور (حداقل ۸ کاراکتر)', Icons.lock_outline, isPassword: true),
          const SizedBox(height: 10),
          _buildTextField(_regRefCtrl, 'کد رفرال معرف (اختیاری)', Icons.card_giftcard),
          const SizedBox(height: 18),
          _buildSubmitButton('دریافت کد تایید ایمیل', _handleSendRegisterOtp),
        ],
      );
    } else {
      return Column(
        children: [
          Text('کد تایید ۶ رقمی به ایمیل ${_regEmailCtrl.text} ارسال شد:', style: const TextStyle(fontSize: 12, color: Color(0xFFA0A0B0))),
          const SizedBox(height: 14),
          _buildTextField(_regOtpCtrl, 'کد تایید ۶ رقمی', Icons.pin_outlined, keyboardType: TextInputType.number, isCenter: true),
          const SizedBox(height: 18),
          _buildSubmitButton('تایید نهایی و ساخت حساب', _handleConfirmRegister),
        ],
      );
    }
  }

  Widget _buildTextField(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
    bool isCenter = false,
  }) {
    return TextField(
      controller: ctrl,
      obscureText: isPassword,
      keyboardType: keyboardType,
      textAlign: isCenter ? TextAlign.center : TextAlign.start,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        prefixIcon: isCenter ? null : Icon(icon, size: 18, color: const Color(0x80FFFFFF)),
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0x4DFFFFFF), fontSize: 12),
        filled: true,
        fillColor: const Color(0xFF14141E),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0x1AFFFFFF))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0x1AFFFFFF))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFFF3B5C))),
      ),
    );
  }

  Widget _buildSubmitButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton(
        onTap: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF3B5C),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
      ),
    );
  }

  Widget _buildGoogleAuthButton() {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: OutlinedButton(
        onTap: () async {
          // Open web Google Auth flow directly in Chrome/Default browser
          final mode = _isLoginTab ? 'login' : 'register';
          final url = Uri.parse('https://ryzerdns.ir/auth?mode=$mode');
          await launchUrl(url, mode: LaunchMode.externalApplication);
          if (mounted) Navigator.pop(context);
        },
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0x33FFFFFF)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: const Color(0xFF14141E),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.g_mobiledata, color: Colors.white, size: 24),
            const SizedBox(width: 6),
            Text(
              _isLoginTab ? 'ورود مستقیم با حساب گوگل' : 'ثبت‌نام مستقیم با حساب گوگل',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    final u = _loginUserCtrl.text.trim();
    final p = _loginPassCtrl.text.trim();
    if (u.isEmpty || p.isEmpty) {
      setState(() => _errorMsg = 'نام کاربری و کلمه عبور را وارد فرمایید.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    final res = await ApiService.login(u, p);
    setState(() => _isLoading = false);

    if (res['success'] == true && res['token'] != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ryzer_user_token', res['token']);
      if (mounted) Navigator.pop(context);
    } else {
      setState(() => _errorMsg = res['message'] ?? 'نام کاربری یا رمز عبور اشتباه است.');
    }
  }

  Future<void> _handleSendRegisterOtp() async {
    final u = _regUserCtrl.text.trim();
    final e = _regEmailCtrl.text.trim();
    final p = _regPassCtrl.text.trim();
    final r = _regRefCtrl.text.trim();

    if (u.isEmpty || e.isEmpty || p.isEmpty) {
      setState(() => _errorMsg = 'کلیه فیلدهای الزامی را تکمیل فرمایید.');
      return;
    }
    if (p.length < 8) {
      setState(() => _errorMsg = 'رمز عبور باید حداقل ۸ کاراکتر باشد.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    final res = await ApiService.sendRegisterOtp(username: u, email: e, password: p, referralCode: r);
    setState(() => _isLoading = false);

    if (res['success'] == true) {
      setState(() => _otpSent = true);
    } else {
      setState(() => _errorMsg = res['message'] ?? 'خطا در ارسال کد تایید.');
    }
  }

  Future<void> _handleConfirmRegister() async {
    final c = _regOtpCtrl.text.trim();
    if (c.length < 6) {
      setState(() => _errorMsg = 'کد تایید ۶ رقمی را کامل وارد نمایید.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    final res = await ApiService.confirmRegister(
      username: _regUserCtrl.text.trim(),
      email: _regEmailCtrl.text.trim(),
      password: _regPassCtrl.text.trim(),
      code: c,
      referralCode: _regRefCtrl.text.trim(),
    );
    setState(() => _isLoading = false);

    if (res['success'] == true && res['token'] != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ryzer_user_token', res['token']);
      if (mounted) Navigator.pop(context);
    } else {
      setState(() => _errorMsg = res['message'] ?? 'کد تایید اشتباه است.');
    }
  }
}
