# 05 - Guia de la App Flutter (Cliente)

## Visión General

La app Flutter es el cliente que se conecta al servidor TCP del Pico W
para recibir y visualizar las mediciones analogicas en tiempo real.
Funciona en Android e iOS.

## Dependencias del Proyecto Flutter

`pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  socket_common: ^1.0.0    # Alternativa: usar dart:io directamente
  # Para graficos:
  fl_chart: ^0.65.0         # Graficos de lineas y barras
  # Para JSON:
  dart:convert               # Incluido en Dart
```

## Conexion TCP basica

### Clase del Servidor de Datos

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Estructura que contiene una medicion del Pico W
class AdcMeasurement {
  final double voltageCh0;   // Voltaje canal 0 en mV
  final double voltageCh1;   // Voltaje canal 1 en mV
  final double voltageCh2;   // Voltaje canal 2 en mV
  final int rawCh0;          // Valor crudo canal 0
  final int rawCh1;          // Valor crudo canal 1
  final int rawCh2;          // Valor crudo canal 2
  final double temperature;  // Temperatura interna en °C
  final int timestampMs;     // Milisegundos desde boot

  AdcMeasurement({
    required this.voltageCh0,
    required this.voltageCh1,
    required this.voltageCh2,
    required this.rawCh0,
    required this.rawCh1,
    required this.rawCh2,
    required this.temperature,
    required this.timestampMs,
  });

  factory AdcMeasurement.fromJson(Map<String, dynamic> json) {
    return AdcMeasurement(
      voltageCh0: (json['ch0_mv'] as num).toDouble(),
      voltageCh1: (json['ch1_mv'] as num).toDouble(),
      voltageCh2: (json['ch2_mv'] as num).toDouble(),
      rawCh0: json['ch0_raw'] as int,
      rawCh1: json['ch1_raw'] as int,
      rawCh2: json['ch2_raw'] as int,
      temperature: (json['temp_c'] as num).toDouble(),
      timestampMs: json['ts_ms'] as int,
    );
  }
}

/// Servidor TCP que recibe datos del Pico W
class PicoTcpClient {
  Socket? _socket;
  String _buffer = '';
  String _ip;
  int _port;

  /// Callback llamado cuando llega una medicion nueva
  Function(AdcMeasurement)? onMeasurement;

  /// Callback de conexion/desconexion
  Function(bool connected)? onConnectionChanged;

  /// Estado actual de la conexion
  bool get isConnected => _socket != null;

  PicoTcpClient({required String ip, int port = 5000})
      : _ip = ip,
        _port = port;

  /// Conectar al servidor TCP del Pico W
  Future<void> connect() async {
    try {
      _socket = await Socket.connect(_ip, _port,
        timeout: const Duration(seconds: 5));

      onConnectionChanged?.call(true);

      // Escuchar datos entrantes
      _socket!.listen(
        _onData,
        onError: _onError,
        onDone: _onDone,
      );
    } catch (e) {
      print('Error de conexion: $e');
      onConnectionChanged?.call(false);
    }
  }

  /// Desconectar del servidor
  Future<void> disconnect() async {
    await _socket?.close();
    _socket = null;
    onConnectionChanged?.call(false);
  }

  /// Procesar datos entrantes del socket
  void _onData(List<int> data) {
    _buffer += String.fromCharCodes(data);

    // Separar por newlines (cada JSON termina en \n)
    while (_buffer.contains('\n')) {
      final index = _buffer.indexOf('\n');
      final line = _buffer.substring(0, index).trim();
      _buffer = _buffer.substring(index + 1);

      if (line.isNotEmpty) {
        try {
          final json = jsonDecode(line) as Map<String, dynamic>;
          final measurement = AdcMeasurement.fromJson(json);
          onMeasurement?.call(measurement);
        } catch (e) {
          print('Error parseando JSON: $e');
        }
      }
    }
  }

  void _onError(dynamic error) {
    print('Error de socket: $error');
    _socket = null;
    onConnectionChanged?.call(false);
  }

  void _onDone() {
    print('Conexion cerrada por el servidor');
    _socket = null;
    onConnectionChanged?.call(false);
  }
}
```

## Widget Principal de Flutter

```dart
import 'package:flutter/material.dart';

class MonitorScreen extends StatefulWidget {
  final String picoIp;
  final int picoPort;

  const MonitorScreen({
    Key? key,
    required this.picoIp,
    this.picoPort = 5000,
  }) : super(key: key);

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen> {
  late PicoTcpClient _client;
  AdcMeasurement? _latestMeasurement;
  bool _isConnected = false;
  List<AdcMeasurement> _history = [];

  @override
  void initState() {
    super.initState();
    _client = PicoTcpClient(ip: widget.picoIp, port: widget.picoPort);
    _client.onMeasurement = _onMeasurementReceived;
    _client.onConnectionChanged = _onConnectionChanged;
    _client.connect();
  }

  void _onMeasurementReceived(AdcMeasurement measurement) {
    setState(() {
      _latestMeasurement = measurement;
      _history.add(measurement);
      // Mantener solo los ultimos 100 valores
      if (_history.length > 100) _history.removeAt(0);
    });
  }

  void _onConnectionChanged(bool connected) {
    setState(() => _isConnected = connected);
  }

  @override
  void dispose() {
    _client.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pico ADC Monitor'),
        actions: [
          Icon(
            _isConnected ? Icons.wifi : Icons.wifi_off,
            color: _isConnected ? Colors.green : Colors.red,
          ),
        ],
      ),
      body: _latestMeasurement == null
          ? Center(child: Text('Esperando datos...'))
          : _buildDashboard(),
    );
  }

  Widget _buildDashboard() {
    final m = _latestMeasurement!;
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          _buildVoltageCard('Canal 0 (GP26)', m.voltageCh0, m.rawCh0),
          _buildVoltageCard('Canal 1 (GP27)', m.voltageCh1, m.rawCh1),
          _buildVoltageCard('Canal 2 (GP28)', m.voltageCh2, m.rawCh2),
          _buildTempCard(m.temperature),
          _buildTimestamp(m.timestampMs),
        ],
      ),
    );
  }

  Widget _buildVoltageCard(String label, double mv, int raw) {
    final volts = mv / 1000.0;
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Icon(Icons.electric_bolt, color: Colors.amber),
        title: Text(label),
        subtitle: Text('${volts.toStringAsFixed(3)} V  (${mv.toStringAsFixed(1)} mV)'),
        trailing: Text('RAW: $raw',
          style: TextStyle(fontFamily: 'monospace', fontSize: 12)),
      ),
    );
  }

  Widget _buildTempCard(double tempC) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      color: Colors.orange.shade50,
      child: ListTile(
        leading: Icon(Icons.thermostat, color: Colors.red),
        title: Text('Temperatura Interna'),
        subtitle: Text('${tempC.toStringAsFixed(1)} °C'),
      ),
    );
  }

  Widget _buildTimestamp(int tsMs) {
    final seconds = tsMs ~/ 1000;
    final minutes = seconds ~/ 60;
    final hours = minutes ~/ 60;
    return Padding(
      padding: EdgeInsets.only(top: 16),
      child: Text(
        'Uptime: ${hours}h ${minutes % 60}m ${seconds % 60}s',
        style: TextStyle(color: Colors.grey),
      ),
    );
  }
}
```

## Ejemplo de main.dart Completo

```dart
import 'package:flutter/material.dart';

void main() {
  runApp(const PicoMonitorApp());
}

class PicoMonitorApp extends StatelessWidget {
  const PicoMonitorApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pico ADC Monitor',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const IpConfigScreen(),
    );
  }
}

/// Pantalla de configuracion de IP
class IpConfigScreen extends StatefulWidget {
  const IpConfigScreen({Key? key}) : super(key: key);

  @override
  State<IpConfigScreen> createState() => _IpConfigScreenState();
}

class _IpConfigScreenState extends State<IpConfigScreen> {
  final _ipController = TextEditingController(text: '192.168.1.100');
  final _portController = TextEditingController(text: '5000');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Configurar Pico W')),
      body: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.settings_ethernet, size: 64, color: Colors.blue),
            SizedBox(height: 32),
            TextField(
              controller: _ipController,
              decoration: InputDecoration(
                labelText: 'IP del Pico W',
                hintText: '192.168.1.100',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 16),
            TextField(
              controller: _portController,
              decoration: InputDecoration(
                labelText: 'Puerto TCP',
                hintText: '5000',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MonitorScreen(
                      picoIp: _ipController.text,
                      picoPort: int.parse(_portController.text),
                    ),
                  ),
                );
              },
              icon: Icon(Icons.play_arrow),
              label: Text('Conectar'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

## Widgets Recomendados

| Widget | Uso | Paquete |
|--------|-----|---------|
| `CircularProgressIndicator` | Gauge analogico de voltaje | flutter (built-in) |
| `LineChart` | Grafico de historial temporal | `fl_chart` |
| `LinearProgressIndicator` | Barra de nivel de voltaje | flutter (built-in) |
| `Card` | Contenedor de cada canal | flutter (built-in) |
| `StreamBuilder` | Reconstruir UI con cada dato | flutter (built-in) |

## Permisos Requeridos

### Android (`AndroidManifest.xml`)

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
```

### iOS (`Info.plist`)

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsLocalNetworking</key>
    <true/>
</dict>
```
