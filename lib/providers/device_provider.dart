/// Proveedor del estado del dispositivo y de la actualizacion en tiempo real.
///
/// Ejecuta un polling configurable de `/api/analog` (y `/api/status` a una
/// frecuencia menor), evita peticiones simultaneas, reintenta automaticamente
/// ante fallos y conserva el ultimo valor valido recibido.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/analog_measurement.dart';
import '../models/device_status.dart';
import '../repositories/measurement_repository.dart';
import '../services/api_exceptions.dart';
import '../utils/formatters.dart';
import 'device_state.dart';
import 'settings_provider.dart';

class DeviceProvider extends ChangeNotifier {
  DeviceProvider(this._settings, this._repository);

  final SettingsProvider _settings;
  final MeasurementRepository _repository;

  Timer? _pollTimer;
  Timer? _statusTimer;
  bool _pollInFlight = false;
  bool _statusInFlight = false;
  bool _running = false;

  DeviceConnectionState _connectionState = DeviceConnectionState.disconnected;
  DeviceStatus? _deviceStatus;
  AnalogMeasurement? _lastMeasurement;
  DateTime? _lastUpdate;
  String? _lastError;
  int _consecutiveFailures = 0;

  /// Ultimo estado de conexion.
  DeviceConnectionState get connectionState => _connectionState;

  /// Ultimo estado reportado por `GET /api/status`.
  DeviceStatus? get deviceStatus => _deviceStatus;

  /// Ultima medicion valida recibida (se conserva ante fallos).
  AnalogMeasurement? get lastMeasurement => _lastMeasurement;

  /// Instante de la ultima actualizacion exitosa.
  DateTime? get lastUpdate => _lastUpdate;

  /// Ultimo error ocurrido (texto amigable para el usuario).
  String? get lastError => _lastError;

  /// Cantidad de fallos consecutivos (util para mostrar reintentos).
  int get consecutiveFailures => _consecutiveFailures;

  /// Configuracion actual.
  AppSettings get settings => _settings.settings;

  /// Nombres de los canales esperados, segun la configuracion.
  List<int> get expectedChannels =>
      [for (var i = 0; i < settings.channelCount; i++) i];

  /// Arranca el polling. Es seguro llamarlo varias veces.
  void start() {
    if (_running) {
      return;
    }
    _running = true;
    _settings.addListener(_onSettingsChanged);
    _startTimers(fetchNow: true);
  }

  /// Detiene el polling y libera los temporizadores.
  void stop() {
    if (!_running) {
      return;
    }
    _running = false;
    _settings.removeListener(_onSettingsChanged);
    _stopTimers();
  }

  /// Pausa temporalmente el polling (por ejemplo al pasar a segundo plano).
  void pause() {
    _stopTimers();
  }

  /// Reanuda el polling desde el ultimo intervalo configurado.
  void resume() {
    if (_running) {
      _startTimers(fetchNow: true);
    }
  }

  void _onSettingsChanged() {
    if (_running) {
      _startTimers(fetchNow: true);
    }
  }

  void _startTimers({required bool fetchNow}) {
    _stopTimers();

    final interval = Duration(milliseconds: settings.pollIntervalMs);
    _pollTimer = Timer.periodic(interval, (_) => unawaited(_pollAnalog()));
    // El estado se actualiza a una frecuencia menor para no saturar la red.
    _statusTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(_pollStatus()),
    );

    if (fetchNow) {
      unawaited(_pollAnalog());
      unawaited(_pollStatus());
    }
  }

  void _stopTimers() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _statusTimer?.cancel();
    _statusTimer = null;
  }

  /// Consulta el estado el dispositivo. Solo una request a la vez.
  void refresh() {
    unawaited(_pollAnalog());
    unawaited(_pollStatus());
  }

  Future<void> _pollAnalog() async {
    if (_pollInFlight || !_running) {
      return;
    }
    _pollInFlight = true;
    _connectionState = _lastMeasurement == null
        ? DeviceConnectionState.connecting
        : _connectionState;

    try {
      final measurement = await _repository.fetchAnalog();
      _lastMeasurement = measurement;
      _lastUpdate = DateTime.now();
      _lastError = null;
      _consecutiveFailures = 0;
      _connectionState = DeviceConnectionState.connected;
      await _repository.saveMeasurement(measurement);
    } on ApiException catch (e) {
      _markFailure(e);
    } catch (e) {
      _markFailure(
        const ApiException(ApiErrorType.network, 'Error inesperado'),
      );
    } finally {
      _pollInFlight = false;
      notifyListeners();
    }
  }

  Future<void> _pollStatus() async {
    if (_statusInFlight || !_running) {
      return;
    }
    _statusInFlight = true;

    try {
      final status = await _repository.fetchDeviceStatus();
      _deviceStatus = status;
    } on ApiException {
      // El estado es informativo; un fallo aqui no rompe el flujo principal.
    } finally {
      _statusInFlight = false;
      notifyListeners();
    }
  }

  void _markFailure(ApiException error) {
    _consecutiveFailures++;
    _connectionState = DeviceConnectionState.disconnected;
    _lastError = friendlyError(error);
  }

  @override
  void dispose() {
    _stopTimers();
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }
}