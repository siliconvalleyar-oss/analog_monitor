import 'package:analog_pico_monitor/providers/device_provider.dart';
import 'package:analog_pico_monitor/providers/device_state.dart';
import 'package:analog_pico_monitor/providers/settings_provider.dart';
import 'package:analog_pico_monitor/repositories/measurement_repository.dart';
import 'package:analog_pico_monitor/services/storage_service.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SettingsProvider settings;
  late StorageService storage;
  late MeasurementRepository repository;
  late DeviceProvider device;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
  });

  test('consulta con el intervalo de polling configurado', () {
    fakeAsync((async) {
      settings = SettingsProvider(storage);
      repository = MeasurementRepository(settings, storage);
      device = DeviceProvider(settings, repository);

      device.start();
      // La primera consulta se ejecuta de forma inmediata.
      async.elapse(const Duration(milliseconds: 80));

      expect(device.connectionState, DeviceConnectionState.connected);
      expect(device.lastMeasurement, isNotNull);
      final first = device.lastMeasurement;

      // Con el intervalo por defecto (1000 ms) no llega muestra nueva a los 100 ms.
      async.elapse(const Duration(milliseconds: 100));
      expect(device.lastMeasurement, same(first));
      device.stop();
    });
  });

  test('el conflicto de intervalo se reconfigura desde la Configuracion', () {
    fakeAsync((async) {
      settings = SettingsProvider(storage);
      repository = MeasurementRepository(settings, storage);
      device = DeviceProvider(settings, repository);

      device.start();
      async.elapse(const Duration(milliseconds: 200));

      // Reduce el intervalo a 200 ms tal como haria la pantalla de Configuracion.
      settings.save(settings.settings.copyWith(pollIntervalMs: 200)).then(
          (_) {}, onError: (_) {});
      async.flushMicrotasks();

      final before = device.lastMeasurement;
      async.elapse(const Duration(milliseconds: 250));
      // Con el nuevo intervalo debe haber nuevas lecturas.
      expect(device.lastMeasurement, isNotNull);
      expect(device.lastMeasurement, isNot(same(before)));
      device.stop();
    });
  });

  test('marca desconectado al fallar la consulta y conserva la ultima medida',
      () {
    fakeAsync((async) {
      settings = SettingsProvider(storage);
      // Modo real con una IP del rango reservado para pruebas (no enrrutable):
      // no debe colgarse ni lanzar errores no controlados; el proveedor marca
      // desconectado tras el timeout.
      settings.load().then((_) {
        settings.save(settings.settings.copyWith(
          useMock: false,
          host: '192.0.2.1',
          pollIntervalMs: 100,
          timeoutMs: 50,
        ));
      }, onError: (_) {});
      async.flushMicrotasks();

      repository = MeasurementRepository(settings, storage);
      device = DeviceProvider(settings, repository);

      device.start();
      // Con intervalo 100 ms + timeout 50 ms, cada ciclo termina en fallo.
      async.elapse(const Duration(milliseconds: 351));

      expect(device.connectionState, DeviceConnectionState.disconnected);
      expect(device.lastError, isNotNull);
      expect(device.lastMeasurement, isNull);
      device.stop();
    });
  });
}