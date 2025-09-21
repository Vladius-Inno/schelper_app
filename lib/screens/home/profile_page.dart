import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';
import '../../services/authorized_api_client.dart';
import '../../services/api_client.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _api = AuthorizedApiClient();
  final _auth = AuthService();

  Map<String, dynamic>? _user;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final me = await _api.getJson('/users/me');
      if (!mounted) return;
      setState(() {
        _user = me;
      });
    } on ApiException catch (e) {
      if (e.statusCode == 401 && mounted) {
        context.go('/auth/login');
        return;
      }
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!, style: Theme.of(context).textTheme.bodyLarge))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const CircleAvatar(radius: 36, child: Icon(Icons.person, size: 36)),
                      const SizedBox(height: 16),
                      if (_user != null) ...[
                        Text(_user!['name']?.toString() ?? '-',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        Text(_user!['email']?.toString() ?? '-',
                            style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: 8),
                        Chip(
                          label: Text('Роль: ${_user!['role'] ?? '-'}'),
                          avatar: const Icon(Icons.badge, size: 18),
                        ),
                      ],
                      const Spacer(),
                      ElevatedButton(
                        onPressed: () async {
                          await _auth.logout();
                          if (!mounted) return;
                          context.go('/auth/login');
                        },
                        child: const Text('Выйти'),
                      ),
                    ],
                  ),
      ),
    );
  }
}
