import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final auth = AuthService();
    // brief splash delay for UX
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final token = await auth.getAccessToken();
    if (token != null) {
      if (!mounted) return;
      context.go('/home');
      return;
    }
    final newToken = await auth.refreshToken();
    if (newToken != null) {
      if (!mounted) return;
      context.go('/home');
      return;
    }
    if (!mounted) return;
    context.go('/auth/login');
  }

  @override
  Widget build(BuildContext context) {
    // This is shown after native splash fades; keep branding consistent
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.school, size: 64, color: Color(0xFF3B82F6)),
            const SizedBox(height: 16),
            Text(
              'Домашечка',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
