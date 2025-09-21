import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _PageWrap(title: 'Лента', child: _PlaceholderCard(text: 'Добро пожаловать!')),
      _PageWrap(title: 'Задачи', child: _PlaceholderCard(text: 'Ваши задания здесь')),
      _PageWrap(title: 'Настройки', child: _PlaceholderCard(text: 'Настройки приложения')),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Домашечка'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/home/profile'),
            tooltip: 'Профиль',
          ),
        ],
      ),
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Домой'),
          NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment), label: 'Задачи'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Настройки'),
        ],
      ),
    );
  }
}

class _PageWrap extends StatelessWidget {
  final String title;
  final Widget child;
  const _PageWrap({required this.title, required this.child});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _PlaceholderCard extends StatelessWidget {
  final String text;
  const _PlaceholderCard({required this.text});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Center(
        child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
      ),
    );
  }
}

