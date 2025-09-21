import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const CircleAvatar(radius: 36, child: Icon(Icons.person, size: 36)),
            const SizedBox(height: 16),
            Text('Имя пользователя', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('email@example.com', style: Theme.of(context).textTheme.bodyMedium),
            const Spacer(),
            ElevatedButton(
              onPressed: () async {
                await auth.logout();
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('Выйти'),
            ),
          ],
        ),
      ),
    );
  }
}
