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
        Uri.parse('$baseUrl/api/user/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'User-Agent': userAgent,
        },
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
            'is_trial': data['is_trial'] == true,
            'has_paid': data['has_paid'] == true,
            'remaining_text': remainingText,
            'registered_ip': data['registered_ip'] ?? '',
            'referral_code': data['referral_code'] ?? '',
            'telegram_id': data['telegram_id'] ?? 0,
          }
        };
      }
      return {
        'success': false,
        'statusCode': response.statusCode,
        'message': data['message'] ?? data['detail'] ?? 'خطا در بازیابی پروفایل.'
      };
    } catch (e) {
      return {'success': false, 'statusCode': 0, 'message': 'عدم دسترسی به اینترنت.'};
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
    String source = 'app',
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
          'source': source,
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

  /// Detect Current Public IP from Server
  static Future<String?> detectIp() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/user/detect-ip'),
        headers: {'User-Agent': userAgent},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final ip = data['ip']?.toString().trim();
        if (ip != null && ip.isNotEmpty) {
          return ip;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Register Device IP in System
  static Future<Map<String, dynamic>> registerIp(String token, {String? manualIp}) async {
    try {
      final bodyMap = <String, dynamic>{'token': token};
      if (manualIp != null && manualIp.trim().isNotEmpty) {
        bodyMap['manual_ip'] = manualIp.trim();
      }
      final response = await http.post(
        Uri.parse('$baseUrl/api/user/register-ip'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': userAgent,
        },
        body: jsonEncode(bodyMap),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200 && (data['status'] == 'success' || data['success'] == true)) {
        return {
          'success': true,
          'registered_ip': data['registered_ip'] ?? manualIp ?? '',
          'message': data['message'] ?? 'آی‌پی با موفقیت ثبت شد.',
        };
      } else {
        return {
          'success': false,
          'message': data['detail'] ?? data['message'] ?? 'خطا در ثبت آی‌پی.',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'خطا در برقراری ارتباط با سرور.'};
    }
  }

  /// Logout & Invalidate Server Session
  static Future<void> logout(String token) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/api/user/logout'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': userAgent,
        },
        body: jsonEncode({'token': token}),
      ).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }
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
      'secondary_dns': '193.242.208.98',
      'update_available': false,
    };
  }

  /// Authenticate with Google ID Token / Access Token directly from Google Play Services
  static Future<Map<String, dynamic>> authWithGoogleToken({
    required String token,
    required String mode,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/google'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': userAgent,
        },
        body: jsonEncode({
          'credential': token,
          'mode': mode,
          'ref_code': '',
          'init_data': '',
        }),
      ).timeout(const Duration(seconds: 12));

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200 && data['token'] != null) {
        return {
          'success': true,
          'token': data['token'],
          'displayName': data['web_username'] ?? 'کاربر',
        };
      } else {
        return {
          'success': false,
          'message': data['detail'] ?? data['message'] ?? 'خطا در احراز هویت با حساب گوگل.',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'خطا در ارتباط با سرور.'};
    }
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

  /// Support Tickets & Messages API
  static Future<List<dynamic>> getTicketsList(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/user/messages/list?token=${Uri.encodeComponent(token)}'),
        headers: {'User-Agent': userAgent},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data is List) return data;
      }
    } catch (_) {}
    return [];
  }

  static Future<Map<String, dynamic>> getTicketHistory(String token, int ticketId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/user/messages/history?token=${Uri.encodeComponent(token)}&ticket_id=$ticketId'),
        headers: {'User-Agent': userAgent},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
    } catch (_) {}
    return {};
  }

  static Future<Map<String, dynamic>> submitTicket({
    required String token,
    required String category,
    required String subject,
    required String message,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/user/messages/submit'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': userAgent,
        },
        body: jsonEncode({
          'token': token,
          'category': category,
          'subject': subject,
          'message': message,
        }),
      ).timeout(const Duration(seconds: 12));

      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (e) {
      return {'status': 'error', 'detail': 'خطا در برقراری ارتباط با سرور'};
    }
  }

  static Future<Map<String, dynamic>> replyTicket({
    required String token,
    required int ticketId,
    required String message,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/user/messages/reply'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': userAgent,
        },
        body: jsonEncode({
          'token': token,
          'ticket_id': ticketId,
          'message': message,
        }),
      ).timeout(const Duration(seconds: 12));

      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (e) {
      return {'status': 'error', 'detail': 'خطا در برقراری ارتباط با سرور'};
    }
  }

  /// Myket Server-side verification
  static Future<Map<String, dynamic>> verifyMyketPurchase({
    required String token,
    required String sku,
    required String purchaseToken,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/payment/myket/verify'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': userAgent,
        },
        body: jsonEncode({
          'token': token,
          'sku': sku,
          'purchase_token': purchaseToken,
        }),
      ).timeout(const Duration(seconds: 15));

      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (e) {
      return {'success': false, 'message': 'خطا در تایید تراکنش با سرور'};
    }
  }
}
