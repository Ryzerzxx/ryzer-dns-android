import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'https://ryzerdns.ir';
  static const String userAgent = 'RyzerDNS-AndroidClient/2.0';

  /// Standard Login with Username/Email & Password
  static Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/user/login'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': userAgent,
        },
        body: jsonEncode({
          'username': username.trim(),
          'password': password,
        }),
      ).timeout(const Duration(seconds: 12));

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200 && (data['status'] == 'success' || data['token'] != null)) {
        return {
          'success': true,
          'token': data['token'],
          'displayName': data['web_username'] ?? data['display_name'] ?? username,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? data['detail'] ?? 'نام کاربری یا کلمه عبور نادرست است.'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'خطا در برقراری ارتباط با سرور.'};
    }
  }

  /// Send Registration Email OTP
  static Future<Map<String, dynamic>> sendRegisterOtp({
    required String username,
    required String email,
    required String password,
    String? referralCode,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/user/register/send-otp'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': userAgent,
        },
        body: jsonEncode({
          'username': username.trim(),
          'email': email.trim().toLowerCase(),
          'password': password,
          'ref_code': (referralCode ?? '').trim(),
        }),
      ).timeout(const Duration(seconds: 12));

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'کد تایید ۶ رقمی به ایمیل شما ارسال شد.',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? data['detail'] ?? 'خطا در ارسال کد تایید.',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'خطا در اتصال به سرور.'};
    }
  }

  /// Confirm Registration OTP and create account
  static Future<Map<String, dynamic>> confirmRegister({
    required String username,
    required String email,
    required String password,
    required String code,
    String? referralCode,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/user/register'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': userAgent,
        },
        body: jsonEncode({
          'username': username.trim(),
          'email': email.trim().toLowerCase(),
          'password': password,
          'code': code.trim(),
          'ref_code': (referralCode ?? '').trim(),
        }),
      ).timeout(const Duration(seconds: 12));

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200 && data['token'] != null) {
        return {
          'success': true,
          'token': data['token'],
          'displayName': data['web_username'] ?? username,
          'message': 'ثبت‌نام با موفقیت انجام شد!',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? data['detail'] ?? 'کد تایید نادرست یا منقضی شده است.',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'خطا در برقراری ارتباط با سرور.'};
    }
  }

  /// Fetch User Profile and Plan Details
  static Future<Map<String, dynamic>> getProfile(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/user/profile?token=$token'),
        headers: {'User-Agent': userAgent},
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200 && (data['status'] == 'success' || data['plan_tier'] != null)) {
        int daysLeft = 0;
        int hoursLeft = 0;
        bool isExpired = false;
        String remainingText = '';

        if (data['plan_expires_at'] != null) {
          try {
            final exp = DateTime.parse(data['plan_expires_at']);
            final diff = exp.difference(DateTime.now());
            if (diff.isNegative) {
              isExpired = true;
              remainingText = 'منقضی شده';
            } else {
              daysLeft = diff.inDays;
              hoursLeft = diff.inHours % 24;
              if (daysLeft > 0) {
                remainingText = '$daysLeft روز و $hoursLeft ساعت باقیمانده';
              } else {
                remainingText = '${diff.inHours} ساعت باقیمانده';
              }
            }
          } catch (_) {}
        }

        return {
          'success': true,
          'data': {
            'username': data['web_username'] ?? data['username'] ?? 'کاربر',
            'display_name': data['first_name'] ?? data['web_username'] ?? 'کاربر',
            'email': data['email'] ?? '',
            'plan_tier': data['plan_tier'] ?? 'pro',
            'days_left': daysLeft,
            'is_expired': isExpired,
            'remaining_text': remainingText,
            'registered_ip': data['registered_ip'] ?? '',
            'referral_code': data['referral_code'] ?? '',
            'telegram_id': data['telegram_id'] ?? 0,
          }
        };
      }
      return {'success': false, 'message': data['message'] ?? data['detail'] ?? 'خطا در بازیابی پروفایل.'};
    } catch (e) {
      return {'success': false, 'message': 'عدم دسترسی به اینترنت.'};
    }
  }

  /// Request Profile Changes (Username, Password, Email) -> Sends OTP
  static Future<Map<String, dynamic>> requestProfileChange({
    required String token,
    String? newUsername,
    String? newPassword,
    String? newEmail,
    String otpChannel = 'email',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/user/profile/request-change'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': userAgent,
        },
        body: jsonEncode({
          'token': token,
          'new_username': (newUsername ?? '').trim(),
          'new_password': newPassword ?? '',
          'new_email': (newEmail ?? '').trim().toLowerCase(),
          'otp_channel': otpChannel,
        }),
      ).timeout(const Duration(seconds: 12));

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200) {
        return {
          'success': true,
          'direct': data['direct'] == true,
          'challenge_id': data['challenge_id'] ?? '',
          'message': data['message'] ?? 'کد تایید ارسال شد.',
        };
      } else {
        return {
          'success': false,
          'message': data['detail'] ?? data['message'] ?? 'خطا در درخواست تغییر مشخصات.',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'خطا در اتصال به سرور.'};
    }
  }

  /// Confirm Profile Changes with OTP
  static Future<Map<String, dynamic>> confirmProfileChange({
    required String token,
    required String challengeId,
    required String otp,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/user/profile/confirm-change'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': userAgent,
        },
        body: jsonEncode({
          'token': token,
          'challenge_id': challengeId,
          'otp': otp.trim(),
        }),
      ).timeout(const Duration(seconds: 12));

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'مشخصات حساب با موفقیت به‌روزرسانی شد.',
        };
      } else {
        return {
          'success': false,
          'message': data['detail'] ?? data['message'] ?? 'کد تایید نامعتبر است.',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'خطا در تایید کد.'};
    }
  }

  /// Request Zarinpal Payment URL for Plans (Pro / Plus)
  static Future<Map<String, dynamic>> requestPayment({
    required String token,
    required String planTier,
    required int durationMonths,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/payment/request'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': userAgent,
        },
        body: jsonEncode({
          'token': token,
          'plan_tier': planTier.toLowerCase(),
          'duration_months': durationMonths,
        }),
      ).timeout(const Duration(seconds: 12));

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200 && data['payment_url'] != null) {
        return {
          'success': true,
          'payment_url': data['payment_url'],
          'track_id': data['track_id'],
        };
      } else {
        return {
          'success': false,
          'message': data['detail'] ?? data['message'] ?? 'خطا در اتصال به درگاه پرداخت.',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'خطا در ارتباط با سرور پرداخت.'};
    }
  }

  /// Register Current Device IP in System
  static Future<bool> registerIp(String token) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/user/register-ip'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': userAgent,
        },
        body: jsonEncode({'token': token}),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return response.statusCode == 200 && (data['status'] == 'success' || data['success'] == true);
    } catch (_) {
      return false;
    }
  }

  /// Get Remote App Config
  static Future<Map<String, dynamic>> getRemoteConfig() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/app/config'),
        headers: {'User-Agent': userAgent},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
    } catch (_) {}
    return {
      'primary_dns': '87.248.145.40',
      'secondary_dns': '46.8.102.223',
      'update_available': false,
    };
  }

  /// Initialize Google OAuth State for Android Client
  static Future<Map<String, dynamic>> initGoogleAuth(String mode, String nonce) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/google/miniapp-init'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': userAgent,
        },
        body: jsonEncode({
          'credential': 'android_app_init',
          'mode': mode,
          'ref_code': '',
          'init_data': '',
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data is Map<String, dynamic> ? data : {};
    } catch (_) {
      return {};
    }
  }

  /// Poll Google Auth Completion
  static Future<Map<String, dynamic>> pollGoogleAuth(String state) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/auth/google/poll?state=${Uri.encodeComponent(state)}'),
        headers: {'User-Agent': userAgent},
      ).timeout(const Duration(seconds: 8));

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data is Map<String, dynamic> ? data : {'status': 'pending'};
    } catch (_) {
      return {'status': 'pending'};
    }
  }
}
