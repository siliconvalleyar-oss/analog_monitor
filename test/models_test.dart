import 'dart:convert';

import 'package:analog_pico_monitor/models/analog_channel.dart';
import 'package:analog_pico_monitor/models/analog_measurement.dart';
import 'package:analog_pico_monitor/models/device_status.dart';
import 'package:analog_pico_monitor/models/measurement_sample.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeviceStatus.fromJson', () {
    test('parsea el JSON de ejemplo', () {
      final json = jsonDecode(
        '{"device":"Raspberry Pi Pico W","connected":true,'
        '"ip":"192.168.1.100","uptime":12345,"wifi_rssi":-55}',
      ) as Map<String, dynamic>;

      final status = DeviceStatus.fromJson(json);

      expect(status.device, 'Raspberry Pi Pico W');
      expect(status.connected, isTrue);
      expect(status.ip, '192.168.1.100');
      expect(status.uptimeSeconds, 12345);
      expect(status.wifiRssi, -55);
    });

    test('wifi_rssi es opcional', () {
      final json = jsonDecode(
        '{"device":"Pico","connected":false,"ip":"10.0.0.1","uptime":0}',
      ) as Map<String, dynamic>;

      final status = DeviceStatus.fromJson(json);

      expect(status.connected, isFalse);
      expect(status.wifiRssi, isNull);
    });

    test('JSON invalido lanza FormatException', () {
      expect(
        () => DeviceStatus.fromJson(const {'device': 'Pico'}),
        throwsFormatException,
      );
      expect(
        () => DeviceStatus.fromJson(const {'connected': true}),
        throwsFormatException,
      );
    });
  });

  group('AnalogChannel.fromJson', () {
    test('parsea el JSON de ejemplo', () {
      final json = jsonDecode(
        '{"channel":0,"gpio":26,"raw":2048,"voltage":1.65}',
      ) as Map<String, dynamic>;

      final channel = AnalogChannel.fromJson(json);

      expect(channel.channel, 0);
      expect(channel.gpio, 26);
      expect(channel.raw, 2048);
      expect(channel.voltage, 1.65);
    });

    test('voltage y gpio son opcionales', () {
      final channel = AnalogChannel.fromJson(
        const {'channel': 1, 'raw': 3000},
      );

      expect(channel.gpio, isNull);
      expect(channel.voltage, isNull);
    });

    test('carta un canal sin raw como incompleto', () {
      expect(
        () => AnalogChannel.fromJson(const {'channel': 0}),
        throwsFormatException,
      );
    });

    test('rechaza valores RAW negativos', () {
      expect(
        () => AnalogChannel.fromJson(const {'channel': 0, 'raw': -5}),
        throwsFormatException,
      );
    });

    test('resolvedVoltage usa el voltaje de la API si existe', () {
      final channel = AnalogChannel.fromJson(
        const {'channel': 0, 'raw': 1000, 'voltage': 2.5},
      );
      expect(channel.resolvedVoltage(adcMax: 4095, referenceVoltage: 3.3), 2.5);
    });

    test('isOutOfRange detecta valores fuera de rango', () {
      final ok = AnalogChannel.fromJson(const {'channel': 0, 'raw': 2048});
      final high = AnalogChannel.fromJson(const {'channel': 0, 'raw': 99999});
      expect(ok.isOutOfRange(4095), isFalse);
      expect(high.isOutOfRange(4095), isTrue);
    });
  });

  group('AnalogMeasurement.fromJson', () {
    test('parsea el JSON de ejemplo completo', () {
      final json = jsonDecode('''
        {
          "timestamp": 123456,
          "channels": [
            {"channel": 0, "gpio": 26, "raw": 2048, "voltage": 1.65},
            {"channel": 1, "gpio": 27, "raw": 3000, "voltage": 2.42},
            {"channel": 2, "gpio": 28, "raw": 1024, "voltage": 0.83}
          ]
        }
      ''') as Map<String, dynamic>;

      final measurement = AnalogMeasurement.fromJson(json);

      expect(measurement.timestamp, 123456);
      expect(measurement.channels, hasLength(3));
      expect(measurement.channels[0].channel, 0);
      expect(measurement.channels[2].voltage, 0.83);
    });

    test('soporta cualquier cantidad de canales', () {
      final json = jsonDecode('''
        {
          "timestamp": 1,
          "channels": [
            {"channel": 0, "raw": 10},
            {"channel": 1, "raw": 20},
            {"channel": 2, "raw": 30},
            {"channel": 3, "raw": 40},
            {"channel": 4, "raw": 50}
          ]
        }
      ''') as Map<String, dynamic>;

      final measurement = AnalogMeasurement.fromJson(json);

      expect(measurement.channels, hasLength(5));
    });

    test('permite la lista de canales vacia', () {
      final json = jsonDecode('{"timestamp": 1, "channels": []}')
          as Map<String, dynamic>;
      final measurement = AnalogMeasurement.fromJson(json);
      expect(measurement.channels, isEmpty);
    });

    test('lanza si timestamp no existe', () {
      expect(
        () => AnalogMeasurement.fromJson(const {'channels': []}),
        throwsFormatException,
      );
    });

    test('lanza si channels no es una lista', () {
      expect(
        () => AnalogMeasurement.fromJson(const {'timestamp': 1, 'channels': {}}),
        throwsFormatException,
      );
    });

    test('lanza si un canal es invalido', () {
      expect(
        () => AnalogMeasurement.fromJson(const {
          'timestamp': 1,
          'channels': [
            {'channel': 0}
          ],
        }),
        throwsFormatException,
      );
    });
  });

  group('MeasurementSample', () {
    test('round-trip toJson/fromJson', () {
      final sample = MeasurementSample(
        timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        channel: 1,
        gpio: 27,
        raw: 3000,
        voltage: 2.42,
      );

      final restored = MeasurementSample.fromJson(sample.toJson());

      expect(restored.timestamp, sample.timestamp);
      expect(restored.channel, 1);
      expect(restored.gpio, 27);
      expect(restored.raw, 3000);
      expect(restored.voltage, 2.42);
    });
  });
}