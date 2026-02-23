import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'config/theme/app_theme.dart';
import 'config/theme/theme_notifier.dart';
import 'presentation/screens/splash/splash_screen.dart';
import 'services/push_notification_service.dart';

/// Background message handler — must be a top-level function (not a closure).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialised by the time this is called.
  // FCM displays the notification automatically from the system tray.
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Register background message handler before runApp
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await ThemeNotifier.instance.init();

  runApp(const SabiTrakApp());
}

class SabiTrakApp extends StatelessWidget {
  const SabiTrakApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeNotifier.instance,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'SabiTrak',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          // Global navigator key so PushNotificationService can show banners
          navigatorKey: PushNotificationService.navigatorKey,
          home: const SplashScreen(),
        );
      },
    );
  }
}
