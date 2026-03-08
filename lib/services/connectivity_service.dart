import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  /// Returns true if the device has a working internet connection.
  /// First checks the connectivity type (WiFi/mobile/etc.), then attempts
  /// an actual DNS lookup so we catch captive portals and limited connections.
  Future<bool> isConnected() async {
    final results = await Connectivity().checkConnectivity();
    if (results.contains(ConnectivityResult.none)) return false;

    // Confirm real internet access with a DNS lookup
    try {
      final lookup = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 5));
      return lookup.isNotEmpty && lookup.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
