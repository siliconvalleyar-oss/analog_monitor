import 'package:analog_pico_monitor/services/mock_api_service.dart';
import 'package:analog_pico_monitor/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const adcMax = 4095;
  const referenceVoltage = 3.3;

  MockApiService api({int channels = 3}) => MockApiService(
        host: '192.168.1.100',
        channelCount: channels,
        adcMax: adcMax,
        referenceVoltage: referenceVoltage,
      );

  test('genera la cantidad configurable de canales', () async {
    final withThree = await api(channels: 3).fetchAnalogMeasurement();
    final withFive = await api(channels: 5).fetchAnalogMeasurement();

    expect(withThree.channels, hasLength(3));
    expect(withFive.channels, hasLength(5));
  });

  test('los valores cambian con el tiempo', () async {
    final mock = api();
    final first = await mock.fetchAnalogMeasurement();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final second = await mock.fetchAnalogMeasurement();

    expect(second.timestamp, greaterThanOrEqualTo(first.timestamp));
    // Los canales estan dentro del rango valido.
    for (final channel in second.channels) {
      expect(channel.raw, inInclusiveRange(0, adcMax));
    }
    // Al menos un canal debe haber variado.
    final anyChanged = first.channels.asMap().entries.any((entry) =>
        entry.value.raw != second.channels[entry.key].raw);
    expect(anyChanged, isTrue);
  });

  test('los voltajes son consistentes con la conversion RAW -> voltaje', () async {
    final measurement = await api().fetchAnalogMeasurement();
    for (final channel in measurement.channels) {
      final expected = convertRawToVoltage(
        channel.raw,
        adcMax: adcMax,
        referenceVoltage: referenceVoltage,
      );
      expect(channel.voltage, closeTo(expected, 0.001));
    }
  });

  test('el estado reporta el host configurado y secuencia de uptime', () async {
    final mock = api();
    final first = await mock.fetchDeviceStatus();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final second = await mock.fetchDeviceStatus();

    expect(first.connected, isTrue);
    expect(first.ip, '192.168.1.100');
    expect(second.uptimeSeconds, greaterThanOrEqualTo(first.uptimeSeconds));
  });
}