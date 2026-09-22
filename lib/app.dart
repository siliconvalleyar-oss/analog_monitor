/// Definicion de la aplicacion: tema, localizacion e inyeccion de providers.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'providers/device_provider.dart';
import 'providers/measurement_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/home_shell.dart';

class AnalogPicoApp extends StatelessWidget {
  const AnalogPicoApp({
    super.key,
    required this.settingsProvider,
    required this.deviceProvider,
    required this.measurementProvider,
  });

  final SettingsProvider settingsProvider;
  final DeviceProvider deviceProvider;
  final MeasurementProvider measurementProvider;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settingsProvider),
        ChangeNotifierProvider.value(value: deviceProvider),
        ChangeNotifierProvider.value(value: measurementProvider),
      ],
      child: MaterialApp(
        title: 'Analog Pico Monitor',
        debugShowCheckedModeBanner: false,
        locale: const Locale('es'),
        supportedLocales: const [
          Locale('es'),
          Locale('en'),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFF00696D),
          brightness: Brightness.light,
        ),
        darkTheme: ThemeData(
          colorSchemeSeed: const Color(0xFF00696D),
          brightness: Brightness.dark,
        ),
        themeMode: ThemeMode.system,
        home: const HomeShell(),
      ),
    );
  }
}