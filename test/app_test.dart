import 'package:analog_pico_monitor/app.dart';
import 'package:analog_pico_monitor/providers/device_provider.dart';
import 'package:analog_pico_monitor/providers/measurement_provider.dart';
import 'package:analog_pico_monitor/providers/settings_provider.dart';
import 'package:analog_pico_monitor/repositories/measurement_repository.dart';
import 'package:analog_pico_monitor/services/storage_service.dart';
import 'package:analog_pico_monitor/widgets/analog_channel_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('la app arranca y muestra el dashboard en modo simulacion',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    final settings = SettingsProvider(storage);
    final repository = MeasurementRepository(settings, storage);
    final device = DeviceProvider(settings, repository);
    final measurements = MeasurementProvider(settings, repository);
    measurements.attach(device);
    await settings.load();

    await tester.pumpWidget(
      AnalogPicoApp(
        settingsProvider: settings,
        deviceProvider: device,
        measurementProvider: measurements,
      ),
    );
    await tester.pump();
    // Deja tiempo a la primera consulta simulada (30 ms) para completarse.
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.text('Conectado'), findsOneWidget);
    expect(find.text('CANAL 0'), findsOneWidget);
    expect(find.byType(AnalogChannelCard), findsWidgets);

    device.stop();
  });

  testWidgets('la navegacion muestra las cuatro pantallas', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    final settings = SettingsProvider(storage);
    final repository = MeasurementRepository(settings, storage);
    final device = DeviceProvider(settings, repository);
    final measurements = MeasurementProvider(settings, repository);
    measurements.attach(device);
    await settings.load();

    await tester.pumpWidget(
      AnalogPicoApp(
        settingsProvider: settings,
        deviceProvider: device,
        measurementProvider: measurements,
      ),
    );
    await tester.pump();

    Finder navLabel(String label) => find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        );

    expect(find.text('Dashboard'), findsWidgets);

    await tester.tap(navLabel('Graficos'));
    await tester.pumpAndSettle();
    expect(find.text('Canales'), findsOneWidget);

    await tester.tap(navLabel('Historial'));
    await tester.pumpAndSettle();
    expect(find.text('Rango temporal'), findsOneWidget);

    await tester.tap(navLabel('Configuracion'));
    await tester.pumpAndSettle();
    expect(find.text('IP de la Pico'), findsOneWidget);

    device.stop();
  });
}