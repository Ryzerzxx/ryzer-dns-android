import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'https://ryzerdns.ir';

  static Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/user/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username.trim(),
          'password': password,
        }),
      ).timeout(const Duration(seconds: 12));

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'token': data['token'], 'displayName': data['display_name'] ?? username};
      } else {
        return {'success': false, 'message': data['message'] ?? data['detail'] ?? 'نام کاربری یا کلمه عبور نادرست است.'};
      }
    } catch (e) {
      return {'success': false, 'message': 'خطا در برقراری ارتباط با سرور.'};
    }
  }

  static Future<Map<String, dynamic>> getProfile(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/user/profile?token=$token'),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'data': data};
      }
      return {'success': false, 'message': data['message'] ?? 'خطا در بازیابی پروفایل.'};
    } catch (e) {
      return {'success': false, 'message': 'عدم دسترسی به اینترنت.'};
    }
  }

  static Future<bool> registerIp(String token) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/user/register-ip'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': token}),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return response.statusCode == 200 && data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> getRemoteConfig() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/app/config'),
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
