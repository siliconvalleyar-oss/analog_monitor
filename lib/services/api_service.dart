/// Capa de comunicacion HTTP con la Raspberry Pi Pico W.
///
/// Encapsula el acceso a los endpoints `GET /api/status` y `GET /api/analog`.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/analog_measurement.dart';
import '../models/device_status.dart';
import '../utils/constants.dart';
import 'api_exceptions.dart';

/// Interfaz de la capa de comunicacion.
///
/// Permite intercambiar la implementacion real por la simulada sin tocar el
/// resto de la aplicacion.
abstract class ApiService {
  /// Consulta el estado del dispositivo (`GET /api/status`).
  Future<DeviceStatus> fetchDeviceStatus();

  /// Consulta todas las mediciones analogicas (`GET /api/analog`).
  Future<AnalogMeasurement> fetchAnalogMeasurement();
}

/// Implementacion real que consulta la API HTTP de la Pico W por WiFi.
class HttpApiService implements ApiService {
  /// Direccion IP del dispositivo.
  final String host;

  /// Puerto HTTP.
  final int port;

  /// Timeout aplicado a cada peticion.
  final Duration timeout;

  /// Cliente HTTP inyectable (permite usar mocks en los tests).
  final http.Client client;

  HttpApiService({
    required this.host,
    required this.port,
    required this.timeout,
    http.Client? client,
  }) : client = client ?? http.Client();

  Uri _uri(String path) => Uri.parse('http://$host:$port$path');

  @override
  Future<DeviceStatus> fetchDeviceStatus() async {
    final json = await _get(ApiPaths.status);
    try {
      return DeviceStatus.fromJson(json);
    } on FormatException {
      throw const ApiException(
        ApiErrorType.invalidData,
        'Respuesta de /api/status incompleta o invalida',
      );
    }
  }

  @override
  Future<AnalogMeasurement> fetchAnalogMeasurement() async {
    final json = await _get(ApiPaths.analog);
    try {
      return AnalogMeasurement.fromJson(json);
    } on FormatException {
      throw const ApiException(
        ApiErrorType.invalidData,
        'Respuesta de /api/analog incompleta o invalida',
      );
    }
  }

  /// Obtiene una ruta, valida el codigo HTTP y decodifica el JSON.
  Future<Map<String, dynamic>> _get(String path) async {
    final http.Response response;
    try {
      response = await client.get(_uri(path)).timeout(timeout);
    } on TimeoutException {
      throw const ApiException(ApiErrorType.timeout, 'Tiempo de espera agotado');
    } on SocketException {
      throw const ApiException(
        ApiErrorType.network,
        'No se pudo conectar con la Pico',
      );
    } on http.ClientException {
      throw const ApiException(
        ApiErrorType.network,
        'Fallo de red al conectar con la Pico',
      );
    }

    if (response.statusCode == 404) {
      throw const ApiException(
        ApiErrorType.notFound,
        'Endpoint no encontrado (404)',
        statusCode: 404,
      );
    }
    if (response.statusCode >= 500) {
      throw ApiException(
        ApiErrorType.server,
        'Error interno del servidor (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }
    if (response.statusCode != 200) {
      throw ApiException(
        ApiErrorType.httpError,
        'Respuesta HTTP inesperada',
        statusCode: response.statusCode,
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const ApiException(
        ApiErrorType.invalidJson,
        'La respuesta no es un JSON valido',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException(
        ApiErrorType.invalidJson,
        'El JSON de respuesta no es un objeto',
      );
    }
    return decoded;
  }
}