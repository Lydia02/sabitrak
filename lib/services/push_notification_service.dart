import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'firebase_service.dart';

/// Handles FCM push notifications:
///   - Requests permission on first launch
///   - Saves the FCM token to Firestore so Cloud Functions can target this device
///   - Refreshes the token whenever Firebase rotates it
///   - Shows an in-app banner for foreground messages
class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseService _firebase = FirebaseService();

  // Global navigator key so we can show overlays from anywhere
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  // ── Initialise ─────────────────────────────────────────────────────────────

  Future<void> init() async {
    // 1. Create the Android notification channel (Android 8+)
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 2. Request permission (Android 13+, iOS)
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // 3. Save token for the currently signed-in user
    await _saveToken();

    // 4. Listen for token refreshes (device changes, app reinstalls, etc.)
    _fcm.onTokenRefresh.listen((token) => _updateToken(token));

    // 5. Foreground message handler — show in-app banner
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 6. Background/terminated tap handler — app opened from notification
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // 7. Check if app was launched via a notification while terminated
    final initial = await _fcm.getInitialMessage();
    if (initial != null) _handleNotificationTap(initial);
  }

  // ── Token management ───────────────────────────────────────────────────────

  Future<void> _saveToken() async {
    final uid = _firebase.currentUser?.uid;
    if (uid == null) return;
    final token = await _fcm.getToken();
    if (token == null) return;
    await _updateToken(token);
  }

  Future<void> _updateToken(String token) async {
    final uid = _firebase.currentUser?.uid;
    if (uid == null) return;
    try {
      await _firebase.users.doc(uid).set(
        {'fcmToken': token, 'fcmUpdatedAt': Timestamp.now()},
        SetOptions(merge: true),
      );
    } catch (_) {}
  }

  /// Call this after sign-out to remove the token so this device no longer
  /// receives notifications for the signed-out user.
  Future<void> clearToken() async {
    final uid = _firebase.currentUser?.uid;
    if (uid == null) return;
    try {
      await _firebase.users.doc(uid).update({
        'fcmToken': FieldValue.delete(),
        'fcmUpdatedAt': FieldValue.delete(),
      });
      await _fcm.deleteToken();
    } catch (_) {}
  }

  // ── Foreground handler ─────────────────────────────────────────────────────

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    final title = notification.title ?? 'SabiTrak';
    final body = notification.body ?? '';
    final data = message.data;

    _showInAppBanner(title: title, body: body, data: data);
  }

  void _handleNotificationTap(RemoteMessage message) {
    // Navigate based on payload type if needed in the future
    // For now, just bring app to foreground (default Flutter behaviour)
  }

  // ── In-app banner overlay ─────────────────────────────────────────────────

  void _showInAppBanner({
    required String title,
    required String body,
    Map<String, dynamic> data = const {},
  }) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _InAppBanner(
        title: title,
        body: body,
        onDismiss: () => entry.remove(),
      ),
    );
    overlay.insert(entry);

    // Auto-dismiss after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      if (entry.mounted) entry.remove();
    });
  }
}

// ── In-app notification banner widget ─────────────────────────────────────────

class _InAppBanner extends StatefulWidget {
  final String title;
  final String body;
  final VoidCallback onDismiss;

  const _InAppBanner({
    required this.title,
    required this.body,
    required this.onDismiss,
  });

  @override
  State<_InAppBanner> createState() => _InAppBannerState();
}

class _InAppBannerState extends State<_InAppBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));
    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slide,
        child: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(14),
          color: const Color(0xFF1B5E20),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: widget.onDismiss,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.eco, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        if (widget.body.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: widget.onDismiss,
                    child: const Icon(Icons.close,
                        color: Colors.white70, size: 16),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
