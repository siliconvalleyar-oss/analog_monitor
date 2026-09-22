# 01 - Arquitectura del Sistema

## Vision General

El sistema monitorea las entradas analogicas de una **Raspberry Pi Pico W**
desde una aplicacion **Android escrita en Flutter**. La comunicacion se realiza
por **HTTP REST** dentro de la red WiFi local: la Pico W actua como servidor,
expone una API con 2 endpoints y la app la consulta periodicamente (polling).

```
+-----------------------------+         WiFi (HTTP REST)         +--------------------------+
|   Dispositivo Android       |                                  |   Raspberry Pi Pico W    |
|                             |  GET /api/status  ------------>  |                          |
|   Analog Pico Monitor       |                                  |   Servidor HTTP           |
|   (app Flutter)             |                                  |   (firmware)              |
|                             |  <----------- JSON 200          |                          |
|                             |                                  |   - ADC (GPIO 26/27/28)   |
|   GET /api/analog   ------> |                                  |   - Sensor interno temp   |
|   <----------- JSON 200     |----------------------------------|   - Estado WiFi/uptime    |
+-----------------------------+                                  +--------------------------+
```

## Componentes

### 1. Aplicacion Flutter (este repositorio)

Aplicacion de un solo proyecto (`analog_pico_monitor`) dividida en capas:

| Capa | Ubicacion | Responsabilidad |
|------|-----------|-----------------|
| Presentacion | `lib/screens/`, `lib/widgets/` | Pantallas y componentes visuales |
| Estado | `lib/providers/` | Polling, estado de conexion, configuracion, series |
| Dominio | `lib/models/` | Modelos de datos (status, canales, mediciones) |
| Datos | `lib/services/`, `lib/repositories/` | HTTP, simulacion, persistencia, historial |
| Utilidades | `lib/utils/` | Constantes, conversion, formateo |

### 2. Firmware de la Pico W

No forma parte de este repositorio. El firmware de la Pico W debe implementar
una **API HTTP REST** con dos endpoints (ver `03-api-firmware.md`):

- `GET /api/status` -> estado del dispositivo (IP, uptime, RSSI, conectado).
- `GET /api/analog` -> todas las mediciones analogicas del ADC.

Puede implementarse con `lwip` + el servidor HTTP embebido del SDK de Pico,
`tinywifi`, `mongoose`, o cualquier servidor HTTP que devuelva el JSON
documentado.

## Flujo de Datos

```
[Pico W]  >=(HTTP GET)=>  [HttpApiService / MockApiService]
                                   |  JSON
                                   v
                        [Modelos: DeviceStatus, AnalogMeasurement]
                                   |
                                   v
                        [MeasurementRepository] (persiste historial si activado)
                                   |
                                   v
                        [DeviceProvider]  (polling cada N ms, guard antidelไม่มี)
                                   |
                        +----------+-----------+
                        |                      |
                        v                      v
              [MeasurementProvider]    [Dashboard / Graficos / Historial]
              (series en memoria)         (UI, formateadores)
```

- Cada tick del polling consulta `/api/analog`; `/api/status` se consulta cada
  5 segundos.
- El proveedor **no lanza dos consultas simultaneas** de un mismo tipo.
- Ante fallos se conserva el **ultimo valor valido** y la interfaz muestra
  estado "Desconectado" y el motivo.
- `MeasurementProvider` acumula una serie por canal (buffer en memoria, maximo
  600 muestras por canal) y expone el historial persistido.

## Modos de Conexion

| Modo | Implementacion | Uso |
|------|----------------|-----|
| Simulacion (default) | `MockApiService` | Sin Pico: genera ondas senoidales + ruido por canal |
| Real | `HttpApiService` | Consulta la API HTTP de la Pico por WiFi |

El modo se selecciona desde Configuracion (`useMock`).

## Decisiones de Diseno

- **HTTP REST en vez de TCP crudo / MQTT / BLE / Firebase**: requisito del
  proyecto: comunicacion local, sin Internet, sin bluetooth. HTTP es simple de
  implementar en el firmware con lwip y facil de depurar (`curl`,
  `nc`).
- **Polling periodico en vez de sockets web**: requisito del proyecto; el
  intervalo es configurable.
- **Inyeccion de dependencias (constructor)**: `ApiService` es una interfaz;
  `MeasurementRepository` decide cual implementacion instanciar segun la
  configuracion. Esto permite tests sin red.
- **Snapshot inmutable `AppSettings`**: la configuracion es un objeto inmutable
  que el `SettingsProvider` sustituye completo al cambiar; se persiste con
  `SharedPreferences`.

## Persistencia

| Dato | Almacenamiento | Clave |
|------|----------------|-------|
| Configuracion de la app | `SharedPreferences` | `settings_*` (ver `07-configuracion.md`) |
| Historial de mediciones | `SharedPreferences` | `measurement_history` (lista de JSON en texto plano) |

El historial guarda muestras individuales por canal con `timestamp` (epoch
segundos), `channel`, `gpio`, `raw` y `voltage`. Maximo 5000 registros.