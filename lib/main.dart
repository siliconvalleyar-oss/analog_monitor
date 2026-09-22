/// Punto de entrada de la aplicacion.
///
/// Prepara el almacenamiento, carga la configuracion guardada y construye el
/// arbol de providers antes de lanzar la interfaz.
library;

import 'package:flutter/material.dart';

import 'app.dart';
import 'providers/device_provider.dart';
import 'providers/measurement_provider.dart';
import 'providers/settings_provider.dart';
import 'repositories/measurement_repository.dart';
import 'services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = StorageService();
  final settingsProvider = SettingsProvider(storage);
  await settingsProvider.load();

  final repository = MeasurementRepository(settingsProvider, storage);
  final deviceProvider = DeviceProvider(settingsProvider, repository);
  final measurementProvider = MeasurementProvider(settingsProvider, repository);
  // El proveedor de graficos observa las mediciones que llegan por polling.
  measurementProvider.attach(deviceProvider);

  runApp(
    AnalogPicoApp(
      settingsProvider: settingsProvider,
      deviceProvider: deviceProvider,
      measurementProvider: measurementProvider,
    ),
  );
}