/// Navegacion principal de la aplicacion.
///
/// Mantiene las cuatro pantallas en un [IndexedStack] y gestiona el ciclo de
/// vida de la aplicacion para pausar el polling al pasar a segundo plano y
/// reanudarlo al volver al frente.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/device_provider.dart';
import 'charts_screen.dart';
import 'dashboard_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final List<Widget> _screens = const [
    DashboardScreen(),
    ChartsScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  int _index = 0;
  late final AppLifecycleListener _lifecycleListener;
  DeviceProvider? _device;

  @override
  void initState() {
    super.initState();
    _device = context.read<DeviceProvider>();
    _device!.start();
    _lifecycleListener = AppLifecycleListener(
      onPause: _device!.pause,
      onHide: _device!.pause,
      onResume: _device!.resume,
      onShow: _device!.resume,
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    _device?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.show_chart_outlined),
            selectedIcon: Icon(Icons.show_chart),
            label: 'Graficos',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Historial',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Configuracion',
          ),
        ],
      ),
    );
  }
}