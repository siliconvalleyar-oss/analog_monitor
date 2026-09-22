import 'dart:convert';

import 'package:analog_pico_monitor/services/api_exceptions.dart';
import 'package:analog_pico_monitor/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _validStatus = '{"device":"Raspberry Pi Pico W","connected":true,'
    '"ip":"192.168.1.100","uptime":12345,"wifi_rssi":-55}';

const _validAnalog = '{"timestamp":123456,"channels":['
    '{"channel":0,"gpio":26,"raw":2048,"voltage":1.65}]}';

HttpApiService _service(http.Client client,
    {Duration timeout = const Duration(seconds: 2)}) {
  return HttpApiService(
    host: '192.168.1.100',
    port: 80,
    timeout: timeout,
    client: client,
  );
}

void main() {
  group('HttpApiService - respuestas exitosas', () {
    test('parsea GET /api/status', () async {
      final api = _service(
        MockClient((request) async {
          expect(request.url.path, '/api/status');
          return http.Response(_validStatus, 200);
        }),
      );

      final status = await api.fetchDeviceStatus();

      expect(status.device, 'Raspberry Pi Pico W');
      expect(status.uptimeSeconds, 12345);
    });

    test('parsea GET /api/analog', () async {
      final api = _service(
        MockClient((request) async {
          expect(request.url.path, '/api/analog');
          return http.Response(_validAnalog, 200);
        }),
      );

      final measurement = await api.fetchAnalogMeasurement();

      expect(measurement.channels, hasLength(1));
      expect(measurement.channels.first.voltage, 1.65);
    });
  });

  group('HttpApiService - errores HTTP', () {
    test('HTTP 404 lanza ApiException tipo notFound', () async {
      final api = _service(
        MockClient((request) async => http.Response('Not Found', 404)),
      );

      await expectLater(
        api.fetchAnalogMeasurement(),
        throwsA(isA<ApiException>()
            .having((e) => e.type, 'type', ApiErrorType.notFound)
            .having((e) => e.statusCode, 'statusCode', 404)),
      );
    });

    test('HTTP 500 lanza ApiException tipo server', () async {
      final api = _service(
        MockClient((request) async => http.Response('Error', 500)),
      );

      await expectLater(
        api.fetchAnalogMeasurement(),
        throwsA(isA<ApiException>()
            .having((e) => e.type, 'type', ApiErrorType.server)),
      );
    });

    test('HTTP 401 lanza ApiException tipo httpError', () async {
      final api = _service(
        MockClient((request) async => http.Response('No auth', 401)),
      );

      await expectLater(
        api.fetchAnalogMeasurement(),
        throwsA(isA<ApiException>()
            .having((e) => e.type, 'type', ApiErrorType.httpError)
            .having((e) => e.statusCode, 'statusCode', 401)),
      );
    });

    test('error de red lanza ApiException tipo network', () async {
      final api = _service(
        MockClient(
          (request) async => throw http.ClientException('Sin red'),
        ),
      );

      await expectLater(
        api.fetchAnalogMeasurement(),
        throwsA(isA<ApiException>()
            .having((e) => e.type, 'type', ApiErrorType.network)),
      );
    });

    test('timeout lanza ApiException tipo timeout', () async {
      final api = _service(
        MockClient((request) async {
          await Future<void>.delayed(const Duration(milliseconds: 400));
          return http.Response(_validAnalog, 200);
        }),
        timeout: const Duration(milliseconds: 50),
      );

      await expectLater(
        api.fetchAnalogMeasurement(),
        throwsA(isA<ApiException>()
            .having((e) => e.type, 'type', ApiErrorType.timeout)),
      );
    });
  });

  group('HttpApiService - JSON invalido', () {
    test('cuerpo que no es JSON lanza invalidJson', () async {
      final api = _service(
        MockClient((request) async => http.Response('<html>hola</html>', 200)),
      );

      await expectLater(
        api.fetchAnalogMeasurement(),
        throwsA(isA<ApiException>()
            .having((e) => e.type, 'type', ApiErrorType.invalidJson)),
      );
    });

    test('JSON que no es objeto lanza invalidJson', () async {
      final api = _service(
        MockClient((request) async => http.Response('[1,2,3]', 200)),
      );

      await expectLater(
        api.fetchAnalogMeasurement(),
        throwsA(isA<ApiException>()
            .having((e) => e.type, 'type', ApiErrorType.invalidJson)),
      );
    });

    test('JSON incompleto de /api/analog lanza invalidData', () async {
      final api = _service(
        MockClient(
          (request) async => http.Response(
            jsonEncode({'timestamp': 1, 'channels': 'no-sirve'}),
            200,
          ),
        ),
      );

      await expectLater(
        api.fetchAnalogMeasurement(),
        throwsA(isA<ApiException>()
            .having((e) => e.type, 'type', ApiErrorType.invalidData)),
      );
    });

    test('canal incompleto lanza invalidData', () async {
      final api = _service(
        MockClient(
          (request) async => http.Response(
            jsonEncode({'timestamp': 1, 'channels': [
              {'channel': 0}
            ]}),
            200,
          ),
        ),
      );

      await expectLater(
        api.fetchAnalogMeasurement(),
        throwsA(isA<ApiException>()
            .having((e) => e.type, 'type', ApiErrorType.invalidData)),
      );
    });
  });
}