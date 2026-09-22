/// Repositorio de mediciones.
///
/// Punto unico de acceso a los datos de la Pico: consulta la API HTTP y
/// persiste/consulta el historial local. Separa la UI y los providers de los
/// detalles concretos de red y almacenamiento.
library;

import 'dart:convert';

import '../models/analog_measurement.dart';
import '../models/device_status.dart';
import '../models/measurement_sample.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../services/mock_api_service.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';

class MeasurementRepository {
  MeasurementRepository(this._settings, this._storage) {
    _api = _buildApi();
    _settings.addListener(_onSettingsChanged);
  }

  final SettingsProvider _settings;
  final StorageService _storage;
  late ApiService _api;

  /// Construye la capa de comunicacion segun la configuracion actual.
  ApiService _buildApi() {
    final s = _settings.settings;
    if (s.useMock) {
      return MockApiService(
        host: s.host,
        channelCount: s.channelCount,
        adcMax: s.adcMax,
        referenceVoltage: s.referenceVoltage,
      );
    }
    return HttpApiService(
      host: s.host,
      port: s.port,
      timeout: Duration(milliseconds: s.timeoutMs),
    );
  }

  void _onSettingsChanged() {
    _api = _buildApi();
  }

  /// Capa de comunicacion actual (real o simulada).
  ApiService get api => _api;

  /// Consulta el estado del dispositivo.
  Future<DeviceStatus> fetchDeviceStatus() => _api.fetchDeviceStatus();

  /// Consulta todas las mediciones analogicas.
  Future<AnalogMeasurement> fetchAnalog() => _api.fetchAnalogMeasurement();

  /// Guarda una medicion en el historial local (si el registro esta activado).
  Future<void> saveMeasurement(AnalogMeasurement measurement) async {
    final s = _settings.settings;
    if (!s.enableLogging) {
      return;
    }

    final existing = await _storage.readStringList(StorageKeys.history) ?? [];
    final rows = <String>[...existing];

    for (final channel in measurement.channels) {
      final sample = MeasurementSample(
        timestamp: measurement.timestampDate,
        channel: channel.channel,
        gpio: channel.gpio,
        raw: channel.raw,
        voltage: channel.resolvedVoltage(
          adcMax: s.adcMax,
          referenceVoltage: s.referenceVoltage,
        ),
      );
      rows.add(jsonEncode(sample.toJson()));
    }

    if (rows.length > AppDefaults.maxHistoryEntries) {
      rows.removeRange(0, rows.length - AppDefaults.maxHistoryEntries);
    }

    await _storage.writeStringList(StorageKeys.history, rows);
  }

  /// Consulta el historial, opcionalmente filtrado por canal y rango temporal.
  ///
  /// Devuelve las muestras ordenadas por fecha ascendente.
  Future<List<MeasurementSample>> loadHistory({
    int? channel,
    DateTime? from,
    DateTime? to,
  }) async {
    final rows = await _storage.readStringList(StorageKeys.history) ?? [];
    final samples = <MeasurementSample>[];

    for (final row in rows) {
      try {
        final decoded = jsonDecode(row);
        if (decoded is! Map<String, dynamic>) {
          continue;
        }
        samples.add(
          MeasurementSample.fromJson(Map<String, dynamic>.from(decoded)),
        );
      } on FormatException {
        // Registros corruptos se ignoran para no romper el historial.
        continue;
      }
    }

    return samples
        .where((sample) {
          if (channel != null && sample.channel != channel) {
            return false;
          }
          if (from != null && sample.timestamp.isBefore(from)) {
            return false;
          }
          if (to != null && sample.timestamp.isAfter(to)) {
            return false;
          }
          return true;
        })
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  /// Elimina todo el historial de mediciones.
  Future<void> clearHistory() async {
    await _storage.writeStringList(StorageKeys.history, <String>[]);
  }

  /// Numero total de registros guardados en el historial.
  Future<int> historyCount() async {
    final rows = await _storage.readStringList(StorageKeys.history) ?? [];
    return rows.length;
  }

  /// Libera la suscripcion a cambios de configuracion.
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
  }
}