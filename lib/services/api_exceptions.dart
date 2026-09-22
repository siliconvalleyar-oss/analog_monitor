/// Tipos de error que pueden producirse al comunicarse con la Pico W.
library;

enum ApiErrorType {
  /// Problema de red: sin WiFi, IP inalcanzable, pico apagado, etc.
  network,

  /// Se agoto el tiempo de espera de la conexion.
  timeout,

  /// HTTP 404: el endpoint no existe.
  notFound,

  /// HTTP 5xx: error interno del servidor.
  server,

  /// La respuesta no es JSON valido.
  invalidJson,

  /// La respuesta es JSON, pero esta incompleta o estructuralmente invalida.
  invalidData,

  /// Cualquier otro codigo HTTP no esperado.
  httpError,
}

/// Excepcion tipada para todos los errores de comunicacion con la API.
class ApiException implements Exception {
  /// Tipo de error producido.
  final ApiErrorType type;

  /// Descripcion tecnica del error.
  final String message;

  /// Codigo HTTP, si aplica.
  final int? statusCode;

  const ApiException(this.type, this.message, {this.statusCode});

  @override
  String toString() =>
      'ApiException($type): $message${statusCode != null ? ' (HTTP $statusCode)' : ''}';
}