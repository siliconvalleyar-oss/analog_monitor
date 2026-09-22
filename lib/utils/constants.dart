/// Constantes y valores por defecto de la aplicacion.
///
/// Centralizar aqui los valores por defecto, claves de almacenamiento y rutas
/// de la API permite modificar el comportamiento de la app sin tocar la logica.
library;

/// Valores por defecto de la configuracion.
class AppDefaults {
  AppDefaults._();

  /// IP por defecto de la Raspberry Pi Pico W.
  static const String host = '192.168.1.100';

  /// Puerto HTTP por defecto.
  static const int port = 80;

  /// Intervalo de polling por defecto (milisegundos).
  static const int pollIntervalMs = 1000;

  /// Timeout de conexion por defecto (milisegundos).
  static const int timeoutMs = 3000;

  /// Cantidad esperada de canales analogicos por defecto.
  static const int channelCount = 3;

  /// Valor maximo del ADC (12 bits -> 0-4095).
  static const int adcMax = 4095;

  /// Voltaje de referencia del ADC.
  static const double referenceVoltage = 3.3;

  /// Registro de mediciones activado por defecto.
  static const bool enableLogging = true;

  /// Modo de conexion por defecto (simulacion para poder probar sin Pico).
  static const bool useMock = true;

  /// Cantidad maxima de muestras conservadas en memoria para graficos.
  static const int maxInMemorySamples = 600;

  /// Cantidad maxima de registros conservados en el historial local.
  static const int maxHistoryEntries = 5000;

  /// Cantidad maxima de bytes permitida en una respuesta HTTP.
  static const int maxResponseBytes = 65536;
}

/// Rutas de los endpoints HTTP que debe exponer el firmware de la Pico W.
class ApiPaths {
  ApiPaths._();

  /// Informacion de estado del dispositivo.
  static const String status = '/api/status';

  /// Todas las mediciones analogicas disponibles.
  static const String analog = '/api/analog';
}

/// Claves usadas para persistir la configuracion y los datos locales.
class StorageKeys {
  StorageKeys._();

  static const String host = 'settings_host';
  static const String port = 'settings_port';
  static const String pollIntervalMs = 'settings_poll_interval_ms';
  static const String timeoutMs = 'settings_timeout_ms';
  static const String channelCount = 'settings_channel_count';
  static const String adcMax = 'settings_adc_max';
  static const String referenceVoltage = 'settings_reference_voltage';
  static const String enableLogging = 'settings_enable_logging';
  static const String useMock = 'settings_use_mock';

  /// Clave del historial de mediciones (lista de JSON en texto plano).
  static const String history = 'measurement_history';
}