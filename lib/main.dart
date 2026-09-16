import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:myket_iap/myket_iap.dart';
import 'package:myket_iap/util/iab_result.dart';
import 'package:myket_iap/util/purchase.dart';
import 'package:myket_iap/util/inventory.dart';
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
          onPrimary: Colors.white,
          surface: Color(0xFF0E0E14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.w800),
          ),
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

  // 🌐 Server-Driven UI & Remote Config State
  Map<String, dynamic> _remoteConfig = {};
  Map<String, dynamic> get _uiConfig => _remoteConfig['ui_config'] ?? {};

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _loadStoredSession();
    _fetchRemoteConfig();
    _loadTickets();
    _initMyketBilling();
  }

  void _initMyketBilling() async {
    try {
      await MyketIAP.init(rsaKey: "", enableDebugLogging: false);
    } catch (_) {}
  }

  Future<void> _fetchRemoteConfig() async {
    final cfg = await ApiService.getRemoteConfig();
    if (mounted && cfg.isNotEmpty) {
      setState(() => _remoteConfig = cfg);
      _checkAndPromptUpdate(cfg);
    }
  }

  void _checkAndPromptUpdate(Map<String, dynamic> cfg) {
    const currentAppVersion = "2.0.0";
    final latestVersion = cfg['latest_version'] ?? currentAppVersion;
    final updateAvailable = cfg['update_available'] == true || latestVersion != currentAppVersion;
    final minRequired = cfg['min_required_version'] ?? currentAppVersion;
    final isForceUpdate = minRequired != currentAppVersion && _isVersionLower(currentAppVersion, minRequired);

    if (updateAvailable) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showUpdateDialog(
          latestVersion: latestVersion,
          updateUrl: cfg['update_url'] ?? 'https://ryzerdns.ir/static/download/RyzerDNS_v1.apk',
          changelog: cfg['changelog'] ?? 'بهبود پایداری شبکه و رفع خطاهای اتصال.',
          isForce: isForceUpdate,
        );
      });
    }
  }

  bool _isVersionLower(String current, String target) {
    try {
      final cParts = current.split('.').map(int.parse).toList();
      final tParts = target.split('.').map(int.parse).toList();
      for (int i = 0; i < cParts.length && i < tParts.length; i++) {
        if (cParts[i] < tParts[i]) return true;
        if (cParts[i] > tParts[i]) return false;
      }
    } catch (_) {}
    return false;
  }

  void _showUpdateDialog({
    required String latestVersion,
    required String updateUrl,
    required String changelog,
    required bool isForce,
  }) {
    showDialog(
      context: context,
      barrierDismissible: !isForce,
      builder: (ctx) => WillPopScope(
        onWillPop: () async => !isForce,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: const Color(0xFF0E0E14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFFF3B5C), width: 1.2),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0x1AFF3B5C),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.system_update_rounded, color: Color(0xFFFF3B5C), size: 22),
                ),
                const SizedBox(width: 10),
                Text(
                  'نسخه جدید منتشر شد ($latestVersion)',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'برای دسترسی به آخرین بهینه‌سازی‌ها و پایداری سرورها، نسخه جدید را نصب فرمایید.',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFFA0A0B0), height: 1.6),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14141E),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0x1AFFFFFF)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('تغییرات این نسخه:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white70)),
                      const SizedBox(height: 6),
                      Text(changelog, style: const TextStyle(fontSize: 12, color: Color(0xFFD0D0E0), height: 1.5)),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              if (!isForce)
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('بعداً', style: TextStyle(color: Colors.white54)),
                ),
              ElevatedButton.icon(
                onPressed: () async {
                  final uri = Uri.tryParse(updateUrl);
                  if (uri != null) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('دانلود و نصب نسخه جدید'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF3B5C),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
      // Auto-register device IP silently on startup!
      ApiService.registerIp(token);
      _loadTickets();
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
      // If user is logged in, register IP with user token
      if (_userToken != null && _userToken!.isNotEmpty) {
        final regSuccess = await ApiService.registerIp(_userToken!);
        if (!regSuccess) {
          setState(() => _isConnecting = false);
          _showToast('ثبت آی‌پی با خطا مواجه شد. اشتراک خود را بررسی نمایید.');
          return;
        }
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
        margin: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom > 0
              ? MediaQuery.of(context).viewInsets.bottom + 20
              : 80,
        ),
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
                    _buildSupportTab(),
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x1AFFFFFF))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                'assets/nav-logo.png',
                height: 44,
                width: 44,
                fit: BoxFit.contain,
              ),
              SizedBox(
                width: (_uiConfig['logo_gap'] is num)
                    ? (_uiConfig['logo_gap'] as num).toDouble()
                    : 3.0,
              ),
              Padding(
                padding: EdgeInsets.only(
                  bottom: (_uiConfig['logo_lift_up'] is num)
                      ? (_uiConfig['logo_lift_up'] as num).toDouble()
                      : 2.5,
                ),
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: _uiConfig['top_title_prefix'] ?? 'RYZER',
                        style: TextStyle(
                          fontFamily: 'Syne',
                          fontSize: (_uiConfig['logo_font_size'] is num)
                              ? (_uiConfig['logo_font_size'] as num).toDouble()
                              : 19.0,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.5,
                          height: 1.0,
                        ),
                      ),
                      TextSpan(
                        text: _uiConfig['top_title_suffix'] ?? 'DNS',
                        style: TextStyle(
                          fontFamily: 'Syne',
                          fontSize: (_uiConfig['logo_font_size'] is num)
                              ? (_uiConfig['logo_font_size'] as num).toDouble()
                              : 19.0,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFFF3B5C),
                          letterSpacing: -0.5,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
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
              onPressed: _showAuthModal,
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
          if (_uiConfig['enable_banner'] == true && (_uiConfig['banner_text'] ?? '').isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0x1AFF3B5C),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFF3B5C)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.campaign_rounded, color: Color(0xFFFF3B5C), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _uiConfig['banner_text'] ?? '',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
              onPressed: _showAuthModal,
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
                      tier.toUpperCase(),
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
            onPressed: () => setState(() => _currentNavIndex = 1),
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
                          _isConnected
                              ? (_uiConfig['power_connected_text'] ?? 'قطع اتصال')
                              : (_uiConfig['power_disconnected_text'] ?? 'اتصال مستقیم'),
                          style: TextStyle(
                            fontSize: 14,
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
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFFA0A0B0)),
                ),
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
                _isConnected ? (_uiConfig['connected_status_text'] ?? 'سرویس فعال') : (_uiConfig['disconnected_status_text'] ?? 'سرویس غیرفعال'),
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
            title: _uiConfig['action_btn1_title'] ?? 'خرید اشتراک',
            subtitle: _uiConfig['action_btn1_subtitle'] ?? 'پلن Pro و Plus',
            onTap: () => setState(() => _currentNavIndex = 1),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            icon: Icons.tune,
            title: _uiConfig['action_btn2_title'] ?? 'تنظیمات حساب',
            subtitle: _uiConfig['action_btn2_subtitle'] ?? 'تغییر رمز و مشخصات',
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
    return Material(
      color: const Color(0xFF0E0E14),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: const Color(0x1AFF3B5C),
        highlightColor: const Color(0x0DFF3B5C),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
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
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 💎 TAB 2: PLANS & IN-APP PURCHASE
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildPlansTab() {
    final proCard = _buildPlanCard(
      tier: 'pro',
      title: _uiConfig['pro_plan_title'] ?? 'پلن PRO (نامحدود و کامل)',
      features: (_uiConfig['pro_features'] as List?)?.map((e) => e.toString()).toList() ?? [
        'دسترسی به کل ۳۰,۰۰۰ دامنه تحریم‌شده بین‌المللی',
        'پشتیبانی کامل هوش مصنوعی (ChatGPT, Claude, Gemini)',
        'پشتیبانی کلیه بازی‌های آنلاین و پلتفرم‌های گیمینگ',
        'پایداری حداکثری و اولویت ترافیکی سرورها',
        'تک کاربره همزمان (ثبت آی‌پی هوشمند)',
      ],
      price1m: _uiConfig['pro_price_1m'] ?? '۱۴۹,۰۰۰ تومان',
      price3m: _uiConfig['pro_price_3m'] ?? '۴۴۷,۰۰۰ تومان',
      isPro: true,
    );

    final plusCard = _buildPlanCard(
      tier: 'plus',
      title: _uiConfig['plus_plan_title'] ?? 'پلن PLUS (ویژه گیمینگ)',
      features: (_uiConfig['plus_features'] as List?)?.map((e) => e.toString()).toList() ?? [
        'اختصاصی بازی‌های آنلاین و استورهای گیمینگ',
        'پینگ بهینه و اتصال پایدار سرورهای بازی',
        'پشتیبانی لانچرهای Steam, Epic Games, EA App, Riot',
      ],
      price1m: _uiConfig['plus_price_1m'] ?? '۸۹,۰۰۰ تومان',
      price3m: _uiConfig['plus_price_3m'] ?? '۲۶۷,۰۰۰ تومان',
      isPro: false,
    );

    final order = (_uiConfig['plans_order'] as List?)?.map((e) => e.toString().toLowerCase()).toList() ?? ['pro', 'plus'];
    final cards = <Widget>[];
    for (int i = 0; i < order.length; i++) {
      if (order[i] == 'plus') {
        cards.add(plusCard);
      } else {
        cards.add(proCard);
      }
      if (i < order.length - 1) {
        cards.add(const SizedBox(height: 18));
      }
    }

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
        ...cards,
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
                  child: Text(_uiConfig['pro_badge_text'] ?? 'پیشنهادی', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.white)),
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
                  onPressed: () => _handlePurchasePlan(tier, 1, price1m),
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
                  onPressed: () => _handlePurchasePlan(tier, 3, price3m),
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

    // Exact official pricing and ZarinPal fees identical to website
    final Map<String, Map<String, dynamic>> planDetails = {
      'plus_1': {'base': 89000, 'fee': 945, 'total': 89945, 'dur': '۱ ماهه', 'title': 'Ryzer Plus'},
      'plus_3': {'base': 267000, 'fee': 1835, 'total': 268835, 'dur': '۳ ماهه', 'title': 'Ryzer Plus'},
      'pro_1': {'base': 149000, 'fee': 1245, 'total': 150245, 'dur': '۱ ماهه', 'title': 'Ryzer Pro'},
      'pro_3': {'base': 447000, 'fee': 2735, 'total': 449735, 'dur': '۳ ماهه', 'title': 'Ryzer Pro'},
    };

    final planKey = '${tier.toLowerCase()}_$months';
    final planInfo = planDetails[planKey] ?? {
      'base': 0,
      'fee': 0,
      'total': 0,
      'dur': '$months ماهه',
      'title': 'Ryzer ${tier.toUpperCase()}'
    };

    final baseFormatted = '${(planInfo['base'] as int).toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} تومان';
    final feeFormatted = '${(planInfo['fee'] as int).toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} تومان';
    final totalFormatted = '${(planInfo['total'] as int).toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} تومان';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF0E0E14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0x33FFFFFF)),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0x1AFF3B5C),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.receipt_long_rounded, color: Color(0xFFFF3B5C), size: 18),
              ),
              const SizedBox(width: 8),
              const Text('پیش‌فاکتور خرید اشتراک', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF14141E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x1AFFFFFF)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('پلن انتخابی', style: TextStyle(fontSize: 12, color: Color(0xFFA0A0B0))),
                        Text(
                          '${tier.toUpperCase()} (${planInfo['dur']})',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ],
                    ),
                    const Divider(color: Color(0x1AFFFFFF), height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('مبلغ اشتراک', style: TextStyle(fontSize: 12, color: Color(0xFFA0A0B0))),
                        Text(baseFormatted, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white)),
                      ],
                    ),
                    const Divider(color: Color(0x33FFFFFF), height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('مبلغ قابل پرداخت', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                        Text(
                          baseFormatted,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF00E676)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'پرداخت امن از طریق درگاه رسمی انجام می‌شود و اشتراک بلافاصله فعال می‌گردد.',
                style: TextStyle(fontSize: 11, color: Color(0xFFA0A0B0), height: 1.5),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0x33FFFFFF)),
                      foregroundColor: Colors.white70,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('انصراف', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E676),
                      foregroundColor: Colors.black,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('پرداخت', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    // Myket In-App Billing ONLY (Official SDK with Full Android 12-16 Compatibility)
    final sku = '${tier.toLowerCase()}_${months}m';
    try {
      _showToast('در حال اتصال به مایکت...');
      
      // Ensure billing client is initialized
      try {
        await MyketIAP.init(rsaKey: "", enableDebugLogging: false);
      } catch (_) {}

      final dynamic buyRes = await MyketIAP.launchPurchaseFlow(
        sku: sku,
        payload: _userToken,
      );

      final IabResult? iabResult = buyRes[MyketIAP.RESULT];
      final Purchase? purchase = buyRes[MyketIAP.PURCHASE];

      if (iabResult != null && iabResult.isSuccess() && purchase != null) {
        final purchaseToken = purchase.mToken;
        _showToast('تراکنش با موفقیت انجام شد، در حال ثبت اشتراک...');
        
        // Auto-consume consumable purchase so it can be renewed/repurchased
        try {
          await MyketIAP.consume(purchase: purchase);
        } catch (_) {}

        final valRes = await ApiService.verifyMyketPurchase(
          token: _userToken!,
          sku: sku,
          purchaseToken: purchaseToken,
        );
        if (valRes['success'] == true) {
          _showToast('اشتراک شما با موفقیت فعال شد!');
          _refreshUserProfile();
          return;
        } else {
          _showToast(valRes['message'] ?? 'خطا در تایید اشتراک مایکت');
          return;
        }
      } else {
        if (iabResult != null && iabResult.mResponse == 1) { // USER_CANCELED
          _showToast('پرداخت توسط شما لغو شد.');
        } else if (iabResult != null && iabResult.mResponse == 7) { // ITEM_ALREADY_OWNED
          _showToast('اشتراک قبلی شناسایی شد. در حال بازیابی...');
          try {
            final invMap = await MyketIAP.queryInventory(querySkuDetails: false);
            final Inventory? inv = invMap[MyketIAP.INVENTORY];
            final owned = inv?.mPurchaseMap[sku];
            if (owned != null) {
              await MyketIAP.consume(purchase: owned);
              _showToast('لطفاً مجدداً دکمه پرداخت را لمس فرمایید.');
            }
          } catch (_) {}
        } else {
          _showToast(iabResult?.mMessage ?? 'پرداخت انجام نشد.');
        }
      }
    } catch (e) {
      _showToast('خطا در اجرای فرآیند خرید مایکت.');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 💬 TAB 3: SUPPORT, TICKETS & DOMAIN REQUESTS (Mirrors Website Perfectly)
  // ══════════════════════════════════════════════════════════════════════════
  int _supportCategoryIndex = 0; // 0: تیکت, 1: فیدبک, 2: درخواست دامنه
  final _ticketSubjectCtrl = TextEditingController();
  final _ticketMessageCtrl = TextEditingController();
  bool _isSubmittingTicket = false;
  List<dynamic> _myTickets = [];
  bool _isLoadingTickets = false;

  void _loadTickets() async {
    if (_userToken == null) return;
    setState(() => _isLoadingTickets = true);
    final tickets = await ApiService.getTicketsList(_userToken!);
    if (mounted) {
      setState(() {
        _myTickets = tickets;
        _isLoadingTickets = false;
      });
    }
  }

  void _submitTicket() async {
    if (_userToken == null) {
      _showToast('لطفاً ابتدا وارد حساب کاربری شوید.');
      return;
    }
    final msg = _ticketMessageCtrl.text.trim();
    if (msg.isEmpty) {
      _showToast('متن پیام نمی‌تواند خالی باشد.');
      return;
    }
    final categories = ['تیکت', 'فیدبک', 'درخواست دامنه'];
    final category = categories[_supportCategoryIndex];
    final subject = _ticketSubjectCtrl.text.trim().isEmpty ? category : _ticketSubjectCtrl.text.trim();

    setState(() => _isSubmittingTicket = true);
    final res = await ApiService.submitTicket(
      token: _userToken!,
      category: category,
      subject: subject,
      message: msg,
    );
    setState(() => _isSubmittingTicket = false);

    if (res['status'] == 'success') {
      _ticketSubjectCtrl.clear();
      _ticketMessageCtrl.clear();
      _showToast('تیکت شما با موفقیت ثبت شد و کد پیگیری صادر گردید.');
      _loadTickets();
    } else {
      _showToast(res['detail'] ?? 'خطا در ثبت پیام');
    }
  }

  void _showTicketChatDialog(int ticketId, String subject) async {
    if (_userToken == null) return;
    final replyCtrl = TextEditingController();
    bool isReplying = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0C0C12),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: Color(0x33FFFFFF)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return FutureBuilder<Map<String, dynamic>>(
            future: ApiService.getTicketHistory(_userToken!, ticketId),
            builder: (context, snapshot) {
              final data = snapshot.data;
              final messages = (data?['messages'] as List?) ?? [];
              final ticket = data?['ticket'] as Map<String, dynamic>?;
              final status = ticket?['status'] ?? 'open';

              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                  left: 18,
                  right: 18,
                  top: 18,
                ),
                child: SizedBox(
                  height: MediaQuery.of(ctx).size.height * 0.75,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white70),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                          Expanded(
                            child: Text(
                              'پیگیری تیکت #$ticketId ($subject)',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: status == 'open' ? const Color(0x26FFAB00) : const Color(0x2600E676),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: status == 'open' ? const Color(0xFFFFAB00) : const Color(0xFF00E676)),
                            ),
                            child: Text(
                              status == 'open' ? 'در انتظار بررسی' : 'پاسخ داده شد',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: status == 'open' ? const Color(0xFFFFAB00) : const Color(0xFF00E676),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(color: Color(0x1AFFFFFF), height: 24),
                      Expanded(
                        child: snapshot.connectionState == ConnectionState.waiting
                            ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF3B5C)))
                            : messages.isEmpty
                                ? const Center(child: Text('پیامی یافت نشد.', style: TextStyle(color: Colors.white54)))
                                : ListView.builder(
                                    reverse: false,
                                    itemCount: messages.length,
                                    itemBuilder: (context, idx) {
                                      final m = messages[idx];
                                      final isUser = m['sender_type'] == 'user';
                                      return Align(
                                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                                        child: Container(
                                          margin: const EdgeInsets.symmetric(vertical: 6),
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                          constraints: BoxConstraints(maxWidth: MediaQuery.of(ctx).size.width * 0.8),
                                          decoration: BoxDecoration(
                                            color: isUser ? const Color(0x26FF3B5C) : const Color(0xFF1E1E2A),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: isUser ? const Color(0x4DFF3B5C) : const Color(0x33FFFFFF),
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                isUser ? (m['sender_name'] ?? 'شما') : 'پشتیبانی فنی Ryzer',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                  color: isUser ? const Color(0xFFFF8595) : const Color(0xFF00E676),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                m['message'] ?? '',
                                                style: const TextStyle(fontSize: 12.5, color: Colors.white, height: 1.5),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                (m['created_at'] ?? '').toString().replaceFirst('T', ' ').split('.')[0],
                                                style: const TextStyle(fontSize: 9.5, color: Colors.white38),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: replyCtrl,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'ارسال پاسخ یا پیام تکمیلی...',
                                hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                                filled: true,
                                fillColor: const Color(0xFF14141E),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          isReplying
                              ? const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF3B5C)))
                              : IconButton(
                                  icon: const Icon(Icons.send_rounded, color: Color(0xFFFF3B5C)),
                                  onPressed: () async {
                                    final text = replyCtrl.text.trim();
                                    if (text.isEmpty) return;
                                    setModalState(() => isReplying = true);
                                    final res = await ApiService.replyTicket(token: _userToken!, ticketId: ticketId, message: text);
                                    setModalState(() => isReplying = false);
                                    if (res['status'] == 'success') {
                                      replyCtrl.clear();
                                      setModalState(() {});
                                      _loadTickets();
                                    } else {
                                      _showToast(res['detail'] ?? 'خطا در ارسال پاسخ');
                                    }
                                  },
                                ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showTicketsModal() {
    setState(() => _currentNavIndex = 2); // Switch to support tab
  }

  Widget _buildSupportTab() {
    if (_userToken == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.support_agent_outlined, size: 52, color: Color(0xFFA0A0B0)),
            const SizedBox(height: 14),
            const Text('جهت ارسال تیکت و پیگیری پیام‌ها وارد حساب شوید.', style: TextStyle(fontSize: 13, color: Colors.white70)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _showAuthModal,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF3B5C)),
              child: const Text('ورود به حساب کاربری'),
            ),
          ],
        ),
      );
    }

    final categories = ['ارسال تیکت پشتیبانی', 'ارسال نظر و فیدبک', 'درخواست افزودن دامنه'];

    return RefreshIndicator(
      onRefresh: () async => _loadTickets(),
      color: const Color(0xFFFF3B5C),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          const Text('مرکز پشتیبانی و ارتباط مستقیم', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
          const SizedBox(height: 4),
          const Text('پیام‌ها مستقیماً با سایت، ربات تلگرام و تیم پشتیبانی همگام است', style: TextStyle(fontSize: 11.5, color: Color(0xFFA0A0B0))),
          const SizedBox(height: 16),

          // Categories Tabs (Mirrors Web)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF0E0E14),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0x1AFFFFFF)),
            ),
            child: Row(
              children: List.generate(categories.length, (idx) {
                final isSelected = _supportCategoryIndex == idx;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _supportCategoryIndex = idx),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFFF3B5C) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        categories[idx],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                          color: isSelected ? Colors.white : Colors.white60,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 14),

          // New Ticket Box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0E0E14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0x1AFFFFFF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_supportCategoryIndex == 0) ...[
                  TextField(
                    controller: _ticketSubjectCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'موضوع تیکت (مثال: مشکل در اتصال به FC 26)',
                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                      filled: true,
                      fillColor: const Color(0xFF14141E),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                TextField(
                  controller: _ticketMessageCtrl,
                  maxLines: 4,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: _supportCategoryIndex == 2
                        ? 'آدرس دامنه یا نام بازی مورد نظر جهت رفع تحریم را بنویسید...'
                        : _supportCategoryIndex == 1
                            ? 'پیشنهاد، نظر یا انتقاد خود را برای بهبود سرویس بنویسید...'
                            : 'توضیحات کامل مشکل خود، نوع کنسول/سیستم و اپراتور اینترنت را بنویسید...',
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFF14141E),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B5C),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: _isSubmittingTicket ? null : _submitTicket,
                      child: Center(
                        child: _isSubmittingTicket
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.send_rounded, size: 16, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Text(
                                    _supportCategoryIndex == 0
                                        ? 'ثبت تیکت و دریافت کد پیگیری'
                                        : _supportCategoryIndex == 1
                                            ? 'ارسال نظر و فیدبک'
                                            : 'ارسال درخواست دامنه',
                                    style: const TextStyle(
                                      fontFamily: 'Vazirmatn',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Tickets History Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('تیکت‌ها و درخواست‌های من', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
              TextButton.icon(
                onPressed: _loadTickets,
                icon: const Icon(Icons.refresh, size: 14, color: Color(0xFFFF3B5C)),
                label: const Text('بروزرسانی', style: TextStyle(fontSize: 11, color: Color(0xFFFF3B5C))),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (_isLoadingTickets)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Color(0xFFFF3B5C))))
          else if (_myTickets.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF0E0E14),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0x1AFFFFFF)),
              ),
              child: const Center(
                child: Text('تاکنون تیکت یا درخواستی ثبت نکرده‌اید.', style: TextStyle(color: Colors.white54, fontSize: 12)),
              ),
            )
          else
            ..._myTickets.map((t) {
              final status = t['status'] ?? 'open';
              final isAnswered = status != 'open';
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E0E14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isAnswered ? const Color(0x4D00E676) : const Color(0x1AFFFFFF)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  title: Row(
                    children: [
                      Text('#${t['id']}', style: const TextStyle(color: Color(0xFF00BCD4), fontWeight: FontWeight.w800, fontSize: 12)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          t['subject'] ?? t['category'] ?? 'تیکت',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          t['category'] ?? 'پشتیبانی',
                          style: const TextStyle(fontSize: 11, color: Color(0xFFA0A0B0)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isAnswered ? const Color(0x2600E676) : const Color(0x26FFAB00),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isAnswered ? 'پاسخ داده شد' : 'در انتظار بررسی',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isAnswered ? const Color(0xFF00E676) : const Color(0xFFFFAB00),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white54, size: 18),
                  onTap: () => _showTicketChatDialog(t['id'], t['subject'] ?? 'پشتیبانی'),
                ),
              );
            }),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ⚙️ TAB 4: ACCOUNT & SETTINGS
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
              onPressed: _showAuthModal,
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
              _showToast('کد رفرال کپی شد! با دعوت هر کاربر ۴ ساعت اشتراک رایگان دریافت می‌کنید.');
            }
          },
        ),
        _buildSettingsItem(
          icon: Icons.support_agent_outlined,
          title: 'تیکت‌ها و پشتیبانی',
          value: 'مشاهده و ارسال',
          onTap: () => _showTicketsModal(),
        ),
        if (_uiConfig['show_support_in_settings'] == true) ...[
          _buildSettingsItem(
            icon: Icons.headset_mic_outlined,
            title: 'پشتیبانی آنلاین',
            value: _uiConfig['support_label'] ?? 'ارتباط با ما',
            onTap: () {
              final email = _uiConfig['support_email'] ?? 'info@ryzerdns.ir';
              launchUrl(Uri.parse('mailto:$email'), mode: LaunchMode.externalApplication);
            },
          ),
        ],
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
      child: Material(
        color: const Color(0xFF0E0E14),
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: const Color(0x1AFF3B5C),
          highlightColor: const Color(0x0DFF3B5C),
          child: Container(
            decoration: BoxDecoration(
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
            ),
          ),
        ),
      ),
    );
  }

  void _showEditProfileDialog({required String target}) {
    final textController = TextEditingController();
    final otpController = TextEditingController();
    String? challengeId;
    bool otpSent = false;
    String? dialogError;

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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (dialogError != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0x1AFF3B5C),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFF3B5C)),
                      ),
                      child: Text(
                        dialogError!,
                        style: const TextStyle(color: Color(0xFFFF3B5C), fontSize: 12, fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
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
                        hintStyle: const TextStyle(
                          color: Color(0x2EFFFFFF),
                          fontFamily: 'Syne',
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 4,
                        ),
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
                    setDialogState(() => dialogError = null);
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
                            dialogError = null;
                          });
                          _showToast('کد تایید به ایمیل شما ارسال شد.');
                        }
                      } else {
                        setDialogState(() {
                          dialogError = res['message'] ?? 'خطا در ثبت درخواست.';
                        });
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
                        setDialogState(() {
                          dialogError = res['message'] ?? 'کد تایید اشتباه است.';
                        });
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('تایید'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleLogout() async {
    if (_userToken != null) {
      // Invalidate on server
      ApiService.logout(_userToken!);
    }
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
          BottomNavigationBarItem(icon: Icon(Icons.support_agent_outlined), label: 'پشتیبانی'),
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
        onPressed: _isLoading ? null : onPressed,
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
        onPressed: () async {
          final mode = _isLoginTab ? 'login' : 'register';
          setState(() {
            _isLoading = true;
            _errorMsg = null;
          });

          try {
            // Native Google Sign-In with Play Services Dialog directly on Android!
            final googleSignIn = GoogleSignIn(
              serverClientId: '607759999989-rkpp4ovbl69o73vqaunhue5h4frainq7.apps.googleusercontent.com',
              scopes: ['email', 'profile'],
            );

            // Force sign out to ensure account chooser dialog always pops up
            try { await googleSignIn.signOut(); } catch (_) {}

            final googleAccount = await googleSignIn.signIn();
            if (googleAccount != null) {
              final auth = await googleAccount.authentication;
              // Prioritize idToken (standard JWT containing aud/client_id)
              final tokenToVerify = auth.idToken ?? auth.accessToken;

              if (tokenToVerify != null) {
                final authRes = await ApiService.authWithGoogleToken(
                  token: tokenToVerify,
                  mode: mode,
                );

                if (authRes['success'] == true && authRes['token'] != null) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('ryzer_user_token', authRes['token']);
                  if (mounted) {
                    setState(() => _isLoading = false);
                    Navigator.pop(context);
                  }
                  return;
                } else {
                  setState(() {
                    _isLoading = false;
                    _errorMsg = authRes['message'] ?? 'خطا در ورود با گوگل';
                  });
                  return;
                }
              }
            }
            setState(() => _isLoading = false);
          } catch (e) {
            setState(() {
              _isLoading = false;
              _errorMsg = 'خطا در اتصال به گوگل‌پلی: $e';
            });
          }
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
