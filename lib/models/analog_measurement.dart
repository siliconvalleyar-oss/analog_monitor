/// Modelo con todas las mediciones analogicas provenientes del ADC de la Pico W.
///
/// Corresponde a la respuesta completa de `GET /api/analog`.
library;

import 'analog_channel.dart';

class AnalogMeasurement {
  /// Marca de tiempo de la medicion como epoch en segundos (segun la API).
  final int timestamp;

  /// Canales analogicos medidos.
  final List<AnalogChannel> channels;

  const AnalogMeasurement({
    required this.timestamp,
    required this.channels,
  });

  /// Instante de la medicion.
  DateTime get timestampDate =>
      DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);

  /// Construye un [AnalogMeasurement] a partir del JSON de la API.
  ///
  /// Lanza [FormatException] si `timestamp` esta ausente o `channels` no es
  /// una lista de canales validos.
  factory AnalogMeasurement.fromJson(Map<String, dynamic> json) {
    final timestamp = json['timestamp'];
    final channels = json['channels'];

    if (timestamp is! num || channels is! List) {
      throw const FormatException('Salida de /api/analog incompleta');
    }

    final parsed = <AnalogChannel>[];
    for (final item in channels) {
      if (item is! Map) {
        throw const FormatException('Elemento de channels invalido');
      }
      parsed.add(
        AnalogChannel.fromJson(Map<String, dynamic>.from(item)),
      );
    }

    return AnalogMeasurement(
      timestamp: timestamp.toInt(),
      channels: parsed,
    );
  }

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp,
        'channels': channels.map((c) => c.toJson()).toList(),
      };

  @override
  String toString() => 'AnalogMeasurement(timestamp: $timestamp, '
      'channels: ${channels.length})';
}