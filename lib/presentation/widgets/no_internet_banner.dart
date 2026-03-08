import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/connectivity_service.dart';

/// Animated banner that appears at the top of a screen when the device
/// has no internet connection, and disappears automatically when it comes back.
class NoInternetBanner extends StatefulWidget {
  const NoInternetBanner({super.key});

  @override
  State<NoInternetBanner> createState() => _NoInternetBannerState();
}

class _NoInternetBannerState extends State<NoInternetBanner>
    with SingleTickerProviderStateMixin {
  bool _isOffline = false;
  late AnimationController _animController;
  late Animation<double> _slideAnim;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnim = Tween<double>(
      begin: -1,
      end: 0,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _checkAndSchedule();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _checkAndSchedule() async {
    await _check();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _check());
  }

  Future<void> _check() async {
    final connected = await ConnectivityService().isConnected();
    if (!mounted) return;
    final nowOffline = !connected;
    if (nowOffline != _isOffline) {
      setState(() => _isOffline = nowOffline);
      if (nowOffline) {
        _animController.forward();
      } else {
        _animController.reverse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _slideAnim,
      builder: (context, _) {
        if (_slideAnim.value <= -1 && !_isOffline) {
          return const SizedBox.shrink();
        }
        return FractionalTranslation(
          translation: Offset(0, _slideAnim.value),
          child: const Material(
            color: Colors.transparent,
            child: _BannerContent(),
          ),
        );
      },
    );
  }
}

class _BannerContent extends StatelessWidget {
  const _BannerContent();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFFC62828),
      child: const Row(
        children: [
          Icon(Icons.wifi_off, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'No internet connection — showing cached data',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
