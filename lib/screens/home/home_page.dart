import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../store/tasks_store.dart';
import '../tasks/tasks_page.dart';
import 'settings_page.dart';

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
      const _PageWrap(
        title: '�����',
        child: _PlaceholderCard(text: '���� ᪮� �㤥�!'),
      ),
      const _TasksTab(),
      const SettingsPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_index == 2 ? 'Настройки' : '�����窠'),
        actions: [
          if (_index == 1)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => tasksStore.reloadCurrentWeek(),
              tooltip: '�������� �����',
            ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/home/profile'),
            tooltip: '��䨫�',
          ),
        ],
      ),
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '�����',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: '�����',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '����ன��',
          ),
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
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
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

class _TasksTab extends StatelessWidget {
  const _TasksTab();
  @override
  Widget build(BuildContext context) {
    return const TasksPage();
  }
}

