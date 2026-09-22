/// Modelo con la informacion de estado del dispositivo (Raspberry Pi Pico W).
///
/// Corresponde a la respuesta de `GET /api/status`.
library;

class DeviceStatus {
  /// Nombre o identificador del dispositivo.
  final String device;

  /// Indica si el dispositivo esta operativo.
  final bool connected;

  /// Direccion IP reportada por el dispositivo.
  final String ip;

  /// Tiempo de funcionamiento en segundos.
  final int uptimeSeconds;

  /// Intensidad de la senal WiFi en dBm (puede omitirse en la respuesta).
  final int? wifiRssi;

  const DeviceStatus({
    required this.device,
    required this.connected,
    required this.ip,
    required this.uptimeSeconds,
    this.wifiRssi,
  });

  /// Construye un [DeviceStatus] a partir del JSON de la API.
  ///
  /// Lanza [FormatException] si falta algun campo obligatorio o los tipos no
  /// coinciden.
  factory DeviceStatus.fromJson(Map<String, dynamic> json) {
    final device = json['device'];
    final connected = json['connected'];
    final ip = json['ip'];
    final uptime = json['uptime'];

    if (device is! String || connected is! bool || ip is! String || uptime is! num) {
      throw const FormatException('Salida de /api/status incompleta');
    }

    final rssi = json['wifi_rssi'];
    return DeviceStatus(
      device: device,
      connected: connected,
      ip: ip,
      uptimeSeconds: uptime.toInt(),
      wifiRssi: rssi is num ? rssi.toInt() : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'device': device,
        'connected': connected,
        'ip': ip,
        'uptime': uptimeSeconds,
        if (wifiRssi != null) 'wifi_rssi': wifiRssi,
      };
}