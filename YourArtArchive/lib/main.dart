import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'database/database_helper.dart';
import 'models/user_model.dart';
import 'pages/app_shell.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/splash_page.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => const YourArtArchiveApp();
}

enum _EntryPage { splash, login, register }

class YourArtArchiveApp extends StatefulWidget {
  const YourArtArchiveApp({super.key, this.authService});

  final AuthService? authService;

  @override
  State<YourArtArchiveApp> createState() => _YourArtArchiveAppState();
}

class _YourArtArchiveAppState extends State<YourArtArchiveApp> {
  late final AuthService _authService;
  Future<void>? _webDatabaseReady;
  _EntryPage _entryPage = _EntryPage.splash;
  UserModel? _user;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
    if (kIsWeb) {
      _webDatabaseReady = DatabaseHelper.instance.database.then((_) {});
    }
  }

  void _show(_EntryPage page) => setState(() => _entryPage = page);

  void _authenticated(UserModel user) {
    setState(() => _user = user);
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (!mounted) return;
    setState(() {
      _user = null;
      _entryPage = _EntryPage.splash;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final Widget home;
    if (user != null) {
      home = AppShell(user: user, onLogout: _logout);
    } else {
      home = switch (_entryPage) {
        _EntryPage.splash => SplashPage(
          onLogin: () => _show(_EntryPage.login),
          onRegister: () => _show(_EntryPage.register),
        ),
        _EntryPage.login => LoginPage(
          authService: _authService,
          onAuthenticated: _authenticated,
          onRegister: () => _show(_EntryPage.register),
          onBack: () => _show(_EntryPage.splash),
        ),
        _EntryPage.register => RegisterPage(
          authService: _authService,
          onAuthenticated: _authenticated,
          onLogin: () => _show(_EntryPage.login),
          onBack: () => _show(_EntryPage.splash),
        ),
      };
    }

    final app = MaterialApp(
      title: 'YourArtArchive',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        child: KeyedSubtree(
          key: ValueKey(user == null ? _entryPage : user.id),
          child: home,
        ),
      ),
    );

    final webDatabaseReady = _webDatabaseReady;
    if (webDatabaseReady == null) return app;

    return FutureBuilder<void>(
      future: webDatabaseReady,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return MaterialApp(
            title: 'YourArtArchive',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            home: _DatabaseErrorPage(
              onRetry: () {
                setState(() {
                  _webDatabaseReady = DatabaseHelper.instance.database.then(
                    (_) {},
                  );
                });
              },
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return MaterialApp(
            title: 'YourArtArchive',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            home: const _ArchiveLoadingPage(),
          );
        }
        return app;
      },
    );
  }
}

class _ArchiveLoadingPage extends StatelessWidget {
  const _ArchiveLoadingPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: SizedBox.square(
          dimension: 28,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }
}

class _DatabaseErrorPage extends StatelessWidget {
  const _DatabaseErrorPage({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.inventory_2_outlined, size: 44),
                const SizedBox(height: 20),
                Text(
                  'Your archive could not be opened',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 10),
                Text(
                  'Check this site’s storage permissions, then try again.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
