/// Proveedor de mediciones: series en memoria para graficos e historial.
///
/// Escucha al [DeviceProvider] para ir acumulando muestras en una serie por
/// canal (buffer circular) utilizada por la pantalla de graficos, y expone el
/// acceso al historial persistido a traves del [MeasurementRepository].
library;

import 'package:flutter/foundation.dart';

import '../models/analog_measurement.dart';
import '../models/measurement_sample.dart';
import '../repositories/measurement_repository.dart';
import '../utils/constants.dart';
import 'device_provider.dart';
import 'settings_provider.dart';

class MeasurementProvider extends ChangeNotifier {
  MeasurementProvider(this._settings, this._repository);

  final SettingsProvider _settings;
  final MeasurementRepository _repository;

  final Map<int, List<MeasurementSample>> _series = {};
  DeviceProvider? _device;
  AnalogMeasurement? _lastSeen;
  bool _attached = false;

  /// Series de voltaje por canal, con muestras ordenadas por fecha.
  Map<int, List<MeasurementSample>> get series => _series;

  /// Serie de un canal concreto (o `null` si aun no tiene muestras).
  List<MeasurementSample>? seriesForChannel(int channel) => _series[channel];

  /// Cantidad de muestras acumuladas en memoria.
  int get inMemoryCount =>
      _series.values.fold<int>(0, (sum, list) => sum + list.length);

  /// Suscribe el proveedor a las mediciones del dispositivo. Idempotente.
  void attach(DeviceProvider device) {
    if (_attached) {
      return;
    }
    _attached = true;
    _device = device;
    device.addListener(_onDeviceChanged);
  }

  void _onDeviceChanged() {
    final measurement = _device?.lastMeasurement;
    if (measurement == null || identical(measurement, _lastSeen)) {
      return;
    }
    _lastSeen = measurement;
    final s = _settings.settings;

    for (final channel in measurement.channels) {
      _append(MeasurementSample(
        timestamp: measurement.timestampDate,
        channel: channel.channel,
        gpio: channel.gpio,
        raw: channel.raw,
        voltage: channel.resolvedVoltage(
          adcMax: s.adcMax,
          referenceVoltage: s.referenceVoltage,
        ),
      ));
    }

    notifyListeners();
  }

  void _append(MeasurementSample sample) {
    final list = _series.putIfAbsent(sample.channel, () => <MeasurementSample>[]);
    list.add(sample);
    if (list.length > AppDefaults.maxInMemorySamples) {
      list.removeAt(0);
    }
  }

  // ---------------------------------------------------------------- Historial

  /// Consulta el historial con filtros opcionales.
  Future<List<MeasurementSample>> loadHistory({
    int? channel,
    DateTime? from,
    DateTime? to,
  }) =>
      _repository.loadHistory(channel: channel, from: from, to: to);

  /// Numero de registros conservados en el historial local.
  Future<int> historyCount() => _repository.historyCount();

  /// Borra todo el historial local.
  Future<void> clearHistory() => _repository.clearHistory();

  @override
  void dispose() {
    _device?.removeListener(_onDeviceChanged);
    super.dispose();
  }
}