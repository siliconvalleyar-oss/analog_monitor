/// Estado de conexion presentado al usuario.
library;

enum DeviceConnectionState {
  /// Aun no se ha obtenido una respuesta confiable.
  connecting,

  /// La ultima lectura fue exitosa.
  connected,

  /// La ultima consulta fallo (sin conexion, timeout, error, etc.).
  disconnected,
}