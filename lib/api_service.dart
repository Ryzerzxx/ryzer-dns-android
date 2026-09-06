import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'https://ryzerdns.ir';

  static Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/user/login'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'RyzerDNS-AndroidClient/1.0',
        },
        body: jsonEncode({
          'username': username.trim(),
          'password': password,
        }),
      ).timeout(const Duration(seconds: 12));

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200 && (data['status'] == 'success' || data['success'] == true || data['token'] != null)) {
        return {
          'success': true,
          'token': data['token'],
          'displayName': data['web_username'] ?? data['display_name'] ?? username
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

  static Future<Map<String, dynamic>> getProfile(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/user/profile?token=$token'),
        headers: {'User-Agent': 'RyzerDNS-AndroidClient/1.0'},
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200 && (data['status'] == 'success' || data['plan_tier'] != null)) {
        int daysLeft = 30;
        bool isExpired = false;
        if (data['plan_expires_at'] != null) {
          try {
            final exp = DateTime.parse(data['plan_expires_at']);
            final diff = exp.difference(DateTime.now()).inDays;
            daysLeft = diff > 0 ? diff : 0;
            isExpired = diff <= 0;
          } catch (_) {}
        }
        return {
          'success': true,
          'data': {
            'username': data['web_username'] ?? data['username'] ?? 'کاربر',
            'plan_tier': data['plan_tier'] ?? 'pro',
            'days_left': daysLeft,
            'is_expired': isExpired,
          }
        };
      }
      return {'success': false, 'message': data['message'] ?? data['detail'] ?? 'خطا در بازیابی پروفایل.'};
    } catch (e) {
      return {'success': false, 'message': 'عدم دسترسی به اینترنت.'};
    }
  }

  static Future<bool> registerIp(String token) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/user/register-ip'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'RyzerDNS-AndroidClient/1.0',
        },
        body: jsonEncode({'token': token}),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return response.statusCode == 200 && (data['status'] == 'success' || data['success'] == true);
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> getRemoteConfig() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/app/config'),
        headers: {'User-Agent': 'RyzerDNS-AndroidClient/1.0'},
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
}
