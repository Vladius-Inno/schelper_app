import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'theme.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_page.dart';
import 'screens/auth/register_page.dart';
import 'screens/home/home_page.dart';
import 'screens/home/profile_page.dart';
import 'screens/home/notifications_settings_page.dart';
import 'services/notification_scheduler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize notifications and reschedule in the background to avoid
  // blocking the first frame (splash → Flutter UI transition).
  // Any failures are ignored so startup isn't affected.
  // ignore: discarded_futures
  NotificationScheduler.init()
      .then((_) => NotificationScheduler.rescheduleFromPrefs())
      .catchError((_) {});
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
