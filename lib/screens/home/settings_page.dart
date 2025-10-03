import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.push('/home/settings/notifications'),
              child: const ListTile(
                title: Text('Уведомления'),
                trailing: Icon(Icons.chevron_right),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

