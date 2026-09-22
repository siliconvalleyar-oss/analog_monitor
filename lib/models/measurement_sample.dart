/// Muestra de medicion de un solo canal, usada para el historial local y las
/// series de graficos.
///
/// Combina el `timestamp` de [AnalogMeasurement] con los datos de un
/// [AnalogChannel], ademas del voltaje ya resuelto.
library;

class MeasurementSample {
  /// Instante de la medicion.
  final DateTime timestamp;

  /// Numero de canal analogico.
  final int channel;

  /// GPIO del canal (puede ser desconocido).
  final int? gpio;

  /// Valor RAW de 12 bits.
  final int raw;

  /// Voltaje resuelto (enviado por la Pico o calculado localmente).
  final double voltage;

  const MeasurementSample({
    required this.timestamp,
    required this.channel,
    this.gpio,
    required this.raw,
    required this.voltage,
  });

  factory MeasurementSample.fromJson(Map<String, dynamic> json) {
    final timestamp = json['timestamp'];
    final channel = json['channel'];
    final raw = json['raw'];
    final voltage = json['voltage'];

    if (timestamp is! num || channel is! num || raw is! num || voltage is! num) {
      throw const FormatException('Registro de historial invalido');
    }
    return MeasurementSample(
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (timestamp * 1000).round(),
      ),
      channel: channel.toInt(),
      gpio: json['gpio'] is num ? (json['gpio'] as num).toInt() : null,
      raw: raw.toInt(),
      voltage: voltage.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.millisecondsSinceEpoch ~/ 1000,
        'channel': channel,
        if (gpio != null) 'gpio': gpio,
        'raw': raw,
        'voltage': voltage,
      };
}