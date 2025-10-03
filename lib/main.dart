import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'theme.dart';
import 'package:flutter/foundation.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_page.dart';
import 'screens/auth/register_page.dart';
import 'screens/home/home_page.dart';
import 'screens/home/profile_page.dart';
import 'screens/home/notifications_settings_page.dart';
import 'services/notification_scheduler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
WidgetsBinding.instance.addPostFrameCallback((_) {
  // ignore: discarded_futures
  Future(() async {
    debugPrint('NotificationScheduler: kickoff init/reschedule (post-frame)');
    try {
      await NotificationScheduler.init();
      await NotificationScheduler.rescheduleFromPrefs();
      debugPrint('NotificationScheduler: init/reschedule finished');
    } catch (e) {
      debugPrint('NotificationScheduler: init/reschedule failed: ' + e.toString());
    }
  });
});
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: '/auth/login',
          builder: (context, state) => const LoginPage(),
        ),
        GoRoute(
          path: '/auth/register',
          builder: (context, state) => const RegisterPage(),
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomePage(),
          routes: [
            GoRoute(
              path: 'profile',
              builder: (context, state) => const ProfilePage(),
            ),
            GoRoute(
              path: 'settings/notifications',
              builder: (context, state) => const NotificationsSettingsPage(),
            ),
          ],
        ),
      ],
    );

    return MaterialApp.router(
      title: 'Домашечка',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      routerConfig: router,
    );
  }
}
