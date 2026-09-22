/// Utilidades de conversion y formateo de valores.
///
/// Contiene la conversion RAW -> voltaje y los formateadores usados en la UI
/// para presentar los datos de forma consistente y en espanol.
library;

import 'package:intl/intl.dart';

import '../services/api_exceptions.dart';

/// Convierte el valor RAW del ADC a voltaje.
///
/// Formula por defecto: `voltage = raw / adcMax * referenceVoltage`.
/// Devuelve `0.0` si los parametros no son validos para evitar errores.
double convertRawToVoltage(
  int raw, {
  required int adcMax,
  required double referenceVoltage,
}) {
  if (adcMax <= 0 || raw < 0) {
    return 0.0;
  }
  return raw / adcMax * referenceVoltage;
}

/// Formatea un valor de voltaje en volts, p. ej. `1.65 V`.
String formatVoltage(double volts) {
  final text = volts.toStringAsFixed(2);
  return '$text V';
}

/// Formatea un valor RAW entero.
String formatRaw(int raw) => raw.toString();

/// Formatea el numero de GPIO, p. ej. `GPIO 26`.
String formatGpio(int? gpio) => gpio == null ? 'GPIO --' : 'GPIO $gpio';

/// Formatea una hora completa, p. ej. `12:34:56 22/09/2026`.
String formatDateTime(DateTime dateTime) =>
    DateFormat('HH:mm:ss dd/MM/yyyy').format(dateTime);

/// Formatea solo la hora, p. ej. `12:34:56`.
String formatTime(DateTime dateTime) =>
    DateFormat('HH:mm:ss').format(dateTime);

/// Formatea un tiempo de funcionamiento en formato legible, p. ej. `1h 23m 45s`.
String formatUptime(int seconds) {
  if (seconds < 0) {
    seconds = 0;
  }
  final days = seconds ~/ 86400;
  final hours = (seconds % 86400) ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final rest = seconds % 60;

  final parts = <String>[
    if (days > 0) '${days}d',
    if (hours > 0) '${hours}h',
    if (minutes > 0) '${minutes}m',
    '${rest}s',
  ];
  return parts.join(' ');
}

/// Formatea la senal WiFi, p. ej. `-55 dBm`.
String formatRssi(int? rssi) => rssi == null ? '-- dBm' : '$rssi dBm';

/// Devuelve un mensaje de error comprensible para el usuario a partir de una
/// excepcion de la API.
String friendlyError(dynamic error) {
  if (error is ApiException) {
    return switch (error.type) {
      ApiErrorType.network =>
        'No se pudo conectar. Revisa el WiFi y la IP de la Pico.',
      ApiErrorType.timeout => 'Tiempo de espera agotado al consultar la Pico.',
      ApiErrorType.notFound =>
        'El endpoint no existe (404). Revisa la IP y el firmware.',
      ApiErrorType.server => 'La Pico respondio con un error interno (500).',
      ApiErrorType.invalidJson =>
        'La respuesta de la Pico no es un JSON valido.',
      ApiErrorType.invalidData =>
        'La respuesta de la Pico esta incompleta o es invalida.',
      ApiErrorType.httpError => 'Error HTTP ${error.statusCode ?? 'desconocido'}.',
    };
  }
  return 'Error inesperado: $error';
}