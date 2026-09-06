import 'dart:io';
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
    try {
      final stopwatch = Stopwatch()..start();
      final socket = await Socket.connect(host, 53, timeout: const Duration(milliseconds: 2000));
      stopwatch.stop();
      socket.destroy();
      return stopwatch.elapsedMilliseconds;
    } catch (_) {
      return null;
    }
  }
}
