/// Implementacion simulada de [ApiService].
///
/// Genera varios canales analogicos con valores que cambian con el tiempo
/// (ondas senoidal + ruido) para poder desarrollar y probar la aplicacion sin
/// tener conectada fisicamente la Raspberry Pi Pico W.
library;

import 'dart:math';

import '../models/analog_channel.dart';
import '../models/analog_measurement.dart';
import '../models/device_status.dart';
import '../utils/formatters.dart';
import 'api_service.dart';

class MockApiService implements ApiService {
  /// IP configurada por el usuario (se muestra como si fuera del Pico).
  final String host;

  /// Cantidad de canales simulados.
  final int channelCount;

  /// Valor maximo del ADC.
  final int adcMax;

  /// Voltaje de referencia.
  final double referenceVoltage;

  /// Identificador del dispositivo simulado.
  final String deviceName;

  final Random _random = Random();
  final DateTime _startedAt = DateTime.now();
  double _phase = 0;

  MockApiService({
    required this.host,
    required this.channelCount,
    required this.adcMax,
    required this.referenceVoltage,
    this.deviceName = 'Raspberry Pi Pico W (simulacion)',
  });

  int get _uptimeSeconds =>
      DateTime.now().difference(_startedAt).inSeconds;

  @override
  Future<DeviceStatus> fetchDeviceStatus() async {
    await Future<void>.delayed(const Duration(milliseconds: 30));
    return DeviceStatus(
      device: deviceName,
      connected: true,
      ip: host,
      uptimeSeconds: _uptimeSeconds,
      wifiRssi: -45 + _random.nextInt(20),
    );
  }

  @override
  Future<AnalogMeasurement> fetchAnalogMeasurement() async {
    await Future<void>.delayed(const Duration(milliseconds: 30));
    _phase += 0.05;

    final channels = <AnalogChannel>[
      for (var i = 0; i < channelCount; i++) _simulateChannel(i),
    ];

    return AnalogMeasurement(
      timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      channels: channels,
    );
  }

  /// Genera un canal con valores suaves que cambian con el tiempo.
  AnalogChannel _simulateChannel(int index) {
    final gpio = 26 + index;
    final base = 0.25 + 0.15 * index;
    final amplitude = 0.45 + 0.08 * index;
    final wobble = sin(_phase * (1.0 + 0.3 * index) + index * 1.7) * amplitude +
        (_random.nextDouble() - 0.5) * 0.03;

    final raw = (base + amplitude + wobble)
        .clamp(0.0, 1.0)
        * adcMax;
    final rawInt = raw.round();
    final voltage =
        convertRawToVoltage(rawInt, adcMax: adcMax, referenceVoltage: referenceVoltage);

    return AnalogChannel(
      channel: index,
      gpio: gpio,
      raw: rawInt,
      voltage: _rounded(voltage),
    );
  }

  double _rounded(double value) => double.parse(value.toStringAsFixed(3));
}