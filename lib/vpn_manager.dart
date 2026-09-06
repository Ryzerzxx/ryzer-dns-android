import 'dart:io';
import 'dart:async';
import 'package:flutter/services.dart';

class VpnManager {
  static const MethodChannel _channel = MethodChannel('ir.ryzerdns/vpn');

  static Future<bool> startVpn({required String primaryDns, required String secondaryDns}) async {
    try {
      final bool result = await _channel.invokeMethod('startVpn', {
        'primary_dns': primaryDns,
        'secondary_dns': secondaryDns,
      });
      return result;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> stopVpn() async {
    try {
      final bool result = await _channel.invokeMethod('stopVpn');
      return result;
    } catch (_) {
      return false;
    }
  }

  static Future<int?> measurePing(String host) async {
    // 1. Try TCP Port 53 first
    try {
      final sw = Stopwatch()..start();
      final socket = await Socket.connect(host, 53, timeout: const Duration(milliseconds: 1200));
      sw.stop();
      socket.destroy();
      final ms = sw.elapsedMilliseconds;
      if (ms > 0) return ms;
    } catch (_) {}

    // 2. Fallback to HTTPS ping to ryzerdns.ir
    try {
      final sw = Stopwatch()..start();
      final client = HttpClient()..connectionTimeout = const Duration(milliseconds: 1500);
      final req = await client.getUrl(Uri.parse('https://ryzerdns.ir/api/app/config'));
      final resp = await req.close();
      sw.stop();
      client.close();
      if (resp.statusCode == 200) {
        return sw.elapsedMilliseconds;
      }
    } catch (_) {}

    // 3. Fallback to secondary server
    try {
      final sw = Stopwatch()..start();
      final socket = await Socket.connect('46.8.102.223', 53, timeout: const Duration(milliseconds: 1500));
      sw.stop();
      socket.destroy();
      return sw.elapsedMilliseconds;
    } catch (_) {}

    return null;
  }
}
