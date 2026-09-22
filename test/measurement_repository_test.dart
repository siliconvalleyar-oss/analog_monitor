import 'package:analog_pico_monitor/models/analog_measurement.dart';
import 'package:analog_pico_monitor/providers/settings_provider.dart';
import 'package:analog_pico_monitor/repositories/measurement_repository.dart';
import 'package:analog_pico_monitor/services/api_service.dart';
import 'package:analog_pico_monitor/services/mock_api_service.dart';
import 'package:analog_pico_monitor/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SettingsProvider settings;
  late StorageService storage;
  late MeasurementRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = SettingsProvider(storage = StorageService());
    await settings.load();
    // Modo simulacion: genera datos sin necesidad de la Pico real.
    await settings.save(settings.settings.copyWith(useMock: true));
    repository = MeasurementRepository(settings, storage);
  });

  tearDown(() {
    repository.dispose();
  });

  Future<AnalogMeasurement> fetchMock() => repository.fetchAnalog();

  test('consulta mediciones a traves de la API simulada', () async {
    final measurement = await fetchMock();
    expect(measurement.channels, hasLength(settings.settings.channelCount));
  });

  test('guarda mediciones en el historial al habilitar el registro', () async {
    final measurement = await fetchMock();
    await repository.saveMeasurement(measurement);

    final history = await repository.loadHistory();
    expect(history, hasLength(measurement.channels.length));
  });

  test('no guarda cuando el registro esta desactivado', () async {
    await settings.save(settings.settings.copyWith(enableLogging: false));
    final measurement = await fetchMock();
    await repository.saveMeasurement(measurement);

    expect(await repository.loadHistory(), isEmpty);
  });

  test('filtra por canal', () async {
    await repository.saveMeasurement(await fetchMock());
    final history = await repository.loadHistory(channel: 0);

    expect(history, isNotEmpty);
    expect(history.every((s) => s.channel == 0), isTrue);
  });

  test('filtra por rango temporal', () async {
    await repository.saveMeasurement(await fetchMock());
    final history = await repository.loadHistory(
      from: DateTime.now().add(const Duration(days: 1)),
    );

    expect(history, isEmpty);
  });

  test('borra el historial', () async {
    await repository.saveMeasurement(await fetchMock());
    expect(await repository.historyCount(), greaterThan(0));

    await repository.clearHistory();

    expect(await repository.historyCount(), 0);
    expect(await repository.loadHistory(), isEmpty);
  });

  test('ignora registros corruptos sin romper la carga', () async {
    await storage.writeStringList('measurement_history', [
      '{"invalid json',
      '{"timestamp":1,"channel":0,"raw":10,"voltage":1.0}',
    ]);

    final history = await repository.loadHistory();
    expect(history, hasLength(1));
  });

  test('cambia la capa de red segun el modo', () async {
    final mockApi = repository.api;
    expect(mockApi, isA<MockApiService>());

    await settings.save(settings.settings.copyWith(useMock: false));
    final httpApi = repository.api;
    expect(httpApi, isA<HttpApiService>());
  });
}