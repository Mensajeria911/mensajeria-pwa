import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_state.dart';
import 'app_config.dart';
import 'repository.dart';
import 'screens/account_screen.dart';
import 'screens/admin_screen.dart';
import 'screens/admin_operations_screen.dart';
import 'screens/earnings_screen.dart';
import 'screens/home_screen.dart';
import 'screens/incoming_sheet.dart';
import 'screens/login_screen.dart';
import 'theme.dart';
import 'widgets/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!AppConfig.hasValidSupabase) {
    runApp(_MissingConfigApp(message: AppConfig.configurationMessage));
    return;
  }
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
  );
  final state = AppState(CourierRepository(Supabase.instance.client));
  runApp(CourierApp(state: state));
  unawaited(state.start());
}

class CourierApp extends StatelessWidget {
  const CourierApp({required this.state, super.key});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder:
          (context, _) => MaterialApp(
            title: 'Mensajeros 911',
            debugShowCheckedModeBanner: false,
            theme: buildTheme(Brightness.light),
            darkTheme: buildTheme(Brightness.dark),
            themeMode: state.themeMode,
            home: switch (state.phase) {
              AppPhase.loading => const _LoadingScreen(),
              AppPhase.signedOut => LoginScreen(state: state),
              AppPhase.blocked => BlockedScreen(state: state),
              AppPhase.ready =>
                state.isAdmin
                    ? AdminShell(state: state)
                    : CourierShell(state: state),
            },
          ),
    );
  }
}

class CourierShell extends StatefulWidget {
  const CourierShell({required this.state, super.key});
  final AppState state;

  @override
  State<CourierShell> createState() => _CourierShellState();
}

class _CourierShellState extends State<CourierShell>
    with WidgetsBindingObserver {
  var _tab = 0;
  String? _sheetFor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.state.addListener(_maybeShowIncoming);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.state.removeListener(_maybeShowIncoming);
    super.dispose();
  }

  // Al volver a la app se sincroniza por si algo cambió mientras estaba cerrada.
  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    unawaited(widget.state.handleLifecycle(lifecycle));
  }

  void _maybeShowIncoming() {
    final service = widget.state.incoming;
    if (service == null || _sheetFor == service.id || !mounted) return;
    _sheetFor = service.id;
    setState(() => _tab = 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showIncomingSheet(context, widget.state, service);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final pages = [
      HomeScreen(state: s),
      EarningsScreen(state: s),
      AccountScreen(state: s),
    ];
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (s.error != null)
              Material(
                color: context.palette.dangerWash,
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.wifi_off, color: context.palette.danger),
                  title: Text(
                    s.error!,
                    style: TextStyle(
                      color: context.palette.danger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: TextButton(
                    onPressed: s.refresh,
                    child: const Text('Reintentar'),
                  ),
                ),
              ),
            Expanded(child: IndexedStack(index: _tab, children: pages)),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
            icon: Badge(
              isLabelVisible: s.active.isNotEmpty,
              label: Text('${s.active.length}'),
              child: const Icon(Icons.route_outlined),
            ),
            selectedIcon: const Icon(Icons.route),
            label: 'Domicilios',
          ),
          const NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Ganancias',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Mi cuenta',
          ),
        ],
      ),
    );
  }
}

/// Panel básico de administración dentro de la misma APK.
class AdminShell extends StatefulWidget {
  const AdminShell({required this.state, super.key});
  final AppState state;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  var _tab = 0;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (state.error != null)
              Material(
                color: context.palette.dangerWash,
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.wifi_off, color: context.palette.danger),
                  title: Text(
                    state.error!,
                    style: TextStyle(
                      color: context.palette.danger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: TextButton(
                    onPressed: state.refresh,
                    child: const Text('Reintentar'),
                  ),
                ),
              ),
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: [
                  AdminEarningsScreen(state: state),
                  AdminUsersScreen(state: state),
                  AdminRatesScreen(state: state),
                  AdminLocationsScreen(state: state),
                  AccountScreen(state: state),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.trending_up),
            label: 'Ganancias',
          ),
          NavigationDestination(
            icon: Icon(Icons.group_outlined),
            selectedIcon: Icon(Icons.group),
            label: 'Usuarios',
          ),
          NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            selectedIcon: Icon(Icons.payments),
            label: 'Tarifas',
          ),
          NavigationDestination(
            icon: Icon(Icons.location_on_outlined),
            selectedIcon: Icon(Icons.location_on),
            label: 'Ubicación',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Mi cuenta',
          ),
        ],
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BrandMark(size: 72),
          const SizedBox(height: 18),
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: context.palette.primary,
            ),
          ),
        ],
      ),
    ),
  );
}

class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildTheme(Brightness.light),
    home: Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Text(
            '$message Vuelve a compilar con SUPABASE_URL y SUPABASE_ANON_KEY.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
  );
}
