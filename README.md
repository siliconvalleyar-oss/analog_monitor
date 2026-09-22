# Analog Pico Monitor

Aplicacion Flutter para Android que se conecta por **WiFi** a una
**Raspberry Pi Pico W** y permite obtener, visualizar y registrar en tiempo real
todas las mediciones de sus entradas analogicas, mediante una **API HTTP REST**
sobre la red local.

- Idioma de la interfaz: **espanol**.
- Sin Bluetooth, sin Firebase y sin depender de Internet: toda la comunicacion
  ocurre dentro de la red WiFi local.
- Incluye un **modo de simulacion** para desarrollar y probar la app aun sin
  tener la Pico fisicamente conectada.

> Nota: este directorio tambien contiene documentacion del firmware de la Pico
> (protocolo TCP/JSON) en `docs/`. La aplicacion Flutter de este repo usa una
> **API HTTP REST** cuyo contrato se documenta mas abajo.

---

## 1. Requisitos

- **Flutter SDK** >= 3.29 (probado con Flutter 3.44.1 / Dart 3.12.1).
- Un dispositivo Android (telefono o emulador) en la **misma red WiFi** que la
  Pico W.
- Opcional: una Raspberry Pi Pico W con firmware que exponga la API documentada
  en la seccion 9.

## 2. Instalacion de Flutter

Consulta la guia oficial: <https://docs.flutter.dev/get-started/install>.

Resumen para Linux:

```bash
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:`pwd`/flutter/bin"
flutter --version
flutter doctor   # verifica que Android toolchain este OK
```

## 3. Como ejecutar el proyecto

```bash
cd analog_pico_flt
flutter pub get
flutter run
```

Selecciona tu dispositivo Android (o emulador) cuando Flutter lo pida.

La app abre en **modo simulacion** por defecto: muestra canales analogicos con
valores que cambian con el tiempo, sin necesidad de la Pico.

### Ejecutar los tests

```bash
flutter test
```

### Analisis estatico

```bash
flutter analyze
```

## 4. Como configurar la IP de la Pico

1. Abre la pestana **Configuracion** (icono de engranaje).
2. En **IP de la Pico** escribe la direccion de la Pico W, por ejemplo
   `192.168.1.100` (sin `http://`; ese prefijo se agrega solo).
3. Ajusta el **puerto HTTP** (por defecto `80`).
4. Pulsa **Guardar configuracion**.

La configuracion se guarda en el dispositivo y permanece al cerrar la app.

## 5. Formato JSON esperado

### `GET /api/status`

```json
{
  "device": "Raspberry Pi Pico W",
  "connected": true,
  "ip": "192.168.1.100",
  "uptime": 12345,
  "wifi_rssi": -55
}
```

- `wifi_rssi` es **opcional**.
- `device`, `connected`, `ip` y `uptime` son obligatorios.

### `GET /api/analog`

```json
{
  "timestamp": 123456,
  "channels": [
    { "channel": 0, "gpio": 26, "raw": 2048, "voltage": 1.65 },
    { "channel": 1, "gpio": 27, "raw": 3000, "voltage": 2.42 },
    { "channel": 2, "gpio": 28, "raw": 1024, "voltage": 0.83 }
  ]
}
```

- `timestamp`: epoch **en segundos**.
- `channels`: lista de cualquier cantidad de canales (la app soporta una
  cantidad **configurable**, no se asume que sean 3).
- Por canal, `channel` y `raw` son obligatorios. `gpio` es opcional.
- `voltage` es **opcional**: si la Pico no lo envia, la app lo calcula con
  `voltage = raw / adcMax * referenceVoltage` (configurable).

## 6. Endpoints HTTP

| Metodo | Ruta          | Descripcion                             |
|--------|---------------|------------------------------------------|
| GET    | `/api/status` | Estado del dispositivo (IP, uptime, RSSI, conectado) |
| GET    | `/api/analog` | Todas las mediciones analogicas          |

La app envia peticiones a `http://<ip>:<puerto>` + ruta, con timeout
configurable.

## 7. Como funciona el polling

- El intervalo por defecto es **1000 ms** (configurable desde 200 ms a 5 s en
  Configuracion).
- Cada tick se consulta `/api/analog`. `/api/status` se consulta cada 5 s.
- **Nunca se lanzan dos peticiones simultaneas**: si una esta en curso, la
  siguiente se salta hasta que termine.
- Si la conexion falla (Pico apagada, IP incorrecta, timeout, HTTP 404/500):
  - La interfaz muestra el estado **Desconectado** y el motivo.
  - Se muestran los **ultimos valores validos** recibidos.
  - El polling **reintenta automaticamente** en cada tick.
- Al pasar la app a segundo plano, el polling se pausa para ahorrar bateria y
  se reanuda al volver al frente.

## 8. Modo simulacion

En **Configuracion** existe el conmutador *Modo simulacion* (activo por defecto).

Con el modo simulado **no se usa la red**: se generan N canales (segun la
cantidad configurada) con valores que varian con el tiempo de forma realista
combinando ondas senoidales y ruido, incluido el estado del dispositivo.

Para conectar con la Pico real, desactiva ese conmutador, configura la IP y
guarda.

## 9. Conectar una Raspberry Pi Pico W real

La app no necesita cambios para funcionar con la Pico real; lo unico necesario
es que el **firmware** de la Pico W implemente esta API REST:

1. **Conecta la Pico W a la misma red WiFi** del telefono (p. ej. con
   `cyw43_arch` / `lwip` y el SDK oficial de Pico).
2. Reporta su **IP fija o conocida** (o consultala en el monitor serial).
3. Levanta un servidor HTTP (p. ej. con el modulo `lwip` o `tinywifi`/`mongoose`)
   que responda a `GET /api/status` y `GET /api/analog` con el **mismo formato
   JSON** de la seccion 5 (los nombres de campo deben coincidir exactamente).
4. Lee los canales ADC (GPIO 26, 27, 28 en RP2040) con resolucion 12 bits y
   envia `raw` (0-4095) y, opcionalmente, `voltage = raw / 4095 * 3.3`.

Ejemplo minimo del contrato para el firmware:

| Campo en JSON | Tipo   | Obligatorio | Descripcion              |
|---------------|--------|-------------|--------------------------|
| `device`      | string | si          | Nombre del dispositivo   |
| `connected`   | bool   | si          | Estado operativo         |
| `ip`          | string | si          | IP de la Pico            |
| `uptime`      | int    | si          | Segundos de actividad    |
| `wifi_rssi`   | int    | no          | dBm                      |
| `timestamp`   | int    | si (en `/api/analog`) | Epoch en segundos |
| `channels`    | list   | si (en `/api/analog`) | Canales medidos  |
| `channel`     | int    | si (por canal) | Numero de canal         |
| `gpio`        | int    | no          | GPIO del canal           |
| `raw`         | int    | si          | Valor ADC sin escala     |
| `voltage`     | float  | no          | Voltaje (si se omite, se calcula) |

## 10. Estructura del proyecto

```
lib/
  main.dart                     # Punto de entrada, carga config y providers
  app.dart                      # Theme, localizacion y arbol de providers
  models/
    device_status.dart          # DeviceStatus
    analog_channel.dart         # AnalogChannel
    analog_measurement.dart     # AnalogMeasurement
    measurement_sample.dart     # Muestra por canal (historial / graficos)
  services/
    api_service.dart            # ApiService (abstracta) + HttpApiService (HTTP REST)
    api_exceptions.dart         # Tipos y excepciones de error de la API
    mock_api_service.dart       # MockApiService (simulacion sin Pico)
    storage_service.dart        # Persistencia local (SharedPreferences)
  repositories/
    measurement_repository.dart # Orquesta API + persistencia del historial
  providers/
    settings_provider.dart      # Configuracion guardada localmente
    device_provider.dart        # Polling, estado de conexion y reintentos
    device_state.dart           # Enum de estado de conexion
    measurement_provider.dart   # Series en memoria y acceso al historial
  screens/
    dashboard_screen.dart       # Dashboard principal
    charts_screen.dart          # Graficos con zoom/pan y estadisticas
    history_screen.dart         # Historial con filtros por canal y fecha
    settings_screen.dart        # Configuracion
    home_shell.dart             # NavigationBar + ciclo de vida
  widgets/
    analog_channel_card.dart    # Tarjeta de cada entrada analogica
    analog_gauge.dart           # Barra proporcional al valor
    connection_status.dart      # Indicador de conexion
    measurement_chart.dart      # Grafico de lineas (fl_chart)
  utils/
    constants.dart              # Valores por defecto, rutas y claves
    formatters.dart             # Conversion y formateo de valores
test/                           # Tests de modelos, API, conversion, config, polling y UI
```

## Tecnologias usadas

- **provider** (gestion de estado)
- **http** (cliente HTTP REST)
- **shared_preferences** (persistencia local)
- **fl_chart** (graficos)
- **flutter_localizations** / **intl** (interfaz en espanol)
- Material 3 con tema claro/oscuro automatico