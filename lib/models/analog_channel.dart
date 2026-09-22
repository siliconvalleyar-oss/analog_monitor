/// Modelo de una entrada analogica individual del ADC de la Pico W.
///
/// Corresponde a cada elemento de `channels` en la respuesta de
/// `GET /api/analog`.
library;

import '../utils/formatters.dart';

class AnalogChannel {
  /// Numero de canal analogico.
  final int channel;

  /// GPIO al que esta conectado el pin analogico (opcional en la respuesta).
  final int? gpio;

  /// Valor RAW de 12 bits (0-4095).
  final int raw;

  /// Voltaje enviado por la Pico. Si la Pico no lo incluye, queda `null` y se
  /// calcula con la conversion RAW -> voltaje.
  final double? voltage;

  const AnalogChannel({
    required this.channel,
    this.gpio,
    required this.raw,
    this.voltage,
  });

  /// Construye un [AnalogChannel] a partir del JSON de la API.
  ///
  /// Se tolera la ausencia de `gpio` y `voltage`, pero el canal sin `channel`
  /// o sin `raw` se considera una respuesta incompleta y lanza
  /// [FormatException].
  factory AnalogChannel.fromJson(Map<String, dynamic> json) {
    final channel = json['channel'];
    final raw = json['raw'];

    if (channel is! num || raw is! num) {
      throw const FormatException('Canal analogico incompleto');
    }

    final rawValue = raw.toInt();
    if (rawValue < 0) {
      throw const FormatException('Valor RAW fuera de rango');
    }

    final gpio = json['gpio'];
    final voltage = json['voltage'];
    return AnalogChannel(
      channel: channel.toInt(),
      gpio: gpio is num ? gpio.toInt() : null,
      raw: rawValue,
      voltage: voltage is num ? voltage.toDouble() : null,
    );
  }

  /// Voltaje final: usa el enviado por la Pico si existe, si no lo calcula.
  double resolvedVoltage({
    required int adcMax,
    required double referenceVoltage,
  }) =>
      voltage ??
      convertRawToVoltage(
        raw,
        adcMax: adcMax,
        referenceVoltage: referenceVoltage,
      );

  /// Devuelve `true` si el valor RAW esta fuera del rango `[0, adcMax]`.
  bool isOutOfRange(int adcMax) => raw < 0 || raw > adcMax;

  Map<String, dynamic> toJson() => {
        'channel': channel,
        if (gpio != null) 'gpio': gpio,
        'raw': raw,
        if (voltage != null) 'voltage': voltage,
      };

  @override
  String toString() => 'AnalogChannel(channel: $channel, gpio: $gpio, '
      'raw: $raw, voltage: $voltage)';
}