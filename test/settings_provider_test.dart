import 'package:analog_pico_monitor/providers/settings_provider.dart';
import 'package:analog_pico_monitor/services/storage_service.dart';
import 'package:analog_pico_monitor/utils/constants.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SettingsProvider> _freshProvider() async {
  SharedPreferences.setMockInitialValues({});
  final provider = SettingsProvider(StorageService());
  await provider.load();
  return provider;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('usa los valores por defecto sin configuracion guardada', () async {
    final provider = await _freshProvider();
    expect(provider.settings.pollIntervalMs, AppDefaults.pollIntervalMs);
    expect(provider.settings.host, AppDefaults.host);
    expect(provider.settings.useMock, isTrue);
  });

  test('persiste el intervalo de polling despues de cerrar la app', () async {
    var provider = await _freshProvider();
    await provider.save(provider.settings.copyWith(pollIntervalMs: 2000));

    // Simula un reinicio de la aplicacion con otra instancia.
    provider = SettingsProvider(StorageService());
    await provider.load();

    expect(provider.settings.pollIntervalMs, 2000);
  });

  test('la configuracion de polling configurable se guarda en el storage',
      () async {
    final provider = await _freshProvider();
    await provider.save(provider.settings.copyWith(pollIntervalMs: 3500));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(StorageKeys.pollIntervalMs), 3500);
  });

  test('persiste host, timeout y modo real/simulacion', () async {
    var provider = await _freshProvider();
    await provider.save(
      provider.settings.copyWith(
        host: '192.168.1.50',
        timeoutMs: 5000,
        useMock: false,
      ),
    );

    provider = SettingsProvider(StorageService());
    await provider.load();

    expect(provider.settings.host, '192.168.1.50');
    expect(provider.settings.timeoutMs, 5000);
    expect(provider.settings.useMock, isFalse);
  });

  test('persiste los parametros de conversion RAW -> voltaje', () async {
    var provider = await _freshProvider();
    await provider.save(
      provider.settings.copyWith(adcMax: 65535, referenceVoltage: 5.0),
    );

    provider = SettingsProvider(StorageService());
    await provider.load();

    expect(provider.settings.adcMax, 65535);
    expect(provider.settings.referenceVoltage, 5.0);
  });
}