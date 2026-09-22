/// Configuracion de la aplicacion y su persistencia.
///
/// Mantiene un snapshot inmutable [AppSettings] y lo guarda en el almacenamiento
/// local para que permanezca despues de cerrar la aplicacion.
library;

import 'package:flutter/foundation.dart';

import '../services/storage_service.dart';
import '../utils/constants.dart';

/// Snapshot inmutable de todos los parametros configurables.
@immutable
class AppSettings {
  /// IP del Raspberry Pi Pico W.
  final String host;

  /// Puerto HTTP.
  final int port;

  /// Intervalo de polling en milisegundos.
  final int pollIntervalMs;

  /// Timeout de conexion en milisegundos.
  final int timeoutMs;

  /// Cantidad esperada de canales analogicos.
  final int channelCount;

  /// Valor maximo del ADC.
  final int adcMax;

  /// Voltaje de referencia del ADC.
  final double referenceVoltage;

  /// Si se registro las mediciones en el historial local.
  final bool enableLogging;

  /// `true` = modo simulacion, `false` = modo real (Pico conectada).
  final bool useMock;

  const AppSettings({
    required this.host,
    required this.port,
    required this.pollIntervalMs,
    required this.timeoutMs,
    required this.channelCount,
    required this.adcMax,
    required this.referenceVoltage,
    required this.enableLogging,
    required this.useMock,
  });

  /// Configuracion con los valores por defecto.
  static const AppSettings defaults = AppSettings(
    host: AppDefaults.host,
    port: AppDefaults.port,
    pollIntervalMs: AppDefaults.pollIntervalMs,
    timeoutMs: AppDefaults.timeoutMs,
    channelCount: AppDefaults.channelCount,
    adcMax: AppDefaults.adcMax,
    referenceVoltage: AppDefaults.referenceVoltage,
    enableLogging: AppDefaults.enableLogging,
    useMock: AppDefaults.useMock,
  );

  AppSettings copyWith({
    String? host,
    int? port,
    int? pollIntervalMs,
    int? timeoutMs,
    int? channelCount,
    int? adcMax,
    double? referenceVoltage,
    bool? enableLogging,
    bool? useMock,
  }) {
    return AppSettings(
      host: host ?? this.host,
      port: port ?? this.port,
      pollIntervalMs: pollIntervalMs ?? this.pollIntervalMs,
      timeoutMs: timeoutMs ?? this.timeoutMs,
      channelCount: channelCount ?? this.channelCount,
      adcMax: adcMax ?? this.adcMax,
      referenceVoltage: referenceVoltage ?? this.referenceVoltage,
      enableLogging: enableLogging ?? this.enableLogging,
      useMock: useMock ?? this.useMock,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettings &&
          other.host == host &&
          other.port == port &&
          other.pollIntervalMs == pollIntervalMs &&
          other.timeoutMs == timeoutMs &&
          other.channelCount == channelCount &&
          other.adcMax == adcMax &&
          other.referenceVoltage == referenceVoltage &&
          other.enableLogging == enableLogging &&
          other.useMock == useMock;

  @override
  int get hashCode => Object.hash(
        host,
        port,
        pollIntervalMs,
        timeoutMs,
        channelCount,
        adcMax,
        referenceVoltage,
        enableLogging,
        useMock,
      );
}

/// Provee el estado de [AppSettings] y lo persiste.
class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this._storage);

  final StorageService _storage;
  AppSettings _settings = AppSettings.defaults;
  bool _loaded = false;

  AppSettings get settings => _settings;

  bool get isLoaded => _loaded;

  /// Carga la configuracion guardada (o los valores por defecto).
  Future<void> load() async {
    _settings = AppSettings(
      host: await _storage.readString(StorageKeys.host) ?? AppDefaults.host,
      port: await _storage.readInt(StorageKeys.port) ?? AppDefaults.port,
      pollIntervalMs:
          await _storage.readInt(StorageKeys.pollIntervalMs) ??
              AppDefaults.pollIntervalMs,
      timeoutMs:
          await _storage.readInt(StorageKeys.timeoutMs) ?? AppDefaults.timeoutMs,
      channelCount:
          await _storage.readInt(StorageKeys.channelCount) ??
              AppDefaults.channelCount,
      adcMax: await _storage.readInt(StorageKeys.adcMax) ?? AppDefaults.adcMax,
      referenceVoltage:
          await _storage.readDouble(StorageKeys.referenceVoltage) ??
              AppDefaults.referenceVoltage,
      enableLogging:
          await _storage.readBool(StorageKeys.enableLogging) ??
              AppDefaults.enableLogging,
      useMock:
          await _storage.readBool(StorageKeys.useMock) ?? AppDefaults.useMock,
    );
    _loaded = true;
    notifyListeners();
  }

  /// Guarda la configuracion en memoria y en el almacenamiento local.
  Future<void> save(AppSettings value) async {
    _settings = value;
    notifyListeners();

    await _storage.writeString(StorageKeys.host, value.host);
    await _storage.writeInt(StorageKeys.port, value.port);
    await _storage.writeInt(StorageKeys.pollIntervalMs, value.pollIntervalMs);
    await _storage.writeInt(StorageKeys.timeoutMs, value.timeoutMs);
    await _storage.writeInt(StorageKeys.channelCount, value.channelCount);
    await _storage.writeInt(StorageKeys.adcMax, value.adcMax);
    await _storage.writeDouble(
      StorageKeys.referenceVoltage,
      value.referenceVoltage,
    );
    await _storage.writeBool(StorageKeys.enableLogging, value.enableLogging);
    await _storage.writeBool(StorageKeys.useMock, value.useMock);
  }
}