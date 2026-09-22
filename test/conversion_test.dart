import 'package:analog_pico_monitor/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('convertRawToVoltage', () {
    const adcMax = 4095;
    const referenceVoltage = 3.3;

    test('aplica la formula raw / adcMax * referenceVoltage', () {
      expect(
        convertRawToVoltage(2048, adcMax: adcMax, referenceVoltage: referenceVoltage),
        closeTo(1.65, 0.001),
      );
    });

    test('valor cero devuelve cero', () {
      expect(
        convertRawToVoltage(0, adcMax: adcMax, referenceVoltage: referenceVoltage),
        0.0,
      );
    });

    test('valor maximo devuelve el voltaje de referencia', () {
      expect(
        convertRawToVoltage(adcMax, adcMax: adcMax, referenceVoltage: referenceVoltage),
        closeTo(referenceVoltage, 0.0001),
      );
    });

    test('adcMax invalido devuelve cero en vez de fallar', () {
      expect(
        convertRawToVoltage(100, adcMax: 0, referenceVoltage: referenceVoltage),
        0.0,
      );
    });

    test('raw negativo devuelve cero en vez de fallar', () {
      expect(
        convertRawToVoltage(-1, adcMax: adcMax, referenceVoltage: referenceVoltage),
        0.0,
      );
    });
  });

  group('formatUptime', () {
    test('formatea horas, minutos y segundos', () {
      expect(formatUptime(3661), '1h 1m 1s');
    });

    test('formatea solo segundos', () {
      expect(formatUptime(12), '12s');
    });

    test('formatea dias', () {
      expect(formatUptime(90061), '1d 1h 1m 1s');
    });

    test('omite los minutos cuando son cero', () {
      expect(formatUptime(61), '1m 1s');
      expect(formatUptime(3661), '1h 1m 1s');
    });
  });
}