import 'dart:io';
import 'dart:async';
import 'package:flutter/services.dart';

class VpnManager {
  static const MethodChannel _channel = MethodChannel('ir.ryzerdns/vpn');

  static Future<bool> startVpn({
    required String primaryDns,
    required String secondaryDns,
    bool enableDoh = false,
    String dohUrl = 'https://ryzerdns.ir/dns-query',
  }) async {
    try {
      final bool result = await _channel.invokeMethod('startVpn', {
        'primary_dns': primaryDns,
        'secondary_dns': secondaryDns,
        'enable_doh': enableDoh,
        'doh_url': dohUrl,
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
    // 1. Try native ICMP ping via MethodChannel (real Linux network ping)
    try {
      final int? nativePing = await _channel.invokeMethod<int>('measureIcmpPing', {'host': host});
      if (nativePing != null && nativePing > 0) {
        return nativePing;
      }
    } catch (_) {}

    // 2. Try TCP Port 53 socket measurement
    try {
      final sw = Stopwatch()..start();
      final socket = await Socket.connect(host, 53, timeout: const Duration(milliseconds: 1200));
      sw.stop();
      socket.destroy();
      final ms = sw.elapsedMilliseconds;
      if (ms > 0) return ms;
    } catch (_) {}

    // 3. Fallback to lightweight HTTPS ping to ryzerdns.ir
    try {
      final sw = Stopwatch()..start();
      final client = HttpClient()..connectionTimeout = const Duration(milliseconds: 1500);
      final req = await client.getUrl(Uri.parse('https://ryzerdns.ir/favicon.png'));
      final resp = await req.close();
      sw.stop();
      client.close();
      if (resp.statusCode == 200) {
        return sw.elapsedMilliseconds;
      }
    } catch (_) {}

    return null;
  }
}
